extends Node3D
## Assembly hall (the player builds the engine and the spacecraft step by step) and
## launch pad (countdown, lift-off, staging, fairing and spacecraft separation).

const Gfx = preload("res://scripts/gfx.gd")
const CD = preload("res://scripts/campaign_data.gd")

const SHIP_Y := 3.0
const ENG := Vector3(-17.0, 0.0, 1.0)      # engine test stand
const INST_COLS := ["e8742a", "2fb36a", "c23a9a", "2a6bd6", "d9a520", "d63a3a"]

var cam: Camera3D
var env: Environment
var ship
var ui
var audio
var speed := 1.0
var root: Node3D
var shake := 0.0
var idle := false
var focus := Vector3.ZERO
var idle_base := 0.6
var idle_r := 16.0
var idle_h := 4.0
var _sway := 0.0
var _t := 0.0
var _saved := {}
var _hall_on := false
var _shown := {}
var _ship_vis := {}
var _flames: Array = []        # {n: Node3D, lvl: float, glow: MeshInstance3D, light: OmniLight3D}
var _ep := {}                  # engine parts
var eng: Node3D
var bridge: Node3D
var cable: MeshInstance3D
var hook: MeshInstance3D
var _lamp: OmniLight3D
var _smoke_n: CPUParticles3D
# launch pad
var rk: Node3D
var s1: Node3D
var s2: Node3D
var boosters: Array = []
var fair_l: Node3D
var fair_r: Node3D
var arm: Node3D
var sky_mat: ProceduralSkyMaterial
var _top_y := 0.0
var _trail: CPUParticles3D
var stars: Node3D             # the world star field, hidden indoors and in daylight


func setup(cam_: Camera3D, env_: Environment, ship_, ui_, audio_) -> void:
	cam = cam_
	env = env_
	ship = ship_
	ui = ui_
	audio = audio_
	visible = false


# ------------------------------------------------------------ helpers

func _tw(dur: float, fn: Callable) -> void:
	var t := create_tween()
	t.tween_method(fn, 0.0, 1.0, maxf(0.01, dur / maxf(0.1, speed)))
	await t.finished


## Like _tw, but stops at once when the player skips the cinematic.
func _tws(dur: float, fn: Callable) -> void:
	var d := dur / maxf(0.1, speed)
	var t := 0.0
	while t < d and not ui.cine_skip:
		fn.call(t / d)
		await get_tree().process_frame
		t += get_process_delta_time()
	if not ui.cine_skip:
		fn.call(1.0)


func _wait(sec: float) -> void:
	await get_tree().create_timer(maxf(0.01, sec / maxf(0.1, speed))).timeout


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(parent, b, mat, pos, rot_deg)


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, caps: bool = true, seg: int = 24) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	return _mi(parent, c, mat, pos, rot_deg)


func _ball(parent: Node3D, r: float, mat: Material, pos: Vector3, hemi: bool = false) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = 20
	s.rings = 10
	return _mi(parent, s, mat, pos)


func _mat(col: String, metal: float = 0.3, rough: float = 0.5, two_sided: bool = false) -> StandardMaterial3D:
	var m := Gfx.std_mat(Color(col), metal, rough)
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _flame_mat(col: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.r, col.g, col.b, a)
	return m


## Downward flame: the pivot sits at the nozzle exit, scale.y follows the level.
func _flame(parent: Node3D, pos: Vector3, r: float, length: float, with_light: bool) -> Dictionary:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	for L in [[1.0, 1.0, Color("ff9a3c"), 0.28], [0.7, 0.75, Color("ffc97a"), 0.34], [0.38, 0.5, Color("cfe6ff"), 0.5]]:
		var ln: float = length * float(L[1])
		var f := _cyl(n, r * float(L[0]), r * 0.12 * float(L[0]), ln, _flame_mat(L[2], L[3]), Vector3(0, -ln * 0.5, 0), Vector3.ZERO, false, 14)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var g := Gfx.glow(Color("ffb060"), r * 9.0, 0.0)
	g.position = pos + Vector3(0, -r, 0)
	parent.add_child(g)
	var d := {"n": n, "lvl": 0.0, "glow": g, "light": null}
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Color("ffb060")
		l.omni_range = r * 40.0
		l.light_energy = 0.0
		l.position = pos + Vector3(0, -r * 2.0, 0)
		parent.add_child(l)
		d.light = l
	n.visible = false
	_flames.append(d)
	return d


