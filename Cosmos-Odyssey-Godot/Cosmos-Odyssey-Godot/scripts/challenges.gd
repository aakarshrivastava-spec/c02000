extends RefCounted
## Universal Mission Challenge System (Category B), planetary environment events (Category A)
## and engineering decisions. Every consequence is worked out from the live mission state.
## Ported from the web version (src/campaign/challenges.js).

const CD = preload("res://scripts/campaign_data.gd")
const M = preload("res://scripts/mission.gd")

const JOVIAN := ["jupiter", "europa", "io", "saturn", "mercury", "mars"]
const FAR := ["mars", "jupiter", "saturn", "uranus", "neptune", "europa", "titan", "io", "enceladus"]
const NOT_RANDOM := ["budgetTrap", "massLimit", "fuelShortage", "diagnostics", "launchWindow"]

const EVENTS := [
	# ---- Category B: universal ----
	{"id": "powerCrisis", "cat": "universal", "title": "CHALLENGE 01 — POWER CRISIS", "phases": ["cruise", "arrive", "ops"]},
	{"id": "commsBlackout", "cat": "universal", "title": "CHALLENGE 02 — COMMUNICATION BLACKOUT", "phases": ["cruise", "arrive", "ops"]},
	{"id": "navError", "cat": "universal", "title": "CHALLENGE 03 — NAVIGATION ERROR", "phases": ["cruise", "ops"]},
	{"id": "instrumentFailure", "cat": "universal", "title": "CHALLENGE 04 — INSTRUMENT FAILURE", "phases": ["ops"]},
	{"id": "structuralAlert", "cat": "universal", "title": "CHALLENGE 05 — STRUCTURAL ALERT", "phases": ["cruise", "ops"]},
	{"id": "budgetTrap", "cat": "universal", "title": "CHALLENGE 06 — THE BUDGET TRAP", "phases": ["design"]},
	{"id": "massLimit", "cat": "universal", "title": "CHALLENGE 07 — MASS LIMIT EXCEEDED", "phases": ["launch"]},
	{"id": "fuelShortage", "cat": "universal", "title": "CHALLENGE 08 — FUEL SHORTAGE", "phases": ["arrive"]},
	{"id": "launchWindow", "cat": "universal", "title": "CHALLENGE 09 — THE LAUNCH WINDOW", "phases": ["launch"]},
	{"id": "signal", "cat": "universal", "title": "EVENT 10 — UNIDENTIFIED SIGNAL", "phases": ["cruise", "ops"]},
	{"id": "micrometeoroid", "cat": "universal", "title": "EVENT 11 — MICROMETEOROID ALERT", "phases": ["cruise", "ops"]},
	{"id": "discovery", "cat": "universal", "title": "EVENT 12 — SCIENTIFIC DISCOVERY", "phases": ["ops"]},
	{"id": "dataCorruption", "cat": "universal", "title": "EVENT 13 — DATA CORRUPTION", "phases": ["ops"]},
	{"id": "orbitDeviation", "cat": "universal", "title": "EVENT 14 — UNEXPECTED ORBITAL DEVIATION", "phases": ["ops"]},
	{"id": "lifeSupport", "cat": "universal", "title": "CHALLENGE 15 — LIFE SUPPORT ALERT", "phases": ["ops"], "crewed": true},
	{"id": "crewSchedule", "cat": "universal", "title": "CHALLENGE 16 — CREW SCHEDULE DISRUPTION", "phases": ["ops"], "crewed": true},
	# ---- Category A: planetary environment ----
	{"id": "dustStorm", "cat": "env", "title": "DUST STORM", "phases": ["ops"], "dests": ["mars"]},
	{"id": "dustDevil", "cat": "env", "title": "DUST DEVIL", "phases": ["ops"], "dests": ["mars"]},
	{"id": "sandTrap", "cat": "env", "title": "ROVER STUCK IN SOFT GROUND", "phases": ["ops"], "dests": ["mars", "titan", "earth"]},
	{"id": "thermalSpike", "cat": "env", "title": "SUNRISE THERMAL SHOCK", "phases": ["ops"], "dests": ["mercury"]},
	{"id": "overheat", "cat": "env", "title": "EQUIPMENT OVERHEATING", "phases": ["ops"], "dests": ["mercury", "venus", "io"]},
	{"id": "pressureCreak", "cat": "env", "title": "PRESSURE FAILURE WARNING", "phases": ["ops"], "dests": ["venus"]},
	{"id": "weatherHold", "cat": "env", "title": "WEATHER INTERRUPTION", "phases": ["arrive", "ops"], "dests": ["earth"]},
	{"id": "radSurge", "cat": "env", "title": "RADIATION SURGE", "phases": ["ops", "cruise"], "dests": JOVIAN},
	{"id": "ringCrossing", "cat": "env", "title": "RING PARTICLE HAZARD", "phases": ["ops"], "dests": ["saturn"]},
	{"id": "stormObs", "cat": "env", "title": "STORM OBSERVATION", "phases": ["ops"], "dests": ["jupiter", "saturn", "neptune", "uranus"]},
	{"id": "deepCold", "cat": "env", "title": "EXTREME COLD: HEATER FAULT", "phases": ["ops", "cruise"], "dests": ["uranus", "neptune", "europa", "titan", "enceladus"]},
	{"id": "iceFracture", "cat": "env", "title": "ICE FRACTURE AHEAD", "phases": ["ops"], "dests": ["europa", "enceladus"]},
	{"id": "eruption", "cat": "env", "title": "VOLCANIC ERUPTION", "phases": ["ops"], "dests": ["io"]},
	{"id": "terrainShift", "cat": "env", "title": "TERRAIN HAS CHANGED", "phases": ["ops"], "dests": ["io"]},
	{"id": "plumeBurst", "cat": "env", "title": "PLUME OUTBURST", "phases": ["ops"], "dests": ["enceladus"]},
	{"id": "hydrocarbon", "cat": "env", "title": "EQUIPMENT COMPATIBILITY: HYDROCARBONS", "phases": ["ops"], "dests": ["titan"]},
	{"id": "hazeNav", "cat": "env", "title": "NAVIGATION IN THE HAZE", "phases": ["ops"], "dests": ["titan"]},
	{"id": "lowGHop", "cat": "env", "title": "LOW-GRAVITY NAVIGATION", "phases": ["ops"], "dests": ["enceladus"]},
	{"id": "commsDelay", "cat": "env", "title": "COMMUNICATION DELAY", "phases": ["ops"], "dests": FAR},
	# ---- engineering / science decisions ----
	{"id": "dsnTime", "cat": "eng", "title": "DEEP SPACE NETWORK TIME", "phases": ["ops"]},
	{"id": "sampleTriage", "cat": "eng", "title": "SAMPLE PRIORITISATION", "phases": ["ops"]},
	{"id": "thermalTrade", "cat": "eng", "title": "THERMAL MARGIN TRADE", "phases": ["ops", "cruise"]},
	{"id": "calibration", "cat": "eng", "title": "INSTRUMENT CROSS-CALIBRATION", "phases": ["cruise", "ops"]},
	{"id": "diagnostics", "cat": "eng", "title": "PRE-LAUNCH SYSTEM DIAGNOSTICS", "phases": ["launch"]},
	{"id": "orbitTrim", "cat": "eng", "title": "ORBITAL POSITIONING", "phases": ["ops", "arrive"]},
]


