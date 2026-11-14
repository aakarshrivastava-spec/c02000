extends RefCounted
## Campaign mission rules: spacecraft design, mission state, the Environmental Damage Engine (EDE),
## operations, atmospheric probe and final assessment. Ported from the web version (src/campaign/*.js).
## The mission is a Dictionary "m" so every system (damage engine, challenges, scoring) shares one state.

const CD = preload("res://scripts/campaign_data.gd")

const DIST_RATE := {"earth": 1.4, "venus": 1.1, "mercury": 1.0, "mars": 1.0, "jupiter": 0.75, "europa": 0.75, "io": 0.75,
	"saturn": 0.65, "titan": 0.65, "enceladus": 0.65, "uranus": 0.5, "neptune": 0.45}
const CYCLE_DAYS := {"earth": 1.0, "mercury": 14.0, "venus": 0.01, "mars": 1.03, "jupiter": 20.0, "saturn": 20.0, "uranus": 20.0,
	"neptune": 20.0, "europa": 1.0, "titan": 1.0, "io": 1.0, "enceladus": 1.0}
const CRUISE_DAYS := {"earth": 0, "venus": 110, "mercury": 200, "mars": 210, "jupiter": 900, "europa": 900, "io": 900,
	"saturn": 1500, "titan": 1500, "enceladus": 1500, "uranus": 3000, "neptune": 4400}
const ORBIT_OK := {"radiation": 1.0, "particles": 1.0, "thermalHeat": 0.6, "thermalCold": 0.6}
const CLASSES := [[80, "Optimal", "ok"], [60, "Stable", "ok"], [40, "Degraded", "warn"], [20, "Critical", "bad"], [1, "Severe", "bad"], [0, "Non-functional", "bad"]]
const MOD_NAMES := {"imaging": "Image the area around the spacecraft", "composition": "Measure composition from where you are",
	"sample": "Analyse a sample within arm's reach", "atmosphere": "Record local atmospheric conditions", "thermal": "Map temperatures nearby",
	"fields": "Measure the magnetic environment", "radiation": "Measure the radiation environment",
	"subsurface": "Sound the ground beneath the spacecraft", "plume": "Analyse fallen plume material"}


static func r1(v: float) -> float:
	return snappedf(v, 0.1)


static func classify(v: float) -> Array:
	var r := roundi(v)
	for c in CLASSES:
		if r >= c[0]:
			return c
	return CLASSES[5]


static func comp_name(id: String, short: bool = true) -> String:
	for c in CD.COMPONENTS:
		if c.id == id:
			return c.short if short else c.name
	return id


static func stage_by_n(n: int) -> Dictionary:
	for s in CD.STAGES:
		if int(s.n) == n:
			return s
	return {}


static func special_by_id(id: String) -> Dictionary:
	for s in CD.SPECIALS:
		if s.id == id:
			return s
	return {}


# ------------------------------------------------------------------ design

static func _group(id: String) -> Dictionary:
	for g in CD.EQUIPMENT:
		if g.id == id:
			return g
	return {}


static func _by_id(list: Array, id) -> Dictionary:
	for x in list:
		if x.id == id:
			return x
	return {}


static func group_applies(g: Dictionary, dest: Dictionary) -> bool:
	if g.get("surfaceOnly", false) and dest.type != "surface":
		return false
	if g.get("probeOnly", false) and dest.type != "probe":
		return false
	return true


static func option_allowed(o: Dictionary, dest: Dictionary) -> bool:
	if o.has("needs") and not dest.get(o.needs, false):
		return false
	return true


static func sev(dest: Dictionary, k: String) -> float:
	var f = dest.env.get(k)
	return float(f.sev) if f != null else 0.0


static func capacity(dest: Dictionary, launcher_id: String, traj_id: String) -> int:
	var l := _by_id(CD.LAUNCHERS, launcher_id)
	var t := _by_id(CD.TRAJECTORIES, traj_id)
	if t.is_empty():
		t = CD.TRAJECTORIES[0]
	return roundi(float(l.cap) * minf(1.0, float(dest.c3) * float(t.massMul)))


static func default_design(dest: Dictionary) -> Dictionary:
	var drive := false
	for o in dest.objectives:
		if o.mode == "drive":
			drive = true
	return {"thermal": "std", "structure": "std", "radiation": "std", "power": "solar", "dust": "none", "coating": "none", "landing": "legs",
		"mobility": "rover" if dest.type == "surface" and drive else "none", "probe": "std", "spares": "s2", "backup": [], "instruments": [],
		"launcher": "medium", "trajectory": "direct"}


static func design_totals(dest: Dictionary, d: Dictionary) -> Dictionary:
	var mass: float = CD.BUS.mass
	var cost: float = CD.BUS.cost
	var power := 0.0
	var stats := {"heatTol": 0.0, "coldTol": 0.0, "pressTol": 0.0, "impactTol": 0.0, "windTol": 0.0, "geoTol": 0.0, "radTol": 0.0, "dustMit": 0.0,
		"corrTol": 0.0, "hazardAvoid": 0.0, "wheelTol": 0.0, "rover": false, "rotor": false, "gen": "solar", "panel": 1.0, "rtg": 0.0, "battery": 100.0,
		"probeBar": 0.0, "probeHeat": 0.0, "spares": 0, "backupComms": false, "backupInst": false, "backupNav": false}
	for g in CD.EQUIPMENT:
		if not group_applies(g, dest):
			continue
		var ids: Array = d.get(g.id, []) if g.get("multi", false) else [d.get(g.id, "")]
		for id in ids:
			var o := _by_id(g.options, id)
			if o.is_empty():
				continue
			mass += o.mass
			cost += o.cost
			for k in o.stats:
				stats[k] = o.stats[k]
	var tags := {}
	for id in d.get("instruments", []):
		var i := _by_id(CD.INSTRUMENTS, id)
		if i.is_empty():
			continue
		mass += i.mass
		cost += i.cost
		power += i.power
		tags[i.tag] = true
	if dest.type == "probe":
		tags["probe"] = true
	if stats.rover:
		tags["drive"] = true
	var l := _by_id(CD.LAUNCHERS, d.launcher)
	return {"mass": roundi(mass), "cost": roundi(cost + l.cost), "cap": capacity(dest, d.launcher, d.trajectory), "power": power, "stats": stats, "tags": tags}