func _smoke(parent: Node3D, pos: Vector3, amount: int, size: float, vel: float, dir: Vector3, spread: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, 1.2, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.25))
	sc.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.88, 0.75))
	g.set_color(1, Color(0.85, 0.85, 0.88, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var gt := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gg
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	m.albedo_texture = gt
	q.material = m
	p.mesh = q
	p.emitting = false
	p.position = pos
	parent.add_child(p)
	return p


func _env_save() -> void:
	_saved = {"bg": env.background_mode, "col": env.background_color, "asrc": env.ambient_light_source, "acol": env.ambient_light_color,
		"aen": env.ambient_light_energy, "fog": env.fog_enabled, "fogd": env.fog_density, "fogc": env.fog_light_color, "sky": env.sky}


func leave() -> void:
	idle = false
	shake = 0.0
	_hall_on = false
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	_flames.clear()
	_ep.clear()
	boosters.clear()
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
	rk = null
	if not _saved.is_empty():
		env.background_mode = _saved.bg
		env.background_color = _saved.col
		env.ambient_light_source = _saved.asrc
		env.ambient_light_color = _saved.acol
		env.ambient_light_energy = _saved.aen
		env.fog_enabled = _saved.fog
		env.fog_density = _saved.fogd
		env.fog_light_color = _saved.fogc
		env.sky = _saved.sky
		_saved = {}
	for c in ship.get_children():
		if _ship_vis.has(c):
			c.visible = _ship_vis[c]
	for id in ship.parts:
		(ship.parts[id] as Node3D).position = Vector3.ZERO
	_ship_vis.clear()
	_shown.clear()
	ship.scale = Vector3.ONE
	ship.rotation = Vector3.ZERO
	if stars != null:
		stars.visible = true
	visible = false


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	for f in _flames:
		var lvl: float = f.lvl
		var n: Node3D = f.n
		if not is_instance_valid(n):
			continue
		n.visible = lvl > 0.02
		n.scale = Vector3(1.0, maxf(0.05, lvl) * (0.9 + 0.1 * sin(_t * 47.0)), 1.0)
		Gfx.set_glow_opacity(f.glow, 0.85 * clampf(lvl, 0.0, 1.0))
		(f.glow as MeshInstance3D).visible = lvl > 0.02
		if f.light != null:
			(f.light as OmniLight3D).light_energy = 6.0 * lvl * (0.85 + 0.15 * sin(_t * 31.0))
	if _hall_on:
		for c in ship.get_children():
			(c as Node3D).visible = _shown.has(c)
	if idle:
		_sway += dt * 0.25
		var a := idle_base + sin(_sway) * 0.22
		cam.position = focus + Vector3(sin(a) * idle_r, idle_h, cos(a) * idle_r)
		cam.look_at(focus, Vector3.UP)
	if shake > 0.001:
		cam.h_offset = randf_range(-1.0, 1.0) * shake * 0.25
		cam.v_offset = randf_range(-1.0, 1.0) * shake * 0.25
		shake = maxf(0.0, shake - dt * 0.5)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


## Moves the camera to a slow-swaying view of a point.
func _frame(f: Vector3, base: float, r: float, h: float, dur: float) -> void:
	idle = false
	var p0 := cam.position
	var t0 := focus
	var p1 := f + Vector3(sin(base) * r, h, cos(base) * r)
	await _tw(dur, func(u: float):
		var e := _ease(u)
		cam.position = p0.lerp(p1, e)
		cam.look_at(t0.lerp(f, e), Vector3.UP))
	focus = f
	idle_base = base
	idle_r = r
	idle_h = h
	_sway = 0.0
	idle = true


# ============================================================ ASSEMBLY HALL

func _build_hall() -> void:
	root = Node3D.new()
	add_child(root)
	var floor_m := _mat("7c8694", 0.1, 0.4)
	var wall_m := _mat("aab3bf", 0.0, 0.8)
	var dark := _mat("3a4352", 0.4, 0.5)
	var yellow := _mat("f2b21d", 0.3, 0.5)
	var blue := _mat("2a6bd6", 0.2, 0.5)
	_box(root, Vector3(76, 0.4, 50), floor_m, Vector3(0, -0.2, 0))
	_box(root, Vector3(76, 24, 0.5), wall_m, Vector3(0, 12, -25))
	_box(root, Vector3(76, 24, 0.5), wall_m, Vector3(0, 12, 25))
	for sx in [-38.0, 38.0]:
		_box(root, Vector3(0.5, 24, 50), wall_m, Vector3(sx, 12, 0))
	_box(root, Vector3(76, 1.2, 0.1), blue, Vector3(0, 7.0, -24.7))
	for i in range(-5, 6):
		_box(root, Vector3(0.12, 24, 0.1), _mat("8a93a0", 0.0, 0.7), Vector3(i * 7.0, 12, -24.7))
	var lamp_m := Gfx.unshaded_mat(Color("ffffff"))
	for k in range(-2, 3):
		_box(root, Vector3(76, 0.5, 0.5), dark, Vector3(0, 22, k * 10.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in range(-3, 4):
			_box(root, Vector3(5, 0.12, 1.0), lamp_m, Vector3(i * 10.0, 21.6, k * 10.0))
	# safety lines round the two work areas
	for c in [[Vector3(0, 0.02, 0), 7.0, 10.0], [ENG + Vector3(0, 0.02, 0), 7.0, 7.0]]:
		var o: Vector3 = c[0]
		var w: float = c[1]
		var d: float = c[2]
		_box(root, Vector3(w * 2.0, 0.03, 0.25), yellow, o + Vector3(0, 0, d))
		_box(root, Vector3(w * 2.0, 0.03, 0.25), yellow, o + Vector3(0, 0, -d))
		_box(root, Vector3(0.25, 0.03, d * 2.0), yellow, o + Vector3(w, 0, 0))
		_box(root, Vector3(0.25, 0.03, d * 2.0), yellow, o + Vector3(-w, 0, 0))
	# lights
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -28, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	root.add_child(sun)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(2, 12, 9)
	_lamp.omni_range = 60.0
	_lamp.light_energy = 0.8
	root.add_child(_lamp)
	var l2 := OmniLight3D.new()
	l2.position = ENG + Vector3(4, 10, 8)
	l2.omni_range = 40.0
	l2.light_energy = 0.7
	root.add_child(l2)
	# overhead crane
	for sz in [-7.0, 7.0]:
		_box(root, Vector3(70, 0.6, 0.6), yellow, Vector3(0, 18.3, sz))
	bridge = Node3D.new()
	bridge.position = Vector3(10, 18, 0)
	root.add_child(bridge)
	_box(bridge, Vector3(1.3, 0.9, 15.0), yellow, Vector3.ZERO)
	_box(bridge, Vector3(1.8, 0.7, 1.8), dark, Vector3(0, -0.7, 0))
	cable = _cyl(bridge, 0.05, 0.05, 1.0, dark, Vector3.ZERO, Vector3.ZERO, true, 6)
	hook = _box(bridge, Vector3(0.5, 0.35, 0.5), yellow, Vector3.ZERO)
	_set_cable(2.0)
	# spacecraft cradle
	_box(root, Vector3(5.0, 0.5, 8.0), dark, Vector3(0, 0.25, 0))
	for sz in [-1.5, 1.5]:
		_box(root, Vector3(1.5, SHIP_Y - 1.15, 0.3), blue, Vector3(0, 0.5 + (SHIP_Y - 1.15) * 0.5, sz))
	# work platform, tool carts and technicians in clean-room suits
	_box(root, Vector3(3.2, 1.6, 1.6), _mat("8d96a5", 0.5, 0.4), Vector3(5.6, 0.8, -3.6))
	_box(root, Vector3(3.2, 0.08, 0.08), yellow, Vector3(5.6, 2.6, -4.3))
	for sx in [4.1, 7.1]:
		_box(root, Vector3(0.08, 1.0, 0.08), yellow, Vector3(sx, 2.1, -4.3))
	_box(root, Vector3(1.2, 0.9, 0.7), _mat("d63a3a", 0.3, 0.5), Vector3(-5.0, 0.45, 4.6))
	_box(root, Vector3(1.2, 0.9, 0.7), _mat("d63a3a", 0.3, 0.5), Vector3(-11.5, 0.45, 5.0))
	for p in [Vector3(5.2, 0, 2.6), Vector3(-4.6, 0, 3.4), Vector3(-12.6, 0, 3.6), Vector3(5.4, 1.6, -3.6), Vector3(-20.6, 0, 3.4)]:
		_tech(p)
	# engine test stand
	eng = Node3D.new()
	eng.position = ENG
	root.add_child(eng)
	var stand := Node3D.new()
	stand.position = ENG
	root.add_child(stand)
	for sx in [-1.7, 1.7]:
		for sz in [-1.7, 1.7]:
			_cyl(stand, 0.14, 0.14, 5.5, dark, Vector3(sx, 2.75, sz), Vector3.ZERO, true, 8)
		_box(stand, Vector3(0.25, 0.25, 3.6), dark, Vector3(sx, 5.45, 0))
		_box(stand, Vector3(3.6, 0.25, 0.25), dark, Vector3(0, 5.45, sx))
	_box(stand, Vector3(3.0, 0.3, 3.0), _mat("2b2f38", 0.5, 0.6), Vector3(0, 0.15, 0))
	_build_engine()
	_smoke_n = _smoke(root, ENG + Vector3(0, 0.6, 0), 60, 3.2, 9.0, Vector3(0, 0.15, 0), 88.0, 2.4)


func _tech(p: Vector3) -> void:
	var suit := _mat("f4f6fa", 0.0, 0.8)
	var c := CapsuleMesh.new()
	c.radius = 0.27
	c.height = 1.45
	_mi(root, c, suit, p + Vector3(0, 0.73, 0))
	_ball(root, 0.22, suit, p + Vector3(0, 1.65, 0))
	_box(root, Vector3(0.26, 0.1, 0.06), _mat("7fb4e6", 0.6, 0.2), p + Vector3(0, 1.67, 0.2))


func _set_cable(len: float) -> void:
	cable.scale = Vector3(1, len, 1)
	cable.position = Vector3(0, -1.0 - len * 0.5, 0)
	hook.position = Vector3(0, -1.0 - len - 0.15, 0)


func _engine_part(id: String) -> Node3D:
	var n := Node3D.new()
	n.visible = false
	eng.add_child(n)
	_ep[id] = n
	return n


func _build_engine() -> void:
	var copper := _mat("b87333", 0.85, 0.3)
	var steel := _mat("cfd5de", 0.8, 0.3)
	var dark := _mat("4b525e", 0.8, 0.35, true)
	var pipe := _mat("9aa3b0", 0.8, 0.3)
	var ch := _engine_part("chamber")
	_cyl(ch, 0.62, 0.62, 1.2, copper, Vector3(0, 6.2, 0))
	_cyl(ch, 0.62, 0.36, 0.34, copper, Vector3(0, 5.43, 0))
	for k in 3:
		_cyl(ch, 0.66, 0.66, 0.07, steel, Vector3(0, 5.8 + k * 0.4, 0))
	var pm := _engine_part("pump")
	_cyl(pm, 0.72, 0.72, 0.2, steel, Vector3(0, 6.9, 0))
	_ball(pm, 0.62, steel, Vector3(0, 7.0, 0), true)
	for sx in [-1.0, 1.0]:
		_cyl(pm, 0.34, 0.34, 0.95, _mat("3b4250", 0.7, 0.4), Vector3(sx * 1.2, 6.5, 0), Vector3(90, 0, 0))
		_cyl(pm, 0.4, 0.4, 0.12, steel, Vector3(sx * 1.2, 6.5, 0.3), Vector3(90, 0, 0))
		_cyl(pm, 0.09, 0.09, 0.9, pipe, Vector3(sx * 0.75, 6.95, 0), Vector3(0, 0, sx * 58.0), true, 8)
	var nz := _engine_part("nozzle")
	_cyl(nz, 0.36, 1.3, 2.3, dark, Vector3(0, 4.12, 0), Vector3.ZERO, false)
	_cyl(nz, 1.34, 1.34, 0.1, steel, Vector3(0, 3.0, 0), Vector3.ZERO, false)
	for k in 4:
		var rr := lerpf(0.5, 1.2, (k + 1) / 5.0)
		_cyl(nz, rr + 0.03, rr + 0.03, 0.05, pipe, Vector3(0, lerpf(5.2, 3.0, (k + 1) / 5.0), 0), Vector3.ZERO, false)
	var tk := _engine_part("tanks")
	_ball(tk, 1.0, _mat("e3e7ee", 0.6, 0.3), Vector3(-1.2, 8.75, 0))
	_ball(tk, 1.0, _mat("9fc4e6", 0.6, 0.3), Vector3(1.2, 8.75, 0))
	_cyl(tk, 1.02, 1.02, 0.14, _mat("e8742a", 0.3, 0.5), Vector3(-1.2, 8.75, 0))
	_cyl(tk, 1.02, 1.02, 0.14, _mat("2a6bd6", 0.3, 0.5), Vector3(1.2, 8.75, 0))
	for sx in [-1.0, 1.0]:
		_cyl(tk, 0.09, 0.09, 1.0, pipe, Vector3(sx * 1.2, 7.4, 0), Vector3.ZERO, true, 8)
	_box(tk, Vector3(1.0, 0.12, 0.12), pipe, Vector3(0, 8.75, 0))
	_flame(eng, Vector3(0, 3.0, 0), 1.15, 2.7, true)


func _sparks(at: Vector3, n: int = 26) -> void:
	Gfx.burst(root, at, n, Color("ffd27a"), 5.0)
	if audio != null:
		audio.thud()


func _install_engine(id: String, from: Vector3) -> void:
	var n: Node3D = _ep[id]
	n.position = from
	n.visible = true
	await _tw(1.9, func(u: float): n.position = from.lerp(Vector3.ZERO, _ease(u)))
	n.position = Vector3.ZERO
	_sparks(ENG + Vector3(0, 6.2, 0.8))
	await _wait(0.5)


func _hot_fire() -> void:
	var f: Dictionary = _flames[0]
	_smoke_n.emitting = true
	if audio != null:
		audio.alarm()
	await _tw(0.7, func(u: float): f.lvl = u)
	shake = 0.45
	await _tw(2.6, func(_u: float):
		f.lvl = 1.0
		shake = maxf(shake, 0.3))
	await _tw(0.8, func(u: float): f.lvl = 1.0 - u)
	f.lvl = 0.0
	_smoke_n.emitting = false
	shake = 0.0


## Lowers one of the ship's own parts into place with the crane.
func _install_part(id: String, drop: float = 9.0) -> void:
	if not ship.parts.has(id):
		return
	var n: Node3D = ship.parts[id]
	ship.visible = true
	_shown[n] = true
	n.position = Vector3(0, drop, 0)
	var bx0 := bridge.position.x
	await _tw(0.8, func(u: float): bridge.position.x = lerpf(bx0, 0.0, _ease(u)))
	await _tw(2.2, func(u: float):
		n.position = Vector3(0, drop * (1.0 - _ease(u)), 0)
		_set_cable(maxf(0.5, 18.0 - 1.0 - (SHIP_Y + n.position.y + 1.2))))
	n.position = Vector3.ZERO
	_sparks(Vector3(0, SHIP_Y + 0.4, 0.6))
	var l0: float = cable.scale.y
	await _tw(0.7, func(u: float): _set_cable(lerpf(l0, 2.0, u)))


func _prop_fly(n: Node3D, to: Vector3, from: Vector3, dur: float = 1.3) -> void:
	n.position = from
	n.visible = true
	await _tw(dur, func(u: float): n.position = from.lerp(to, _ease(u)))
	n.position = to
	_sparks(to, 12)


static func _eq_name(group: String, id: String) -> String:
	for g in CD.EQUIPMENT:
		if g.id == group:
			for o in g.options:
				if o.id == id:
					return o.name
	return id


static func _inst_names(ids: Array) -> Array:
	var out: Array = []
	for i in ids:
		for x in CD.INSTRUMENTS:
			if x.id == i:
				out.append(x.name)
	return out


func _steps(design: Dictionary) -> Array:
	var pw: String = design.get("power", "solar")
	var pkind := "rtg" if pw.begins_with("rtg") else ("batt" if pw.begins_with("batt") else "solar")
	var plabel := {"solar": "Solar arrays", "rtg": "Radioisotope generator (RTG)", "batt": "Batteries only"}
	var pfact := {
		"solar": "Solar arrays are folded for launch and open in space. Sunlight weakens with distance: at Jupiter it is about 27 times weaker than at Earth.",
		"rtg": "An RTG turns the heat of decaying plutonium into electricity. It works in the dark and the cold, where solar arrays cannot.",
		"batt": "Batteries alone last hours or days. They suit short missions, such as a Venus lander that cannot survive long in any case."}
	var pwrong: Array = []
	for k in ["solar", "rtg", "batt"]:
		if k != pkind:
			pwrong.append(plabel[k])
	var inst := _inst_names(design.get("instruments", []))
	return [
		{"id": "chamber", "phase": "ENGINE", "title": "Combustion chamber",
			"q": "A rocket engine needs a strong vessel where fuel and oxidiser burn at very high pressure. Which part is that?",
			"right": "Combustion chamber", "wrong": ["Nozzle bell", "Turbopump"],
			"fact": "The chamber holds gas hotter than 3,000 °C. Cold fuel is pumped through channels in its wall so the metal does not melt."},
		{"id": "pump", "phase": "ENGINE", "title": "Turbopumps and injector",
			"q": "The burning gas pushes back against anything that tries to enter the chamber. Which part forces propellant in against that pressure?",
			"right": "Turbopumps and injector", "wrong": ["Gimbal mount", "Fuel gauge"],
			"fact": "A turbopump spins tens of thousands of times a minute. The injector plate sprays fuel and oxidiser as a fine mist so they mix and burn evenly."},
		{"id": "nozzle", "phase": "ENGINE", "title": "Bell nozzle",
			"q": "Gas leaves the chamber hot and at high pressure, but slowly. Which part turns that pressure into speed?",
			"right": "Bell nozzle", "wrong": ["Injector plate", "Propellant tank"],
			"fact": "The nozzle narrows to a throat and then widens. The gas passes the speed of sound, and that fast exhaust is what pushes the spacecraft forward."},
		{"id": "tanks", "phase": "ENGINE", "title": "Propellant tanks",
			"q": "There is no air in space, so the engine cannot burn fuel the way a car engine does. What must the spacecraft carry?",
			"right": "Fuel and an oxidiser, in separate tanks", "wrong": ["Fuel only", "An air intake"],
			"fact": "Propellant is most of the mass at launch. Every extra kilogram of spacecraft needs many more kilograms of propellant to move it."},
		{"id": "fire", "phase": "ENGINE", "title": "Hot-fire test",
			"q": "The engine is complete. What do engineers do before it is allowed to fly?",
			"right": "Fire it on a test stand", "wrong": ["Fit it straight to the spacecraft", "Repaint it"],
			"fact": "A hot-fire test runs the real engine while it is bolted down. Sensors record thrust, temperature and vibration."},
		{"id": "bus", "phase": "SPACECRAFT", "title": "Main structure",
			"q": "Every part of the spacecraft bolts to one main frame, which must survive the shaking of launch. What is it called?",
			"right": "The bus (main structure)", "wrong": ["The fairing", "The payload"],
			"fact": "The bus carries the loads and holds the computers, wiring and tanks. It is built light, because mass is the most expensive thing to launch."},
		{"id": "power", "phase": "SPACECRAFT", "title": "Power: %s" % _eq_name("power", pw),
			"q": "The computers, heaters and radio need electricity for the whole mission. Which power source did you choose in your design?",
			"right": plabel[pkind], "wrong": pwrong, "fact": pfact[pkind], "pkind": pkind},
		{"id": "thermal", "phase": "SPACECRAFT", "title": "Thermal protection",
			"q": "In sunlight a spacecraft bakes, and in shadow it freezes. What keeps the electronics at a safe temperature?",
			"right": "Insulation blankets and a heat shield", "wrong": ["A bigger engine", "Extra solar arrays"],
			"fact": "The shiny foil on a spacecraft is multi-layer insulation: many thin reflective sheets. Your design uses: %s." % _eq_name("thermal", design.get("thermal", "std"))},
		{"id": "comms", "phase": "SPACECRAFT", "title": "Communications",
			"q": "The spacecraft will be millions of kilometres away. Which part sends its data back to Earth?",
			"right": "High-gain antenna (the dish)", "wrong": ["Star tracker", "Sensor mast"],
			"fact": "The dish focuses a weak radio signal into a narrow beam aimed at Earth. A signal from Mars still takes between 3 and 22 minutes to arrive."},
		{"id": "inst", "phase": "SPACECRAFT", "title": "Science instruments",
			"q": "Which parts are fitted last, so that they stay clean and undamaged?",
			"right": "The science instruments", "wrong": ["The propellant tanks", "The main frame"],
			"fact": "Instruments are the reason for the mission and its most delicate parts. " + ("On board: %s." % ", ".join(PackedStringArray(inst)) if inst.size() > 0 else "This design carries no science instruments."),
			"inst": inst.size()},
		{"id": "test", "phase": "TESTING", "title": "Shake and bake",
			"q": "Launch shakes the spacecraft harder than anything else in the mission. Which test checks that nothing will break loose?",
			"right": "Vibration test on a shake table", "wrong": ["Weighing it", "A photo inspection"],
			"fact": "After the shake test comes thermal-vacuum: the spacecraft is sealed in a chamber with no air and cycled between hot and cold."},
	]


## Runs the whole build. Returns {asked, right, skipped}.
func run_build(design: Dictionary, dest_name: String) -> Dictionary:
	_env_save()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c1119").srgb_to_linear()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe8f5")
	env.ambient_light_energy = 0.42
	env.fog_enabled = false
	_build_hall()
	if stars != null:
		stars.visible = false
	_ship_vis.clear()
	_shown.clear()
	for c in ship.get_children():
		_ship_vis[c] = (c as Node3D).visible
	ship.set_flame(0.0)
	ship.scale = Vector3.ONE
	ship.position = Vector3(0, SHIP_Y, 0)
	ship.rotation = Vector3.ZERO
	ship.visible = false
	_hall_on = true
	visible = true
	focus = ENG + Vector3(0, 6, 0)
	cam.position = Vector3(6, 12, 30)
	cam.look_at(Vector3(-6, 5, 0), Vector3.UP)
	ui.cine_passive = true
	ui.cinema_begin()
	ui.cinema_caption("ASSEMBLY HALL", "Mission to %s. First the engine, then the spacecraft. Answer each question to fit the next part." % dest_name)
	await _tw(4.0, func(u: float):
		cam.position = Vector3(6, 12, 30).lerp(Vector3(-4, 9, 22), _ease(u))
		cam.look_at(Vector3(-6, 5, 0), Vector3.UP))
	focus = Vector3(-6, 5, 0)

	var steps := _steps(design)
	var right := 0
	var asked := 0
	var skipped := false
	var props: Array = []
	var last_phase := ""
	for i in steps.size():
		var s: Dictionary = steps[i]
		if s.phase != last_phase:
			last_phase = s.phase
			if s.phase == "ENGINE":
				await _frame(ENG + Vector3(0, 5.6, 0), 0.62, 13.5, 2.2, 1.6)
			elif s.phase == "SPACECRAFT":
				await _frame(Vector3(0, SHIP_Y + 0.6, 0), 0.75, 13.0, 3.2, 2.0)
		ui.cinema_caption("", "")
		var opts: Array = [{"id": "ok", "label": s.right, "ok": true}]
		for w in s.wrong:
			opts.append({"id": "no%d" % opts.size(), "label": w})
		opts.shuffle()
		opts.append({"id": "__skip", "label": "Skip the rest of the build", "sub": "The engineers finish the spacecraft."})
		var pick: String = await ui.choose("asm", "%s  ·  step %d of %d" % [s.phase, i + 1, steps.size()], s.q, opts)
		ui.cine_skip = false
		if pick == "__skip":
			skipped = true
			break
		asked += 1
		if pick == "ok":
			right += 1
			if audio != null:
				audio.ok()
			ui.cinema_caption(str(s.title).to_upper(), "Correct. " + s.fact)
		else:
			if audio != null:
				audio.warn()
			ui.cinema_caption(str(s.title).to_upper(), "Not quite: the answer is “%s”. %s" % [s.right, s.fact])
		match s.id:
			"chamber":
				await _install_engine("chamber", Vector3(6, 1.5, 3))
			"pump":
				await _install_engine("pump", Vector3(0, 5, 0))
			"nozzle":
				await _install_engine("nozzle", Vector3(0, -2.6, 6))
			"tanks":
				await _install_engine("tanks", Vector3(0, 6, 0))
			"fire":
				await _wait(0.8)
				await _hot_fire()
			"bus":
				await _install_part("hull")
				await _mate_engine()
			"power":
				if s.pkind == "solar":
					await _install_part("arrays", 7.0)
				else:
					var p := Node3D.new()
					p.visible = false
					root.add_child(p)
					props.append(p)
					if s.pkind == "rtg":
						_cyl(p, 0.2, 0.2, 1.2, _mat("23262d", 0.6, 0.5), Vector3.ZERO, Vector3(0, 0, 90))
						for k in 6:
							var fin := _box(p, Vector3(1.0, 0.5, 0.03), _mat("2e323b", 0.6, 0.5), Vector3.ZERO)
							fin.rotation = Vector3(k * PI / 6.0, 0, 0)
						_cyl(p, 0.05, 0.05, 0.7, _mat("9aa3b0", 0.8, 0.3), Vector3(-0.9, 0, 0), Vector3(0, 0, 90), true, 8)
						await _prop_fly(p, Vector3(1.75, SHIP_Y + 0.05, 2.0), Vector3(8, SHIP_Y + 4, 2.0), 2.0)
					else:
						_box(p, Vector3(0.7, 0.35, 0.9), _mat("2fb36a", 0.4, 0.4), Vector3.ZERO)
						await _prop_fly(p, Vector3(0, SHIP_Y + 0.62, 0.9), Vector3(7, SHIP_Y + 3, 0.9), 2.0)
			"thermal":
				await _install_part("shield", -2.4)
			"comms":
				await _install_part("comms", 7.0)
			"inst":
				await _install_part("sensors", 7.0)
				for k in mini(int(s.inst), 6):
					var b := Node3D.new()
					b.visible = false
					root.add_child(b)
					props.append(b)
					_box(b, Vector3(0.3, 0.22, 0.36), _mat(INST_COLS[k % INST_COLS.size()], 0.5, 0.4), Vector3.ZERO)
					_cyl(b, 0.07, 0.07, 0.12, _mat("101216", 0.9, 0.1), Vector3(0, 0.0, -0.22), Vector3(90, 0, 0), true, 10)
					var side := -1.0 if k % 2 == 0 else 1.0
					var to := Vector3(side * 0.3, SHIP_Y + 0.55, 0.9 + float(k / 2) * 0.5)
					await _prop_fly(b, to, to + Vector3(side * 5.0, 3.0, 0), 0.9)
				if design.get("mobility", "none") != "none" and str(design.get("mobility", "none")).findn("rov") >= 0:
					ui.cinema_caption("ROVER", "The rover is folded and stowed under the spacecraft for the journey.")
					var rv := Node3D.new()
					rv.visible = false
					root.add_child(rv)
					props.append(rv)
					_box(rv, Vector3(0.7, 0.2, 1.0), _mat("d9dde4", 0.4, 0.4), Vector3.ZERO)
					for wx in [-0.42, 0.42]:
						for wz in [-0.4, 0.0, 0.4]:
							_cyl(rv, 0.13, 0.13, 0.1, _mat("23262d", 0.3, 0.7), Vector3(wx, -0.12, wz), Vector3(0, 0, 90), true, 10)
					await _prop_fly(rv, Vector3(0, SHIP_Y - 0.75, -0.6), Vector3(9, 0.4, -0.6), 2.4)
			"test":
				var base := Vector3(0, SHIP_Y, 0)
				if audio != null:
					audio.alarm()
				await _tw(2.6, func(u: float):
					var a := sin(u * PI) * 0.07
					ship.position = base + Vector3(randf_range(-a, a), randf_range(-a, a), randf_range(-a, a)))
				ship.position = base
				ui.cinema_caption("THERMAL-VACUUM TEST", "Hot as full sunlight, then cold as deep shadow, with all the air pumped out.")
				var c0 := Color("dfe8f5")
				await _tw(4.2, func(u: float):
					var hot := maxf(0.0, sin(u * TAU))
					var cold := maxf(0.0, -sin(u * TAU))
					env.ambient_light_color = c0.lerp(Color("ff8a4a"), hot * 0.85).lerp(Color("5aa8ff"), cold * 0.85)
					_lamp.light_color = Color.WHITE.lerp(Color("ff7a3a"), hot).lerp(Color("4a9cff"), cold))
				env.ambient_light_color = c0
				_lamp.light_color = Color.WHITE
		await _wait(1.6 if pick == "ok" else 2.6)

	# reveal the finished spacecraft
	ship.visible = true
	_hall_on = false
	for c in ship.get_children():
		if _ship_vis.has(c):
			c.visible = _ship_vis[c]
	for id in ship.parts:
		(ship.parts[id] as Node3D).position = Vector3.ZERO
	ui.cinema_caption("SPACECRAFT COMPLETE", ("The engineers finished the build." if skipped else "Correct answers: %d of %d." % [right, asked]) + " Next it is sealed inside the rocket's nose cone.")
	if audio != null:
		audio.ok()
	idle = false
	var f := Vector3(0, SHIP_Y + 0.4, 0)
	await _tw(5.5, func(u: float):
		var a := 0.75 + u * 2.2
		cam.position = f + Vector3(sin(a) * 11.5, 3.0 + u * 1.5, cos(a) * 11.5)
		cam.look_at(f, Vector3.UP))
	ui.cinema_end()
	ui.cine_passive = false
	leave()
	ship.visible = false
	return {"asked": asked, "right": right, "skipped": skipped, "total": steps.size()}


## The tested engine travels from the stand to the rear of the bus and becomes the ship's own engine section.
func _mate_engine() -> void:
	ui.cinema_caption("PROPULSION", "The tested engine is bolted to the rear of the bus, with its tanks inside the structure.")
	var p0 := eng.position
	var p1 := Vector3(0, SHIP_Y, 3.3)
	var q0 := Quaternion.IDENTITY
	var q1 := Quaternion(Vector3.RIGHT, -PI * 0.5)
	var c := Vector3(0, 5.5, 0)
	await _tw(3.2, func(u: float):
		var e := _ease(u)
		eng.quaternion = q0.slerp(q1, e)
		eng.scale = Vector3.ONE * lerpf(1.0, 0.3, e)
		var centre := (p0 + c).lerp(p1, e) + Vector3(0, sin(u * PI) * 3.5, 0)
		eng.position = centre - eng.basis * c)
	eng.visible = false
	if ship.parts.has("thrusters"):
		var n: Node3D = ship.parts["thrusters"]
		_shown[n] = true
		n.position = Vector3.ZERO
	_sparks(Vector3(0, SHIP_Y, 2.9), 34)
	await _wait(0.6)


# ============================================================ LAUNCH PAD

func _half_shell(profile: Array, a0: float, a1: float, seg: int = 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(profile.size() - 1):
		var a: Array = profile[i]
		var b: Array = profile[i + 1]
		for k in seg:
			var t0 := lerpf(a0, a1, float(k) / seg)
			var t1 := lerpf(a0, a1, float(k + 1) / seg)
			var p00 := Vector3(cos(t0) * a[1], a[0], sin(t0) * a[1])
			var p01 := Vector3(cos(t1) * a[1], a[0], sin(t1) * a[1])
			var p10 := Vector3(cos(t0) * b[1], b[0], sin(t0) * b[1])
			var p11 := Vector3(cos(t1) * b[1], b[0], sin(t1) * b[1])
			for v in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


func _build_pad(launcher: String) -> void:
	root = Node3D.new()
	add_child(root)
	var R: float = {"light": 1.5, "medium": 1.9, "heavy": 2.3}.get(launcher, 1.9)
	var H1: float = {"light": 17.0, "medium": 21.0, "heavy": 25.0}.get(launcher, 21.0)
	var H2: float = {"light": 5.0, "medium": 6.5, "heavy": 8.0}.get(launcher, 6.5)
	var white := _mat("eef1f6", 0.2, 0.4)
	var dark := _mat("2b2f38", 0.5, 0.5)
	var bell := _mat("4b525e", 0.8, 0.35, true)
	# ground, pad, tower
	_box(root, Vector3(9000, 1, 9000), _mat("5f7b4a", 0.0, 0.9), Vector3(0, -1.5, 0))
	_cyl(root, 17.0, 18.0, 1.0, _mat("9aa0a8", 0.1, 0.8), Vector3(0, -0.5, 0), Vector3.ZERO, true, 40)
	_box(root, Vector3(6.0, 0.1, 30.0), _mat("3a3d44", 0.1, 0.9), Vector3(0, 0.02, 14.0))
	_box(root, Vector3(9000, 0.1, 14), _mat("7d828a", 0.0, 0.9), Vector3(0, -0.95, -60))
	var tower := Node3D.new()
	tower.position = Vector3(-(R + 6.5), 0, 0)
	root.add_child(tower)
	var tm := _mat("8a3b2e", 0.5, 0.5)
	var th := H1 + H2 + 14.0
	for sx in [-1.5, 1.5]:
		for sz in [-1.5, 1.5]:
			_box(tower, Vector3(0.4, th, 0.4), tm, Vector3(sx, th * 0.5, sz))
	var lv := 0.0
	while lv < th:
		lv += 4.0
		_box(tower, Vector3(3.4, 0.25, 0.25), tm, Vector3(0, lv, 1.5))
		_box(tower, Vector3(3.4, 0.25, 0.25), tm, Vector3(0, lv, -1.5))
		_box(tower, Vector3(0.25, 0.25, 3.4), tm, Vector3(1.5, lv, 0))
		_box(tower, Vector3(0.25, 0.25, 3.4), tm, Vector3(-1.5, lv, 0))
	_cyl(tower, 0.03, 0.12, 7.0, _mat("c9ced6", 0.8, 0.3), Vector3(0, th + 3.5, 0), Vector3.ZERO, true, 6)
	arm = Node3D.new()
	arm.position = Vector3(1.5, H1 + 2.5, 0)
	tower.add_child(arm)
	_box(arm, Vector3(5.2, 0.5, 0.9), _mat("c9ced6", 0.5, 0.4), Vector3(2.6, 0, 0))
	# far objects for scale
	_ball(root, 5.0, white, Vector3(60, 11, -40))
	for a in 4:
		_cyl(root, 0.3, 0.3, 11.0, _mat("9aa3b0", 0.6, 0.4), Vector3(60 + cos(a * PI * 0.5 + 0.8) * 3.0, 5.5, -40 + sin(a * PI * 0.5 + 0.8) * 3.0), Vector3.ZERO, true, 6)
	_box(root, Vector3(40, 14, 26), _mat("d9dde4", 0.1, 0.7), Vector3(-90, 7, -70))
	_box(root, Vector3(40.2, 2.0, 26.2), _mat("2a6bd6", 0.2, 0.5), Vector3(-90, 11, -70))
	for k in 4:
		var ang := k * PI * 0.5 + 0.6
		_cyl(root, 0.06, 0.25, 46.0, _mat("c9ced6", 0.7, 0.4), Vector3(cos(ang) * 22.0, 23.0, sin(ang) * 22.0), Vector3.ZERO, true, 6)
	# rocket
	rk = Node3D.new()
	rk.position = Vector3(0, 1.4, 0)
	root.add_child(rk)
	s1 = Node3D.new()
	rk.add_child(s1)
	_cyl(s1, R, R, H1, white, Vector3(0, H1 * 0.5, 0))
	_cyl(s1, R * 1.01, R * 1.01, 1.4, dark, Vector3(0, 0.7, 0))
	_cyl(s1, R * 1.01, R * 1.01, 0.6, dark, Vector3(0, H1 * 0.55, 0))
	_cyl(s1, R * 0.96, R * 1.0, 1.2, dark, Vector3(0, H1 + 0.6, 0))
	var nn := 1 if launcher == "light" else 3
	for k in nn:
		var off := Vector3.ZERO if nn == 1 else Vector3(cos(k * TAU / 3.0), 0, sin(k * TAU / 3.0)) * R * 0.5
		_cyl(s1, R * 0.2, R * 0.36, 1.3, bell, off + Vector3(0, -0.6, 0), Vector3.ZERO, false)
	_flame(s1, Vector3(0, -1.2, 0), R * 0.85, R * 9.0, true)
	if launcher != "light":
		var br: float = R * (0.72 if launcher == "heavy" else 0.42)
		var bh: float = H1 * (0.86 if launcher == "heavy" else 0.5)
		for sx in [-1.0, 1.0]:
			var b := Node3D.new()
			b.position = Vector3(sx * (R + br + 0.05), 0, 0)
			rk.add_child(b)
			_cyl(b, br, br, bh, white, Vector3(0, bh * 0.5, 0))
			_cyl(b, 0.05, br, br * 2.2, _mat("d63a3a" if launcher == "medium" else "eef1f6", 0.2, 0.4), Vector3(0, bh + br * 1.1, 0))
			_cyl(b, br * 1.01, br * 1.01, 0.8, dark, Vector3(0, 0.4, 0))
			_cyl(b, br * 0.4, br * 0.7, 1.0, bell, Vector3(0, -0.5, 0), Vector3.ZERO, false)
			_flame(b, Vector3(0, -1.0, 0), br * 0.8, br * 9.0, false)
			boosters.append(b)
	s2 = Node3D.new()
	s2.position = Vector3(0, H1 + 1.2, 0)
	rk.add_child(s2)
	_cyl(s2, R * 0.96, R * 0.96, H2, white, Vector3(0, H2 * 0.5, 0))
	_cyl(s2, R * 0.97, R * 0.97, 0.5, _mat("2a6bd6", 0.2, 0.5), Vector3(0, H2 * 0.7, 0))
	_cyl(s2, R * 0.25, R * 0.5, 1.1, bell, Vector3(0, -0.5, 0), Vector3.ZERO, false)
	_cyl(s2, R * 0.5, R * 0.96, 0.5, dark, Vector3(0, H2 + 0.25, 0))
	_flame(s2, Vector3(0, -1.0, 0), R * 0.5, R * 5.0, false)
	_top_y = H1 + 1.2 + H2 + 0.5
	var RF := maxf(R * 1.02, 2.5)
	var prof := [[0.0, R * 0.96], [0.9, RF], [5.2, RF], [6.8, RF * 0.78], [8.0, RF * 0.45], [8.8, RF * 0.16], [9.1, 0.02]]
	var fm := _mat("eef1f6", 0.2, 0.4, true)
	fair_l = Node3D.new()
	fair_r = Node3D.new()
	for pair in [[fair_l, PI * 0.5, PI * 1.5], [fair_r, -PI * 0.5, PI * 0.5]]:
		var fn: Node3D = pair[0]
		fn.position = Vector3(0, _top_y, 0)
		rk.add_child(fn)
		_mi(fn, _half_shell(prof, pair[1], pair[2]), fm)
	# exhaust smoke: a cloud at the pad and a trail behind the rocket
	_smoke_n = _smoke(root, Vector3(0, 0.6, 0), 110, 9.0, 22.0, Vector3(0, 0.1, 0), 89.0, 4.5)
	_trail = _smoke(rk, Vector3(0, -3.0, 0), 90, 5.0, 6.0, Vector3(0, -1, 0), 12.0, 2.6)
	# sky and sun
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -52, 0)
	sun.light_energy = 1.7
	sun.light_color = Color("fff3dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	root.add_child(sun)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9cde6")
	env.ambient_light_energy = 0.85
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.18
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("c4dcf2")
	_set_sky(0.0)


## 0 = on the ground, 1 = in space.
func _set_sky(u: float) -> void:
	var e := clampf(u, 0.0, 1.0)
	sky_mat.sky_top_color = Color("3f7fd0").lerp(Color("01020a"), e)
	sky_mat.sky_horizon_color = Color("cfe6ff").lerp(Color("01020a"), e * e)
	sky_mat.ground_horizon_color = Color("cfe6ff").lerp(Color("20304a"), e)
	sky_mat.ground_bottom_color = Color("55703a").lerp(Color("0a1626"), e)
	env.fog_density = lerpf(0.0016, 0.0, minf(1.0, e * 3.0))
	env.ambient_light_energy = lerpf(0.85, 0.45, e)
	if stars != null:
		stars.visible = e > 0.8


func _fire(node: Node3D, lvl: float) -> void:
	for f in _flames:
		if is_instance_valid(f.n) and (f.n as Node3D).get_parent() == node:
			f.lvl = lvl


func _seat_ship(lift: float) -> void:
	ship.position = rk.position + Vector3(0, _top_y + 1.9 + lift, 0)
	ship.rotation = Vector3(PI * 0.5, 0, 0)


func _skip() -> bool:
	return ui.cine_skip


## Countdown, lift-off, staging and separation. The player can skip it with Enter, Space or a click.
func run_launch(launcher: String, launcher_name: String, dest_name: String, mass: int) -> void:
	_env_save()
	_build_pad(launcher)
	ship.visible = false
	ship.set_flame(0.0)
	ship.scale = Vector3.ONE * 0.5
	visible = true
	idle = false
	var look := Vector3(0, 16, 0)
	ui.cinema_begin()
	ui.cinema_caption("LAUNCH PAD", "%s%s, bound for %s. The spacecraft is sealed inside the nose cone." % [launcher_name, (". Payload %d kg" % mass) if mass > 0 else "", dest_name])
	await _tws(5.0, func(u: float):
		if _skip():
			return
		cam.position = Vector3(62, 7, 78).lerp(Vector3(34, 4, 44), _ease(u))
		cam.look_at(look, Vector3.UP))
	# countdown
	var c0 := Vector3(34, 4, 44)
	var c1 := Vector3(17, 2.2, 22)
	for n in range(10, 0, -1):
		if _skip():
			break
		var sub := ""
		if n == 10:
			sub = "All stations report GO."
		elif n == 6:
			sub = "Service arm retracts."
		elif n == 3:
			sub = "Main engine start."
		ui.cinema_caption("T − %d" % n, sub)
		if audio != null:
			if n > 3:
				audio.ok()
			else:
				audio.thud()
		var k := float(10 - n)
		await _tws(0.85, func(u: float):
			cam.position = c0.lerp(c1, _ease((k + u) / 10.0))
			cam.look_at(look.lerp(Vector3(0, 11, 0), (k + u) / 10.0), Vector3.UP)
			if n <= 6 and n > 3:
				arm.scale.x = maxf(0.05, 1.0 - (float(6 - n) + u) / 3.0)
			if n <= 3:
				var lv := (float(3 - n) + u) / 3.0
				_fire(s1, lv * 0.8)
				for b in boosters:
					_fire(b, lv * 0.8)
				shake = maxf(shake, 0.25 * lv))
		if n == 3:
			_smoke_n.emitting = true
	arm.scale.x = 0.05
	# lift-off
	if not _skip():
		ui.cinema_caption("LIFT-OFF", "The engines must push harder than the rocket's whole weight before it moves at all.")
		if audio != null:
			audio.alarm()
		_trail.emitting = true
		_fire(s1, 1.0)
		for b in boosters:
			_fire(b, 1.0)
		shake = 0.7
		await _tws(7.0, func(u: float):
			if _skip():
				return
			rk.position.y = 1.4 + 110.0 * u * u
			shake = maxf(shake, 0.35 * (1.0 - u))
			cam.position = c1 + Vector3(0, 0.6 * u, 0)
			cam.look_at(rk.position + Vector3(0, 14.0, 0), Vector3.UP))
	_smoke_n.emitting = false
	# ascent
	if not _skip():
		ui.cinema_caption("MAX-Q", "The moment of greatest air pressure on the rocket. The engines throttle down for a few seconds to protect it.")
		var y0 := rk.position.y
		var cp := cam.position
		await _tws(7.5, func(u: float):
			if _skip():
				return
			rk.position.y = y0 + 220.0 * u + 1400.0 * u * u
			_set_sky(u * 0.55)
			var off := Vector3(34, -6, 44).lerp(Vector3(26, 12, 36), u)
			cam.position = cp.lerp(rk.position + off, minf(1.0, u * 4.0))
			cam.look_at(rk.position + Vector3(0, 16.0, 0), Vector3.UP)
			_fire(s1, 1.0 - 0.25 * sin(clampf(u * 2.0, 0.0, 1.0) * PI)))
	# booster separation
	if not _skip() and boosters.size() > 0:
		ui.cinema_caption("BOOSTER SEPARATION", "The side boosters have burned all their propellant. Dropping them saves mass.")
		var y1 := rk.position.y
		var bx: Array = []
		for b in boosters:
			_fire(b, 0.0)
			bx.append((b as Node3D).position)
		if audio != null:
			audio.thud()
		await _tws(4.0, func(u: float):
			if _skip():
				return
			rk.position.y = y1 + 700.0 * u
			_set_sky(0.55 + u * 0.15)
			for i in boosters.size():
				var b: Node3D = boosters[i]
				var sx := signf(bx[i].x)
				b.position = bx[i] + Vector3(sx * 9.0 * u, -70.0 * u * u, 0)
				b.rotation.z = -sx * u * 0.9
			cam.position = rk.position + Vector3(26, 12, 36)
			cam.look_at(rk.position + Vector3(0, 14.0, 0), Vector3.UP))
		for b in boosters:
			(b as Node3D).visible = false
	# stage separation
	if not _skip():
		ui.cinema_caption("STAGE SEPARATION", "The empty first stage drops away. The second stage lights its own engine and carries on.")
		var y2 := rk.position.y
		_fire(s1, 0.0)
		_trail.emitting = false
		if audio != null:
			audio.thud()
		await _tws(5.5, func(u: float):
			if _skip():
				return
			rk.position.y = y2 + 600.0 * u
			_set_sky(0.7 + u * 0.3)
			s1.position = Vector3(2.0 * u, -90.0 * u * u, 0)
			s1.rotation.z = u * 0.35
			_fire(s2, clampf((u - 0.22) * 5.0, 0.0, 1.0))
			var off := Vector3(26, 12, 36).lerp(Vector3(17, _top_y - 6.0, 24), _ease(u))
			cam.position = rk.position + off
			cam.look_at(rk.position + Vector3(0, lerpf(14.0, _top_y - 2.0, _ease(u)), 0), Vector3.UP))
		s1.visible = false
	# fairing separation
	if not _skip():
		ui.cinema_caption("FAIRING SEPARATION", "Above the atmosphere the nose cone is dead weight. It splits in two and falls away.")
		var y3 := rk.position.y
		_set_sky(1.0)
		ship.visible = true
		if audio != null:
			audio.thud()
		await _tws(5.0, func(u: float):
			if _skip():
				return
			rk.position.y = y3 + 400.0 * u
			_seat_ship(0.0)
			var e := _ease(u)
			fair_l.position = Vector3(-26.0 * u * u - 1.5 * e, _top_y - 30.0 * u * u, 0)
			fair_r.position = Vector3(26.0 * u * u + 1.5 * e, _top_y - 30.0 * u * u, 0)
			fair_l.rotation.z = e * 1.1
			fair_r.rotation.z = -e * 1.1
			var off := Vector3(17, _top_y - 6.0, 24).lerp(Vector3(9, _top_y + 3.0, 13), e)
			cam.position = rk.position + off
			cam.look_at(rk.position + Vector3(0, _top_y + 1.5, 0), Vector3.UP))
		fair_l.visible = false
		fair_r.visible = false
	# spacecraft separation
	if not _skip():
		ui.cinema_caption("SPACECRAFT SEPARATION", "%s has done its job. From here the spacecraft flies on its own engine." % launcher_name)
		var y4 := rk.position.y
		var s2y := s2.position.y
		_fire(s2, 0.0)
		await _tws(4.5, func(u: float):
			if _skip():
				return
			rk.position.y = y4 + 200.0 * u
			_seat_ship(9.0 * u * u)
			s2.position.y = s2y - 16.0 * u * u
			cam.position = rk.position + Vector3(9, _top_y + 3.0 + 6.0 * u, 13)
			cam.look_at(ship.position, Vector3.UP))
	ui.cinema_end()
	leave()