static func by_id(id: String) -> Dictionary:
	for e in EVENTS:
		if e.id == id:
			return e
	return {}


static func _hit(m: Dictionary, id: String, n: float, src: String, why: String = "") -> String:
	var a := M.damage(m, id, n, src, why)
	return "%s −%s%%." % [M.comp_name(id), str(a)] if a > 0.0 else ""


static func _join(parts: Array) -> String:
	var out: Array = []
	for p in parts:
		if p != "":
			out.append(p)
	return " ".join(PackedStringArray(out))


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v)


static func _o(id: String, label: String, sub: String, q: String) -> Dictionary:
	return {"id": id, "label": label, "sub": sub, "q": q}


static func _surf(m: Dictionary) -> bool:
	return m.mode == "surface"


static func _rover_ok(m: Dictionary) -> bool:
	return m.c.has("rover") and m.c.rover > 0.0


static func _burn(m: Dictionary) -> int:
	return roundi(3.0 / M.nav_factor(m))


static func _corrupt(m: Dictionary, frac: float, secondary_only: bool = false) -> void:
	var lost := 0.0
	var keep: Array = []
	for q in m.queue:
		var o := M.obj_of(m, q.obj)
		if not o.is_empty() and not (secondary_only and o.primary):
			var l := M.r1(q.units * frac)
			q.units = M.r1(q.units - l)
			o.collected = M.r1(o.collected - l)
			lost += l
		if q.units > 0.01:
			keep.append(q)
	m.queue = keep
	m.corrupted = M.r1(m.corrupted + lost)


static func _storm(m: Dictionary) -> void:
	m.env.storm = 0.85
	m.env.stormLeft = 3.0 + roundf(randf() * 2.0)


# ------------------------------------------------------------------ eligibility and selection

static func when(m: Dictionary, id: String) -> bool:
	match id:
		"commsBlackout": return not m.offline.comms
		"navError", "micrometeoroid": return m.mode != "surface"
		"instrumentFailure": return m.c.has("instruments") and m.c.instruments > 0.0
		"fuelShortage": return m.fuel < (float(m.dest.insertFuel) + m.nav_debt) * 1.15
		"discovery": return M.inst_factor(m) > 0.0
		"dataCorruption": return M.queued(m) > 0.6
		"orbitDeviation": return m.mode in ["orbit", "probe"]
		"dustStorm": return _surf(m) and m.env.storm <= 0.0
		"dustDevil": return _surf(m) and m.env.dustCover > 0.25 and m.c.has("solar")
		"sandTrap": return _surf(m) and _rover_ok(m) and not m.stats.rotor and m.last_action == "drive"
		"thermalSpike": return _surf(m) and m.cycle >= 1 and m.cycle <= 3
		"overheat": return _surf(m) and M.cv(m, "instruments", 0.0) > 10.0
		"pressureCreak", "eruption", "plumeBurst", "hydrocarbon": return _surf(m)
		"weatherHold": return m.mode != "cruise"
		"radSurge": return M.sev(m.dest, "radiation") > 0.3
		"ringCrossing", "stormObs": return m.mode != "surface"
		"iceFracture", "lowGHop": return _surf(m) and _rover_ok(m)
		"terrainShift", "hazeNav": return _surf(m) and m.c.has("rover")
		"dsnTime": return M.queued(m) > 0.5
		"sampleTriage":
			if not _surf(m):
				return false
			for o in m.objectives:
				if o.status == "active" and o.primary and int(o.seg) == int(m.seg):
					return true
			return false
		"calibration": return m.c.has("instruments")
		"orbitTrim": return m.mode == "orbit"
	return true


static func weight(m: Dictionary, id: String) -> float:
	match id:
		"powerCrisis": return 1.0 + (2.0 if m.battery < 40.0 else 0.0) + (1.0 if M.cv(m, "solar") < 60.0 else 0.0) + (1.0 if m.env.dustCover > 0.4 else 0.0)
		"commsBlackout": return 1.0 + (2.0 if m.c.comms < 60.0 else 0.0)
		"navError": return 1.0 + (2.0 if m.c.nav < 60.0 else 0.0)
		"instrumentFailure": return 1.0 + (2.0 if m.env.dose > 40.0 else 0.0) + (1.0 if m.env.dustCover > 0.4 else 0.0)
		"structuralAlert": return 1.0 + (2.0 if m.c.structure < 70.0 else 0.0)
		"signal": return 0.7
		"micrometeoroid": return 1.0 + (1.0 if m.stats.impactTol < 0.5 else 0.0)
		"discovery", "thermalTrade", "calibration", "terrainShift", "hazeNav": return 0.9
		"lifeSupport": return 1.2
		"dustStorm", "ringCrossing", "plumeBurst": return 1.6
		"dustDevil", "commsDelay": return 0.8
		"sandTrap": return 1.2
		"thermalSpike": return 1.4
		"overheat": return 0.8 + (1.0 - float(m.stats.heatTol))
		"pressureCreak", "weatherHold", "iceFracture", "hydrocarbon": return 1.3
		"radSurge": return 0.6 + M.sev(m.dest, "radiation")
		"deepCold": return 0.8 + (1.0 - float(m.stats.coldTol))
		"eruption": return 1.7
		"sampleTriage": return 1.6 if int(m.stage.get("level", m.stage.get("unlockLevel", 2))) >= 4 else 0.8
	return 1.0


static func eligible(m: Dictionary, e: Dictionary, phase: String) -> bool:
	if not e.phases.has(phase):
		return false
	if e.get("crewed", false) and not m.crewed:
		return false
	if e.has("dests") and not e.dests.has(m.dest.id):
		return false
	return when(m, e.id)