## A sensible configuration built from the destination's real environment.
static func recommended_design(dest: Dictionary) -> Dictionary:
	var d := default_design(dest)
	var hot := sev(dest, "heat") > 0.5
	var cold := sev(dest, "cold") > 0.6
	d.thermal = "dual" if hot and cold else ("hot" if hot else ("cryo" if cold else "std"))
	d.structure = "pressure" if sev(dest, "pressure") > 0.5 else ("whipple" if sev(dest, "particles") > 0.5 or sev(dest, "geology") > 0.5 else "std")
	d.radiation = "vault" if sev(dest, "radiation") > 0.7 else ("std" if sev(dest, "radiation") > 0.25 else "none")
	d.power = "rtg" if sev(dest, "solar") < 0.2 else ("solarXL" if sev(dest, "dust") > 0.5 else "solar")
	if dest.id == "venus":
		d.power = "batt"
	d.dust = "mitig" if sev(dest, "dust") > 0.4 and d.power != "rtg" and dest.type == "surface" else "none"
	d.coating = "acid" if sev(dest, "corrosion") > 0.3 else "none"
	if dest.type == "surface":
		d.landing = "trn"
		var needs_drive := false
		for o in dest.objectives:
			if o.mode == "drive":
				needs_drive = true
		if not needs_drive:
			d.mobility = "none"
		elif dest.get("allowsRotor", false):
			d.mobility = "rotor"
		else:
			d.mobility = "roverPlus" if sev(dest, "terrain") > 0.55 else "rover"
	d.backup = ["lga"]
	var inst: Array = []
	for i in CD.INSTRUMENTS:
		if i.get("surfaceOnly", false) and dest.type != "surface":
			continue
		for o in dest.objectives:
			if o.tag == i.tag and not inst.has(i.id):
				inst.append(i.id)
	d.instruments = inst
	if sev(dest, "radiation") > 0.25 and dest.type == "orbiter":
		d.radiation = "std"
	d.trajectory = "assist" if float(dest.c3) < 0.35 else "direct"
	d.launcher = "heavy"
	var t := design_totals(dest, d)
	for l in CD.LAUNCHERS:
		if t.mass <= capacity(dest, l.id, d.trajectory):
			d.launcher = l.id
			break
	return d


## How well the equipment ratings match the destination. Returns {score, lines:[{tone,text}]}.
static func design_fit(dest: Dictionary, stats: Dictionary) -> Dictionary:
	var lines: Array = []
	var ok := 0
	var n := 0
	for hid in dest.hazards:
		var h: Dictionary = CD.HAZARDS[hid]
		if h.get("special", "") == "dust":
			n += 1
			if stats.dustMit > 0.0 or stats.gen != "solar":
				ok += 1
			else:
				lines.append({"tone": "warn", "text": "Dust will settle on solar panels with no way to clean them."})
			continue
		if h.get("onlyWhen", "") == "driving" and not stats.rover:
			continue
		var f = dest.env.get(h.factor)
		if f == null:
			continue
		n += 1
		var r: float = stats.get(h.protect, 0.0)
		if r >= float(f.sev) * 0.9:
			ok += 1
		else:
			lines.append({"tone": "bad" if float(f.sev) - r > 0.35 else "warn",
				"text": "%s: %s vs equipment rating %d%% (severity %d%%)." % [h.name, f.shown, roundi(r * 100.0), roundi(float(f.sev) * 100.0)]})
	n += 1
	var sun := sev(dest, "solar")
	if stats.gen == "solar" and sun < 0.1 and dest.id != "venus":
		lines.append({"tone": "bad", "text": "Sunlight here is %s. Solar panels will produce almost nothing." % dest.env.solar.shown})
	elif stats.gen == "none" and dest.id != "venus":
		lines.append({"tone": "warn", "text": "Primary batteries only: the mission will be short."})
	else:
		ok += 1
	return {"score": roundi(float(ok) / maxf(1.0, float(n)) * 100.0), "lines": lines}


# ------------------------------------------------------------------ mission state

static func build_segments(stage: Dictionary) -> Array:
	if stage.has("segments"):
		return stage.segments.duplicate(true)
	var d: Dictionary = CD.DESTINATIONS[stage.dest]
	return [{"dest": stage.dest, "mode": "probe" if d.type == "probe" else "surface"}]


static func build_objectives(stage: Dictionary) -> Array:
	var segs := build_segments(stage)
	var last := segs.size() - 1
	var base: Array = stage.objectives if stage.has("objectives") else CD.DESTINATIONS[segs[last].dest].objectives
	var out: Array = []
	for src in [base, stage.get("extraObjectives", [])]:
		for o0 in src:
			var o: Dictionary = o0.duplicate(true)
			o["seg"] = int(o.get("seg", last))
			o["units"] = float(o.units)
			o["collected"] = 0.0
			o["returned"] = 0.0
			o["status"] = "active"
			o["modified"] = false
			o["value"] = 1.0
			o["replaces"] = ""
			out.append(o)
	return out


## The destination as the design screen sees it (type depends on what the stage really does).
static func design_dest(stage: Dictionary) -> Dictionary:
	var segs := build_segments(stage)
	var main: Dictionary = CD.DESTINATIONS[stage.dest].duplicate(true)
	var type := "orbiter"
	for sg in segs:
		if sg.mode == "probe" and type != "surface":
			type = "probe"
		if sg.mode == "surface":
			type = "surface"
	for sg in segs:
		if sg.dest == stage.dest:
			continue
		var d: Dictionary = CD.DESTINATIONS[sg.dest]
		for k in ["particles", "radiation"]:
			var e = d.env.get(k)
			if e != null and (main.env.get(k) == null or float(e.sev) > float(main.env[k].sev)):
				main.env[k] = {"sev": float(e.sev) * 0.5, "shown": e.shown}
	main.type = type
	main.objectives = build_objectives(stage)
	return main


static func new_mission(stage: Dictionary, diff_id: String, design: Dictionary, rewards: Dictionary = {}) -> Dictionary:
	var diff: Dictionary = CD.DIFFICULTY.get(diff_id, CD.DIFFICULTY.intermediate)
	var segments := build_segments(stage)
	var dd := design_dest(stage)
	var t := design_totals(dd, design)
	var stats: Dictionary = t.stats
	if rewards.get("betterWheels", false) and stats.wheelTol > 0.0:
		stats.wheelTol = minf(0.95, stats.wheelTol + 0.1)
	if rewards.get("eRTG", false) and stats.gen == "rtg":
		stats.rtg += 2.0
	if rewards.get("radHard", false):
		stats.radTol = minf(0.95, stats.radTol + 0.1)
	if rewards.get("lightFrame", false):
		t.mass -= 60
	var surface_any := false
	for sg in segments:
		if sg.mode == "surface":
			surface_any = true
	var c := {}
	for x in CD.COMPONENTS:
		if x.get("surfaceOnly", false) and not surface_any:
			continue
		if x.get("roverOnly", false) and not (surface_any and stats.rover):
			continue
		if x.id == "solar" and stats.gen != "solar":
			continue
		c[x.id] = 100.0
	var budget := roundi(float(stage.budget) * float(diff.budgetMul))
	var spares := maxi(0, int(stats.spares) + int(diff.spares))
	var crewed: bool = stage.get("crewed", false)
	return {
		"stage": stage, "diff": diff, "design": design, "totals": t, "stats": stats,
		"segments": segments, "seg": 0, "dest": CD.DESTINATIONS[segments[0].dest], "mode": "cruise",
		"c": c, "start": c.duplicate(),
		"budget0": budget, "budget": float(budget - t.cost),
		"fuel": 100.0, "battery": float(stats.battery), "spares": spares, "spares_start": spares,
		"sent": 0.0, "lost": 0.0, "corrupted": 0.0, "queue": [],
		"objectives": build_objectives(stage),
		"cycle": 0, "max_cycles": 0, "days": 0.0,
		"env": {"dustCover": 0.0, "storm": 0.0, "stormLeft": 0.0, "weather": 0.0, "eruption": 0.0, "plume": 0.0, "day": true, "interior": 25.0, "dose": 0.0, "surge": 0.0},
		"orbit": {}, "site": {}, "tilt": 0.0, "landed": false,
		"backup": {"comms": false, "inst": false, "nav": false},
		"offline": {"inst": false, "comms": false, "nav": false},
		"power_mode": "balanced", "brownouts": 0, "brownout_run": 0,
		"crewed": crewed, "crew": 100.0, "crew_rest": 100.0,
		"log": [], "decisions": [], "challenges": [], "used": {},
		"probe": {}, "retreated": false, "failed": "",
		"spent_budget": float(t.cost), "spent_power": 0.0, "cycles_used": 0,
		# short-lived flags set by decisions
		"skip": 0, "no_downlink": false, "down_mul": 1.0, "yield_penalty": 0, "unreliable": 0, "nav_debt": 0.0, "insert_paid": false,
		"orbit_sci": 1.0, "bonus_sci": 0.0, "burst": false, "shield_attitude": false, "heat_shelter": false, "covers_closed": false,
		"drive_slow": false, "redesign": false, "last_action": "", "note": "",
	}


