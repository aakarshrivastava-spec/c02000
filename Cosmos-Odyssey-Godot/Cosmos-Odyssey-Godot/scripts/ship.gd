extends Node3D
## The spacecraft, built from primitives. Forward is -Z (Godot convention), exhaust at +Z.
## Visuals react to subsystem health: scorching, glowing when critical, bent arrays, etc.

const Gfx = preload("res://scripts/gfx.gd")
const Data = preload("res://scripts/data.gd")
const SCORCH := Color("2a120c")
const ACCENTS := {"blue": ["2a6bd6", "78beff"], "orange": ["e8742a", "ffb36a"], "green": ["2fb36a", "7dffb0"], "pink": ["c23a9a", "ff8ad8"], "red": ["d63a3a", "ff7a6a"], "gold": ["d9a520", "ffd166"]}
const HULLS := {"pearl": "eef1f6", "red": "d8484e", "orange": "f0903a", "steel": "9aa6b8", "navy": "3a4f8a", "green": "5fae7a", "gold": "d9b45a"}

var parts := {}
var _mats := {}   # id -> Array of {m: StandardMaterial3D, base: Color, emissive_base: Color}
var wings: Array = []
var boom: Node3D
var dish_g: Node3D
var hull_node: Node3D
var flame_pivot: Node3D
var flame_mat: StandardMaterial3D
var glows: Array = []
var model := "orbiter"
var cfg: Dictionary = Data.SHIP_DEFAULT.duplicate()
var plasma: MeshInstance3D
var flame_level := 1.0
var gear: Node3D
var gear_legs: Node3D
var jets_pivot: Node3D
var jet_glows: Array = []
var jet_mat: StandardMaterial3D
var plasma_level := 0.0


func _ready() -> void:
	_build()


func set_custom(c: Dictionary) -> void:
	cfg = c.duplicate()
	set_model("custom")


func set_model(id: String) -> void:
	model = id
	for c in get_children():
		c.queue_free()
		remove_child(c)
	parts.clear()
	_mats.clear()
	wings.clear()
	glows.clear()
	gear = null
	gear_legs = null
	jets_pivot = null
	jet_glows.clear()
	_fx = null
	_pits.clear()
	_lights.clear()
	_beacons.clear()
	_build()


func _reg(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = id
	parts[id] = n
	_mats[id] = []
	add_child(n)
	return n


func _std(id: String, color: Color, metal: float = 0.55, rough: float = 0.45, emissive: Color = Color.BLACK) -> StandardMaterial3D:
	var m := Gfx.std_mat(color, metal, rough)
	m.emission_enabled = true
	m.emission = emissive
	_mats[id].append({"m": m, "base": color, "ebase": emissive})
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, seg: int = 20, caps: bool = true) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	return c


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _loft(sections: Array, seg: int = 24) -> ArrayMesh:
	# sections: [z, half_width, half_height, y_offset]; builds a smooth fuselage along Z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(sections.size() - 1):
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		for k in seg:
			var t0 := TAU * float(k) / seg
			var t1 := TAU * float(k + 1) / seg
			var p00 := Vector3(cos(t0) * a[1], sin(t0) * a[2] + a[3], a[0])
			var p01 := Vector3(cos(t1) * a[1], sin(t1) * a[2] + a[3], a[0])
			var p10 := Vector3(cos(t0) * b[1], sin(t0) * b[2] + b[3], b[0])
			var p11 := Vector3(cos(t1) * b[1], sin(t1) * b[2] + b[3], b[0])
			for v in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	return st.commit()


