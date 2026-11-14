extends Node
## Mission Campaign: 5 levels, 20 stages and special missions.
## Runs each stage through briefing, spacecraft design, launch, cruise, arrival, operations and assessment.
## Rules live in mission.gd (damage engine) and challenges.gd (events). This file is the game flow.

const CD = preload("res://scripts/campaign_data.gd")
const M = preload("res://scripts/mission.gd")
const CH = preload("res://scripts/challenges.gd")
const WorldScript = preload("res://scripts/world.gd")
const SAVE_PATH := "user://campaign.cfg"

const TASK_VIS := {"sample": "drill", "imaging": "photo", "atmosphere": "mast", "composition": "sample", "thermal": "scan",
	"subsurface": "drill", "plume": "lab", "radiation": "scan", "fields": "scan"}
const TONE_COL := {"ok": "#7be3a5", "warn": "#f0c24b", "bad": "#ff9c90", "": "#e8eefc"}

var g                      # main.gd node
var m: Dictionary = {}     # current mission
var active := false
var visuals := true
var prog: Dictionary = {}
var _orbit_t := 0.0
var _on_surface := false
var _bot_lab := false
var _bot_lab2 := false
var _cine_seen := {}       # level introductions already shown in this session


func setup(main) -> void:
	g = main
	prog = _load()
	if g.camp_unlock:
		prog.unlock_all = true


# ------------------------------------------------------------------ progress (saved on this computer)

func _load() -> Dictionary:
	var p := {"diff": "beginner", "passed": {}, "specials": {}, "best": {}, "points": 0, "design1": {}, "unlock_all": false}
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in ["diff", "passed", "specials", "best", "points", "design1"]:
			p[k] = cf.get_value("campaign", k, p[k])
	return p


func _save() -> void:
	if g != null and g.bot != "":
		return     # automated test runs never touch the player's progress
	var cf := ConfigFile.new()
	for k in ["diff", "passed", "specials", "best", "points", "design1"]:
		cf.set_value("campaign", k, prog[k])
	cf.save(SAVE_PATH)


func level_done(n: int) -> bool:
	for s in CD.STAGES:
		if int(s.level) == n and not prog.passed.has(int(s.n)):
			return false
	return true


func stage_unlocked(n: int) -> bool:
	if prog.unlock_all or n == 1:
		return true
	var st := M.stage_by_n(n)
	if int(st.level) > 1 and not level_done(int(st.level) - 1):
		return false
	var prev := M.stage_by_n(n - 1)
	return int(prev.level) != int(st.level) or prog.passed.has(n - 1)


func rewards() -> Dictionary:
	var r := {}
	for n in range(1, 6):
		if level_done(n):
			r[CD.REWARDS[str(n)].key] = true
	return r


func _record(key, res: Dictionary, special: bool) -> void:
	var store: Dictionary = prog.specials if special else prog.passed
	if res.pass:
		store[key] = maxi(int(store.get(key, 0)), maxi(1, int(res.stars)))
	var bk := ("s" if special else "") + str(key)
	if int(res.total) > int(prog.best.get(bk, 0)):
		prog.points += int(res.total) - int(prog.best.get(bk, 0))
		prog.best[bk] = int(res.total)
	_save()