static func has(m: Dictionary, id: String) -> bool:
	return m.c.has(id)


static func cv(m: Dictionary, id: String, dflt: float = 100.0) -> float:
	return float(m.c.get(id, dflt))


static func damage(m: Dictionary, id: String, amount: float, source: String, why: String = "") -> float:
	if not m.c.has(id):
		return 0.0
	var a := amount
	if id != "structure" and m.c.has("structure") and m.c.structure < 40.0:
		a *= 1.0 + (40.0 - m.c.structure) / 80.0   # a weak frame makes everything else worse
	a = r1(a)
	if a < 0.5:
		return 0.0
	var before: float = m.c[id]
	m.c[id] = r1(clampf(before - a, 0.0, 100.0))
	var real := r1(before - m.c[id])
	if real > 0.0:
		m.log.append({"cycle": m.cycle, "comp": id, "amount": real, "source": source, "why": why, "where": m.dest.name})
	return real


static func heal(m: Dictionary, id: String, amount: float) -> float:
	if not m.c.has(id):
		return 0.0
	var before: float = m.c[id]
	m.c[id] = r1(clampf(before + amount, 0.0, 100.0))
	return r1(m.c[id] - before)


# ---- performance factors: condition directly changes what the spacecraft can do ----

static func inst_factor(m: Dictionary) -> float:
	if not m.c.has("instruments"):
		return 0.0
	var v: float = m.c.instruments
	if v < 20.0 and not m.backup.inst:
		return 0.0
	if m.offline.inst:
		return 0.0
	var eff: float = 55.0 if v < 20.0 and m.backup.inst else v
	return 0.35 + 0.65 * (eff / 100.0)


static func nav_factor(m: Dictionary) -> float:
	var v: float = m.c.nav
	if m.offline.nav and not m.backup.nav:
		return 0.35
	var eff: float = maxf(v, 65.0) if m.backup.nav and v < 40.0 else v
	return 0.4 + 0.6 * (eff / 100.0)


static func comms_rate(m: Dictionary) -> float:
	var dist: float = DIST_RATE.get(m.dest.id, 0.7)
	if m.c.comms <= 0.0 or m.offline.comms:
		return 0.7 * dist if m.backup.comms else 0.0
	return (0.6 + 2.6 * (float(m.c.comms) / 100.0)) * dist


static func battery_cap(m: Dictionary) -> float:
	var cold_loss := maxf(0.0, sev(m.dest, "cold") - float(m.stats.coldTol)) * 0.5
	return maxf(15.0, float(m.stats.battery) * (0.35 + 0.65 * (float(m.c.power) / 100.0)) * (1.0 - cold_loss))


# ---- objectives and data ----

static func obj_of(m: Dictionary, id: String) -> Dictionary:
	for o in m.objectives:
		if o.id == id:
			return o
	return {}


static func can_attempt(m: Dictionary, o: Dictionary) -> bool:
	if o.status != "active" or int(o.seg) != int(m.seg):
		return false
	if o.tag == "drive":
		return m.mode == "surface" and m.c.has("rover") and m.c.rover > 0.0
	if o.tag == "probe":
		return m.mode == "probe" and m.probe.is_empty()
	if not m.totals.tags.has(o.tag):
		return false
	if o.mode == "surface" and m.mode != "surface":
		return false
	if o.mode == "orbit" and not (m.mode in ["orbit", "flyby", "probe"]):
		return false
	return true


static func objective_blocked(m: Dictionary, o: Dictionary) -> String:
	if o.status != "active":
		return ""
	if o.tag == "drive":
		if not m.c.has("rover"):
			return "No rover was carried."
		if m.c.rover <= 0.0:
			return "The rover can no longer move."
		if m.retreated:
			return "Surface operations have ended."
	if o.tag != "drive" and o.tag != "probe" and o.tag != "launch" and not m.totals.tags.has(o.tag):
		return "No instrument for this objective was carried."
	if o.mode == "surface" and m.retreated:
		return "Surface operations have ended."
	if inst_factor(m) == 0.0 and o.tag != "drive":
		if m.c.get("instruments", 0.0) <= 0.0 and not m.backup.inst:
			return "Instruments are destroyed."
		return "Instruments are offline (recalibrate, repair or use a backup)."
	return ""


## Permanent blocks are the ones that justify changing an objective.
static func permanently_blocked(m: Dictionary, o: Dictionary) -> String:
	var b := objective_blocked(m, o)
	return "" if b.contains("offline") else b


static func add_data(m: Dictionary, o: Dictionary, units: float) -> float:
	var u := r1(units)
	if u <= 0.0:
		return 0.0
	o.collected = r1(o.collected + u)
	m.queue.append({"obj": o.id, "units": u})
	return u


static func queued(m: Dictionary) -> float:
	var t := 0.0
	for q in m.queue:
		t += q.units
	return r1(t)


static func downlink(m: Dictionary, mult: float = 1.0) -> float:
	var cap := comms_rate(m) * mult
	var sent := 0.0
	while cap > 0.01 and m.queue.size() > 0:
		var q: Dictionary = m.queue[0]
		var take := minf(q.units, cap)
		q.units = r1(q.units - take)
		cap -= take
		sent += take
		var o := obj_of(m, q.obj)
		if not o.is_empty():
			o.returned = r1(minf(o.units, o.returned + take))
			if o.status == "active" and o.returned >= o.units - 0.05:
				o.status = "done"
		if q.units <= 0.01:
			m.queue.pop_front()
	m.sent = r1(m.sent + sent)
	return r1(sent)


## Modified objectives that working equipment can still do when the original is blocked.
static func modified_options(m: Dictionary, _o: Dictionary) -> Array:
	var out: Array = []
	var remote_ok := ["imaging", "composition", "atmosphere", "fields", "radiation", "subsurface", "thermal"]
	var mode := "surface" if m.mode == "surface" else "orbit"
	for t in m.totals.tags:
		if t == "drive" or t == "probe":
			continue
		var taken := false
		for x in m.objectives:
			if x.tag == t and x.status == "active" and int(x.seg) == int(m.seg) and x.mode == mode:
				taken = true
		if taken:
			continue
		if m.mode != "surface" and not remote_ok.has(t):
			continue
		out.append({"tag": t, "name": ("" if m.mode == "surface" else "From orbit: ") + MOD_NAMES.get(t, t)})
	return out.slice(0, 3)