func _extrude(poly: PackedVector2Array, thick: float, map: Callable) -> ArrayMesh:
	# flat plate from a 2D outline; map(Vector2, depth) -> Vector3 places it in 3D
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(poly)
	var h := thick * 0.5
	for face in [1.0, -1.0]:
		for i in range(0, idx.size(), 3):
			var tri := [idx[i], idx[i + 1], idx[i + 2]]
			if face < 0.0:
				tri.reverse()
			for t in tri:
				st.add_vertex(map.call(poly[t], face * h))
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		for v in [map.call(a, h), map.call(b, h), map.call(b, -h), map.call(a, h), map.call(b, -h), map.call(a, -h)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _build() -> void:
	match model:
		"capsule":
			_build_capsule()
		"probe":
			_build_probe()
		"custom":
			_build_custom()
		_:
			_build_orbiter()


func _build_orbiter() -> void:
	# A white spaceplane: smooth fuselage, swept delta wings, tail fin, dark canopy, twin engines.
	var rx := Vector3(90, 0, 0)
	var white := Color("eef1f6")
	var dark := Color("1b2230")

	hull_node = _reg("hull")
	var body_mat := _std("hull", white, 0.25, 0.4)
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sections := [
		[-3.0, 0.04, 0.04, 0.0], [-2.75, 0.22, 0.18, 0.0], [-2.3, 0.4, 0.3, 0.02],
		[-1.5, 0.56, 0.42, 0.04], [-0.3, 0.66, 0.5, 0.05], [1.0, 0.68, 0.5, 0.05],
		[2.1, 0.62, 0.46, 0.03], [2.75, 0.5, 0.38, 0.0]]
	_mesh(hull_node, _loft(sections), body_mat)
	# canopy / visor
	var canopy := SphereMesh.new()
	canopy.radius = 0.5
	canopy.height = 1.0
	canopy.radial_segments = 20
	canopy.rings = 10
	var visor_mat := _std("hull", Color("0f1a2e"), 0.9, 0.12)
	var cn := _mesh(hull_node, canopy, visor_mat, Vector3(0, 0.36, -1.75))
	cn.scale = Vector3(0.46, 0.26, 1.0)
	# swept delta wings (white, part of the hull)
	var wing_mat := _std("hull", white, 0.2, 0.45)
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wing_poly := PackedVector2Array([Vector2(0.45, -0.9), Vector2(3.25, 2.0), Vector2(3.25, 2.5), Vector2(0.45, 2.55)])
	for side in [1.0, -1.0]:
		var m := func(p: Vector2, d: float) -> Vector3: return Vector3(side * p.x, -0.12 - absf(p.x) * 0.03 + d, p.y)
		_mesh(hull_node, _extrude(wing_poly, 0.07, m), wing_mat)
		# dark wing-tip accent
		var tip := PackedVector2Array([Vector2(3.0, 1.85), Vector2(3.28, 2.0), Vector2(3.28, 2.5), Vector2(3.0, 2.5)])
		var tm := func(p: Vector2, d: float) -> Vector3: return Vector3(side * p.x, -0.12 - absf(p.x) * 0.03 + d * 1.25, p.y)
		_mesh(hull_node, _extrude(tip, 0.07, tm), _std("hull", dark, 0.4, 0.5))
	# tail fin
	var fin_poly := PackedVector2Array([Vector2(0.4, 0.8), Vector2(1.5, 2.0), Vector2(1.5, 2.55), Vector2(0.4, 2.6)])
	var fm := func(p: Vector2, d: float) -> Vector3: return Vector3(d, p.x, p.y)
	_mesh(hull_node, _extrude(fin_poly, 0.07, fm), wing_mat)

	# heat shield: dark nose cap and belly tiles
	var shield := _reg("shield")
	var nose := SphereMesh.new()
	nose.radius = 0.5
	nose.height = 1.0
	nose.radial_segments = 16
	nose.rings = 8
	var nm := _mesh(shield, nose, _std("shield", Color("2a2c33"), 0.2, 0.8), Vector3(0, 0.0, -2.8))
	nm.scale = Vector3(0.34, 0.3, 0.62)
	_mesh(shield, _box(0.9, 0.05, 4.2), _std("shield", Color("2a2c33"), 0.2, 0.85), Vector3(0, -0.5, 0.3))

	# solar arrays: blue panels laid on the wings, they bend up when damaged
	var arrays := _reg("arrays")
	for side in [-1, 1]:
		var w := Node3D.new()
		w.position = Vector3(side * 0.6, -0.04, 0.0)
		_mesh(w, _box(1.5, 0.03, 1.5), _std("arrays", Color("2a4fa6"), 0.35, 0.3, Color("0a1a40")), Vector3(side * 1.25, 0.0, 1.35))
		arrays.add_child(w)
		wings.append(w)

	# sensor mast behind the canopy
	var sensors := _reg("sensors")
	boom = Node3D.new()
	boom.position = Vector3(0, 0.5, -0.7)
	_mesh(boom, _cyl(0.03, 0.03, 0.6, 8), _std("sensors", Color("b8bec8")), Vector3(0, 0.3, 0))
	_mesh(boom, _box(0.22, 0.14, 0.26), _std("sensors", Color("e0e4ea")), Vector3(0, 0.65, 0))
	var lens := SphereMesh.new()
	lens.radius = 0.05
	lens.height = 0.1
	lens.radial_segments = 8
	lens.rings = 4
	_mesh(boom, lens, Gfx.unshaded_mat(Color("66ccff")), Vector3(0, 0.65, -0.14))
	sensors.add_child(boom)

	# comms dish on the spine
	var comms := _reg("comms")
	dish_g = Node3D.new()
	dish_g.position = Vector3(0, 0.55, 0.55)
	var dish := SphereMesh.new()
	dish.radius = 0.3
	dish.height = 0.3
	dish.is_hemisphere = true
	var dish_mat := _std("comms", Color("eeeeee"), 0.3, 0.4)
	dish_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(dish_g, dish, dish_mat, Vector3.ZERO, Vector3(rad_to_deg(0.7), 0, 0))
	comms.add_child(dish_g)
	_build_engines([-0.5, 0.5], 2.95, 0.3, Color("4b525e"), Color("78beff"))
	plasma = Gfx.glow(Color("ff8c3c"), 7.0, 0.0)
	plasma.position = Vector3(0, 0, -3.0)
	add_child(plasma)


func _build_engines(xs: Array, bz: float, r: float, bell_col: Color, flame_col: Color) -> void:
	var rx := Vector3(90, 0, 0)
	var thr := _reg("thrusters")
	var bell_mat := _std("thrusters", bell_col, 0.8, 0.35)
	bell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for x in xs:
		_mesh(thr, _cyl(r, r * 0.73, r * 2.0, 18, false), bell_mat, Vector3(x, -0.02, bz), rx)
		_mesh(thr, _cyl(r * 0.67, r * 0.67, 0.02, 14), Gfx.unshaded_mat(flame_col.lightened(0.3)), Vector3(x, -0.02, bz - r * 0.9), rx)
	flame_pivot = Node3D.new()
	flame_pivot.position = Vector3(0, -0.02, bz)
	add_child(flame_pivot)
	flame_mat = StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flame_mat.no_depth_test = false
	flame_mat.albedo_color = Color(flame_col.r, flame_col.g, flame_col.b, 0.3)
	# three nested soft cones (outer to core) so the flame fades out instead of a hard solid cone
	var layers := [[0.62, 5.0], [0.42, 3.6], [0.22, 2.3]]
	for x in xs:
		for L in layers:
			var rad: float = r * float(L[0])
			var ln: float = r * float(L[1])
			var f := _mesh(flame_pivot, _cyl(0.0, rad, ln, 14), flame_mat, Vector3(x, 0, r * 0.7 + ln * 0.5), rx)
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var g := Gfx.glow(flame_col, r * 8.7, 0.9)
		g.position = Vector3(x, -0.02, bz + r * 1.4)
		add_child(g)
		glows.append(g)


func _add_plasma(z: float) -> void:
	plasma = Gfx.glow(Color("ff8c3c"), 7.0, 0.0)
	plasma.position = Vector3(0, 0, z)
	add_child(plasma)


func _mast(pos: Vector3) -> void:
	var sensors := _reg("sensors")
	boom = Node3D.new()
	boom.position = pos
	_mesh(boom, _cyl(0.03, 0.03, 0.6, 8), _std("sensors", Color("b8bec8")), Vector3(0, 0.3, 0))
	_mesh(boom, _box(0.22, 0.14, 0.26), _std("sensors", Color("e0e4ea")), Vector3(0, 0.65, 0))
	var lens := SphereMesh.new()
	lens.radius = 0.05
	lens.height = 0.1
	lens.radial_segments = 8
	lens.rings = 4
	_mesh(boom, lens, Gfx.unshaded_mat(Color("66ccff")), Vector3(0, 0.65, -0.14))
	sensors.add_child(boom)


func _dish(pos: Vector3, radius: float, tilt: float) -> void:
	var comms := _reg("comms")
	dish_g = Node3D.new()
	dish_g.position = pos
	var d := SphereMesh.new()
	d.radius = radius
	d.height = radius
	d.is_hemisphere = true
	var m := _std("comms", Color("eeeeee"), 0.3, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(dish_g, d, m, Vector3.ZERO, Vector3(rad_to_deg(tilt), 0, 0))
	comms.add_child(dish_g)


func _panel_wings(x0: float, z: float, len: float, wid: float, y: float = 0.0) -> void:
	var arrays := _reg("arrays")
	for side in [-1, 1]:
		var w := Node3D.new()
		w.position = Vector3(side * x0, y, z)
		_mesh(w, _box(len, 0.03, wid), _std("arrays", Color("2a4fa6"), 0.35, 0.3, Color("0a1a40")), Vector3(side * len * 0.5, 0.0, 0.0))
		for k in range(1, 4):
			_mesh(w, _box(0.02, 0.04, wid), _std("arrays", Color("9fb3d6"), 0.5, 0.3), Vector3(side * len * k / 4.0, 0.0, 0.0))
		arrays.add_child(w)
		wings.append(w)


func _build_capsule() -> void:
	# Crew-capsule style: blunt capsule (heat shield forward), gold service module, long solar wings.
	var rx := Vector3(90, 0, 0)
	hull_node = _reg("hull")
	var cap_mat := _std("hull", Color("e4e7ee"), 0.2, 0.45)
	_mesh(hull_node, _cyl(0.4, 1.0, 1.8, 28), cap_mat, Vector3(0, 0, -1.0), rx)
	_mesh(hull_node, _cyl(0.22, 0.4, 0.3, 20), cap_mat, Vector3(0, 0, 0.0), rx)
	var win := _std("hull", Color("0f1a2e"), 0.9, 0.12)
	for sx in [-1, 1]:
		var w := _mesh(hull_node, SphereMesh.new(), win, Vector3(sx * 0.38, 0.28, -0.95))
		w.scale = Vector3(0.14, 0.18, 0.1)
		w.rotation_degrees = Vector3(0, sx * 28, 0)
	var sm := _std("hull", Color("d9b45a"), 0.3, 0.4)
	_mesh(hull_node, _cyl(0.78, 0.78, 2.3, 28), sm, Vector3(0, 0, 1.2), rx)
	_mesh(hull_node, _cyl(0.8, 0.8, 0.1, 28), _std("hull", Color("e4e7ee"), 0.2, 0.45), Vector3(0, 0, 0.1), rx)
	_mesh(hull_node, _cyl(0.8, 0.8, 0.1, 28), _std("hull", Color("e4e7ee"), 0.2, 0.45), Vector3(0, 0, 2.3), rx)
	var shield := _reg("shield")
	_mesh(shield, _cyl(0.98, 1.04, 0.14, 28), _std("shield", Color("2a2c33"), 0.2, 0.85), Vector3(0, 0, -1.95), rx)
	_panel_wings(0.78, 1.2, 3.2, 1.3, 0.0)
	_mast(Vector3(0, 0.78, 0.7))
	_dish(Vector3(0, 0.8, 1.9), 0.34, 0.5)
	_build_engines([0.0], 2.55, 0.4, Color("4b525e"), Color("ffb36a"))
	_add_plasma(-2.0)


func _build_probe() -> void:
	# Sun-probe style: big flat heat shield in front, small hexagonal bus hiding behind it.
	var rx := Vector3(90, 0, 0)
	hull_node = _reg("hull")
	_mesh(hull_node, _cyl(0.62, 0.62, 2.0, 6), _std("hull", Color("d4b863"), 0.3, 0.4), Vector3(0, 0, -0.2), rx)
	_mesh(hull_node, _cyl(0.5, 0.62, 0.35, 6), _std("hull", Color("9aa0aa"), 0.3, 0.45), Vector3(0, 0, 0.95), rx)
	for sx in [-1, 1]:
		_mesh(hull_node, _box(0.18, 0.5, 0.9), _std("hull", Color("e8e8ec"), 0.3, 0.5), Vector3(sx * 0.7, 0.0, -0.3))
	var shield := _reg("shield")
	var sh_mat := _std("shield", Color("ddd6c8"), 0.1, 0.7)
	_mesh(shield, _cyl(1.5, 1.95, 0.14, 40), sh_mat, Vector3(0, 0, -1.55), rx)
	_mesh(shield, _cyl(1.97, 1.97, 0.08, 40), _std("shield", Color("2a2c33"), 0.2, 0.85), Vector3(0, 0, -1.47), rx)
	for k in 3:
		var a := TAU * k / 3.0
		_mesh(shield, _cyl(0.05, 0.05, 1.4, 6), _std("shield", Color("8a8f99"), 0.8, 0.4), Vector3(cos(a) * 0.35, sin(a) * 0.35, -0.9), rx)
	_panel_wings(0.62, 0.2, 2.0, 0.7, 0.0)
	_mast(Vector3(0, 0.6, 0.6))
	_dish(Vector3(0, -0.4, 1.15), 0.42, 3.14159 - 0.4)
	_build_engines([-0.22, 0.22], 1.2, 0.17, Color("4b525e"), Color("9fe0ff"))
	_add_plasma(-1.7)


func _build_custom() -> void:
	var rx := Vector3(90, 0, 0)
	var body: String = cfg.get("body", "classic")
	var w := 0.78 if body == "slim" else (1.28 if body == "stout" else 1.0)
	var h := 0.85 if body == "slim" else (1.2 if body == "stout" else 1.0)
	var zl := 1.0 if body != "stout" else 0.88
	var hull_col := Color(HULLS.get(cfg.get("hull_col", "pearl"), "eef1f6"))
	var acc: Array = ACCENTS.get(cfg.get("accent", "blue"), ACCENTS.blue)
	var acc_col := Color(acc[0])
	var flame_col := Color(acc[1])
	var ws := {"small": 0.7, "medium": 1.0, "large": 1.3}.get(cfg.get("wing_size", "medium"), 1.0) as float

	hull_node = _reg("hull")
	var body_mat := _std("hull", hull_col, 0.25, 0.4)
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var base := [
		[-3.0, 0.04, 0.04, 0.0], [-2.75, 0.22, 0.18, 0.0], [-2.3, 0.4, 0.3, 0.02],
		[-1.5, 0.56, 0.42, 0.04], [-0.3, 0.66, 0.5, 0.05], [1.0, 0.68, 0.5, 0.05],
		[2.1, 0.62, 0.46, 0.03], [2.75, 0.5, 0.38, 0.0]]
	var sections: Array = []
	for b in base:
		sections.append([b[0] * zl, b[1] * w, b[2] * h, b[3]])
	_mesh(hull_node, _loft(sections), body_mat)
	var canopy := SphereMesh.new()
	canopy.radius = 0.5
	canopy.height = 1.0
	canopy.radial_segments = 20
	canopy.rings = 10
	var cn := _mesh(hull_node, canopy, _std("hull", Color("0f1a2e"), 0.9, 0.12), Vector3(0, 0.36 * h, -1.75 * zl))
	cn.scale = Vector3(0.46 * w, 0.26 * h, 1.0)

	# wings
	var wing_kind: String = cfg.get("wings", "delta")
	var wing_mat := _std("hull", hull_col, 0.2, 0.45)
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var panel_z := 1.35 * zl
	if wing_kind != "none":
		var x0 := 0.45 * w
		var xt := x0 + 2.8 * ws
		var poly: PackedVector2Array
		match wing_kind:
			"straight":
				poly = PackedVector2Array([Vector2(x0, 0.0 * zl), Vector2(xt, 0.3 * zl), Vector2(xt, 1.1 * zl), Vector2(x0, 1.7 * zl)])
				panel_z = 0.85 * zl
			"swept":
				poly = PackedVector2Array([Vector2(x0, -0.5 * zl), Vector2(xt, 2.1 * zl), Vector2(xt, 2.6 * zl), Vector2(x0, 2.2 * zl)])
				panel_z = 1.5 * zl
			_:
				poly = PackedVector2Array([Vector2(x0, -0.9 * zl), Vector2(xt, 2.0 * zl), Vector2(xt, 2.5 * zl), Vector2(x0, 2.55 * zl)])
		for side in [1.0, -1.0]:
			var m := func(p: Vector2, d: float) -> Vector3: return Vector3(side * p.x, -0.12 * h - absf(p.x) * 0.03 + d, p.y)
			_mesh(hull_node, _extrude(poly, 0.07, m), wing_mat)
			var tip := _mesh(hull_node, _box(0.3, 0.09, 0.5 + 0.2 * ws), _std("hull", acc_col, 0.4, 0.5),
				Vector3(side * (xt - 0.12), -0.12 * h - xt * 0.03, (poly[1].y + poly[2].y) * 0.5))
			tip.rotation_degrees = Vector3(0, 0, 0)

	# tail fin(s)
	var fin_kind: String = cfg.get("fin", "single")
	if fin_kind != "none":
		var f := 1.7 if fin_kind == "tall" else 1.0
		var fin_poly := PackedVector2Array([Vector2(0.4 * h, 0.8 * zl), Vector2(1.5 * f * h, 2.0 * zl), Vector2(1.5 * f * h, 2.55 * zl), Vector2(0.4 * h, 2.6 * zl)])
		var fin_mat := _std("hull", acc_col if fin_kind == "twin" else hull_col, 0.25, 0.45)
		fin_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var fm := func(p: Vector2, d: float) -> Vector3: return Vector3(d, p.x, p.y)
		if fin_kind == "twin":
			for side in [1.0, -1.0]:
				var pv := Node3D.new()
				pv.position = Vector3(side * 0.5 * w, 0.0, 0.0)
				pv.rotation_degrees = Vector3(0, 0, -side * 18.0)
				hull_node.add_child(pv)
				_mesh(pv, _extrude(fin_poly, 0.07, fm), fin_mat)
		else:
			_mesh(hull_node, _extrude(fin_poly, 0.07, fm), fin_mat)

	# heat shield
	var shield := _reg("shield")
	var nose := SphereMesh.new()
	nose.radius = 0.5
	nose.height = 1.0
	nose.radial_segments = 16
	nose.rings = 8
	var nm := _mesh(shield, nose, _std("shield", Color("2a2c33"), 0.2, 0.8), Vector3(0, 0.0, -2.8 * zl))
	nm.scale = Vector3(0.34 * w, 0.3 * h, 0.62)
	_mesh(shield, _box(0.9 * w, 0.05, 4.2 * zl), _std("shield", Color("2a2c33"), 0.2, 0.85), Vector3(0, -0.5 * h, 0.3 * zl))

	# solar panels
	if cfg.get("panels", "wing") == "boom" or wing_kind == "none":
		_panel_wings(0.66 * w, 0.9 * zl, 3.0, 1.2, 0.0)
	else:
		var arrays := _reg("arrays")
		for side in [-1, 1]:
			var pv := Node3D.new()
			pv.position = Vector3(side * 0.6 * w, -0.04, 0.0)
			var pw := 1.5 * ws
			_mesh(pv, _box(pw, 0.03, 1.4), _std("arrays", Color("2a4fa6"), 0.35, 0.3, Color("0a1a40")), Vector3(side * (0.15 + pw * 0.5 + 0.35 * ws), 0.0, panel_z))
			arrays.add_child(pv)
			wings.append(pv)

	_mast(Vector3(0, 0.5 * h, -0.7 * zl))
	_dish(Vector3(0, 0.55 * h, 0.55 * zl), 0.3, 0.7)

	# engines
	var n := int(cfg.get("engines", "2"))
	var r: float = {"small": 0.2, "medium": 0.28, "large": 0.36}.get(cfg.get("nozzle", "medium"), 0.28)
	var xs: Array = []
	if n == 1:
		xs = [0.0]
	elif n == 2:
		xs = [-0.5 * w, 0.5 * w]
	else:
		xs = [-0.62 * w, 0.0, 0.62 * w]
		r = minf(r, 0.22 * w + 0.05)
	_build_engines(xs, 2.75 * zl + 0.2 + r * 0.2, r, Color("4b525e"), flame_col)
	_add_plasma(-3.0 * zl)


func gear_info() -> Dictionary:
	match model:
		"capsule":
			return {"h": 1.7, "front": -1.0, "rear": 1.8, "x": 0.95}
		"probe":
			return {"h": 2.4, "front": -0.9, "rear": 0.9, "x": 1.0}
		"custom":
			var w := 0.78 if cfg.get("body", "classic") == "slim" else (1.28 if cfg.get("body", "classic") == "stout" else 1.0)
			return {"h": 1.0 + 0.2 * w, "front": -1.4, "rear": 1.5, "x": 0.72 * w}
	return {"h": 1.05, "front": -1.5, "rear": 1.6, "x": 0.8}


func _ensure_gear() -> void:
	if gear != null:
		return
	var gi := gear_info()
	gear = Node3D.new()
	add_child(gear)
	gear_legs = Node3D.new()
	gear_legs.position = Vector3(0, -0.15, 0)
	gear.add_child(gear_legs)
	var metal := Gfx.std_mat(Color("8d95a3"), 0.6, 0.45)
	var depth: float = float(gi.h) - 0.15
	for sx in [-1.0, 1.0]:
		for z in [gi.front, gi.rear]:
			var top := Vector3(sx * float(gi.x) * 0.55, 0.0, z)
			var foot := Vector3(sx * float(gi.x) * 1.15, -depth, z)
			var d := foot - top
			var strut := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.07
			cm.height = d.length()
			cm.radial_segments = 8
			strut.mesh = cm
			strut.material_override = metal
			var t := d.normalized()
			var xa := t.cross(Vector3.FORWARD).normalized()
			var za := xa.cross(t).normalized()
			strut.transform = Transform3D(Basis(xa, t, za), (top + foot) * 0.5)
			gear_legs.add_child(strut)
			var pad := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.3
			pm.bottom_radius = 0.34
			pm.height = 0.07
			pad.mesh = pm
			pad.material_override = metal
			pad.position = foot + Vector3(0, 0.03, 0)
			gear_legs.add_child(pad)
			# lander condition light on each foot
			var bl := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.09
			bs.height = 0.18
			bs.radial_segments = 10
			bs.rings = 5
			bl.mesh = bs
			var bmat := StandardMaterial3D.new()
			bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bmat.albedo_color = Color("5fd68a")
			bl.material_override = bmat
			bl.position = foot + Vector3(0, 0.16, 0)
			bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bl.visible = false
			gear_legs.add_child(bl)
			_beacons.append(bl)
	# landing jets: two downward flames under the belly
	jets_pivot = Node3D.new()
	jets_pivot.position = Vector3(0, -0.4, 0)
	gear.add_child(jets_pivot)
	jet_mat = StandardMaterial3D.new()
	jet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	jet_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	jet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jet_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.6)
	for z in [gi.front * 0.6, gi.rear * 0.8]:
		var f := MeshInstance3D.new()
		var fc := CylinderMesh.new()
		fc.top_radius = 0.26
		fc.bottom_radius = 0.0
		fc.height = 2.2
		fc.radial_segments = 12
		f.mesh = fc
		f.material_override = jet_mat
		f.position = Vector3(0, -1.1, z)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jets_pivot.add_child(f)
		var g := Gfx.glow(Color("cfe6ff"), 3.0, 0.8)
		g.position = Vector3(0, -0.5, z)
		gear.add_child(g)
		jet_glows.append(g)
	set_jets(0.0)
	set_legs(0.0)


## Landing legs: 0 = tucked away, 1 = fully out.
func set_legs(v: float) -> void:
	_ensure_gear()
	gear_legs.visible = v > 0.02
	gear_legs.scale = Vector3(1.0, maxf(0.02, v), 1.0)


## Landing jets (downward flames): 0 = off, 1 = full.
func set_jets(v: float) -> void:
	_ensure_gear()
	jets_pivot.visible = v > 0.02
	jets_pivot.scale = Vector3(1.0, maxf(0.05, v), 1.0)
	for g in jet_glows:
		Gfx.set_glow_opacity(g, 0.8 * clampf(v, 0.0, 1.0))
		(g as MeshInstance3D).visible = v > 0.02


func set_flame(v: float) -> void:
	flame_level = v


func set_plasma(v: float) -> void:
	plasma_level = v
	Gfx.set_glow_opacity(plasma, minf(1.0, v))
	var sc := 5.0 + v * 8.0
	plasma.scale = Vector3(sc / 7.0, sc / 7.0, sc / 7.0)


func update_look(h: Dictionary, known_shield: float, t: float) -> void:
	_update_fx(t)
	_look("hull", h.hull, t)
	_look("shield", known_shield, t)
	_look("arrays", h.arrays, t)
	_look("sensors", h.sensors, t)
	_look("comms", h.comms, t)
	_look("thrusters", h.thrusters, t)
	var da := 1.0 - float(h.arrays) / 100.0
	var ds := 1.0 - float(h.sensors) / 100.0
	var dc := 1.0 - float(h.comms) / 100.0
	var dh := 1.0 - float(h.hull) / 100.0
	wings[0].rotation.z = da * 0.55
	wings[1].rotation.z = -da * 0.8
	boom.rotation.z = ds * 0.9
	dish_g.rotation.y = sin(t * 3.1) * dc * 0.8 if dc > 0.4 else 0.0
	hull_node.scale = Vector3(1.0 - dh * 0.05, 1.0 - dh * 0.05, 1.0)

	var base := flame_level * (0.45 + 0.55 * float(h.thrusters) / 100.0)
	var stutter := 1.0
	if h.thrusters < 55:
		stutter = 0.6 + 0.4 * sin(t * 31.0) * sin(t * 17.0)
	var k := maxf(0.02, base * stutter) * (0.92 + 0.08 * sin(t * 40.0))
	flame_pivot.scale = Vector3(1, 1, k)
	flame_mat.albedo_color.a = 0.05 + 0.22 * minf(1.0, k)
	for g in glows:
		Gfx.set_glow_opacity(g, 0.1 + 0.5 * minf(1.0, k))
	if plasma_level > 0.0:
		Gfx.set_glow_opacity(plasma, minf(1.0, plasma_level * (0.85 + 0.15 * sin(t * 50.0))))


func _look(id: String, v: float, t: float) -> void:
	var d := 1.0 - v / 100.0
	for e in _mats[id]:
		var m: StandardMaterial3D = e.m
		m.albedo_color = (e.base as Color).lerp(SCORCH, minf(0.85, d * 0.95))
		var dusty := dust * (0.85 if id == "arrays" else 0.22)
		if dusty > 0.0:
			m.albedo_color = m.albedo_color.lerp(dust_col, dusty)
		if v < 45.0:
			var pulse := 0.5 + 0.5 * sin(t * 6.0 + id.length())
			m.emission = Color(1, 0.25, 0.05)
			m.emission_energy_multiplier = (1.0 - v / 45.0) * (0.25 + 0.5 * pulse)
		else:
			m.emission = (e.ebase as Color).lerp(Color.BLACK, dust if id == "arrays" else 0.0)
			m.emission_energy_multiplier = 1.0


# ---------------- progressive damage visuals ----------------
# Dust on the solar panels, impact marks on the hull, status lights for the main systems
# and a condition light on each landing foot. All of them change gradually with the mission state.

const LIGHT_OK := Color("4dff8a")
const LIGHT_WARN := Color("ffc93c")
const LIGHT_BAD := Color("ff4a3a")
const MAX_PITS := 18

var dust := 0.0                    # 0..1 dust cover on the panels
var dust_col := Color("c48a62")
var landing_cond := -1.0           # 0..100, -1 hides the foot lights
var _fx: Node3D
var _pits: Array = []
var _lights: Array = []
var _beacons: Array = []
var _status: Array = []            # one value 0..100 per light, -1 = light off
var _impacts := 0


## impacts: number of visible impact marks. status: condition (0..100) for each status light, in order.
func set_fx(impacts: int, status: Array, dust_v: float = 0.0, dust_c: Color = Color("c48a62"), landing: float = -1.0) -> void:
	_impacts = clampi(impacts, 0, MAX_PITS)
	_status = status
	dust = clampf(dust_v, 0.0, 1.0)
	dust_col = dust_c
	landing_cond = landing


static func light_color(v: float, t: float) -> Color:
	if v < 0.0:
		return Color(0.05, 0.05, 0.06)
	if v <= 0.0:
		return Color(0.12, 0.03, 0.03)
	if v >= 60.0:
		return LIGHT_OK
	if v >= 40.0:
		return LIGHT_WARN
	if v >= 20.0:
		return LIGHT_BAD
	return LIGHT_BAD if fmod(t * 2.5, 1.0) < 0.5 else Color(0.2, 0.04, 0.03)   # severe: blinking


func _hull_tris() -> Array:
	var out: Array = []
	if hull_node == null:
		return out
	for c in hull_node.get_children():
		if not (c is MeshInstance3D) or (c as MeshInstance3D).mesh == null:
			continue
		var mi := c as MeshInstance3D
		var f: PackedVector3Array = mi.mesh.get_faces()
		for i in range(0, f.size() - 2, 3):
			var a: Vector3 = mi.transform * f[i]
			var b: Vector3 = mi.transform * f[i + 1]
			var cc: Vector3 = mi.transform * f[i + 2]
			var n := (b - a).cross(cc - a)
			if n.length() < 0.0004:
				continue
			out.append([(a + b + cc) / 3.0, n.normalized()])
	return out


func _ensure_fx() -> void:
	if _fx != null and is_instance_valid(_fx):
		return
	_pits.clear()
	_lights.clear()
	if hull_node == null:
		return
	var tris := _hull_tris()
	_fx = Node3D.new()
	_fx.name = "damage_fx"
	hull_node.add_child(_fx)
	if tris.is_empty():
		return
	var lo: Vector3 = tris[0][0]
	var hi: Vector3 = tris[0][0]
	for tr in tris:
		lo = lo.min(tr[0])
		hi = hi.max(tr[0])
	var mid := (lo + hi) * 0.5
	# impact marks: dark pits with a scorched halo, spread over the hull
	var rng := RandomNumberGenerator.new()
	rng.seed = 20001
	var pit_mat := Gfx.std_mat(Color("0d0a09"), 0.1, 0.95)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(0.16, 0.09, 0.05, 0.55)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.roughness = 1.0
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 1.0
	disc.radial_segments = 9
	disc.rings = 1
	for i in MAX_PITS:
		var tr: Array = tris[rng.randi() % tris.size()]
		var c: Vector3 = tr[0]
		var n: Vector3 = tr[1]
		if n.dot(c - Vector3(mid.x, mid.y, c.z)) < 0.0:
			n = -n
		var ref := Vector3.RIGHT if absf(n.x) < 0.8 else Vector3.FORWARD
		var xa := n.cross(ref).normalized()
		var za := xa.cross(n).normalized()
		var r := rng.randf_range(0.07, 0.17)
		var pit := Node3D.new()
		pit.transform = Transform3D(Basis(xa, n, za), c + n * 0.012)
		var core := MeshInstance3D.new()
		core.mesh = disc
		core.material_override = pit_mat
		core.scale = Vector3(r, 0.02, r * rng.randf_range(0.7, 1.3))
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pit.add_child(core)
		var halo := MeshInstance3D.new()
		halo.mesh = disc
		halo.material_override = halo_mat
		halo.scale = Vector3(r * 2.3, 0.012, r * 2.0)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pit.add_child(halo)
		pit.visible = false
		_fx.add_child(pit)
		_pits.append(pit)
	# status lights: a short row along the top of the fuselage, ahead of the tail
	var ball := SphereMesh.new()
	ball.radius = 0.075
	ball.height = 0.15
	ball.radial_segments = 10
	ball.rings = 5
	for k in 5:
		var z: float = lerpf(mid.z - (hi.z - lo.z) * 0.22, mid.z - (hi.z - lo.z) * 0.02, float(k) / 4.0)
		var best := Vector3(mid.x, hi.y, z)
		var best_y := -INF
		for tr in tris:
			var c2: Vector3 = tr[0]
			if absf(c2.z - z) < 0.3 and absf(c2.x - mid.x) < 0.2 and c2.y > best_y and c2.y < mid.y + (hi.y - mid.y) * 0.7:
				best_y = c2.y
				best = c2
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = LIGHT_OK
		var li := MeshInstance3D.new()
		li.mesh = ball
		li.material_override = lm
		li.position = Vector3(mid.x, best.y + 0.05, z)
		li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		li.visible = false
		_fx.add_child(li)
		_lights.append(li)


func _update_fx(t: float) -> void:
	_ensure_fx()
	for i in _pits.size():
		(_pits[i] as Node3D).visible = i < _impacts
	for i in _lights.size():
		var li: MeshInstance3D = _lights[i]
		li.visible = i < _status.size()
		if li.visible:
			(li.material_override as StandardMaterial3D).albedo_color = light_color(float(_status[i]), t + i * 0.13)
	for b in _beacons:
		if not is_instance_valid(b):
			continue
		(b as MeshInstance3D).visible = landing_cond >= 0.0
		if landing_cond >= 0.0:
			((b as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = light_color(landing_cond, t)
	if gear_legs != null and is_instance_valid(gear_legs):
		# damaged landing gear lets the lander sit slightly crooked
		gear_legs.rotation.z = (0.0 if landing_cond < 0.0 else clampf((70.0 - landing_cond) / 70.0, 0.0, 1.0) * 0.07)