## Random event generator. Depends on the mission stage, design, equipment, current state and past
## events; uses the per-level category weighting; avoids repeating the same event.
static func pick(m: Dictionary, phase: String) -> Dictionary:
	var level := str(int(m.stage.get("level", m.stage.get("unlockLevel", 2))))
	var mix: Dictionary = CD.MIX.get(level, CD.MIX["2"])
	var pool: Array = []
	for e in EVENTS:
		if not NOT_RANDOM.has(e.id) and eligible(m, e, phase):
			pool.append(e)
	if pool.is_empty():
		return {}
	var cats: Array = []
	var tw := 0.0
	for c in ["env", "universal", "eng"]:
		for e in pool:
			if e.cat == c:
				cats.append(c)
				tw += float(mix[c])
				break
	var r := randf() * tw
	var cat: String = cats[0]
	for c in cats:
		r -= float(mix[c])
		if r <= 0.0:
			cat = c
			break
	var sub: Array = []
	var ws: Array = []
	var total := 0.0
	for e in pool:
		if e.cat == cat:
			var w: float = weight(m, e.id) * (0.12 / float(m.used[e.id]) if m.used.has(e.id) else 1.0)
			sub.append(e)
			ws.append(w)
			total += w
	var t := randf() * total
	for i in sub.size():
		t -= ws[i]
		if t <= 0.0:
			return sub[i]
	return sub[sub.size() - 1]


# ------------------------------------------------------------------ text

static func text(m: Dictionary, id: String) -> String:
	var d: Dictionary = m.dest
	match id:
		"powerCrisis":
			var src := "a fault somewhere in the power distribution unit"
			if m.env.dustCover > 0.4:
				src = "dust-covered panels"
			elif M.cv(m, "solar") < 60.0:
				src = "damaged solar panels"
			elif m.c.power < 60.0:
				src = "weakened battery cells"
			m.note = src
			return "The spacecraft reports unexpected power fluctuations. Battery: [b]%d[/b] units. Telemetry hints at %s, but the cause is not confirmed. Identify the source, protect essential systems and preserve the instruments if you can." % [roundi(m.battery), src]
		"commsBlackout":
			return "Mission Control has lost contact with the spacecraft. The last telemetry showed comms at %s. %s Data waiting to be sent: %s units." % [_pct(m.c.comms),
				"A backup low-gain antenna is on board." if m.stats.backupComms else "No backup antenna was carried.", str(M.queued(m))]
		"navError":
			var err := roundi(800.0 + (1.0 - M.nav_factor(m)) * 6000.0 + randf() * 900.0)
			return "The estimated position differs from the planned trajectory by about [b]%d km[/b]. Navigation: %s. Possible causes: a star-tracker error, a thruster misfire, or a small force like sunlight pressure." % [err, _pct(m.c.nav)]
		"instrumentFailure":
			var cause := "An electronics fault"
			if m.env.dose > 40.0:
				cause = "Accumulated radiation dose"
			elif m.env.dustCover > 0.4:
				cause = "Dust in the optics"
			var a := M.damage(m, "instruments", 8.0 + randf() * 8.0, "Instrument failure: %s" % cause.to_lower(), "Readings drifted outside calibration.")
			m.offline.inst = true
			return "A science instrument stopped returning reliable measurements. %s is the most likely cause. Instruments −%s%% (now %s). Readings are suspended until you act." % [cause, str(a), _pct(m.c.instruments)]
		"structuralAlert":
			var s2 := "vibration from the thrusters"
			if M.sev(d, "pressure") > 0.5 and _surf(m):
				s2 = "external pressure"
			elif d.env.get("heat") != null or d.env.get("cold") != null:
				s2 = "repeated heating and cooling"
			m.note = s2
			return "Strain gauges report unexpected stress in the main frame, probably from %s. Structure: %s. Spares left: %d." % [s2, _pct(m.c.structure), m.spares]
		"budgetTrap":
			return "Mission funding has been cut by 20%% (−$%dM). Your design costs $%dM of a new total of $%dM. Review expenses, prioritise science and reconsider equipment." % [roundi(m.budget0 * 0.2), m.totals.cost, roundi(m.budget0 * 0.8)]
		"massLimit":
			return "Final weighing: the payload is [b]%d kg[/b] but the launcher can deliver only [b]%d kg[/b] to this destination on the chosen trajectory." % [m.totals.mass, m.totals.cap]
		"fuelShortage":
			return "Orbit insertion needs about [b]%d[/b] fuel units%s, plus a reserve. You have [b]%d[/b]." % [roundi(float(d.insertFuel) + m.nav_debt),
				" (including the uncorrected navigation error)" if m.nav_debt > 0.0 else "", roundi(m.fuel)]
		"launchWindow":
			return "A %s has delayed the countdown. The planets keep moving: miss the window and the energy needed rises." % ("ground-system fault" if randf() < 0.5 else "weather front")
		"signal":
			return "An unusual repeating signal appears in the instrument data. It does not match any known source in the catalogue. (Unidentified does not mean alien: most signals have natural or technical explanations.)"
		"micrometeoroid":
			return "Tracking predicts a stream of small particles crossing your path. Protection rating: %s." % _pct(m.stats.impactTol * 100.0)
		"discovery":
			var what: String = {"mars": "bright minerals that may have formed in water", "europa": "a fresh-looking reddish streak along a crack",
				"titan": "a rain-darkened patch of ground", "io": "a new lava flow that was not there yesterday",
				"enceladus": "tiny silica grains, a sign of hot water below"}.get(d.id, "an unusual feature in the data")
			return "An unexpected observation stands out: %s. Following it up will take time from the original plan." % what
		"dataCorruption":
			return "Part of the onboard data archive is unreadable. %s units are waiting to be sent; about a third are affected." % str(M.queued(m))
		"orbitDeviation":
			return "The orbit is drifting from its predicted path, probably due to the uneven gravity of the planet and its moons."
		"lifeSupport":
			return "The carbon dioxide scrubber reports abnormal readings. Crew safety: %s." % _pct(m.crew)
		"crewSchedule":
			return "A delay has pushed the crew's work into their sleep period. Crew rest: %s." % _pct(m.crew_rest)
		"dustStorm":
			return "A regional dust storm is rolling toward the landing site. It will cut sunlight and visibility for several %ss. (Mars storms are real: one in 2018 ended the Opportunity rover.) Battery: %d. Power source: %s." % [d.cycleName, roundi(m.battery),
				"RTG, not affected by sunlight" if m.stats.gen == "rtg" else "solar"]
		"dustDevil":
			return "A whirlwind is crossing the plain toward the lander. On Mars, dust devils have cleaned rover panels by chance (Spirit and Opportunity both got lucky this way)."
		"sandTrap":
			return "The rover's wheels are sinking into %s. (Spirit was trapped like this on Mars in 2009 and never escaped.) Rover: %s." % [
				"soft, damp organic sand near the lake shore" if d.id == "titan" else "loose sand hidden under a thin crust", _pct(m.c.rover)]
		"thermalSpike":
			return "The Sun is rising over the horizon. Surface temperature will climb toward +430 °C. Thermal protection: %s (rating %s)." % [_pct(m.c.thermal), _pct(m.stats.heatTol * 100.0)]
		"overheat":
			return "An instrument has passed its temperature limit and is about to shut itself down.%s" % (" Lander interior: %d °C." % roundi(m.env.interior) if d.id == "venus" else "")
		"pressureCreak":
			return "The hull is groaning under 92 bar. A seal near the camera window is weeping. Structure: %s (pressure rating %s)." % [_pct(m.c.structure), _pct(m.stats.pressTol * 100.0)]
		"weatherHold":
			return "A storm front is crossing the landing zone. Strong winds and low cloud are forecast for the next few hours."
		"radSurge":
			return "%s is raising the dose rate sharply. Shielding rating: %s. Accumulated dose: %d." % ["A solar particle event" if d.id in ["mercury", "mars"] else "A burst of energetic particles in the magnetosphere",
				_pct(m.stats.radTol * 100.0), roundi(m.env.dose)]
		"ringCrossing":
			return "The next orbit crosses the ring plane. Particle protection: %s. Orbit: %s." % [_pct(m.stats.impactTol * 100.0), m.orbit.get("name", "—")]
		"stormObs":
			return "A large storm is rotating into view. Powerful winds (%s) make the cloud features change quickly, which complicates long observations." % d.env.wind.shown
		"deepCold":
			return "A heater circuit has failed. Outside: %s. Cold rating: %s. Battery capacity drops in the cold." % [d.env.cold.shown, _pct(m.stats.coldTol * 100.0)]
		"iceFracture":
			return "Hazard cameras show a fracture across the route, with sharp ice blocks on both sides."
		"eruption":
			return "A nearby vent is erupting. Sulfur-rich fallout will reach the lander, and a fresh lava flow may change the terrain around you."
		"terrainShift":
			return "Fresh lava has covered part of your planned route. The old maps are no longer correct."
		"plumeBurst":
			return "The nearest tiger-stripe jet has brightened. Ice grains are raining down on the lander. This is contamination, and also the best sample opportunity of the mission."
		"hydrocarbon":
			return "Liquid methane and ethane droplets are soaking into seals and joints. At −179 °C many plastics turn brittle. Coating rating: %s." % _pct(m.stats.corrTol * 100.0)
		"hazeNav":
			return "Thick orange haze hides landmarks. Navigation cameras struggle to match features."
		"lowGHop":
			return "With gravity about 1% of Earth's, the rover barely presses on the ground. Wheels spin and the rover bounces."
		"commsDelay":
			return "Commands take %s to arrive. A hazard ahead needs a decision faster than Earth can respond." % d.science.lightTime
		"dsnTime":
			return "Another mission needs the big antennas on Earth. %s units of your data are waiting." % str(M.queued(m))
		"sampleTriage":
			return "The science team argues: analyse the primary target now, or a promising secondary target that may disappear (dust, frost, lava)."
		"thermalTrade":
			return "Engineers can lower the heater set-points to save power. Battery %d, thermal %s." % [roundi(m.battery), _pct(m.c.thermal)]
		"calibration":
			return "A calibration opportunity: point the instruments at a known reference target."
		"diagnostics":
			return "Final system checks on the pad. One reading from the navigation unit looks slightly out of family."
		"orbitTrim":
			return "The orbit is slightly too low. Atmospheric drag will slowly pull you down."
	return ""