static func adopt_modified(m: Dictionary, o: Dictionary, opt: Dictionary) -> Dictionary:
	o.status = "dropped"
	var n := {"id": o.id + "_mod", "name": opt.name + " (modified)", "tag": opt.tag, "units": maxf(1.0, o.units - 1.0),
		"mode": "surface" if m.mode == "surface" else "orbit", "primary": o.primary, "seg": m.seg, "collected": 0.0, "returned": 0.0,
		"status": "active", "modified": true, "value": 0.6, "replaces": o.id}
	m.objectives.append(n)
	return n


static func check_fail(m: Dictionary) -> String:
	if m.failed != "":
		return m.failed
	if m.c.has("structure") and m.c.structure <= 0.0:
		m.failed = "Structural failure: the vehicle broke apart."
	elif m.brownout_run >= 3:
		m.failed = "Out of power for three cycles in a row. The electronics froze and the spacecraft fell silent."
	elif m.crewed and m.crew <= 0.0:
		m.failed = "Crew safety could not be maintained. The mission was aborted."
	return m.failed


static func _replaced_done(m: Dictionary, o: Dictionary) -> bool:
	if o.status == "done":
		return true
	for x in m.objectives:
		if x.replaces == o.id and x.status == "done":
			return true
	return false


static func assess(m: Dictionary) -> Dictionary:
	var primary_ok := true
	var any_primary := false
	var done := 0
	var science := 0.0
	var adapted := 0
	for o in m.objectives:
		if o.primary and not o.modified:
			if _replaced_done(m, o):
				any_primary = true
			else:
				primary_ok = false
		if o.status == "done":
			done += 1
			science += (300.0 if o.primary else 150.0) * float(o.value)
			if o.modified:
				adapted += 1
	var avg := 0.0
	for k in m.c:
		avg += m.c[k]
	avg = avg / maxf(1.0, float(m.c.size()))
	var outcome := "success" if primary_ok else ("partial" if any_primary or done > 0 else "unsuccessful")
	if m.failed != "" and not any_primary:
		outcome = "unsuccessful"
	var good := 0
	var dec := 0
	for d in m.decisions:
		dec += {"good": 40, "fair": 15}.get(d.quality, 0)
		if d.quality == "good":
			good += 1
	var pts := {
		"science": roundi(science + m.sent * 20.0),
		"condition": roundi(avg * 3.0),
		"resources": roundi(maxf(0.0, m.budget) * 0.4 + m.fuel * 2.0 + m.spares * 15.0 + (m.crew if m.crewed else 0.0)),
		"decisions": dec,
		"adaptation": adapted * 80,
		"completion": 500 if outcome == "success" else (150 if outcome == "partial" else 0),
		"efficiency": maxi(0, int(m.max_cycles) - int(m.cycle)) * 8 if outcome == "success" else 0,
	}
	var total := 0
	for k in pts:
		total += int(pts[k])
	var stars := 0
	if outcome == "success":
		stars = 3 if avg >= 55.0 and good * 2 >= m.decisions.size() else 2
	elif outcome == "partial":
		stars = 1
	var affected: Array = []
	for k in m.c:
		if roundi(m.c[k]) < roundi(m.start[k]):
			affected.append({"id": k, "start": roundi(m.start[k]), "end": roundi(m.c[k]), "cls": classify(m.c[k])[1]})
	return {"outcome": outcome, "pass": outcome == "success", "pts": pts, "total": total, "stars": stars, "avg": roundi(avg), "affected": affected, "done": done}


# ------------------------------------------------------------------ ENVIRONMENTAL DAMAGE ENGINE
# Damage is never a flat random number. For every hazard the destination really has:
#   damage = rate x (exposure - equipment rating), scaled by duration, current conditions and player decisions.
# Equipment built for the conditions (rating >= exposure) takes no damage.

static func exposure(m: Dictionary, hid: String, ctx: Dictionary = {}, expected: bool = false) -> float:
	var h: Dictionary = CD.HAZARDS[hid]
	var f = m.dest.env.get(h.factor)
	if f == null:
		return 0.0    # this factor does not exist here (for example: no wind without an atmosphere)
	var mode: String = m.mode
	if mode == "cruise":
		return 0.0
	if mode != "surface" and not ORBIT_OK.has(hid):
		return 0.0
	if mode == "surface" and hid == "particles":
		return 0.0
	if h.get("onlyWhen", "") == "driving" and not ctx.get("driving", false):
		return 0.0
	var x: float = f.sev
	var e: Dictionary = m.env
	if mode != "surface":
		x *= ORBIT_OK[hid]
	if hid == "radiation" and mode != "surface" and m.orbit.has("rad"):
		x *= float(m.orbit.rad)
	if hid == "particles" and m.orbit.has("imp"):
		x *= float(m.orbit.imp)
	if hid == "radiation":
		x *= 1.0 + e.surge
	if m.dest.id == "mercury" and mode == "surface":
		if hid == "thermalHeat":
			x *= 1.0 if e.day else 0.05
		if hid == "thermalCold":
			x *= 0.05 if e.day else 1.0
	if m.site.get("cold", false):
		if hid == "thermalCold":
			x = minf(1.2, x + 0.2)
		if hid == "thermalHeat":
			x *= 0.3
	if hid == "thermalCold" and m.dest.id == "mars" and e.storm > 0.0:
		x *= 1.15
	if hid == "terrain":
		var route: String = ctx.get("route", "")
		x *= (0.6 + float(m.site.rough) * 0.6 if m.site.has("rough") else 1.0) * (1.3 if route == "direct" else (0.6 if route == "safe" else 1.0)) * (0.3 if m.stats.rotor else 1.0)
	if hid == "geology":
		x *= 0.5 + e.eruption + e.plume
	if hid == "wind":
		x *= 1.0 + e.storm * 0.8 + e.weather
	if hid == "thermalHeat" and m.dest.get("leaks", false):
		x *= 1.0 + minf(0.3, float(m.cycle) * 0.03)
	# Difficulty changes how variable the scenario is. It never changes the planetary science.
	if not expected:
		x *= 1.0 + (randf() * 2.0 - 1.0) * float(m.diff.variability)
	return maxf(0.0, x)


static func rating(m: Dictionary, hid: String) -> float:
	var h: Dictionary = CD.HAZARDS[hid]
	var r: float = m.stats.get(h.protect, 0.0)
	if (hid == "thermalHeat" or hid == "thermalCold") and m.c.has("thermal"):
		r *= 0.45 + 0.55 * (float(m.c.thermal) / 100.0)
	if hid == "radiation" and m.power_mode == "survival":
		r = minf(0.97, r + 0.1)
	if hid == "particles" and m.shield_attitude:
		r = minf(0.97, r + 0.3)
	if hid == "thermalHeat" and m.heat_shelter:
		r = minf(0.97, r + 0.3)
	if hid == "geology" and m.covers_closed:
		r = minf(0.97, r + 0.3)
	return r