static func _stars(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(maxi(0, 3 - n))


# ------------------------------------------------------------------ frame update

func _process(dt: float) -> void:
	if not active or g == null:
		return
	_ship_fx()
	if m.is_empty():
		return
	if g.surface.visible:
		g.surface.storm = m.env.storm if m.mode == "surface" else 0.0
		g.surface.set_rover(float(m.c.get("rover", 100.0)), float(m.env.dustCover))
		return
	# slow parking orbit around the destination while in orbit
	if m.mode in ["orbit", "probe", "flyby"] and g.ship.visible and g.cam_mode == "free" and g.orbit_on:
		_orbit_t += dt * 0.25
		var v: Dictionary = g.world.view_by(m.dest.body)
		var r: float = (v.park as Vector3).distance_to(v.body)
		var p: Vector3 = v.body + Vector3(cos(_orbit_t) * r, sin(_orbit_t * 0.5) * r * 0.15, sin(_orbit_t) * r)
		g.place_ship(p, Vector3(-sin(_orbit_t), 0, cos(_orbit_t)))


## Maps mission component condition onto the 3D ship, so damage is visible on the model.
func ship_look() -> Dictionary:
	if m.is_empty():
		return {"hull": 100, "arrays": 100, "thrusters": 100, "sensors": 100, "comms": 100, "life": 100, "shield": 100}
	var c: Dictionary = m.c
	var arrays: float = c.get("solar", c.get("power", 100.0))
	return {"hull": c.get("structure", 100.0), "arrays": arrays, "thrusters": c.get("nav", 100.0), "sensors": c.get("instruments", 100.0),
		"comms": c.get("comms", 100.0), "life": 100.0, "shield": c.get("thermal", 100.0)}


## Progressive damage on the 3D model: impact marks from structural damage, dust on the panels,
## status lights for instruments / comms / power / navigation / thermal, and the lander foot lights.
func _ship_fx() -> void:
	if m.is_empty():
		g.ship.set_fx(0, [])
		return
	var c: Dictionary = m.c
	var inst: float = c.get("instruments", -1.0)
	if inst >= 0.0 and m.offline.inst and not m.backup.inst:
		inst = minf(inst, 10.0)       # offline: shown as a blinking red light
	var on_ground: bool = g.surface.visible and m.mode == "surface"
	g.ship.set_fx(int((100.0 - float(c.get("structure", 100.0))) / 5.5),
		[inst, c.get("comms", -1.0), c.get("power", -1.0), c.get("nav", -1.0), c.get("thermal", -1.0)],
		float(m.env.dustCover) if on_ground and c.has("solar") else 0.0,
		Color(g.surface.theme.dust) if on_ground else Color("c48a62"),
		float(c.get("landing", -1.0)) if g.surface.visible else -1.0)


func refresh() -> void:
	if m.is_empty():
		return
	var cap := M.battery_cap(m)
	var rows := [["Battery", m.battery / cap, str(roundi(m.battery))], ["Fuel", m.fuel / 100.0, str(roundi(m.fuel))],
		["Budget", maxf(0.0, m.budget) / maxf(1.0, float(m.budget0)), "$%d" % roundi(m.budget), true]]
	var lines: Array = []
	if m.mode == "cruise":
		lines.append("%s · interplanetary cruise · day %d" % [m.dest.name, roundi(m.days)])
	else:
		lines.append("%s · %s · %s %d/%d" % [m.dest.name, mode_name(), m.dest.cycleName, m.cycle, m.max_cycles])
	lines.append("Data sent %s · waiting %s · spares %d" % [str(m.sent), str(M.queued(m)), m.spares])
	if m.crewed:
		lines.append("Crew safety %d%% · rest %d%%" % [roundi(m.crew), roundi(m.crew_rest)])
	if m.mode == "surface" and m.c.has("solar"):
		lines.append("Dust on panels: %d%%" % roundi(m.env.dustCover * 100.0))
	if not m.probe.is_empty():
		lines.append("Probe: %s" % ("%d%% integrity" % maxi(0, roundi(m.probe.integrity)) if m.probe.alive else "lost"))
	var comps: Array = []
	for c in CD.COMPONENTS:
		if not m.c.has(c.id):
			continue
		var cl := M.classify(m.c[c.id])
		var flag := ""
		if c.id == "instruments" and (m.offline.inst or (m.c[c.id] < 20.0 and not m.backup.inst)):
			flag = " OFFLINE"
		comps.append([c.short, m.c[c.id], cl[1] + flag, cl[2]])
	g.ui.update_campaign(rows, lines, comps)


func mode_name() -> String:
	return {"cruise": "cruise", "orbit": "orbit (retreated)" if m.retreated else "orbit", "flyby": "flyby", "surface": "surface", "probe": "probe descent"}.get(m.mode, m.mode)


func _sleep(sec: float) -> void:
	if g.bot != "":
		return
	await get_tree().create_timer(sec / maxf(0.1, g.speed)).timeout


func _col(tone: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [TONE_COL.get(tone, "#e8eefc"), text]


# ------------------------------------------------------------------ top level

## Returns "classic" when the player picks the Grand Tour, or "done" after a bot run.
func run() -> String:
	active = true
	visuals = g.bot == "" or g.campvis
	if g.bot != "" and g.camp_arg != "":
		prog.diff = g.camp_diff
		prog.unlock_all = true
		var st: Dictionary = M.special_by_id(g.camp_arg) if g.camp_arg.begins_with("sm") else M.stage_by_n(int(g.camp_arg))
		var res: Dictionary = await run_stage(st, g.camp_arg.begins_with("sm"))
		print("CAMPAIGN_RESULT ", JSON.stringify(res))
		active = false
		return "done"
	if prog.unlock_all or level_done(1):
		g.apply_saved_ship(prog.unlock_all or level_done(3))
	while true:
		m = {}
		_idle_view()
		var pick: String = await _level_select()
		if pick == "classic":
			active = false
			return "classic"
		var special := pick.begins_with("sm")
		var stage: Dictionary = M.special_by_id(pick) if special else M.stage_by_n(int(pick))
		while true:
			var r: Dictionary = await run_stage(stage, special)
			if r.get("choice", "") != "retry":
				break
	return "classic"


func _idle_view() -> void:
	_leave_surface_now()
	g.world.set_world_visible(true)
	g.ship.visible = false
	g.cam_mode = "free"
	g.orbit_on = false
	g.cam.position = Vector3(260, 330, 420)
	g.cam_target = Vector3.ZERO
	g.cam.look_at(Vector3.ZERO, Vector3.UP)
	g._sync_orbit()
	g.orbit_on = true
	var blank := M.new_mission(M.stage_by_n(1), "beginner", M.recommended_design(M.design_dest(M.stage_by_n(1))))
	var keep := m
	m = blank
	refresh()
	m = keep


func _level_select() -> String:
	while true:
		var opts: Array = []
		opts.append({"header": true, "label": "DIFFICULTY (planetary science is the same on every setting)"})
		for d in ["beginner", "intermediate", "advanced"]:
			opts.append({"id": "diff:" + d, "label": CD.DIFFICULTY[d].name, "sub": CD.DIFFICULTY[d].desc, "on": prog.diff == d})
		for lv in CD.LEVELS:
			var n: int = int(lv.n)
			opts.append({"header": true, "label": "LEVEL %02d — %s   ·   %s   ·   %s%s" % [n, lv.name, lv.difficulty, lv.theme,
				"   ·   reward unlocked: " + CD.REWARDS[str(n)].label if level_done(n) else ""]})
			for s in CD.STAGES:
				if int(s.level) != n:
					continue
				var sn: int = int(s.n)
				var un := stage_unlocked(sn)
				var done: int = int(prog.passed.get(sn, 0))
				opts.append({"id": str(sn), "label": "Stage %02d · %s   %s" % [sn, s.name, _stars(done) if done > 0 else ""],
					"sub": s.brief if un else "Locked: complete the earlier stages first.", "disabled": not un, "on": done > 0})
		opts.append({"header": true, "label": "SPECIAL MISSIONS (optional)"})
		for s in CD.SPECIALS:
			var un2: bool = prog.unlock_all or int(s.unlockLevel) <= 1 or level_done(int(s.unlockLevel) - 1)
			var done2: int = int(prog.specials.get(s.id, 0))
			opts.append({"id": s.id, "label": "%s   %s" % [s.name, _stars(done2) if done2 > 0 else ""],
				"sub": s.brief if un2 else "Unlocks after Level %02d." % (int(s.unlockLevel) - 1), "disabled": not un2, "on": done2 > 0})
		opts.append({"header": true, "label": "OTHER"})
		opts.append({"id": "look", "label": "Spacecraft appearance", "disabled": not (prog.unlock_all or level_done(1)),
			"sub": ("Choose the spacecraft model%s." % (", or design your own" if prog.unlock_all or level_done(3) else " (custom builder unlocks after Level 03)")) if prog.unlock_all or level_done(1) else "Reward: unlocks after Level 01."})
		opts.append({"id": "classic", "label": "Grand Tour (classic game)", "sub": "The original flight from Earth to the edge of the Solar System."})
		opts.append({"id": "reset", "label": "Reset campaign progress", "sub": ""})
		var master: String = "   ·   [color=#ffd166]COSMOS MASTER MISSION STATUS[/color]" if prog.passed.has(20) else ""
		var pick: String = await g.ui.big_choose("levels", "Mission Campaign", "Mission points: [b]%d[/b]%s\nEngineer a spacecraft that survives the real conditions at each destination. Complete every primary objective to pass a stage." % [prog.points, master], opts)
		if pick.begins_with("diff:"):
			prog.diff = pick.substr(5)
			_save()
		elif pick == "look":
			await g.choose_look(prog.unlock_all or level_done(3), prog.unlock_all or level_done(5))
			_idle_view()
		elif pick == "reset":
			var sure: String = await g.ui.choose("confirm", "Reset campaign progress?", "All stars, unlocks and points will be removed.", [{"id": "no", "label": "No, keep my progress"}, {"id": "yes", "label": "Yes, reset"}])
			if sure == "yes":
				var d: String = prog.diff
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
				prog = _load()
				prog.diff = d
		else:
			return pick
	return "classic"


# ------------------------------------------------------------------ one stage

func run_stage(stage: Dictionary, special: bool) -> Dictionary:
	var diff: Dictionary = CD.DIFFICULTY.get(prog.diff, CD.DIFFICULTY.intermediate)
	var dd := M.design_dest(stage)
	var budget := roundi(float(stage.budget) * float(diff.budgetMul))
	var phases: Array = stage.phases
	g.ui.cue("Mission briefing")
	_leave_surface_now()
	g.world.set_world_visible(true)
	g.ship.visible = false
	await _cinematic(stage, dd, special)
	await _briefing(stage, dd, diff, special)

	var design: Dictionary
	if phases.has("design"):
		var start := M.default_design(dd)
		design = await _design_screen(dd, budget, start, diff, "Spacecraft design: %s" % dd.name,
			"Choose equipment and instruments within the budget. Equipment only protects against the conditions it was built for.")
	elif stage.get("useDesign", false) and not prog.design1.is_empty():
		design = prog.design1.duplicate(true)
	else:
		design = M.recommended_design(dd)

	m = M.new_mission(stage, diff.id, design, rewards())
	if stage.get("degraded", false):
		for k in [["solar", 45.0], ["comms", 40.0], ["instruments", 50.0], ["rover", 35.0], ["power", 30.0], ["nav", 25.0]]:
			M.damage(m, k[0], k[1] * randf_range(0.8, 1.2), "Arrived degraded", "Systems were already below expected performance on arrival.")
		m.spares += 2
		m.spares_start = m.spares
	refresh()

	var forced: Dictionary = stage.get("forced", {})
	var design_events: Array = forced.get("design", []).duplicate()
	if stage.get("special", "") == "gauntlet":
		design_events.append("budgetTrap")
	for id in design_events:
		await _event(CH.by_id(id))
		if m.redesign:
			var nb: int = int(m.budget0)
			var nd: Dictionary = await _design_screen(dd, nb, m.design, diff, "Redesign: the budget has been cut", "New budget: $%dM. Remove non-essential items and keep what the primary objectives need." % nb)
			_rebuild(nd, nb)

	if phases.has("plan"):
		return await _planning_stage(stage, dd, budget)
	if int(stage.get("level", 0)) == 1 and phases.has("design"):
		prog.design1 = m.design.duplicate(true)
		_save()

	if phases.has("launch"):
		await _launch(stage, dd, diff)
	if m.failed == "" and int(stage.get("n", 0)) == 2:
		for o in m.objectives:
			o.status = "done"
			o.returned = o.units
		return await _finish(stage, special)

	if m.failed == "":
		for i in m.segments.size():
			M.enter_segment(m, i)
			refresh()
			if phases.has("cruise") or i > 0:
				await _cruise(stage, i)
			if _dead():
				break
			await _arrive(stage, i)
			if _dead():
				break
			await _ops(stage, i)
			var fr := M.final_relay(m)
			if fr.sent > 0.0:
				g.ui.toast("The orbiter relayed %s more units of stored data to Earth." % str(fr.sent), "good")
			if fr.lost > 0.0:
				g.ui.toast("%s units of data could not be sent and were lost." % str(fr.lost), "bad")
			await _leave_surface(m.failed == "")
			refresh()
			if m.failed != "":
				break
	return await _finish(stage, special)


func _dead() -> bool:
	refresh()
	M.check_fail(m)
	if m.failed != "":
		g.audio.thud()
		return true
	return false


func _rebuild(design: Dictionary, budget: int) -> void:
	var keep := [m.decisions, m.challenges, m.used, m.days]
	m = M.new_mission(m.stage, m.diff.id, design, rewards())
	m.decisions = keep[0]
	m.challenges = keep[1]
	m.used = keep[2]
	m.days = keep[3]
	m.budget0 = budget
	m.budget = float(budget - int(m.totals.cost))
	refresh()


func _finish(stage: Dictionary, special: bool) -> Dictionary:
	var res := M.assess(m)
	var key = stage.id if special else int(stage.n)
	var was_done: bool = true if special else level_done(int(stage.level))
	_record(key, res, special)
	var unlock := ""
	if res.pass and not special:
		var lv: int = int(stage.level)
		if not was_done and level_done(lv):
			unlock = "LEVEL %02d COMPLETE. Unlocked: %s. Reward: %s." % [lv, CD.LEVELS[lv - 1].unlock, CD.REWARDS[str(lv)].label]
		elif int(stage.n) < 20:
			unlock = "Stage %02d unlocked." % (int(stage.n) + 1)
	elif not special:
		unlock = "Complete every primary objective (or an adapted version of it) to pass this stage."
	g.ui.mini_text("")
	var choice: String = await _assessment(res, unlock)
	var out := {"choice": choice, "outcome": res.outcome, "pass": res.pass, "total": res.total, "stars": res.stars, "failed": m.failed,
		"c": m.c.duplicate(), "sent": m.sent, "challenges": m.challenges.size(), "brownouts": m.brownouts, "objectives": []}
	for o in m.objectives:
		out.objectives.append("%s:%s:%s/%s" % [o.id, o.status, str(o.returned), str(o.units)])
	return out


# ------------------------------------------------------------------ cinematic introduction

func _cine_shot(p0: Vector3, t0: Vector3, p1: Vector3, t1: Vector3, dur: float) -> void:
	g.cam_mode = "free"
	g.orbit_on = false
	var d: float = dur / maxf(0.1, g.speed)
	var t := 0.0
	while t < d and not g.ui.cine_skip:
		var u := t / d
		var e := u * u * (3.0 - 2.0 * u)
		g.cam.position = p0.lerp(p1, e)
		g.cam_target = t0.lerp(t1, e)
		g.cam.look_at(g.cam_target, Vector3.UP)
		await get_tree().process_frame
		t += get_process_delta_time()


## Letterboxed camera sequence before the briefing. A level introduction plays the first time a level
## is opened in a session (and always on its first stage); every stage gets the approach to its destination.
func _cinematic(stage: Dictionary, dd: Dictionary, special: bool) -> void:
	var v: Dictionary = g.world.view_by(dd.body)
	if g.bot != "" and not g.campvis:
		return
	var body: Vector3 = v.body
	var off: Vector3 = v.pos - body
	g.ui.cinema_begin()
	var key: String = "special" if special else "L%d" % int(stage.level)
	var first_of_level: bool = not special and (int(stage.n) - 1) % 4 == 0
	if first_of_level or not _cine_seen.has(key):
		_cine_seen[key] = true
		if special:
			g.ui.cinema_caption("SPECIAL MISSION", "Optional scenarios that test one skill to the limit.")
		else:
			var lv: Dictionary = CD.LEVELS[int(stage.level) - 1]
			g.ui.cinema_caption("LEVEL %02d — %s" % [int(lv.n), lv.name], "%s\n%s" % [lv.theme, lv.intro])
		g.audio.ok()
		await _cine_shot(Vector3(-160, 640, 780), Vector3.ZERO, Vector3(250, 300, 440), Vector3.ZERO, 8.0)
	if not g.ui.cine_skip:
		var notes: Array = dd.science.get("notes", [])
		var head: String = stage.name if special else "STAGE %02d — %s" % [int(stage.n), stage.name]
		g.ui.cinema_caption(head, "%s%s" % [dd.name + (": " + str(dd.title).capitalize() if dd.get("title", "") != "" else ""), "\n" + str(notes[0]) if notes.size() > 0 else ""])
		var far: Vector3 = body + off * 4.5 + Vector3(0, off.length() * 2.0, 0)
		await _cine_shot(far, body, body + off * 1.7 + Vector3(0, off.length() * 0.3, 0), body, 6.5)
	if not g.ui.cine_skip:
		g.ui.cinema_caption(str(dd.name).to_upper(), stage.brief)
		var side := Vector3(-off.z, 0.0, off.x) * 0.9
		await _cine_shot(body + off * 1.7 + Vector3(0, off.length() * 0.3, 0), body, v.pos + side, v.target, 5.5)
	g.ui.cinema_end()
	g.cam.position = v.pos
	g.cam_target = v.target
	g.cam.look_at(g.cam_target, Vector3.UP)
	g._sync_orbit()
	g.orbit_on = true


# ------------------------------------------------------------------ screens

func _briefing(stage: Dictionary, dd: Dictionary, diff: Dictionary, special: bool) -> void:
	var sci: Dictionary = dd.science
	var type_text := "Orbiter only (remote sensing)."
	if dd.type == "probe":
		type_text = "Orbiter + atmospheric probe. A gas or ice giant has no solid surface, so nothing can land."
	elif dd.type == "surface":
		type_text = "Orbiter + lander."
	var bb := ""
	if special:
		bb += "[color=#f0c24b]SPECIAL MISSION[/color]\n"
	else:
		var lv: Dictionary = CD.LEVELS[int(stage.level) - 1]
		bb += "[color=#6aa8ff]LEVEL %02d — %s · STAGE %02d[/color]\n[i]%s[/i]\n" % [int(lv.n), lv.name, int(stage.n), lv.intro]
	bb += "[color=#f0c24b]%s — %s[/color]\n%s\n" % [dd.name.to_upper(), dd.title, stage.brief]
	if stage.has("segments") and stage.segments.size() > 1:
		var parts: Array = []
		for sg in stage.segments:
			parts.append("%s (%s)" % [str(sg.dest).capitalize(), sg.mode])
		bb += "[b]Route:[/b] %s\n" % " → ".join(PackedStringArray(parts))
	bb += "[b]Mission type:[/b] %s\n\n[color=#6aa8ff][b]OBJECTIVES[/b][/color]\n" % type_text
	for o in dd.objectives:
		bb += "%s %s\n" % ["★ Primary:" if o.primary else "   Secondary:", o.name]
	bb += "\n[color=#6aa8ff][b]CHALLENGE TYPES[/b][/color]\n%s\n" % " · ".join(PackedStringArray(stage.types))
	bb += "\n[color=#6aa8ff][b]ESTABLISHED SCIENCE[/b][/color]\nGravity: %s\nTemperature: %s\nPressure: %s\nAtmosphere: %s\nSunlight: %s\nSignal delay: %s\n" % [
		sci.gravity, sci.temperature, sci.pressure, sci.atmosphere, sci.sunlight, sci.lightTime]
	for n in sci.notes:
		bb += "• %s\n" % n
	bb += "\n[color=#6aa8ff][b]GAME SIMULATION: HAZARD PROFILE[/b][/color]\n[color=#a9b9dd]Severity is a game value based on the real conditions, not a measurement.[/color]\n"
	for f in CD.FACTORS:
		var e = dd.env.get(f.id)
		if e == null:
			if dd.get("na", {}).has(f.id):
				bb += "[color=#8793b0]%s: not applicable. %s[/color]\n" % [f.name, dd.na[f.id]]
			continue
		var sv: float = e.sev
		bb += "%s: %s  %s\n" % [f.name, e.shown, _col("bad" if sv > 0.7 else ("warn" if sv > 0.4 else "ok"), "▮".repeat(clampi(roundi(sv * 10.0), 0, 10)) + "▯".repeat(10 - clampi(roundi(sv * 10.0), 0, 10)))]
	bb += "\n[color=#a9b9dd]Difficulty: %s. %s[/color]" % [diff.name, diff.desc]
	await g.ui.big_choose("briefing", stage.name, bb, [{"id": "go", "label": "Begin mission   [Enter]", "main": true}])


## Reward items stay locked until their level is complete.
func _locked(o: Dictionary) -> bool:
	return o.has("unlock") and not prog.unlock_all and not level_done(int(o.unlock))


func _opt_text(o: Dictionary) -> String:
	return "%d kg · $%dM%s" % [int(o.mass), int(o.cost), " · " + o.desc if o.get("desc", "") != "" else ""]


func _design_screen(dd: Dictionary, budget: int, start: Dictionary, diff: Dictionary, title: String, note: String) -> Dictionary:
	var d: Dictionary = start.duplicate(true)
	var rec := M.recommended_design(dd)
	if g.bot != "":
		return rec
	while true:
		var t := M.design_totals(dd, d)
		var fit := M.design_fit(dd, t.stats)
		var covered := 0
		var missing: Array = []
		for o in dd.objectives:
			if t.tags.has(o.tag):
				covered += 1
			elif o.primary:
				missing.append(o.name)
		var over: bool = t.cost > budget
		var heavy: bool = t.mass > t.cap
		var bb := "%s\n\n%s    %s    Environment fit: [b]%d%%[/b]    Objectives possible: [b]%d/%d[/b]\n" % [note,
			_col("bad" if over else "ok", "Cost: [b]$%dM[/b] of $%dM" % [t.cost, budget]),
			_col("bad" if heavy else "ok", "Mass: [b]%d kg[/b] of %d kg launch capacity" % [t.mass, t.cap]), fit.score, covered, dd.objectives.size()]
		for l in fit.lines:
			bb += _col(l.tone, "⚠ " + l.text) + "\n"
		if missing.size() > 0:
			bb += _col("bad", "Missing equipment for primary objective: %s." % ", ".join(PackedStringArray(missing))) + "\n"
		if heavy:
			bb += _col("warn", "The payload is heavier than the launcher can deliver. This will be a problem at launch.") + "\n"
		var opts: Array = []
		opts.append({"header": true, "label": "EQUIPMENT (click a row to change it)"})
		for grp in CD.EQUIPMENT:
			if not M.group_applies(grp, dd):
				continue
			var cur := ""
			if grp.get("multi", false):
				var names: Array = []
				for o in grp.options:
					if d[grp.id].has(o.id):
						names.append(o.name)
				cur = ", ".join(PackedStringArray(names)) if names.size() > 0 else "none"
			else:
				cur = M._by_id(grp.options, d[grp.id]).get("name", "—")
			opts.append({"id": "g:" + grp.id, "label": "%s:  %s" % [grp.name, cur], "sub": ""})
		var inames: Array = []
		for i in CD.INSTRUMENTS:
			if d.instruments.has(i.id):
				inames.append(i.name)
		opts.append({"id": "inst", "label": "Scientific instruments:  %s" % (", ".join(PackedStringArray(inames)) if inames.size() > 0 else "none chosen"), "sub": ""})
		opts.append({"id": "launcher", "label": "Launch vehicle:  %s" % M._by_id(CD.LAUNCHERS, d.launcher).name, "sub": ""})
		opts.append({"id": "traj", "label": "Trajectory:  %s" % M._by_id(CD.TRAJECTORIES, d.trajectory).name, "sub": ""})
		if diff.id != "advanced":
			opts.append({"id": "rec", "label": "Use the recommended configuration", "sub": "A sound design for this destination. You can still change it."})
		opts.append({"id": "ok", "label": "Over budget: remove something" if over else "Confirm design   [Enter]", "main": true, "disabled": over})
		var pick: String = await g.ui.big_choose("design", title, bb, opts)
		if pick == "ok":
			return d
		if pick == "rec":
			d = rec.duplicate(true)
		elif pick.begins_with("g:"):
			var grp2 := M._group(pick.substr(2))
			var multi: bool = grp2.get("multi", false)
			while true:
				var sub: Array = []
				for o in grp2.options:
					if not M.option_allowed(o, dd):
						continue
					if _locked(o):
						if d[grp2.id] is String and d[grp2.id] == o.id:
							d[grp2.id] = rec[grp2.id]
						sub.append({"id": o.id, "label": o.name, "sub": "Locked reward: complete Level %02d to unlock." % int(o.unlock), "disabled": true})
						continue
					var on: bool = d[grp2.id].has(o.id) if multi else d[grp2.id] == o.id
					var is_rec: bool = rec[grp2.id].has(o.id) if multi else rec[grp2.id] == o.id
					sub.append({"id": o.id, "label": o.name + ("   (recommended)" if diff.guidance and is_rec else ""), "sub": _opt_text(o), "on": on})
				sub.append({"id": "__back", "label": "Done", "main": true})
				var sp: String = await g.ui.big_choose("design_sub", grp2.name, "Tick any that you want." if multi else "Choose one.", sub)
				if sp == "__back":
					break
				if multi:
					if d[grp2.id].has(sp):
						d[grp2.id].erase(sp)
					else:
						d[grp2.id].append(sp)
				else:
					d[grp2.id] = sp
					break
		elif pick == "inst":
			while true:
				var sub2: Array = []
				for i in CD.INSTRUMENTS:
					if i.get("surfaceOnly", false) and dd.type != "surface":
						continue
					if _locked(i):
						d.instruments.erase(i.id)
						sub2.append({"id": i.id, "label": i.name, "sub": "Locked reward: complete Level %02d to unlock." % int(i.unlock), "disabled": true})
						continue
					var need: Array = []
					for o in dd.objectives:
						if o.tag == i.tag:
							need.append(("★ " if o.primary else "") + o.name)
					sub2.append({"id": i.id, "label": i.name, "sub": "%d kg · $%dM%s" % [int(i.mass), int(i.cost), " · needed for: " + ", ".join(PackedStringArray(need)) if need.size() > 0 else " · no objective here needs it"], "on": d.instruments.has(i.id)})
				sub2.append({"id": "__back", "label": "Done", "main": true})
				var ip: String = await g.ui.big_choose("design_sub", "Scientific instruments", "Each objective needs its matching instrument. Extra instruments cost money and mass.", sub2)
				if ip == "__back":
					break
				if d.instruments.has(ip):
					d.instruments.erase(ip)
				else:
					d.instruments.append(ip)
		elif pick == "launcher":
			var sub3: Array = []
			for l in CD.LAUNCHERS:
				sub3.append({"id": l.id, "label": l.name, "sub": "$%dM · delivers %d kg to %s on this trajectory" % [int(l.cost), M.capacity(dd, l.id, d.trajectory), dd.name], "on": d.launcher == l.id})
			d.launcher = await g.ui.big_choose("design_sub", "Launch vehicle", "Farther destinations need more launch energy, so each rocket delivers less mass.", sub3)
		elif pick == "traj":
			var sub4: Array = []
			for tr in CD.TRAJECTORIES:
				sub4.append({"id": tr.id, "label": tr.name, "sub": tr.desc, "on": d.trajectory == tr.id})
			d.trajectory = await g.ui.big_choose("design_sub", "Trajectory", "", sub4)
	return d


func _lab() -> void:
	var sel := ""
	while true:
		var bb := "[color=#6aa8ff]DESTINATION: %s · %s[/color]\n\n[color=#6aa8ff][b]ENVIRONMENTAL CONDITIONS[/b][/color]\n" % [m.dest.name.to_upper(), mode_name()]
		for r in M.readouts(m):
			bb += "%s:  %s%s\n" % [r[0], _col(r[3], "[b]%s[/b]" % r[1]), "   [color=#8793b0]%s[/color]" % r[2] if r[2] != "" else ""]
		bb += "\n[color=#6aa8ff][b]POWER BALANCE[/b][/color]\nGeneration [b]%.1f[/b] · load [b]%.1f[/b] per cycle · battery [b]%d/%d[/b] · mode [b]%s[/b]%s\n" % [M.generation(m), M.power_load(m),
			roundi(m.battery), roundi(M.battery_cap(m)), "%s · priority: %s" % [m.power_mode, str(M.PRIORITIES[m.power_priority][0]).to_lower()], " · RTG" if m.stats.gen == "rtg" else (" · batteries only" if m.stats.gen == "none" else "")]
		bb += "\n[color=#6aa8ff][b]ACTIVE WARNINGS[/b][/color]\n"
		var ws := M.warnings(m)
		if ws.is_empty():
			bb += "[color=#8793b0]No active warnings for this environment.[/color]\n"
		for w in ws:
			bb += _col(w[0], "⚠ " + w[1]) + "\n"
		if sel != "":
			var cdef := M._by_id(CD.COMPONENTS, sel)
			bb += "\n[color=#6aa8ff][b]%s: %d%% (%s)[/b][/color]\n%s\n" % [cdef.name.to_upper(), roundi(m.c[sel]), M.classify(m.c[sel])[1], cdef.effect]
			var threats := ""
			for hid in m.dest.hazards:
				var h: Dictionary = CD.HAZARDS[hid]
				var dusty: bool = h.get("special", "") == "dust" and sel in ["solar", "instruments"]
				if h.comps.has(sel) or dusty:
					var f = m.dest.env.get(h.factor)
					threats += "• %s: environment %s · your rating %d%%\n" % [h.name, f.shown if f != null else "—", roundi((float(m.stats.dustMit) if dusty else M.rating(m, hid)) * 100.0)]
			bb += "[b]Hazards here that affect it:[/b]\n%s" % (threats if threats != "" else "None of this world's hazards targets it directly.\n")
			bb += "[b]Recent causes of change:[/b]\n"
			var shown := 0
			for i in range(m.log.size() - 1, -1, -1):
				var e: Dictionary = m.log[i]
				if e.comp == sel and shown < 6:
					shown += 1
					bb += "• %s, cycle %d, −%s%%: %s%s\n" % [e.where, e.cycle, str(e.amount), e.source, "\n   [color=#8793b0]%s[/color]" % e.why if e.why != "" else ""]
			if shown == 0:
				bb += "[color=#8793b0]No damage recorded.[/color]\n"
		bb += "\n[color=#8793b0]Environmental values come from established planetary science. Damage rates, severities, events and their timing are simplified game simulation.[/color]"
		var opts: Array = [{"header": true, "label": "SPACECRAFT CONDITION (click a system to see why it is changing)"}]
		for c in CD.COMPONENTS:
			if m.c.has(c.id):
				opts.append({"id": c.id, "label": "%s:  %d%%  %s" % [c.name, roundi(m.c[c.id]), M.classify(m.c[c.id])[1]], "sub": "", "on": sel == c.id})
		opts.append({"id": "__close", "label": "Close   [Enter]", "main": true})
		var pick: String = await g.ui.big_choose("lab", "Mission Lab · Environmental Monitoring", bb, opts)
		if pick == "__close":
			return
		sel = pick


func _assessment(res: Dictionary, unlock: String) -> String:
	var head: Array = {"success": ["Mission successful", "All critical requirements were achieved.", "ok"],
		"partial": ["Partial success", "Some objectives were achieved, but not every critical requirement.", "warn"],
		"unsuccessful": ["Mission unsuccessful", "Critical mission requirements could not be achieved.", "bad"]}[res.outcome]
	var bb := "%s  [color=#ffd166]%s[/color]\n%s%s\n\n" % [_col(head[2], "[b]%s[/b]" % head[0].to_upper()), _stars(res.stars), head[1], " [b]%s[/b]" % m.failed if m.failed != "" else ""]
	bb += "Points [b]%d[/b] · objectives done [b]%d[/b] · data sent [b]%s[/b] · average condition [b]%d%%[/b]\n" % [res.total, res.done, str(m.sent), res.avg]
	bb += "\n[color=#6aa8ff][b]SCIENTIFIC OBJECTIVES[/b][/color]\n"
	for o in m.objectives:
		var mark: String = "✓" if o.status == "done" else ("↺" if o.status == "dropped" else "✗")
		bb += _col("ok" if o.status == "done" else ("" if o.status == "dropped" else "bad"), "%s %s%s  (%s/%s returned%s)" % [mark, "★ " if o.primary else "", o.name, str(o.returned), str(o.units), ", replaced" if o.status == "dropped" else ""]) + "\n"
	bb += "\n[color=#6aa8ff][b]CHALLENGES ENCOUNTERED AND DECISIONS MADE[/b][/color]\n"
	if m.challenges.is_empty():
		bb += "[color=#8793b0]No challenges encountered.[/color]\n"
	for c in m.challenges:
		bb += "• [b]%s[/b] → %s  %s%s\n" % [c.title, c.choice, _col({"good": "ok", "fair": "warn", "poor": "bad"}.get(c.quality, ""), "[%s]" % c.quality),
			"\n   [color=#8793b0]%s[/color]" % c.effects if c.get("effects", "") != "" else ""]
	bb += "\n[color=#6aa8ff][b]SYSTEMS AFFECTED[/b][/color]\n"
	if res.affected.is_empty():
		bb += "No systems lost condition.\n"
	for a in res.affected:
		bb += "• %s: %d%% → [b]%d%%[/b] (%s)\n" % [M.comp_name(a.id, false), a.start, a.end, a.cls]
	bb += "\n[color=#6aa8ff][b]RESOURCES CONSUMED[/b][/color]\n• Budget: $%dM spent, $%dM left\n• Fuel: %d used, %d left\n• Repair kits: %d of %d used\n• Energy used: %d units · brownouts: %d\n• Mission duration: %d days, %d operations cycles\n" % [
		roundi(m.spent_budget), roundi(m.budget), roundi(100.0 - m.fuel), roundi(m.fuel), int(m.spares_start) - int(m.spares), m.spares_start, roundi(m.spent_power), m.brownouts, roundi(m.days), m.cycles_used]
	if m.lost + m.corrupted > 0.0:
		bb += "• Data lost: %s units\n" % str(M.r1(m.lost + m.corrupted))
	var p: Dictionary = res.pts
	bb += "\n[color=#6aa8ff][b]SCORE[/b][/color]\nScience %d · condition %d · resources %d · decisions %d · adaptation %d · completion %d · efficiency %d. Speed alone is not rewarded.\n" % [
		p.science, p.condition, p.resources, p.decisions, p.adaptation, p.completion, p.efficiency]
	if unlock != "":
		bb += "\n[color=#ffd166][b]%s[/b][/color]" % unlock
	return await g.ui.big_choose("assessment", "Final mission assessment", bb, [{"id": "retry", "label": "Retry this mission", "sub": ""}, {"id": "continue", "label": "Continue   [Enter]", "main": true}])


# ------------------------------------------------------------------ Stage 01: design and planning only

func _planning_stage(stage: Dictionary, dd: Dictionary, budget: int) -> Dictionary:
	var opts: Array = []
	for o in m.objectives:
		var cov: bool = m.totals.tags.has(o.tag)
		opts.append({"id": o.id, "label": "%s%s" % ["★ Primary: " if o.primary else "Secondary: ", o.name], "sub": "equipment on board" if cov else "no equipment for this on board", "q": "good" if o.primary and cov else "poor"})
	var pick: String = await g.ui.choose("priority", "Mission objective planning", "Which objective should be the first priority? Pick one the design can actually achieve, and that matters most for the mission.", opts)
	var o2 := M.obj_of(m, pick)
	var ok: bool = o2.primary and m.totals.tags.has(o2.tag)
	m.decisions.append({"id": "priority", "quality": "good" if ok else "poor"})
	var fit := M.design_fit(dd, m.stats)
	var prim := true
	for o in m.objectives:
		if o.primary and not m.totals.tags.has(o.tag):
			prim = false
	var lines := [[m.totals.cost <= budget, "Within budget: $%dM of $%dM" % [m.totals.cost, budget]],
		[m.totals.mass <= m.totals.cap, "Within launch capacity: %d kg of %d kg" % [m.totals.mass, m.totals.cap]],
		[prim, "Equipment for every primary objective"], [fit.score >= 60, "Environment fit %d%% (60%% needed)" % fit.score],
		[ok, "First priority is a primary objective the design can achieve"]]
	var passed := true
	for l in lines:
		if not l[0]:
			passed = false
	prog.design1 = m.design.duplicate(true)
	var stars: int = 0 if not passed else (3 if fit.score >= 90 and m.budget > 20.0 else 2)
	var total := roundi(fit.score * 5.0 + maxf(0.0, m.budget) * 2.0 + (100.0 if ok else 0.0))
	_record(int(stage.n), {"pass": passed, "stars": stars, "total": total}, false)
	var bb := "%s  [color=#ffd166]%s[/color]\n\n" % [_col("ok" if passed else "bad", "[b]%s[/b]" % ("DESIGN APPROVED" if passed else "DESIGN NOT APPROVED")), _stars(stars)]
	for l in lines:
		bb += _col("ok" if l[0] else "bad", "%s %s" % ["✓" if l[0] else "✗", l[1]]) + "\n"
	for l in fit.lines:
		bb += _col(l.tone, "⚠ " + l.text) + "\n"
	bb += "\nThis design will be used for Stages 02 to 04.%s" % ("\n[color=#ffd166][b]Stage 02 unlocked.[/b][/color]" if passed else "")
	var choice: String = await g.ui.big_choose("assessment", "Design review", bb, [{"id": "retry", "label": "Retry this stage", "sub": ""}, {"id": "continue", "label": "Continue   [Enter]", "main": true}])
	return {"choice": choice, "outcome": "success" if passed else "unsuccessful", "pass": passed, "total": total, "stars": stars}


# ------------------------------------------------------------------ launch and cruise

func _launch(stage: Dictionary, dd: Dictionary, diff: Dictionary) -> void:
	g.ui.cue("Launch preparation")
	var earth: Dictionary = g.world.view_by("earth")
	g.ship.visible = true
	g.place_ship(earth.park, Vector3(0, 0, -1))
	g.ship.set_flame(0.15)
	if visuals:
		await g.cam_to(earth.pos, earth.target, 2.0)
	var grow: float = 1.2 if stage.get("special", "") == "gauntlet" else 1.0
	if grow > 1.0:
		m.totals.mass = roundi(m.totals.mass * grow)
		g.ui.toast("Late changes by the instrument teams added 20% to the payload mass.", "bad")
	var tries := 0
	while m.totals.mass > m.totals.cap and tries < 6:
		tries += 1
		await _event(CH.by_id("massLimit"))
		if g.bot != "":
			# the bot fixes an overweight payload the simple way: gravity assist and the biggest rocket
			var bd: Dictionary = m.design.duplicate(true)
			bd.launcher = "heavy"
			bd.trajectory = "assist"
			_rebuild(bd, m.budget0)
		else:
			var nd: Dictionary = await _design_screen(dd, m.budget0, m.design, diff, "Payload too heavy",
				"Launcher capacity to %s: %d kg. Your payload: %d kg. Remove mass, choose a bigger launcher, or use a gravity-assist trajectory." % [dd.name, m.totals.cap, m.totals.mass])
			_rebuild(nd, m.budget0)
		m.redesign = false
		m.totals.mass = roundi(m.totals.mass * grow)
		grow = 1.0 if tries >= 2 else grow
		if int(stage.get("level", 0)) == 1:
			prog.design1 = m.design.duplicate(true)
			_save()
	if m.totals.mass > m.totals.cap:
		m.failed = "The spacecraft was too heavy to launch."
		return
	var forced: Array = stage.get("forced", {}).get("launch", [])
	for id in forced:
		await _event(CH.by_id(id))
	if forced.is_empty() and randf() < 0.3:
		await _event(CH.by_id("launchWindow"))
	if _dead():
		return
	g.audio.ok()
	g.ui.flash(Color(1.0, 0.86, 0.63, 0.4))
	g.ship.set_flame(1.0)
	if visuals:
		var from: Vector3 = earth.park
		var dir: Vector3 = (from - earth.body).normalized()
		g.cam_mode = "chase"
		g.orbit_on = false
		await g._tw(3.0, func(u: float): g.place_ship(from + dir * (u * u * 40.0) + Vector3(0, u * 8.0, 0), dir))
	g.ship.set_flame(0.2)
	g.ui.toast("Launch successful. Spacecraft separated from the upper stage.", "good")


func _cruise(stage: Dictionary, i: int) -> void:
	var from_body: String = "earth" if i == 0 else CD.DESTINATIONS[m.segments[i - 1].dest].body
	var to_body: String = m.dest.body
	var n := M.cruise(m)
	refresh()
	if from_body == to_body:
		return
	g.ui.cue("Interplanetary cruise to %s" % m.dest.name)
	g.world.set_world_visible(true)
	g.ship.visible = true
	var forced: Array = []
	if i == 0 or i == m.segments.size() - 1:
		forced = stage.get("forced", {}).get("cruise", []).duplicate()
	if i == 0 and stage.get("special", "") == "lastChance":
		forced.append_array(["powerCrisis", "commsBlackout", "navError"])
	if i == 0 and stage.get("special", "") == "gauntlet":
		forced.append("navError")
	var legs: int = maxi(n, forced.size()) + 1
	var cp: Array = g.world.curve_by(from_body, to_body)
	g.ship.set_flame(1.0)
	for k in legs:
		if visuals:
			g.cam_mode = "chase"
			g.orbit_on = false
			await g._tw(2.6, func(u: float):
				var s: float = (float(k) + u) / float(legs)
				g.place_ship(WorldScript.bez(cp[0], cp[1], cp[2], s), WorldScript.bez_tan(cp[0], cp[1], cp[2], s)))
		if k == legs - 1:
			break
		m.mode = "cruise"
		if forced.size() > 0:
			await _event(CH.by_id(forced.pop_front()))
		elif randf() < float(m.diff.eventChance):
			await _event(CH.pick(m, "cruise"))
		m.skip = 0
		M.power_step(m, 0.0)
		if _dead():
			return
	g.ship.set_flame(0.15)
	if i == 0 and stage.get("special", "") == "lastChance":
		await _last_chance()


func _last_chance() -> void:
	var weak: Array = []
	for k in m.c:
		if m.c[k] < 80.0:
			weak.append(k)
	weak.sort_custom(func(a, b): return m.c[a] < m.c[b])
	var opts: Array = []
	for k in weak.slice(0, 4):
		opts.append({"id": k, "label": "%s (%d%%)" % [M.comp_name(k), roundi(m.c[k])], "sub": "+25% with a spare kit" if m.spares > 0 else "recalibration only (+8%)", "q": "good" if k in ["comms", "power", "nav"] else "fair"})
	opts.append({"id": "none", "label": "Leave them as they are", "sub": "", "q": "good" if weak.is_empty() else "poor"})
	var pick: String = await g.ui.choose("event:restore", "LAST CHANCE — RESTORE ESSENTIAL FUNCTIONALITY", "Several systems were hit during the journey. You have %d repair kits. Which system do you restore first?" % m.spares, opts)
	if pick != "none":
		if m.spares > 0:
			m.spares -= 1
			M.heal(m, pick, 25.0)
		else:
			M.heal(m, pick, 8.0)
	var ok: bool = m.c.comms > 20.0 and m.fuel > float(m.dest.insertFuel)
	var d: String = await g.ui.choose("event:decide", "LAST CHANCE — IS THE ORIGINAL OBJECTIVE STILL ACHIEVABLE?",
		"Comms %d%%, fuel %d (insertion needs about %d), instruments %d%%." % [roundi(m.c.comms), roundi(m.fuel), int(m.dest.insertFuel), roundi(m.c.instruments)], [
		{"id": "keep", "label": "Keep the original objectives", "sub": "the numbers support it" if ok else "risky with these numbers", "q": "good" if ok else "poor"},
		{"id": "reduce", "label": "Reduce the plan: drop a secondary objective now", "sub": "frees time for the primaries", "q": "fair" if ok else "good"}])
	if d == "reduce":
		for o in m.objectives:
			if not o.primary and o.status == "active":
				o.status = "dropped"
				break
	var q: String = ("good" if ok else "poor") if d == "keep" else ("fair" if ok else "good")
	m.decisions.append({"id": "lastChance", "quality": q})
	m.challenges.append({"title": "Last Chance: restore and decide", "choice": ("no repair" if pick == "none" else "restored %s" % M.comp_name(pick)) + (", kept objectives" if d == "keep" else ", reduced plan"), "quality": q, "effects": ""})
	refresh()


# ------------------------------------------------------------------ arrival and landing

func _park_at_dest() -> void:
	var v: Dictionary = g.world.view_by(m.dest.body)
	g.world.set_world_visible(true)
	g.ship.visible = true
	g.place_ship(v.park, Vector3(0, 0, -1))
	g.ship.set_flame(0.15)
	if visuals:
		await g.cam_to(v.pos, v.target, 2.0)
	else:
		g.cam_mode = "free"


func _arrive(stage: Dictionary, i: int) -> void:
	var seg: Dictionary = m.segments[i]
	g.ui.cue("Arrival: %s" % m.dest.name)
	await _park_at_dest()
	var last: bool = i == m.segments.size() - 1
	var forced: Array = stage.get("forced", {}).get("arrive", []).duplicate() if last else []
	if last and stage.get("special", "") == "gauntlet":
		forced.append("commsBlackout")
	m.mode = "orbit" if seg.mode in ["surface", "probe"] else seg.mode
	for id in forced:
		await _event(CH.by_id(id))
	if seg.mode != "flyby" and CH.when(m, "fuelShortage"):
		await _event(CH.by_id("fuelShortage"))
	m.skip = 0
	var orbit_id := ""
	if m.dest.has("orbits") and seg.mode != "surface":
		if stage.has("forceOrbit"):
			orbit_id = stage.forceOrbit
		else:
			var saturn: bool = m.dest.id == "saturn"
			var opts: Array = []
			for o in m.dest.orbits:
				opts.append({"id": o.id, "label": o.name, "sub": "%s · science ×%s · %s" % [o.note, str(o.sci), "particles ×%s" % str(o.imp) if o.has("imp") else "radiation ×%s" % str(o.rad)]})
			orbit_id = await g.ui.choose("orbit", "Choose your orbit at %s" % m.dest.name, "Your orbit decides how much %s exposure the spacecraft accumulates, and how good the science is. Shielding rating: %d%%." % [
				"ring-particle" if saturn else "radiation", roundi(float(m.stats.impactTol if saturn else m.stats.radTol) * 100.0)], opts)
	var txt := M.arrive(m, orbit_id)
	g.ui.toast(txt if txt != "" else "Arrived at %s." % m.dest.name, "good")
	refresh()
	if seg.mode == "surface":
		await _landing()


func _landing() -> void:
	var opts: Array = []
	for s in m.dest.landingSites:
		var wet: bool = s.get("water", false) or s.get("liquid", false)
		opts.append({"id": s.id, "label": s.name, "sub": "%s · roughness %d%% · science ×%s" % [s.note, roundi(float(s.rough) * 100.0), str(s.sci)], "q": "poor" if wet else "good"})
	var site: String = await g.ui.choose("site", "Choose a landing site on %s" % m.dest.name, "Rougher sites are scientifically richer but harder to land on. Hazard avoidance: %d%%.%s" % [
		roundi(float(m.stats.hazardAvoid) * 100.0), " Tip: pick a site that is both safe and suitable for a lander." if m.diff.guidance else ""], opts)
	var res := M.land(m, site)
	m.decisions.append({"id": "site", "quality": "poor" if m.site.get("water", false) or m.site.get("liquid", false) else "good"})
	if visuals:
		g.cam_mode = "free"
		g.orbit_on = false
		g.world.set_world_visible(false)
		g.ui.loading_show("Descending to %s" % m.dest.name, m.site.name)
		await get_tree().process_frame
		await get_tree().process_frame
		g.surface.speed = g.speed
		g.surface.storm = 0.0
		g.surface.enter(m.dest.id)
		_on_surface = true
		await g.ui.loading_hide(1400)
		await g.surface.descent(res.bad)
		if m.stats.rover and not m.stats.rotor and m.c.has("rover"):
			g.surface.add_rover()
	g.audio.thud()
	if res.bad:
		g.ui.flash()
		g.audio.warn()
	refresh()
	await g.ui.say("Rough landing" if res.bad else "Touchdown", res.text)


func _leave_surface(with_liftoff: bool) -> void:
	if not _on_surface:
		return
	if with_liftoff and visuals and g.surface.visible:
		await g.surface.liftoff()
	_leave_surface_now()
	await _park_at_dest()
	g.orbit_on = true


func _leave_surface_now() -> void:
	_on_surface = false
	if g.surface.visible:
		g.surface.storm = 0.0
		g.surface.leave()
	g.world.set_world_visible(true)


# ------------------------------------------------------------------ operations

func _ops(stage: Dictionary, i: int) -> void:
	var last: bool = i == m.segments.size() - 1
	var forced: Array = stage.get("forced", {}).get("ops", []).duplicate() if last else []
	if last and stage.get("special", "") == "gauntlet":
		forced.append("discovery")
	if last and stage.get("special", "") == "reboot":
		var list: Array = []
		for k in m.c:
			if m.c[k] < 80.0:
				list.append("%s %d%%" % [M.comp_name(k), roundi(m.c[k])])
		await g.ui.say("MISSION REBOOT — INSPECT SPACECRAFT CONDITION", "The spacecraft has arrived with several systems below expected performance: %s. Open the Mission Lab to inspect each one, then prioritise repairs, use backups and adapt objectives to complete as much as possible." % ", ".join(PackedStringArray(list)))
	var forced_at: Array = []
	for k in forced.size():
		forced_at.append({"id": forced[k], "at": 1 + int((float(k) + 0.5) * maxf(1.0, float(m.max_cycles - 2)) / float(forced.size())), "done": false})
	g.ui.cue("%s: operations" % m.dest.name)
	g.orbit_on = not g.surface.visible
	var free_streak := 0
	while m.cycle < m.max_cycles and m.failed == "":
		refresh()
		if free_streak > 30:      # safety: never spin without time passing
			free_streak = 0
			await _cycle_end({"hold": true}, 0.0, true)
			continue
		var fired := false
		for fe in forced_at:
			if not fe.done and fe.at <= m.cycle:
				fe.done = true
				var ev := CH.by_id(fe.id)
				if CH.eligible(m, ev, "ops") or fe.id == "powerCrisis":
					await _event(ev)
					await _after_event()
					fired = true
				break
		if fired:
			if _dead():
				return
			continue
		var acts := M.actions(m)
		var opts: Array = [{"header": true, "label": "USES ONE %s" % str(m.dest.cycleName).to_upper()}]
		for a in acts:
			if a.kind == "cycle":
				opts.append(a)
		opts.append({"header": true, "label": "NO TIME NEEDED"})
		for a in acts:
			if a.kind == "free":
				opts.append(a)
		var bb := "Battery [b]%d/%d[/b] · generation %.1f vs load %.1f per cycle · fuel %d · spares %d\n" % [roundi(m.battery), roundi(M.battery_cap(m)), M.generation(m), M.power_load(m), roundi(m.fuel), m.spares]
		var ws := M.warnings(m)
		for w in ws.slice(0, 4):
			bb += _col(w[0], "⚠ " + w[1]) + "\n"
		var pick: String = await g.ui.big_choose("ops", "%s · %s · %s %d of %d" % [m.dest.name, mode_name(), m.dest.cycleName, m.cycle + 1, m.max_cycles], bb, opts, 1100.0)
		var act := {}
		for a in acts:
			if a.id == pick:
				act = a
		if act.is_empty():
			continue
		if act.kind == "free":
			free_streak += 1
			if await _free_action(act):
				break
			continue
		free_streak = 0
		var arg := ""
		if pick.begins_with("drive:"):
			arg = await g.ui.choose("route", "Choose the route", "Rover %d%% · wheel rating %d%% · terrain: %s%s." % [roundi(m.c.rover), roundi(float(m.stats.wheelTol) * 100.0),
				m.dest.env.terrain.shown if m.dest.env.get("terrain") != null else "—", " · rotorcraft: terrain matters much less" if m.stats.rotor else ""], [
				{"id": "safe", "label": "Safe route", "sub": "slower progress, less wear on the wheels", "q": "good"},
				{"id": "direct", "label": "Direct route", "sub": "faster progress, more rough ground", "q": "fair"}])
		elif pick == "repair":
			var ropts: Array = []
			var keys: Array = m.c.keys()
			keys.sort_custom(func(a, b): return m.c[a] < m.c[b])
			for k in keys:
				if m.c[k] < 100.0:
					ropts.append({"id": k, "label": "%s: %d%% (%s)" % [M.comp_name(k), roundi(m.c[k]), M.classify(m.c[k])[1]], "sub": ""})
			ropts.append({"id": "cancel", "label": "Cancel", "sub": ""})
			arg = await g.ui.choose("repair", "Repair which component?", "Uses one of %d repair kits." % m.spares, ropts)
			if arg == "cancel":
				continue
		elif pick == "orbit":
			var oopts: Array = []
			for o in m.dest.orbits:
				oopts.append({"id": o.id, "label": o.name, "sub": "%s · science ×%s" % [o.note, str(o.sci)], "disabled": o.id == m.orbit.get("id", "")})
			oopts.append({"id": "cancel", "label": "Cancel", "sub": ""})
			arg = await g.ui.choose("orbit2", "Change orbit", "Fuel −6.", oopts)
			if arg == "cancel":
				continue
		elif pick == "probe":
			await _probe()
			if _dead():
				return
			continue
		var r := M.perform(m, pick, arg)
		if visuals and g.surface.visible and (pick.begins_with("sci:") or pick.begins_with("drive:")):
			var tag: String = M.obj_of(m, pick.split(":")[1]).get("tag", "")
			if pick.begins_with("drive:") and g.surface.rover != null and is_instance_valid(g.surface.rover):
				g.surface.set_rover(float(m.c.get("rover", 100.0)), float(m.env.dustCover))
				await g.surface.rover_drive()
			else:
				await g.surface.do_task(TASK_VIS.get(tag, "scan"), false)
		elif pick.begins_with("sci:"):
			g.ui.flash(Color(0.47, 0.86, 1.0, 0.18))
		g.ui.toast(r.text, "good")
		await _cycle_end(r.ctx, r.power)
		await _after_event()
		if _dead():
			return
		if m.cycle < m.max_cycles and randf() < float(m.diff.eventChance):
			await _event(CH.pick(m, "ops"))
			if int(m.diff.maxSimul) > 1 and randf() < float(m.diff.eventChance) * 0.35 and not _dead():
				await _event(CH.pick(m, "ops"))
			await _after_event()
			if _dead():
				return
		var left := false
		for o in m.objectives:
			if o.status == "active" and int(o.seg) == int(m.seg):
				left = true
		if not left and M.queued(m) < 0.05:
			var more: String = await g.ui.choose("done", "All objectives here are complete", "You can finish now (unused time counts toward efficiency) or keep operating.", [
				{"id": "end", "label": "Finish the mission" if last else "Continue the journey", "sub": ""}, {"id": "stay", "label": "Keep operating", "sub": ""}])
			if more == "end":
				break


## Cycles lost to a decision (for example "takes one cycle").
func _after_event() -> void:
	var n: int = int(m.skip)
	m.skip = 0
	for _k in n:
		if m.cycle < m.max_cycles and m.failed == "":
			await _cycle_end({}, 0.0, true)


func _cycle_end(ctx: Dictionary, power: float, quiet: bool = false) -> void:
	var before: Dictionary = m.c.duplicate()
	var r := M.end_cycle(m, ctx, power)
	var lines: Array = []
	for k in m.c:
		if before[k] - m.c[k] >= 0.5:
			lines.append("%s −%s%%" % [M.comp_name(k), str(M.r1(before[k] - m.c[k]))])
	var srcs: Array = []
	for d in r.dmg:
		if d.has("src") and not srcs.has(d.src):
			srcs.append(d.src)
		if d.has("info"):
			g.ui.toast(d.info, "good")
	if lines.size() > 0:
		g.ui.toast("%s: %s" % [", ".join(PackedStringArray(srcs)), " · ".join(PackedStringArray(lines))] if srcs.size() > 0 else " · ".join(PackedStringArray(lines)), "bad")
		g.audio.warn()
		if visuals and g.surface.visible and srcs.size() > 0:
			var s0: String = str(srcs[0]).to_lower()
			g.surface.hazard_fx("dust" if s0.contains("dust") else ("radiation" if s0.contains("radiation") else ("cold" if s0.contains("cold") else ("thermal" if s0.contains("heat") else ("quake" if s0.contains("geolog") or s0.contains("wind") else "equip")))))
	if r.power.brown:
		g.ui.toast("Brownout! The battery ran flat. Heaters and instruments lost power.", "bad")
		g.ui.flash()
		g.audio.alarm()
	if quiet:
		g.ui.toast("One %s passes." % m.dest.cycleName, "")
	elif r.sent > 0.0:
		g.ui.toast("Downlink: %s units of data reached Earth." % str(r.sent), "good")
	refresh()
	await _sleep(0.4)


## Returns true when operations should end.
func _free_action(act: Dictionary) -> bool:
	match act.id:
		"lab":
			await _lab()
		"power":
			var pm: String = await g.ui.choose("power", "Power management", "Battery %d/%d. Generation %.1f per cycle." % [roundi(m.battery), roundi(M.battery_cap(m)), M.generation(m)], [
				{"id": "full", "label": "Full operations", "sub": "all systems at full power (+25% load)"},
				{"id": "balanced", "label": "Balanced", "sub": "normal load"},
				{"id": "survival", "label": "Survival mode", "sub": "essential systems only (−45% load) · instruments rest · better radiation tolerance"}])
			m.power_mode = pm
			var popts: Array = []
			for k in M.PRIORITIES:
				popts.append({"id": k, "label": M.PRIORITIES[k][0] + ("   (current)" if m.power_priority == k else ""), "sub": M.PRIORITIES[k][1], "q": "good" if k == "even" else "fair"})
			m.power_priority = await g.ui.choose("priority", "Power redistribution", "When power becomes limited, which systems keep it first?", popts)
			if pm == "survival":
				m.offline.inst = true
			elif m.offline.inst and M.cv(m, "instruments", 0.0) >= 20.0 and m.battery > 5.0:
				m.offline.inst = false
		"backup":
			var list := M.backup_options(m)
			var bo: Array = []
			for x in list:
				bo.append({"id": x.id, "label": x.label, "sub": ""})
			bo.append({"id": "cancel", "label": "Cancel", "sub": ""})
			var b: String = await g.ui.choose("backup", "Switch to backup systems", "Backups are slower or less capable, but they keep the mission alive.", bo)
			if b != "cancel":
				M.activate_backup(m, b)
				g.ui.toast("Backup system active.", "good")
				m.decisions.append({"id": "backup", "quality": "good"})
		"adapt":
			var blocked: Array = []
			for o in m.objectives:
				if o.status == "active" and int(o.seg) == int(m.seg) and M.permanently_blocked(m, o) != "" and M.modified_options(m, o).size() > 0:
					blocked.append(o)
			var ao: Array = []
			for o in blocked:
				ao.append({"id": o.id, "label": o.name, "sub": M.permanently_blocked(m, o)})
			ao.append({"id": "cancel", "label": "Cancel", "sub": ""})
			var oid: String = await g.ui.choose("adapt1", "Change exploration objectives", "These objectives can no longer be done as planned. Choose one to replace with a modified objective.", ao)
			if oid != "cancel":
				var o3 := M.obj_of(m, oid)
				var mo := M.modified_options(m, o3)
				var mopts: Array = []
				for j in mo.size():
					mopts.append({"id": str(j), "label": mo[j].name, "sub": "uses: %s" % mo[j].tag})
				var k: String = await g.ui.choose("adapt2", "Choose the modified objective", "A modified objective is worth less than the original, but still counts toward the mission.", mopts)
				var n := M.adopt_modified(m, o3, mo[int(k)])
				m.decisions.append({"id": "adapt", "quality": "good"})
				m.challenges.append({"title": "Mission adjustment", "choice": "Replaced \"%s\" with \"%s\"" % [o3.name, n.name], "quality": "good", "effects": ""})
				g.ui.toast("Objective changed.", "good")
		"retreat":
			var c: String = await g.ui.choose("confirm", "Orbital retreat", "End surface operations for good and continue from orbit? Surface objectives will need to be adapted.", [{"id": "yes", "label": "Yes, return to orbital operations"}, {"id": "no", "label": "No"}])
			if c == "yes":
				g.ui.toast(M.retreat(m), "good")
				m.challenges.append({"title": "Orbital retreat", "choice": "Surface exploration ended; switched to orbital operations", "quality": "fair", "effects": ""})
				await _leave_surface(true)
		"end":
			var c2: String = await g.ui.choose("confirm", "End operations here?", "%d %ss remain." % [int(m.max_cycles) - int(m.cycle), m.dest.cycleName], [{"id": "yes", "label": "Yes, finish here"}, {"id": "no", "label": "No, keep going"}])
			refresh()
			return c2 == "yes"
	refresh()
	return false


# ------------------------------------------------------------------ atmospheric probe

func _probe() -> void:
	var entry: String = await g.ui.choose("entry", "Atmospheric probe: entry angle", "The probe hits the atmosphere at tens of kilometres per second. Probe rating: %d bar, %d °C. It keeps descending until it is crushed, overheats or its battery runs out. Data is relayed through the orbiter (comms %d%%)." % [
		int(m.stats.probeBar), int(m.stats.probeHeat), roundi(m.c.comms)], [
		{"id": "shallow", "label": "Shallow entry", "sub": "gentler heating, uses more probe battery", "q": "good"},
		{"id": "steep", "label": "Steep entry", "sub": "saves battery, harsher heating on the heat shield", "q": "fair"}])
	var t := M.probe_start(m, entry)
	g.ui.flash(Color(1.0, 0.63, 0.31, 0.45))
	g.audio.alarm()
	g.ui.toast(t, "good")
	await _sleep(1.2)
	var count: int = m.dest.probe.levels.size()
	while true:
		refresh()
		var lv := M.probe_level(m)
		if lv.is_empty():
			M.probe_step(m, "transmit")
			break
		var pr: Dictionary = m.probe
		var near: bool = lv.bar > float(m.stats.probeBar) * 0.7
		g.ui.mini_text("Probe · depth level %d/%d · next: %s bar, %d °C · integrity %d%% · battery %d%%" % [lv.i + 1, count, str(lv.bar), roundi(lv.temp), maxi(0, roundi(pr.integrity)), maxi(0, roundi(pr.battery))])
		var ch: String = await g.ui.choose("probe", "Descending toward %s bar (%d °C)" % [str(lv.bar), roundi(lv.temp)], "Probe rated to %d bar and %d °C. %s%sHow should the probe spend this step?" % [int(m.stats.probeBar), int(m.stats.probeHeat),
			"[b]Pressure is approaching the probe's limit.[/b] " if near else "", "%s units of measurements are waiting to be relayed. " % str(pr.buffer) if pr.buffer > 0.0 else ""], [
			{"id": "measure", "label": "Prioritise measurements", "sub": "more data, sent on the next step (lost if the probe dies first)", "q": "poor" if near else "good"},
			{"id": "transmit", "label": "Prioritise transmission", "sub": "less data, but sent immediately", "q": "good" if near else "fair"}])
		m.decisions.append({"id": "probe", "quality": "good" if (ch == "measure") != near else "fair"})
		var r := M.probe_step(m, ch)
		if r.has("hist"):
			g.ui.toast("%s bar, %d °C: %s units of data · integrity %d%%" % [str(r.hist.bar), roundi(r.hist.temp), str(r.hist.units), r.hist.integrity], "bad" if r.hist.integrity < 40 else "good")
			if r.hist.integrity < 40:
				g.ui.flash(Color(1.0, 0.4, 0.2, 0.25))
		await _sleep(0.5)
		if r.done:
			break
	g.audio.thud()
	g.ui.mini_text("")
	var o := {}
	for x in m.objectives:
		if x.tag == "probe" and int(x.seg) == int(m.seg):
			o = x
	m.challenges.append({"title": "Atmospheric probe descent", "choice": "%s entry, deepest level %s bar" % [entry, str(m.probe.max_bar)],
		"quality": "good" if o.get("status", "") == "done" else "fair", "effects": m.probe.end})
	await g.ui.say("Probe mission over", "%s Probe data returned: %s of %s units needed." % [m.probe.end, str(o.get("returned", 0)), str(o.get("units", 0))])
	m.mode = "orbit"
	await _cycle_end({}, 4.0)


# ------------------------------------------------------------------ events

func _event(ev: Dictionary) -> void:
	if ev.is_empty() or m.failed != "":
		return
	g.ui.cue("Planetary hazard" if ev.cat == "env" else ("Mission challenge" if ev.cat == "universal" else "Engineering decision"))
	if ev.cat == "universal":
		g.audio.alarm()
	else:
		g.audio.warn()
	var text := CH.text(m, ev.id)
	refresh()
	var opts := CH.options(m, ev.id)
	var tag: String = {"env": "[color=#ffc08a]CATEGORY A · PLANETARY ENVIRONMENT[/color]", "universal": "[color=#b9d4ff]CATEGORY B · UNIVERSAL MISSION CHALLENGE[/color]"}.get(ev.cat, "[color=#d4c2ff]ENGINEERING / SCIENCE DECISION[/color]")
	var pick: String = await g.ui.choose("event:" + ev.id, ev.title, "%s\n%s" % [tag, text], opts)
	var o: Dictionary = opts[0]
	for x in opts:
		if x.id == pick:
			o = x
	var before: Dictionary = m.c.duplicate()
	var r := CH.run(m, ev.id, o.id)
	var hurt := false
	for k in m.c:
		if before.get(k, 0.0) - m.c[k] >= 0.5:
			hurt = true
	m.used[ev.id] = int(m.used.get(ev.id, 0)) + 1
	m.decisions.append({"id": ev.id, "quality": o.q})
	m.challenges.append({"title": ev.title, "choice": o.label, "quality": o.q, "effects": r})
	g.ui.toast(r if r != "" else "Done.", "bad" if hurt else "good")
	if hurt:
		g.ui.flash()
		if visuals and g.surface.visible:
			g.surface.hazard_fx("quake" if ev.cat == "env" else "equip")
	if m.bonus_sci > 0.0:
		m.sent = M.r1(m.sent + m.bonus_sci)
		g.ui.toast("Bonus science: +%s units returned." % str(m.bonus_sci), "good")
		m.bonus_sci = 0.0
	refresh()


# ------------------------------------------------------------------ bot player (automated tests)

func bot_choose(p: Dictionary) -> String:
	var opts: Array = p.options.filter(func(o): return not o.get("disabled", false))
	var id: String = p.id
	var ids: Array = []
	for o in opts:
		ids.append(o.id)
	var good := func() -> String:
		for o in opts:
			if o.get("q", "") == "good":
				return o.id
		return opts[0].id
	if m.is_empty():
		return good.call()
	match id:
		"briefing": return "go"
		"assessment": return "continue"
		"probe": return "transmit" if m.probe.integrity < 45.0 else "measure"
		"orbit", "backup", "adapt1": return opts[0].id
		"adapt2": return "0"
		"done": return "end"
		"confirm": return "yes"
		"power": return "balanced"
		"lab":
			if not _bot_lab2:
				_bot_lab2 = true
				return "instruments" if m.c.has("instruments") else "structure"
			return "__close"
		"repair":
			var keys: Array = m.c.keys()
			keys.sort_custom(func(a, b): return m.c[a] < m.c[b])
			return keys[0] if ids.has(keys[0]) else "cancel"
		"ops":
			var cap := M.battery_cap(m)
			var keys2: Array = m.c.keys()
			keys2.sort_custom(func(a, b): return m.c[a] < m.c[b])
			if not _bot_lab and m.cycle >= 2:
				_bot_lab = true
				return "lab"
			if ids.has("backup"): return "backup"
			if ids.has("adapt"): return "adapt"
			if m.power_mode == "survival" and m.battery > cap * 0.5: return "power"
			if ids.has("probe"): return "probe"
			if m.battery < cap * 0.2: return "hold"
			if ids.has("clean") and m.env.dustCover > 0.4: return "clean"
			if m.c[keys2[0]] < 35.0 and ids.has("repair"): return "repair"
			if m.offline.inst and ids.has("recal"): return "recal"
			var best := ""
			for o in opts:
				if o.has("obj"):
					if best == "" or (M.obj_of(m, o.obj).primary and not M.obj_of(m, opts[ids.find(best)].obj).primary):
						best = o.id
			if best != "": return best
			if M.queued(m) > 0.05: return "hold"
			return "end"
	return good.call()