# ------------------------------------------------------------------ options

static func options(m: Dictionary, id: String) -> Array:
	var o: Array = []
	var rtg: bool = m.stats.gen == "rtg"
	match id:
		"powerCrisis":
			o = [_o("diag", "Run diagnostics, then isolate the faulty circuit", "takes one cycle · battery −6 · finds the cause", "good"),
				_o("survival", "Prioritise essentials: switch to survival mode", "loads −45% · science paused", "good"),
				_o("shed", "Redistribute: turn off the science instruments only", "instruments offline one cycle · battery +8", "fair"),
				_o("ignore", "Keep everything running", "battery −%d · brownout likely if low" % roundi(minf(m.battery, 28.0)), "poor")]
		"commsBlackout":
			o = [_o("safe", "Analyse telemetry and wait for the safe-mode contact", "no data sent this cycle · contact restored", "good")]
			if m.stats.backupComms:
				o.append(_o("lga", "Switch to the backup low-gain antenna", "slow but reliable", "good"))
			o.append(_o("reboot", "Command a comms computer reboot", "%d%% chance of instant fix · otherwise comms −12%%" % roundi(40.0 + m.c.comms * 0.5), "fair"))
		"navError":
			o = [_o("correct", "Plan and perform a correction burn now", "fuel −%d" % _burn(m), "good"),
				_o("remeasure", "Re-measure first, then decide", "two more days of tracking · 70%%: smaller burn (fuel −%d) · 30%%: error grows" % ceili(_burn(m) / 2.0), "good"),
				_o("ignore", "No correction", "free now · arrival costs more fuel later", "poor")]
		"instrumentFailure":
			o = [_o("compare", "Run diagnostics and cross-check with other instruments", "one cycle · recalibrate (instruments +6%)", "good")]
			if m.stats.backupInst and not m.backup.inst:
				o.append(_o("backup", "Activate the redundant instrument electronics", "backup in place permanently", "good"))
			o.append(_o("push", "Keep using it as is", "40% of new data will be unreliable for two cycles", "poor"))
		"structuralAlert":
			o = [_o("inspect", "Inspect and reduce operations", "one cycle · stress reduced", "good")]
			if m.spares > 0:
				o.append(_o("repair", "Inspect and repair with a spare kit", "uses 1 spare · structure +12%", "good"))
			o.append(_o("ignore", "Continue as planned", "structure damage grows", "poor"))
		"budgetTrap":
			o = [_o("redesign", "Review and redesign the spacecraft", "opens the design screen with the new budget", "good")]
		"massLimit":
			o = [_o("redesign", "Remove components or change the launcher (redesign)", "opens the design screen", "good")]
		"fuelShortage":
			var need: float = float(m.dest.insertFuel) + m.nav_debt
			if M.sev(m.dest, "pressure") > 0.01:
				o.append(_o("aero", "Aerobrake: use the atmosphere to slow down over many passes", "fuel −%d · structure and thermal stress · +2 days" % roundi(need * 0.45), "good"))
			o.append(_o("loose", "Enter a looser, higher orbit", "fuel −%d · orbital science −25%%" % roundi(need * 0.65), "fair"))
			o.append(_o("full", "Do the full burn and keep no reserve", "fuel −%d" % roundi(need), "poor"))
		"launchWindow":
			o = [_o("wait", "Hold for the backup date in the same window", "budget −$15M (team and pad time) · +12 days", "good"),
				_o("late", "Launch late in the window", "fuel −8 for the extra energy", "fair"),
				_o("force", "Push through marginal weather", "saves time · 35% chance of vibration damage", "poor")]
		"signal":
			o = [_o("analyse", "Record and analyse it properly", "one cycle · battery −6 · needs working instruments", "good"),
				_o("log", "Log it and stay on schedule", "free", "fair"),
				_o("divert", "Divert the mission to chase it", "two cycles · fuel −6 · large science gain if instruments work", "fair")]
		"micrometeoroid":
			o = [_o("shield", "Turn the antenna dish into the stream as a shield", "no contact for one cycle · much less damage", "good"),
				_o("continue", "Continue normal operations", "expected damage about %d%%" % roundi((1.0 - float(m.stats.impactTol)) * 14.0), "good" if m.stats.impactTol > 0.7 else "poor")]
		"discovery":
			o = [_o("study", "Investigate as a new secondary objective", "adds a bonus objective (2 units)", "good"), _o("note", "Note it and keep to the original plan", "free", "fair")]
		"dataCorruption":
			o = [_o("backup", "Check the redundant memory for copies", "one cycle · recovers most data", "good"),
				_o("prioritise", "Recover the most important (primary) datasets first", "primary data safe · secondary data loses 35%", "good"),
				_o("accept", "Accept the loss and move on", "35% of waiting data lost", "poor")]
		"orbitDeviation":
			o = [_o("correct", "Correct the orbit", "fuel −%d" % _burn(m), "good"), _o("adapt", "Adapt the observation schedule instead", "free · science yield −20% for 2 cycles", "fair")]
		"lifeSupport":
			o = [_o("backup", "Switch to the backup scrubber and inspect", "one cycle · crew safety protected", "good"),
				_o("restrict", "Restrict crew activity to save air", "one cycle of science lost", "fair"), _o("monitor", "Keep monitoring", "crew safety −25%", "poor")]
		"crewSchedule":
			o = [_o("reorg", "Reorganise tasks and protect sleep", "one cycle lost", "good"), _o("push", "Push through", "crew rest −40% · error risk", "poor")]
		"dustStorm":
			o = [_o("survive", "Enter survival mode before it arrives", "loads −45% · less science while it lasts", "fair" if rtg else "good"),
				_o("work", "Keep working through it", "RTG keeps power steady" if rtg else "risky: solar output will crash", "good" if rtg else "poor")]
		"dustDevil":
			o = [_o("watch", "Point the panels into it and hope", "60% chance: dust cleared", "fair"), _o("image", "Film it for science", "bonus science · no cleaning", "good")]
		"sandTrap":
			o = [_o("slow", "Plan a slow, careful reverse", "one extra cycle · small wear", "good"), _o("power", "Full power to all wheels", "50%: free quickly · 50%: motor damage", "poor")]
		"thermalSpike":
			o = [_o("shade", "Turn the sunshade toward the Sun and shut the instrument covers", "science paused one cycle · heat damage reduced", "good"),
				_o("observe", "Observe the sunrise anyway", "bonus thermal science · heat damage risk", "fair")]
		"overheat":
			o = [_o("cool", "Let it shut down and cool", "instruments offline this cycle", "good"), _o("override", "Override the safety limit", "keep collecting · instruments −15%", "poor")]
		"pressureCreak":
			o = [_o("burst", "Run every instrument now in one burst", "double data on the next collection · battery −15", "good"),
				_o("seal", "Close the window shutter to protect the seal", "slower science · structure protected", "fair")]
		"weatherHold":
			o = [_o("wait", "Wait for the weather to clear", "lose time (+1 day) · safe", "good"), _o("go", "Go ahead in the storm", "wind loads on the vehicle", "poor")]
		"radSurge":
			o = [_o("safe", "Enter safe mode until it passes", "one cycle without science · radiation rating +10%", "good"), _o("measure", "Measure the surge (it is good science)", "bonus science · full exposure", "fair")]
		"ringCrossing":
			o = [_o("dish", "Point the dish forward as a shield (Cassini did this)", "no data sent this cycle · protection +30%", "good"),
				_o("sample", "Point the instruments forward to sample particles", "bonus science · more impacts", "fair")]
		"stormObs":
			o = [_o("mosaic", "Take a quick mosaic now", "reliable, smaller gain", "good"), _o("long", "Track it for a full rotation", "one cycle · bigger gain if navigation is 50% or better", "fair")]
		"deepCold":
			if m.spares > 0:
				o.append(_o("spare", "Switch to a spare heater using a repair kit", "uses 1 spare · thermal +10%", "good"))
			o.append(_o("reroute", "Reallocate power to the remaining heaters", "battery −15 · no science this cycle", "good"))
			o.append(_o("accept", "Accept colder electronics", "power and instruments damage", "poor"))
		"iceFracture":
			o = [_o("around", "Map it and drive around", "one cycle · safe", "good"), _o("cross", "Cross at the narrowest point", "saves time · wheel damage risk", "poor")]
		"eruption":
			o = [_o("stow", "Close instrument covers and stow the arm", "no science this cycle · contamination prevented", "good"), _o("film", "Film the eruption", "bonus science · fallout on equipment", "fair")]
		"terrainShift":
			o = [_o("remap", "Re-map the area before moving", "one cycle", "good"), _o("old", "Use the old map", "rover damage risk", "poor")]
		"plumeBurst":
			var ms: bool = m.totals.tags.has("plume")
			o = [_o("collect", "Open the sample inlet and collect fallout", "plume objective +1.5 · panels and optics coated" if ms else "no mass spectrometer carried", "good" if ms else "poor"),
				_o("protect", "Close covers and wait", "contamination avoided", "fair")]
		"hydrocarbon":
			o = [_o("heat", "Warm the joints with waste heat", "battery −10 · protects mechanisms", "good"), _o("ignore", "Carry on", "damage depends on the coating", "poor")]
		"hazeNav":
			o = [_o("radar", "Navigate by short careful hops", "slower travel this cycle · safe", "good"), _o("dead", "Navigate by dead reckoning", "navigation errors build up", "poor")]
		"lowGHop":
			o = [_o("slow", "Drive at crawl speed", "drive progress −40% this cycle", "good"), _o("fast", "Drive at normal speed", "bounce damage risk", "poor")]
		"commsDelay":
			o = [_o("auto", "Trust onboard autonomy", "works well if navigation is 50% or better", "good"), _o("wait", "Stop and wait for Earth", "one cycle lost · safe", "fair")]
		"dsnTime":
			o = [_o("pay", "Pay for extra antenna time", "budget −$10M · double downlink this cycle", "good"), _o("share", "Share the antenna", "half downlink this cycle", "fair")]
		"sampleTriage":
			o = [_o("primary", "Primary first", "protects the critical requirements", "good"), _o("secondary", "Grab the secondary target", "bonus science · primary delayed", "fair")]
		"thermalTrade":
			o = [_o("keep", "Keep thermal margins", "safe", "good"), _o("lower", "Lower the set-points", "battery +12 · thermal −5%", "fair")]
		"calibration":
			o = [_o("cal", "Calibrate now", "one cycle (none in cruise) · instruments +5%", "good"), _o("skip", "Skip it", "free", "fair")]
		"diagnostics":
			o = [_o("check", "Stop and check it", "budget −$5M · +2 days", "good"), _o("go", "It is within limits. Launch.", "navigation −15% later", "poor")]
		"orbitTrim":
			o = [_o("raise", "Raise the orbit", "fuel −%d" % _burn(m), "good"), _o("leave", "Leave it", "drag: structure and solar stress", "poor")]
	return o