## One step of the damage engine. Returns [{comp, amount, src}] and {info} entries.
static func tick(m: Dictionary, ctx: Dictionary = {}) -> Array:
	var out: Array = []
	var w := [1.0, 0.55, 0.35, 0.25]
	for hid in m.dest.hazards:
		var h: Dictionary = CD.HAZARDS[hid]
		if h.get("special", "") == "dust":
			continue
		var x := exposure(m, hid, ctx)
		var r := rating(m, hid)
		var excess := x - r
		if excess <= 0.0:
			continue    # equipment designed for these conditions resists them
		for i in h.comps.size():
			var a := damage(m, h.comps[i], float(h.rate) * excess * w[mini(i, 3)] * (0.75 + randf() * 0.5), h.name,
				"%s Exposure %d%% vs rating %d%%." % [h.why, roundi(x * 100.0), roundi(r * 100.0)])
			if a > 0.0:
				out.append({"comp": h.comps[i], "amount": a, "src": h.name})
	# Venus: heat soaks in however good the insulation is. Mission time is the real limit.
	if m.dest.get("leaks", false) and m.mode == "surface":
		var soak: float = 3.0 + (1.0 - float(m.stats.heatTol)) * 6.0
		m.env.interior = r1(m.env.interior + soak * 3.0)
		var a2 := damage(m, "thermal", soak, "Heat soaking through insulation", "On Venus heat always leaks in. Even the best landers survive only a couple of hours.")
		if a2 > 0.0:
			out.append({"comp": "thermal", "amount": a2, "src": "Heat soak"})
		if m.env.interior > 120.0:
			var b := damage(m, "instruments", 6.0, "Interior over-temperature", "Inside temperature %d °C is above electronics limits." % roundi(m.env.interior))
			if b > 0.0:
				out.append({"comp": "instruments", "amount": b, "src": "Interior heat"})
	# Dust builds up over time, cuts solar output and, when heavy, contaminates instruments.
	if m.mode == "surface" and sev(m.dest, "dust") >= 0.4:
		var add: float = 0.05 * sev(m.dest, "dust") * (1.0 + m.env.storm * 2.5 + m.env.eruption + m.env.plume) * (1.0 - float(m.stats.dustMit)) * (0.8 + randf() * 0.4)
		m.env.dustCover = clampf(m.env.dustCover + add, 0.0, 0.95)
		if m.env.dustCover > 0.45:
			var a3 := damage(m, "instruments", (m.env.dustCover - 0.45) * 8.0 * (0.3 if m.covers_closed else 1.0), "Dust contamination",
				"Dust covers %d%% of exposed surfaces and is getting into instrument optics and joints." % roundi(m.env.dustCover * 100.0))
			if a3 > 0.0:
				out.append({"comp": "instruments", "amount": a3, "src": "Dust"})
	if m.env.stormLeft > 0.0:
		m.env.stormLeft -= 1.0
		if m.env.stormLeft <= 0.0:
			m.env.storm = 0.0
			out.append({"info": "The storm has cleared."})
	m.env.weather = maxf(0.0, m.env.weather - 0.25)
	m.env.eruption = maxf(0.0, m.env.eruption - 0.3)
	m.env.plume = maxf(0.0, m.env.plume - 0.3)
	if m.dest.env.get("radiation") != null:
		m.env.dose = r1(m.env.dose + exposure(m, "radiation") * 10.0 * (1.0 - rating(m, "radiation") * 0.8))
	m.env.surge = maxf(0.0, m.env.surge - 0.4)
	m.shield_attitude = false
	m.heat_shelter = false
	m.covers_closed = false
	return out


static func generation(m: Dictionary) -> float:
	var s: Dictionary = m.stats
	if s.gen == "rtg":
		return float(s.rtg) * (0.6 + 0.4 * (float(m.c.power) / 100.0))
	if s.gen != "solar":
		return 0.0
	var solar: float = cv(m, "solar")
	if m.mode == "cruise":
		return 14.0 * float(s.panel) * 0.6 * (solar / 100.0)
	var g: float = 14.0 * float(s.panel) * minf(1.6, sev(m.dest, "solar")) * (solar / 100.0)
	if m.mode == "surface":
		g *= 1.0 - m.env.dustCover
		g *= 1.0 - 0.75 * m.env.storm
		g *= 1.0 - m.tilt * 0.5
		if m.dest.id == "mercury" and not m.env.day:
			g = 0.0
	return maxf(0.0, g)


static func power_load(m: Dictionary, action_power: float = 0.0) -> float:
	var heaters: float = sev(m.dest, "cold") * 6.0 * (1.0 - float(m.stats.coldTol) * 0.7) + (2.0 if m.dest.id == "mercury" and not m.env.day else 0.0)
	var mode_mul: float = {"full": 1.25, "balanced": 1.0, "survival": 0.55}.get(m.power_mode, 1.0)
	return (7.0 + heaters) * mode_mul + action_power


static func power_step(m: Dictionary, action_power: float = 0.0) -> Dictionary:
	var g := generation(m)
	var l := power_load(m, action_power)
	var cap := battery_cap(m)
	var before: float = m.battery
	m.battery = clampf(before + g - l, 0.0, cap)
	m.spent_power += l
	var brown := false
	if before + g - l < 0.0:
		brown = true
		m.brownouts += 1
		m.brownout_run += 1
		damage(m, "thermal", 5.0, "Power brownout", "Heaters lost power when the battery ran flat.")
		damage(m, "power", 4.0, "Power brownout", "Deep battery discharge damages cells.")
		m.offline.inst = true
	else:
		m.brownout_run = 0
		if m.offline.inst and m.battery > cap * 0.2 and m.power_mode != "survival":
			m.offline.inst = false
	return {"gen": r1(g), "load": r1(l), "cap": roundi(cap), "brown": brown}


## Environmental readouts for the Mission Lab: [[label, value, note, tone]].
static func readouts(m: Dictionary) -> Array:
	var d: Dictionary = m.dest
	var e: Dictionary = d.env
	var st: Dictionary = m.env
	var na: Dictionary = d.get("na", {})
	var rows: Array = []
	if e.get("heat") != null or e.get("cold") != null:
		var t: String = e.heat.shown if e.get("heat") != null else e.cold.shown
		if d.id == "mercury" and m.mode == "surface":
			t = e.heat.shown if st.day else e.cold.shown
		if d.id == "mars":
			t = "−125 °C to +20 °C (daily swing)"
		rows.append(["Temperature", t, "Lander interior: %d °C (simulated)" % roundi(st.interior) if d.id == "venus" and m.mode == "surface" else "", ""])
	rows.append(["Atmospheric pressure", e.pressure.shown if e.get("pressure") != null else "Not applicable", "" if e.get("pressure") != null else na.get("pressure", ""), ""])
	if e.get("dust") != null:
		rows.append(["Dust activity", "STORM (%d%% intensity)" % roundi(st.storm * 100.0) if st.storm > 0.0 else e.dust.shown,
			"Panel / sensor coverage: %d%% (simulated)" % roundi(st.dustCover * 100.0) if m.mode == "surface" else "", "bad" if st.storm > 0.0 else ("warn" if st.dustCover > 0.4 else "")])
	else:
		rows.append(["Dust activity", "Not applicable", na.get("dust", ""), ""])
	rows.append(["Terrain condition", e.terrain.shown if e.get("terrain") != null else "Not applicable",
		("Site: %s" % m.site.name if m.site.has("name") else "") if e.get("terrain") != null else na.get("terrain", ""), ""])
	rows.append(["Radiation level", e.radiation.shown if e.get("radiation") != null else "Low",
		"Accumulated dose (simulated): %d units%s" % [roundi(st.dose), " · SURGE" if st.surge > 0.0 else ""], "bad" if st.surge > 0.0 else ""])
	rows.append(["Wind", e.wind.shown if e.get("wind") != null else "Not applicable",
		("Elevated (event active)" if st.storm > 0.0 or st.weather > 0.0 else "") if e.get("wind") != null else na.get("wind", ""), ""])
	rows.append(["Sunlight for power", e.solar.shown if e.get("solar") != null else "—", "Not needed: RTG power" if m.stats.gen == "rtg" else "", ""])
	if e.get("geology") != null and float(e.geology.sev) > 0.3:
		rows.append(["Geological activity", e.geology.shown, "ACTIVE EVENT" if st.eruption > 0.0 or st.plume > 0.0 else "", "bad" if st.eruption > 0.0 or st.plume > 0.0 else ""])
	if e.get("particles") != null and m.mode != "surface":
		rows.append(["Ring particles", e.particles.shown, "Orbit exposure ×%s" % str(m.orbit.imp) if m.orbit.has("imp") else "", ""])
	rows.append(["Gravity", e.gravity.shown if e.get("gravity") != null else "—", "", ""])
	return rows


## Warnings relevant to the current environment only: [[tone, text]].
static func warnings(m: Dictionary) -> Array:
	var w: Array = []
	for hid in m.dest.hazards:
		var h: Dictionary = CD.HAZARDS[hid]
		if h.get("special", "") == "dust":
			if m.mode == "surface" and m.env.dustCover > 0.3:
				w.append(["bad" if m.env.dustCover > 0.55 else "warn", "Dust on panels and sensors: %d%%. Solar output reduced." % roundi(m.env.dustCover * 100.0)])
			continue
		if m.mode == "cruise":
			continue
		var x := exposure(m, hid, {"driving": true}, true)
		var r := rating(m, hid)
		if x > 0.01 and x > r:
			w.append(["bad" if x - r > 0.3 else "warn", "%s: exposure %d%% exceeds equipment rating %d%%%s." % [h.name, roundi(x * 100.0), roundi(r * 100.0),
				" (while driving)" if h.get("onlyWhen", "") == "driving" else ""]])
	if m.env.storm > 0.0:
		w.append(["bad", "Dust storm: visibility and solar power reduced."])
	if m.dest.get("leaks", false) and m.mode == "surface":
		w.append(["bad" if m.env.interior > 90.0 else "warn", "Interior temperature %d °C and rising." % roundi(m.env.interior)])
	if m.battery < battery_cap(m) * 0.25:
		w.append(["bad", "Battery low: %d units." % roundi(m.battery)])
	if m.offline.comms and not m.backup.comms:
		w.append(["bad", "No contact with Earth."])
	if m.c.has("instruments") and m.c.instruments < 20.0 and not m.backup.inst:
		w.append(["bad", "Instruments below 20%: offline."])
	return w


# ------------------------------------------------------------------ operations

static func enter_segment(m: Dictionary, i: int) -> void:
	m.seg = i
	m.dest = CD.DESTINATIONS[m.segments[i].dest]
	m.mode = "cruise"
	m.orbit = {}
	m.site = {}
	m.landed = false
	m.tilt = 0.0
	m.probe = {}
	m.retreated = false
	for k in ["dustCover", "storm", "stormLeft", "weather", "eruption", "plume", "surge"]:
		m.env[k] = 0.0
	m.env.day = true
	m.env.interior = 25.0


## Applies cruise time and fuel. Returns the number of cruise legs (chances for events).
static func cruise(m: Dictionary) -> int:
	var t: float = 1.7 if m.design.trajectory == "assist" else 1.0
	m.days += roundf(float(CRUISE_DAYS.get(m.segments[m.seg].dest, 300)) * t * (0.6 if m.seg > 0 else 1.0))
	if m.seg == 0:
		var f: float = 8.0 if m.design.trajectory == "assist" else 14.0
		m.fuel = r1(m.fuel - f)
	m.mode = "cruise"
	return maxi(1, roundi(float(m.dest.get("cruise", 1)) * t))


static func arrive(m: Dictionary, orbit_id: String) -> String:
	var seg: Dictionary = m.segments[m.seg]
	var txt := ""
	if seg.mode == "flyby":
		m.mode = "flyby"
		txt = "Gravity-assist flyby: no capture burn needed."
	else:
		if not m.insert_paid:
			var need: float = float(m.dest.insertFuel) + m.nav_debt
			var used := minf(m.fuel, need)
			m.fuel = r1(m.fuel - used)
			m.nav_debt = 0.0
			txt = "Orbit insertion burn: fuel −%d." % roundi(used)
			if used < need:
				m.orbit_sci = 0.6
				txt += " Not enough fuel for the planned orbit: captured into a distant orbit."
		m.mode = "orbit"
	m.insert_paid = false
	m.no_downlink = false
	if m.dest.has("orbits"):
		m.orbit = m.dest.orbits[0]
		for o in m.dest.orbits:
			if o.id == orbit_id:
				m.orbit = o
	m.cycle = 0
	var base: int = int(seg.cycles) if seg.has("cycles") else int(m.dest.cycles) + int(m.diff.cycles)
	m.max_cycles = maxi(2, base)
	return txt


## Touchdown. Returns {text, bad}.
static func land(m: Dictionary, site_id: String) -> Dictionary:
	var site: Dictionary = m.dest.landingSites[0]
	for s in m.dest.landingSites:
		if s.id == site_id:
			site = s
	m.site = site
	m.mode = "surface"
	m.landed = true
	if site.get("water", false) or site.get("liquid", false):
		var what: String = "the ocean" if site.get("water", false) else "a methane sea"
		damage(m, "landing", 100.0, "Landed in %s" % what, "The lander was not designed to float.")
		damage(m, "structure", 45.0, "Splashdown", "Liquid entered the lander body.")
		damage(m, "instruments", 40.0, "Splashdown", "Instruments were flooded.")
		damage(m, "power", 30.0, "Splashdown", "Short circuits.")
		damage(m, "rover", 100.0, "Splashdown", "The rover cannot drive off a floating lander.")
		m.tilt = 0.5
		return {"text": "The lander came down in %s. It is not built to float, and most systems are badly damaged." % what, "bad": true}
	var avoid: float = float(m.stats.hazardAvoid) * nav_factor(m)
	var risk: float = float(site.rough) * (1.0 - avoid * 0.85) * (1.5 if m.env.weather > 0.0 else 1.0) * (1.0 + (randf() * 2.0 - 1.0) * float(m.diff.variability))
	var ld := damage(m, "landing", risk * 50.0, "Touchdown on %s" % site.name.to_lower(), "Terrain roughness %d%%, hazard avoidance %d%%." % [roundi(float(site.rough) * 100.0), roundi(avoid * 100.0)])
	if risk > 0.45:
		damage(m, "structure", (risk - 0.45) * 30.0, "Hard landing", "The lander hit a slope or boulder.")
	m.tilt = clampf((risk - 0.2) * 0.9, 0.0, 0.45) * (1.0 - cv(m, "landing") / 200.0)
	var text: String = "Touchdown! Landing equipment −%s%%." % str(ld) if ld > 0.0 else "A perfect touchdown."
	if m.tilt > 0.12:
		text += " The lander rests on a %d° slope, reducing solar output." % roundi(m.tilt * 40.0)
	if m.stats.hazardAvoid > 0.6:
		text += " Terrain-relative navigation steered around the worst hazards."
	return {"text": text, "bad": ld > 25.0}


static func _inst_for(m: Dictionary, tag: String) -> Dictionary:
	for i in CD.INSTRUMENTS:
		if i.tag == tag and m.design.instruments.has(i.id):
			return i
	return {}