# ------------------------------------------------------------------ consequences

static func _spend_budget(m: Dictionary, v: float) -> void:
	m.budget -= v
	m.spent_budget += v


static func _drain(m: Dictionary, v: float) -> void:
	m.battery = maxf(0.0, m.battery - v)


static func run(m: Dictionary, id: String, opt: String) -> String:
	var s: Dictionary = m.stats
	match id + ":" + opt:
		"powerCrisis:diag":
			_drain(m, 6.0)
			m.skip = 1
			M.heal(m, "power", 4.0)
			return "Diagnostics traced it to %s. The faulty circuit is isolated. Power systems +4%%." % m.note
		"powerCrisis:survival":
			m.power_mode = "survival"
			m.offline.inst = true
			return "Non-essential systems shed. Heaters, computer and radio protected. You can change the power mode later."
		"powerCrisis:shed":
			m.offline.inst = true
			m.battery += 8.0
			return "Instruments switched off. Power recovers slowly."
		"powerCrisis:ignore":
			var before: float = m.battery
			_drain(m, 28.0)
			if before < 28.0:
				m.brownouts += 1
				return _join(["The fluctuations continued. Brownout!", _hit(m, "thermal", 8.0, "Power crisis (ignored)"), _hit(m, "power", 8.0, "Power crisis (ignored)")])
			return "The fluctuations continued."
		"commsBlackout:safe":
			m.no_downlink = true
			return "The spacecraft entered safe mode and called home on schedule. Contact restored."
		"commsBlackout:lga":
			m.backup.comms = true
			return "Backup antenna active. Data trickles home."
		"commsBlackout:reboot":
			if randf() * 100.0 < 40.0 + m.c.comms * 0.5:
				return "Reboot worked. Contact restored immediately."
			m.no_downlink = true
			return _join(["The reboot failed and the radio had to recover slowly.", _hit(m, "comms", 12.0, "Failed comms reboot")])
		"navError:correct":
			m.fuel -= _burn(m)
			return "Correction burn complete. Back on course."
		"navError:remeasure":
			m.days += 2.0
			if randf() < 0.7:
				m.fuel -= ceili(_burn(m) / 2.0)
				return "The new fix was better than feared. A small trim fixed it."
			m.fuel -= _burn(m) + 4
			return "The error had grown. A larger burn was needed."
		"navError:ignore":
			m.nav_debt += _burn(m) * 2.0
			return "Trajectory left uncorrected. The fuel bill will come later."
		"instrumentFailure:compare":
			m.skip = 1
			m.offline.inst = false
			M.heal(m, "instruments", 6.0)
			return "Cross-checks found the drift. Recalibrated and back online."
		"instrumentFailure:backup":
			m.backup.inst = true
			m.offline.inst = false
			return "Redundant electronics online. Science continues."
		"instrumentFailure:push":
			m.offline.inst = false
			m.unreliable = 2
			return "You chose to continue. Some readings will need to be discarded."
		"structuralAlert:inspect":
			m.skip = 1
			return _join(["Inspection found a cracked bracket. Operations reduced while it settles.", _hit(m, "structure", 3.0, "Structural stress (%s)" % m.note)])
		"structuralAlert:repair":
			m.spares -= 1
			M.heal(m, "structure", 12.0)
			return "Bracket reinforced with spare parts."
		"structuralAlert:ignore":
			var r := _hit(m, "structure", 10.0 + randf() * 6.0, "Structural stress (%s, ignored)" % m.note)
			return r if r != "" else "Nothing happened this time."
		"budgetTrap:redesign":
			m.budget0 = roundi(m.budget0 * 0.8)
			m.redesign = true
			return "Back to the drawing board."
		"massLimit:redesign":
			m.redesign = true
			return "Back to the design table."
		"fuelShortage:aero":
			m.fuel -= roundi((float(m.dest.insertFuel) + m.nav_debt) * 0.45)
			m.days += 2.0
			m.nav_debt = 0.0
			m.insert_paid = true
			return _join(["Aerobraking worked, like Mars Reconnaissance Orbiter.", _hit(m, "thermal", 6.0, "Aerobraking heating"), _hit(m, "structure", 4.0, "Aerobraking loads")])
		"fuelShortage:loose":
			m.fuel -= roundi((float(m.dest.insertFuel) + m.nav_debt) * 0.65)
			m.nav_debt = 0.0
			m.insert_paid = true
			m.orbit_sci = 0.75
			return "Captured into a wide orbit. Views are more distant."
		"fuelShortage:full":
			m.fuel = maxf(0.0, m.fuel - (float(m.dest.insertFuel) + m.nav_debt))
			m.nav_debt = 0.0
			m.insert_paid = true
			return "Full insertion completed. Tanks almost empty."
		"launchWindow:wait":
			_spend_budget(m, 15.0)
			m.days += 12.0
			return "Launched on the backup date. Trajectory unchanged."
		"launchWindow:late":
			m.fuel -= 8.0
			return "Launched late. The upper stage worked harder and the spacecraft used extra fuel."
		"launchWindow:force":
			if randf() < 0.35:
				return _join(["Strong winds shook the rocket.", _hit(m, "structure", 10.0, "Launch in marginal weather"), _hit(m, "instruments", 6.0, "Launch vibration")])
			return "You got away with it this time."
		"signal:analyse":
			m.skip = 1
			_drain(m, 6.0)
			if M.inst_factor(m) == 0.0:
				return "Instruments are not working well enough to analyse it. Recorded for later."
			var what := "interference from the spacecraft's own heater switching on and off"
			if m.dest.id == "jupiter" or m.dest.get("parent") == "Jupiter":
				what = "natural radio bursts triggered by Io moving through Jupiter's magnetic field"
			elif randf() < 0.5:
				what = "a pulsar, a spinning neutron star sending regular radio pulses"
			m.bonus_sci += 1.0
			return "Analysis complete: the signal is %s. A useful result for the science team." % what
		"signal:log":
			return "Logged for scientists on the ground."
		"signal:divert":
			m.skip = 2
			m.fuel -= 6.0
			if M.inst_factor(m) == 0.0:
				return "Instruments too weak to resolve it. Time and fuel spent."
			m.bonus_sci += 2.0
			return "Long observation revealed a pulsar with an unusual glitch. A rare dataset, at the cost of mission time."
		"micrometeoroid:shield":
			m.no_downlink = true
			var r2 := _hit(m, "structure", (1.0 - minf(0.95, float(s.impactTol) + 0.35)) * 10.0, "Micrometeoroids (shielded)")
			return r2 if r2 != "" else "The dish took the hits harmlessly."
		"micrometeoroid:continue":
			var r3 := _join([_hit(m, "structure", (1.0 - float(s.impactTol)) * 12.0, "Micrometeoroids"), _hit(m, "solar" if m.c.has("solar") else "comms", (1.0 - float(s.impactTol)) * 10.0, "Micrometeoroids")])
			return r3 if r3 != "" else "The shielding stopped them."
		"discovery:study":
			var tag := "imaging"
			for t in m.totals.tags:
				if t != "drive" and t != "probe":
					tag = t
					break
			m.objectives.append({"id": "disc%d" % m.cycle, "name": "Follow up the unexpected discovery", "tag": tag, "units": 2.0, "mode": "surface" if _surf(m) else "orbit",
				"primary": false, "seg": m.seg, "collected": 0.0, "returned": 0.0, "status": "active", "modified": false, "value": 1.0, "replaces": ""})
			return "New objective added. Original objectives remain."
		"discovery:note":
			return "Noted for a future mission."
		"dataCorruption:backup":
			m.skip = 1
			_corrupt(m, 0.1)
			return "Most records restored from the second memory bank."
		"dataCorruption:prioritise":
			_corrupt(m, 0.35, true)
			return "Primary data protected. Some secondary data lost."
		"dataCorruption:accept":
			_corrupt(m, 0.35)
			return "Corrupted records deleted."
		"orbitDeviation:correct", "orbitTrim:raise":
			m.fuel -= _burn(m)
			return "Orbit corrected. Stable for the mission."
		"orbitDeviation:adapt":
			m.yield_penalty = 2
			return "Schedule rewritten around the new orbit."
		"lifeSupport:backup":
			m.skip = 1
			m.crew = minf(100.0, m.crew + 5.0)
			return "Backup scrubber running. The crew replaced a clogged filter."
		"lifeSupport:restrict":
			m.skip = 1
			return "Activities paused. Readings stabilise."
		"lifeSupport:monitor":
			m.crew -= 25.0
			return "CO₂ levels rose. The crew reported headaches. Crew safety −25%."
		"crewSchedule:reorg":
			m.skip = 1
			m.crew_rest = 100.0
			return "Schedule rebuilt. Crew rested."
		"crewSchedule:push":
			m.crew_rest -= 40.0
			if m.crew_rest < 40.0:
				m.crew -= 15.0
				return "A tired crew made a mistake during a procedure. Crew safety −15%."
			return "The crew pushed through, exhausted."
		"dustStorm:survive":
			_storm(m)
			m.power_mode = "survival"
			m.offline.inst = true
			return "Lander powered down to essentials. Waiting it out. (Change the power mode to resume science.)"
		"dustStorm:work":
			_storm(m)
			return "Operations continue under a darkening sky."
		"dustDevil:watch":
			if randf() < 0.6:
				var c := roundi(m.env.dustCover * 100.0)
				m.env.dustCover *= 0.35
				return "Lucky! Panel dust fell from %d%% to %d%%." % [c, roundi(m.env.dustCover * 100.0)]
			return "It passed by without touching you."
		"dustDevil:image":
			m.bonus_sci += 1.0
			return "A great movie of a Martian dust devil."
		"sandTrap:slow":
			m.skip = 1
			return _join(["Freed after careful planning.", _hit(m, "rover", 3.0, "Soft-ground extraction")])
		"sandTrap:power":
			if randf() < 0.5:
				return "It worked. Free!"
			return _join(["The wheels dug deeper.", _hit(m, "rover", 22.0, "Stuck in soft ground (forced)")])
		"thermalSpike:shade":
			m.skip = 1
			m.heat_shelter = true
			return "Sunshade deployed. Instruments sheltered."
		"thermalSpike:observe":
			m.bonus_sci += 1.0
			var r4 := _hit(m, "instruments", maxf(0.0, 1.0 - float(s.heatTol)) * 18.0, "Sunrise observation", "Instruments faced the Sun during sunrise.")
			return r4 if r4 != "" else "The instruments stayed within limits."
		"overheat:cool":
			m.offline.inst = true
			return "Instrument resting. It restarts when it has cooled."
		"overheat:override":
			var r5 := _hit(m, "instruments", 15.0, "Overheating (safety limit overridden)")
			return r5 if r5 != "" else "It survived."
		"pressureCreak:burst":
			m.burst = true
			_drain(m, 15.0)
			return "All instruments firing. Get the data before the seal fails."
		"pressureCreak:seal":
			M.heal(m, "structure", 4.0)
			m.yield_penalty = 1
			return "Shutter closed. The weep slows."
		"weatherHold:wait":
			m.days += 1.0
			m.env.weather = 0.0
			return "The front passed. Conditions are good."
		"weatherHold:go":
			m.env.weather = 1.0
			return "You pressed on into gusty winds."
		"radSurge:safe":
			m.env.surge = 0.5
			m.skip = 1
			m.power_mode = "survival"
			m.offline.inst = true
			return "Sensitive electronics powered down. Safe mode active (change the power mode to resume science)."
		"radSurge:measure":
			m.env.surge = 1.0
			if m.totals.tags.has("radiation") or m.totals.tags.has("fields"):
				m.bonus_sci += 1.0
				return "The fields instruments captured the surge in detail."
			return "You stayed on, but carried no instrument to measure it well."
		"ringCrossing:dish":
			m.shield_attitude = true
			m.no_downlink = true
			return "Dish turned into the particle stream."
		"ringCrossing:sample":
			m.bonus_sci += 1.0
			return _join(["Particle detectors counted thousands of hits.", _hit(m, "instruments", (1.0 - float(s.impactTol)) * 12.0, "Ring particles (instruments forward)")])
		"stormObs:mosaic":
			m.bonus_sci += 0.5
			return "Mosaic captured."
		"stormObs:long":
			m.skip = 1
			if m.c.nav >= 50.0:
				m.bonus_sci += 1.5
				return "A full rotation tracked. Wind speeds measured."
			return "Pointing drift smeared the images. Little gained."
		"deepCold:spare":
			m.spares -= 1
			M.heal(m, "thermal", 10.0)
			return "Spare heater online."
		"deepCold:reroute":
			_drain(m, 15.0)
			m.skip = 1
			return "Remaining heaters run harder. Temperatures hold."
		"deepCold:accept":
			var k: float = 1.0 - float(s.coldTol) + 0.2
			var r6 := _join([_hit(m, "power", 12.0 * k, "Heater failure (cold)"), _hit(m, "instruments", 8.0 * k, "Heater failure (cold)")])
			return r6 if r6 != "" else "The cold rating held."
		"iceFracture:around":
			m.skip = 1
			m.bonus_sci += 0.5
			return "Fracture mapped and avoided. The map is useful science too."
		"iceFracture:cross":
			if randf() < 0.55:
				return _join(["A wheel slipped into the crack.", _hit(m, "rover", 18.0 * (1.0 - float(s.wheelTol) + 0.3), "Crossing an ice fracture")])
			return "Made it across."
		"eruption:stow":
			m.env.eruption = 0.6
			m.skip = 1
			m.covers_closed = true
			return "Covers shut as the fallout arrives."
		"eruption:film":
			m.env.eruption = 1.2
			m.bonus_sci += 1.5
			return _join(["Spectacular images of the plume.", _hit(m, "solar", 8.0, "Volcanic fallout"), _hit(m, "instruments", 6.0, "Volcanic fallout")])
		"terrainShift:remap":
			m.skip = 1
			return "New route planned on the fresh map."
		"terrainShift:old":
			return _join(["The rover hit unmapped rough lava.", _hit(m, "rover", 14.0, "Driving on outdated maps")])
		"plumeBurst:collect":
			m.env.plume = 1.0
			if m.totals.tags.has("plume") and M.inst_factor(m) > 0.0:
				for o in m.objectives:
					if o.tag == "plume" and o.status == "active":
						M.add_data(m, o, minf(1.5 * M.inst_factor(m), o.units - o.collected))
						break
			return "Plume grains collected. Everything is now frosted with fresh ice."
		"plumeBurst:protect":
			m.env.plume = 0.3
			m.covers_closed = true
			return "Covers closed until the outburst calmed."
		"hydrocarbon:heat":
			_drain(m, 10.0)
			return "Seals warmed and flexible again."
		"hydrocarbon:ignore":
			var r7 := _join([_hit(m, "rover" if m.c.has("rover") else "instruments", 14.0 * (1.0 - float(s.corrTol)), "Hydrocarbon soaking"), _hit(m, "instruments", 6.0 * (1.0 - float(s.corrTol)), "Hydrocarbon soaking")])
			return r7 if r7 != "" else "The coating protected everything."
		"hazeNav:radar", "lowGHop:slow":
			m.drive_slow = true
			return "Moving in short, careful steps."
		"hazeNav:dead":
			var r8 := _hit(m, "nav", 10.0, "Haze navigation errors")
			return r8 if r8 != "" else "You stayed on track."
		"lowGHop:fast":
			return _join(["The rover bounced and landed hard.", _hit(m, "rover", 12.0, "Low-gravity bounce"), _hit(m, "structure", 4.0, "Low-gravity bounce")])
		"commsDelay:auto":
			if m.c.nav >= 50.0:
				return "Autonomy handled it."
			return _join(["Autonomy misjudged it.", _hit(m, "rover" if m.c.has("rover") else "nav", 8.0, "Autonomy error")])
		"commsDelay:wait":
			m.skip = 1
			return "Waited for the round trip of radio signals."
		"dsnTime:pay":
			_spend_budget(m, 10.0)
			m.down_mul = 2.0
			return "Extra antenna time booked."
		"dsnTime:share":
			m.down_mul = 0.5
			return "Downlink shared."
		"sampleTriage:primary":
			return "Primary target scheduled first."
		"sampleTriage:secondary":
			m.bonus_sci += 1.0
			m.skip = 1
			return "Secondary target analysed. Primary work moves back a cycle."
		"thermalTrade:keep":
			return "Margins kept."
		"thermalTrade:lower":
			m.battery += 12.0
			var r9 := _hit(m, "thermal", 5.0, "Reduced heater margins")
			return r9 if r9 != "" else "Saved power."
		"calibration:cal":
			if m.mode != "cruise":
				m.skip = 1
			M.heal(m, "instruments", 5.0)
			return "Calibration complete."
		"calibration:skip":
			return "Calibration skipped."
		"diagnostics:check":
			_spend_budget(m, 5.0)
			m.days += 2.0
			return "A loose connector was found and fixed before launch."
		"diagnostics:go":
			var r10 := _hit(m, "nav", 15.0, "Unchecked connector")
			return r10 if r10 != "" else "Launched."
		"orbitTrim:leave":
			return _join([_hit(m, "structure", 5.0, "Atmospheric drag"), _hit(m, "solar", 6.0, "Atmospheric drag")])
	return ""