static func backup_options(m: Dictionary) -> Array:
	var o: Array = []
	if m.stats.backupComms and not m.backup.comms and (m.c.comms < 40.0 or m.offline.comms):
		o.append({"id": "comms", "label": "Backup low-gain antenna"})
	if m.stats.backupInst and not m.backup.inst and (cv(m, "instruments") < 30.0 or m.offline.inst):
		o.append({"id": "inst", "label": "Redundant instrument electronics"})
	if m.stats.backupNav and not m.backup.nav and (m.c.nav < 50.0 or m.offline.nav):
		o.append({"id": "nav", "label": "Second star tracker"})
	return o


static func activate_backup(m: Dictionary, id: String) -> void:
	m.backup[id] = true
	m.offline[id] = false


static func retreat(m: Dictionary) -> String:
	m.retreated = true
	m.mode = "orbit"
	return "Surface operations ended. The orbiter continues with remote sensing. Objectives that need the surface can be changed to orbital versions."


## Every action available now. kind: "cycle" (uses one cycle) or "free".
static func actions(m: Dictionary) -> Array:
	var a: Array = []
	var blocked_n := 0
	for o in m.objectives:
		if o.status != "active" or int(o.seg) != int(m.seg):
			continue
		if permanently_blocked(m, o) != "" and modified_options(m, o).size() > 0:
			blocked_n += 1
		if o.tag == "probe":
			if m.mode in ["probe", "orbit"] and m.dest.type == "probe" and m.probe.is_empty():
				a.append({"id": "probe", "label": "Release the atmospheric probe", "sub": "one-way descent: data until it is crushed or runs out of power", "kind": "cycle", "obj": o.id})
			continue
		if o.tag == "drive":
			if m.mode == "surface" and not m.retreated:
				var b := objective_blocked(m, o)
				a.append({"id": "drive:" + o.id, "label": "%s: %s" % ["Fly" if m.stats.rotor else "Drive", o.name],
					"sub": b if b != "" else "progress %s/%s · rover %d%%" % [str(r1(o.collected)), str(o.units), roundi(cv(m, "rover"))], "kind": "cycle", "disabled": b != "", "obj": o.id})
			continue
		if not can_attempt(m, o):
			continue
		var bl := objective_blocked(m, o)
		var inst := _inst_for(m, o.tag)
		a.append({"id": "sci:" + o.id, "label": "%sCollect: %s" % ["★ " if o.primary else "", o.name],
			"sub": bl if bl != "" else "collected %s/%s · sent %s · power −%d" % [str(r1(o.collected)), str(o.units), str(r1(o.returned)), int(inst.get("power", 2)) + 2],
			"kind": "cycle", "disabled": bl != "", "obj": o.id})
	if m.mode == "surface" and m.stats.dustMit > 0.0 and m.c.has("solar") and m.env.dustCover > 0.05:
		a.append({"id": "clean", "label": "Clean the solar panels", "sub": "dust %d%% → %d%%" % [roundi(m.env.dustCover * 100.0), roundi(m.env.dustCover * 35.0)], "kind": "cycle"})
	var damaged := false
	for k in m.c:
		if m.c[k] < 100.0:
			damaged = true
	a.append({"id": "repair", "label": "Repair a component", "sub": "uses 1 of %d spare kits · +%d%%" % [m.spares, roundi(25.0 * float(m.diff.repairMul))] if m.spares > 0 else "no spare kits left",
		"kind": "cycle", "disabled": m.spares <= 0 or not damaged})
	if m.c.has("instruments"):
		a.append({"id": "recal", "label": "Recalibrate instruments", "sub": "no spares needed · instruments +6% · clears faults", "kind": "cycle", "disabled": m.c.instruments >= 100.0 and not m.offline.inst})
	if m.dest.has("orbits") and m.mode != "surface":
		a.append({"id": "orbit", "label": "Change orbit", "sub": "fuel −6 · now: %s" % m.orbit.get("name", "—"), "kind": "cycle", "disabled": m.fuel < 6.0})
	a.append({"id": "hold", "label": "Hold and recharge", "sub": "low-power cycle, sends waiting data", "kind": "cycle"})
	a.append({"id": "lab", "label": "Open the Mission Lab", "sub": "environmental monitoring · why each system is changing", "kind": "free"})
	a.append({"id": "power", "label": "Power management (now: %s)" % m.power_mode, "sub": "prioritise essential systems", "kind": "free"})
	var bk := backup_options(m)
	if bk.size() > 0:
		var names: Array = []
		for b2 in bk:
			names.append(b2.label)
		a.append({"id": "backup", "label": "Switch to backup systems", "sub": ", ".join(PackedStringArray(names)), "kind": "free"})
	if blocked_n > 0:
		a.append({"id": "adapt", "label": "Change exploration objectives", "sub": "%d objective(s) can no longer be done as planned" % blocked_n, "kind": "free"})
	if m.mode == "surface" and not m.retreated:
		a.append({"id": "retreat", "label": "Orbital retreat: end surface operations", "sub": "continue with remote sensing from orbit", "kind": "free"})
	a.append({"id": "end", "label": "Finish here and continue the journey" if m.segments.size() - 1 > m.seg else "End the mission now",
		"sub": "%d %ss left" % [int(m.max_cycles) - int(m.cycle), m.dest.cycleName], "kind": "free"})
	return a


## Performs an action that uses a cycle. Returns {text, ctx, power}.
static func perform(m: Dictionary, id: String, arg: String = "") -> Dictionary:
	var ctx := {}
	var power := 0.0
	var text := ""
	m.last_action = id.split(":")[0]
	var penalty: float = (0.8 if m.yield_penalty > 0 else 1.0) * (0.6 if m.unreliable > 0 else 1.0)
	if id.begins_with("sci:"):
		var o := obj_of(m, id.substr(4))
		power = float(_inst_for(m, o.tag).get("power", 2)) + 2.0
		var site: float = float(m.site.get("sci", 1.0)) if m.mode == "surface" else float(m.orbit.get("sci", 1.0)) * float(m.orbit_sci)
		var vis: float = 0.55 if m.env.storm > 0.0 and o.tag == "imaging" else 1.0
		var y: float = 1.05 * inst_factor(m) * site * penalty * vis * (2.0 if m.burst else 1.0) * (1.2 if m.mode == "flyby" else 1.0) * (0.85 if m.tilt > 0.12 and m.mode == "surface" else 1.0)
		if m.retreated and o.mode == "surface":
			y = 0.0
		y = minf(y, o.units - o.collected + 0.01)
		var got := add_data(m, o, y)
		text = "%s: collected %s units of data." % [o.name, str(got)] if got > 0.0 else "%s: no useful data this cycle." % o.name
		m.burst = false
	elif id.begins_with("drive:"):
		var o2 := obj_of(m, id.substr(6))
		var route := arg if arg != "" else "safe"
		ctx = {"driving": true, "route": route}
		power = 7.0 if m.stats.rotor else 4.0
		var prog: float = (1.05 if route == "direct" else 0.7) * nav_factor(m) * (0.45 + 0.55 * (cv(m, "rover") / 100.0)) * (0.6 if m.drive_slow else 1.0) * (0.55 if m.env.storm > 0.0 else 1.0) * (1.3 if m.stats.rotor else 1.0)
		m.drive_slow = false
		var got2 := add_data(m, o2, minf(prog, o2.units - o2.collected + 0.01))
		text = "%s %s: progress +%s." % ["Flew" if m.stats.rotor else "Drove", "the direct route" if route == "direct" else "the safe route", str(got2)]
	elif id == "clean":
		m.env.dustCover = r1(m.env.dustCover * 0.35)
		power = 2.0
		text = "Panels cleaned. Dust now %d%%." % roundi(m.env.dustCover * 100.0)
	elif id == "repair":
		m.spares -= 1
		var a := heal(m, arg, 25.0 * float(m.diff.repairMul))
		if arg == "instruments":
			m.offline.inst = false
		if arg == "comms":
			m.offline.comms = false
		if arg == "nav":
			m.offline.nav = false
		power = 3.0
		text = "Repaired %s: +%s%%." % [comp_name(arg), str(a)]
	elif id == "recal":
		heal(m, "instruments", 6.0)
		m.offline.inst = false
		m.unreliable = 0
		power = 2.0
		text = "Instruments recalibrated."
	elif id == "orbit":
		for ob in m.dest.orbits:
			if ob.id == arg:
				m.orbit = ob
		m.fuel -= 6.0
		power = 1.0
		text = "New orbit: %s." % m.orbit.name
	elif id == "hold":
		ctx = {"hold": true}
		text = "Holding. Batteries charging, data downlinking."
	return {"text": text, "ctx": ctx, "power": power}


## End of a cycle: environment, power, downlink, time. Returns {dmg, power, sent}.
static func end_cycle(m: Dictionary, ctx: Dictionary = {}, power: float = 0.0) -> Dictionary:
	var dmg := tick(m, ctx)
	var hold: bool = ctx.get("hold", false)
	var p := power_step(m, maxf(0.0, power) - (3.0 if hold else 0.0))
	var sent := 0.0
	if not m.no_downlink:
		sent = downlink(m, float(m.down_mul) * (1.4 if hold else 1.0))
	m.no_downlink = false
	m.down_mul = 1.0
	if m.yield_penalty > 0:
		m.yield_penalty -= 1
	if m.unreliable > 0:
		m.unreliable -= 1
	if m.crewed:
		m.crew_rest = maxf(0.0, m.crew_rest - 6.0)
		if m.crew_rest < 30.0:
			m.crew -= 4.0
	m.cycle += 1
	m.cycles_used += 1
	m.days = r1(m.days + float(CYCLE_DAYS.get(m.dest.id, 1.0)))
	if m.dest.id == "mercury":
		m.env.day = m.cycle >= 2 and m.cycle < 8
	check_fail(m)
	return {"dmg": dmg, "power": p, "sent": sent}


## After operations end, the orbiter keeps relaying stored data for a while.
static func final_relay(m: Dictionary) -> Dictionary:
	var s := 0.0
	for _i in 3:
		s += downlink(m, 1.0)
	var left := queued(m)
	if left > 0.0:
		m.lost = r1(m.lost + left)
		m.queue.clear()
	return {"sent": r1(s), "lost": left}


# ------------------------------------------------------------------ atmospheric probe

static func probe_start(m: Dictionary, entry: String) -> String:
	var heat: float = 14.0 if entry == "steep" else 6.0
	m.probe = {"level": -1, "integrity": 100.0 - heat * (1.0 + (randf() * 2.0 - 1.0) * float(m.diff.variability)),
		"battery": 100.0 - (14.0 if entry == "shallow" else 6.0), "buffer": 0.0, "alive": true, "max_bar": 0.0, "end": ""}
	m.mode = "probe"
	return "Entry at %s. The heat shield took the plasma. Probe integrity %d%%." % ["a steep angle: fast but hot" if entry == "steep" else "a shallow angle: gentle heating, longer drain on the probe battery", roundi(m.probe.integrity)]


## The next depth level {i, bar, temp}, or {} when the deepest planned level has been passed.
static func probe_level(m: Dictionary) -> Dictionary:
	var levels: Array = m.dest.probe.levels
	var i: int = int(m.probe.level) + 1
	if i >= levels.size():
		return {}
	return {"i": i, "bar": float(levels[i][0]), "temp": float(levels[i][1])}


static func _probe_relay(m: Dictionary, o: Dictionary, u: float) -> void:
	if u <= 0.0 or o.is_empty():
		return
	o.collected = r1(minf(o.units, o.collected + u))
	if comms_rate(m) > 0.0 and not m.no_downlink:
		o.returned = r1(minf(o.units, o.returned + u))
		m.sent = r1(m.sent + u)
		if o.returned >= o.units - 0.05:
			o.status = "done"
	else:
		m.queue.append({"obj": o.id, "units": r1(u)})


## One step deeper. choice: "measure" (more data, sent on the next step) or "transmit" (less data, sent now).
static func probe_step(m: Dictionary, choice: String) -> Dictionary:
	var pr: Dictionary = m.probe
	var s: Dictionary = m.stats
	var o := {}
	for x in m.objectives:
		if x.tag == "probe" and int(x.seg) == int(m.seg):
			o = x
	if pr.buffer > 0.0:
		_probe_relay(m, o, pr.buffer)
		pr.buffer = 0.0
	var lv := probe_level(m)
	if lv.is_empty():
		pr.alive = false
		pr.end = "The probe reached the deepest planned level and its batteries ran out."
		return {"done": true}
	pr.level = lv.i
	var ratio: float = lv.bar / maxf(1.0, float(s.probeBar))
	var t_ex: float = maxf(0.0, (lv.temp - float(s.probeHeat)) / 100.0)
	var cold: float = maxf(0.0, 0.75 - float(s.coldTol)) * 6.0 if lv.temp < -150.0 else 0.0
	var wind: float = float(m.dest.probe.windSev) * (1.0 if lv.i < 4 else 0.6)
	var buffet: float = wind * (1.0 - maxf(0.4, float(s.windTol)) * 0.6)
	var loss: float = (maxf(0.0, ratio - 0.7) * 70.0) + t_ex * 45.0 + buffet * 5.0 + cold
	loss *= 1.0 + (randf() * 2.0 - 1.0) * float(m.diff.variability)
	pr.integrity = r1(pr.integrity - maxf(0.0, loss))
	pr.battery -= 11.0
	pr.max_bar = lv.bar
	var units := r1((0.55 if choice == "transmit" else 0.85) * maxf(0.4, 1.0 - buffet * 0.35))
	var hist := {"bar": lv.bar, "temp": lv.temp, "integrity": maxi(0, roundi(pr.integrity)), "units": units}
	if pr.integrity <= 0.0:
		pr.alive = false
		pr.end = "Signal lost at about %s bar and %d °C: the probe was %s.%s" % [str(lv.bar), roundi(lv.temp),
			"crushed by the pressure" if ratio > 1.0 else ("overheated" if t_ex > 0.0 else "torn apart by the turbulence"),
			" Its last measurements had not been sent yet and are lost." if choice == "measure" else ""]
		if choice == "transmit":
			_probe_relay(m, o, units)
		return {"done": true, "hist": hist}
	if choice == "transmit":
		_probe_relay(m, o, units)
	else:
		pr.buffer = units
	if pr.battery <= 0.0:
		_probe_relay(m, o, pr.buffer)
		pr.buffer = 0.0
		pr.alive = false
		pr.end = "The probe battery ran out at %s bar." % str(lv.bar)
		return {"done": true, "hist": hist}
	return {"done": false, "hist": hist}
