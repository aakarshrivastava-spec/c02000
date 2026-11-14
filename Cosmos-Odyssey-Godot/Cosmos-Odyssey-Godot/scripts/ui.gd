extends CanvasLayer
## All 2D interface, built in code. Text is 18px or larger (reference 1600x900) so it reads on a projector.
## Dialog helpers are coroutines: `var pick = await ui.choose(...)`.
## Number keys 1-9 pick the matching option, Enter/Space presses the main button.

const Data = preload("res://scripts/data.gd")
const State = preload("res://scripts/state.gd")

signal _result(value)
signal sound_toggled

var speed := 1.0
var auto: Callable = Callable()   # set for bot play; empty = interactive

var hud_box: VBoxContainer
var subs_box: VBoxContainer
var cue_label: Label
var toasts: VBoxContainer
var flash_rect: ColorRect
var mini_label: Label
var dialog: PanelContainer
var dialog_box: VBoxContainer
var overlay: ColorRect
var overlay_center: CenterContainer
var labels_host: Control
var sound_btn: Button
var _cue_tween: Tween
var _flash_tween: Tween
var _buttons: Array = []     # option buttons of the current dialog (for number keys)
var _main_button: Button = null
var _power_left := 0.0
var _power_total := 1.0
var _power_bar: ProgressBar = null
var _power_running := false
# cinematic introductions
var cine: Control
var cine_title: Label
var cine_sub: Label
var cine_passive := false     # true while a cinematic also shows dialogs: no skip, normal input
var cine_skip := false
var _cine_hint: Label
var _hud_panel: PanelContainer
var _subs_panel: PanelContainer
var _cine_tween: Tween

const COL_OK := Color("5fd68a")
const COL_WARN := Color("f0c24b")
const COL_BAD := Color("f06a5a")
const PANEL_BG := Color(0.04, 0.06, 0.13, 0.9)


func _ready() -> void:
	layer = 10
	var theme := Theme.new()
	theme.default_font_size = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	labels_host = Control.new()
	labels_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	labels_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(labels_host)

	# HUD top-left
	var hud_panel := _panel()
	hud_panel.position = Vector2(16, 16)
	hud_panel.custom_minimum_size = Vector2(330, 0)
	hud_box = VBoxContainer.new()
	hud_panel.add_child(hud_box)
	root.add_child(hud_panel)
	_hud_panel = hud_panel

	# Ship systems top-right
	var subs_panel := _panel()
	subs_panel.anchor_left = 1.0
	subs_panel.anchor_right = 1.0
	subs_panel.offset_left = -340
	subs_panel.offset_right = -16
	subs_panel.offset_top = 16
	subs_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	subs_box = VBoxContainer.new()
	subs_panel.add_child(subs_box)
	root.add_child(subs_panel)
	_subs_panel = subs_panel

	# Cue (top centre)
	cue_label = Label.new()
	cue_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cue_label.offset_top = 14
	cue_label.offset_left = -400
	cue_label.offset_right = 400
	cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cue_label.modulate.a = 0.0
	cue_label.add_theme_color_override("font_color", Color("c9d8ff"))
	cue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cue_label.add_theme_constant_override("outline_size", 6)
	root.add_child(cue_label)

	# Mini status (below cue)
	mini_label = Label.new()
	mini_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mini_label.offset_top = 56
	mini_label.offset_left = -400
	mini_label.offset_right = 400
	mini_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mini_label.add_theme_font_size_override("font_size", 22)
	mini_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	mini_label.add_theme_constant_override("outline_size", 7)
	mini_label.visible = false
	root.add_child(mini_label)

	# Toasts (bottom-left, above nothing)
	toasts = VBoxContainer.new()
	toasts.offset_left = 16
	toasts.offset_right = 456
	toasts.offset_top = 150
	toasts.add_theme_constant_override("separation", 8)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)

	# Dialog (bottom centre, grows upward)
	dialog = _panel()
	dialog.anchor_left = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_top = 1.0
	dialog.anchor_bottom = 1.0
	dialog.offset_left = -450
	dialog.offset_right = 450
	dialog.offset_top = -30
	dialog.offset_bottom = -30
	dialog.custom_minimum_size = Vector2(900, 0)
	dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialog.visible = false
	dialog_box = VBoxContainer.new()
	dialog_box.add_theme_constant_override("separation", 10)
	dialog.add_child(dialog_box)
	root.add_child(dialog)

	# Flash
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.2, 0.15, 0)
	root.add_child(flash_rect)

	# Cinematic layer: letterbox bars and captions
	cine = Control.new()
	cine.set_anchors_preset(Control.PRESET_FULL_RECT)
	cine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine.visible = false
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.offset_bottom = 96
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -96
		cine.add_child(bar)
	cine_title = Label.new()
	cine_title.anchor_right = 1.0
	cine_title.anchor_top = 1.0
	cine_title.anchor_bottom = 1.0
	cine_title.offset_top = -270
	cine_title.offset_bottom = -200
	cine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_title.add_theme_font_size_override("font_size", 54)
	cine_title.add_theme_color_override("font_color", Color("f2f6ff"))
	cine_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	cine_title.add_theme_constant_override("outline_size", 10)
	cine.add_child(cine_title)
	cine_sub = Label.new()
	cine_sub.anchor_right = 1.0
	cine_sub.anchor_top = 1.0
	cine_sub.anchor_bottom = 1.0
	cine_sub.offset_left = 160
	cine_sub.offset_right = -160
	cine_sub.offset_top = -196
	cine_sub.offset_bottom = -104
	cine_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cine_sub.add_theme_font_size_override("font_size", 26)
	cine_sub.add_theme_color_override("font_color", Color("c9d8ff"))
	cine_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	cine_sub.add_theme_constant_override("outline_size", 8)
	cine.add_child(cine_sub)
	var hint := Label.new()
	_cine_hint = hint
	hint.text = "Enter / click / any controller button: skip"
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -520
	hint.offset_right = -24
	hint.offset_top = -62
	hint.offset_bottom = -30
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("8793b0"))
	cine.add_child(hint)
	root.add_child(cine)

	# Overlay (title / crew / report)
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.08, 0.84)
	overlay.visible = false
	overlay_center = CenterContainer.new()
	overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(overlay_center)
	Input.joy_connection_changed.connect(_on_joy)
	root.add_child(overlay)

	# Sound toggle (bottom-right)
	sound_btn = Button.new()
	sound_btn.text = "Sound: off"
	sound_btn.focus_mode = Control.FOCUS_NONE
	sound_btn.anchor_left = 1.0
	sound_btn.anchor_right = 1.0
	sound_btn.anchor_top = 1.0
	sound_btn.anchor_bottom = 1.0
	sound_btn.offset_left = -150
	sound_btn.offset_right = -16
	sound_btn.offset_top = -56
	sound_btn.offset_bottom = -16
	sound_btn.pressed.connect(func(): sound_toggled.emit())
	root.add_child(sound_btn)


func _process(delta: float) -> void:
	if _power_running:
		_power_left -= delta * speed
		if _power_bar:
			_power_bar.value = maxf(0.0, _power_left / _power_total * 100.0)
		if _power_left <= 0.0:
			_power_running = false
			_result.emit("__timeout")


func _nav_buttons() -> Array:
	var out: Array = []
	if overlay.visible:
		_collect_buttons(overlay_center, out)
	else:
		for b in _buttons:
			if is_instance_valid(b):
				out.append(b)
	return out.filter(func(b): return (b as Button).is_visible_in_tree() and not (b as Button).disabled)


func _collect_buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_collect_buttons(c, out)


func _click(b: Button) -> void:
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	b.emit_signal("pressed")


func _on_joy(device: int, connected: bool) -> void:
	if connected:
		toast("Controller connected: %s" % Input.get_joy_name(device), "good")
	else:
		toast("Controller disconnected.", "bad")


var _joy_repeat := 0.0


func _input(event: InputEvent) -> void:
	if cine != null and cine.visible and not cine_passive:
		var hit := false
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			hit = true
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			hit = true
		elif event is InputEventJoypadButton and event.pressed:
			hit = true
		if hit:
			cine_skip = true
			get_viewport().set_input_as_handled()
		return
	# Controller: D-pad / left stick pick the button, A presses it, Start presses the main button.
	var dir := Vector2.ZERO
	var press := false
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var bi: int = (event as InputEventJoypadButton).button_index
		if bi == JOY_BUTTON_DPAD_UP:
			dir = Vector2(0, -1)
		elif bi == JOY_BUTTON_DPAD_DOWN:
			dir = Vector2(0, 1)
		elif bi == JOY_BUTTON_DPAD_LEFT:
			dir = Vector2(-1, 0)
		elif bi == JOY_BUTTON_DPAD_RIGHT:
			dir = Vector2(1, 0)
		elif bi >= 0 and bi <= 3:
			press = true   # any face button (pads without a standard mapping number them differently)
		else:
			# Start, Select, shoulders and other buttons: press the main button
			if _main_button != null and is_instance_valid(_main_button) and not _main_button.disabled and _main_button.is_visible_in_tree():
				_main_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()
			return
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) < 0.7:
			return
		if m.axis == JOY_AXIS_LEFT_X:
			dir = Vector2(signf(m.axis_value), 0)
		elif m.axis == JOY_AXIS_LEFT_Y:
			dir = Vector2(0, signf(m.axis_value))
		else:
			return
	else:
		return
	var btns := _nav_buttons()
	if btns.is_empty():
		return
	var cur: Button = null
	var fo := get_viewport().gui_get_focus_owner()
	if fo is Button and btns.has(fo):
		cur = fo
	if press:
		if cur != null:
			_click(cur)
		elif _main_button != null and btns.has(_main_button):
			_click(_main_button)
		else:
			(btns[0] as Button).grab_focus()
		get_viewport().set_input_as_handled()
		return
	if cur == null:
		# start on the main button when it is the only choice, otherwise the first option
		(btns[0] as Button).grab_focus()
		get_viewport().set_input_as_handled()
		return
	var c0 := cur.get_global_rect().get_center()
	var best: Button = null
	var best_score := INF
	for b in btns:
		if b == cur:
			continue
		var d: Vector2 = (b as Button).get_global_rect().get_center() - c0
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var side := absf(d.dot(Vector2(dir.y, dir.x)))
		var score := along + side * 2.5
		if score < best_score:
			best_score = score
			best = b
	if best != null:
		best.grab_focus()
	get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_9:
		var idx := k - KEY_1
		if idx < _buttons.size() and not (_buttons[idx] as Button).disabled:
			var tb := _buttons[idx] as Button
			_click(tb)
			get_viewport().set_input_as_handled()
	elif (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE) and _main_button != null and not _main_button.disabled and _main_button.is_visible_in_tree():
		_main_button.emit_signal("pressed")
		get_viewport().set_input_as_handled()


func _style(bg: Color, border: Color = Color(0.25, 0.4, 0.75, 0.9), radius: int = 10, margin: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin - 2
	sb.content_margin_bottom = margin - 2
	return sb


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PANEL_BG))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _btn(text: String, main: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(0, 52)
	var bg := Color("2a5bd7") if main else Color(0.12, 0.17, 0.32, 1.0)
	b.add_theme_stylebox_override("normal", _style(bg, Color(0.4, 0.6, 1.0, 0.9), 8, 12))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.18), Color(0.7, 0.85, 1.0), 8, 12))
	b.add_theme_stylebox_override("pressed", _style(bg.lightened(0.3), Color.WHITE, 8, 12))
	b.add_theme_stylebox_override("hover_pressed", _style(bg.lightened(0.36), Color.WHITE, 8, 12))
	b.add_theme_stylebox_override("disabled", _style(Color(0.08, 0.1, 0.16, 0.8), Color(0.2, 0.25, 0.35), 8, 12))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color.WHITE, 8, 12))
	return b


func _tone_color(v: float) -> Color:
	return COL_OK if v >= 70.0 else (COL_WARN if v >= 40.0 else COL_BAD)


func _bar(value: float, color: Color, height: int = 14) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = clampf(value, 0, 100)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	return pb


func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _label(text: String, size: int = 20, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rich(bb: String, size: int = 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.text = bb
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---------------- HUD ----------------

func update_hud(s) -> void:
	_clear(hud_box)
	for row in [["Power", s.power, 100.0]]:
		var h := HBoxContainer.new()
		var name_l := _label(row[0], 20)
		name_l.custom_minimum_size = Vector2(84, 0)
		h.add_child(name_l)
		var pct := clampf(float(row[1]) / row[2] * 100.0, 0.0, 100.0)
		h.add_child(_bar(pct, _tone_color(pct), 16))
		var v := _label(str(roundi(row[1])), 20)
		v.custom_minimum_size = Vector2(46, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(v)
		hud_box.add_child(h)
	var d := HBoxContainer.new()
	d.add_child(_label("Day  %d / %d" % [s.days, Data.MAX_DAYS], 20))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_child(sp)
	d.add_child(_label("Science  %d" % s.science, 20))
	hud_box.add_child(d)


func update_subs(s) -> void:
	_clear(subs_box)
	subs_box.add_child(_label("Ship systems", 20, Color("9db8ff")))
	for x in Data.SUBS:
		var shield: bool = x.id == "shield"
		var v: float = s.known_shield if shield else s.h[x.id]
		var row := HBoxContainer.new()
		var nm := _label(x.name + (" (last known)" if shield else ""), 18)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(_label("%d%%" % roundi(v), 18, _tone_color(v)))
		subs_box.add_child(row)
		subs_box.add_child(_bar(v, _tone_color(v), 10))
		if shield:
			var note := "never inspected" if s.shield_checked_day < 0 else "inspected day %d" % s.shield_checked_day
			var nl := _label(note + " · cannot be seen from inside", 16, Color("9aa6c4"))
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(290, 0)
			subs_box.add_child(nl)


func cue(text: String) -> void:
	cue_label.text = "♪ " + text
	if _cue_tween:
		_cue_tween.kill()
	_cue_tween = create_tween()
	_cue_tween.tween_property(cue_label, "modulate:a", 1.0, 0.3)
	_cue_tween.tween_interval(4.6 / speed)
	_cue_tween.tween_property(cue_label, "modulate:a", 0.0, 0.5)


func toast(text: String, kind: String = "") -> void:
	var col := Color(0.05, 0.1, 0.07, 0.92)
	var border := COL_OK
	if kind == "bad":
		col = Color(0.14, 0.05, 0.05, 0.92)
		border = COL_BAD
	elif kind == "":
		col = PANEL_BG
		border = Color(0.4, 0.55, 0.9)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(col, border, 8, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(410, 0)
	p.add_child(l)
	toasts.add_child(p)
	var tw := create_tween()
	tw.tween_interval(5.2 / speed)
	tw.tween_property(p, "modulate:a", 0.0, 0.6 / speed)
	tw.tween_callback(p.queue_free)


func flash(color: Color = Color(1, 0.24, 0.16, 0.35)) -> void:
	if _flash_tween:
		_flash_tween.kill()
	flash_rect.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.7)


func mini_text(text: String) -> void:
	if text == "":
		mini_label.visible = false
		return
	if mini_label.text != text:
		mini_label.text = text
	mini_label.visible = true


# ---------------- dialogs ----------------

func _show_dialog() -> void:
	_buttons.clear()
	_main_button = null
	_clear(dialog_box)
	dialog.visible = true
	dialog.reset_size()


func _hide_dialog() -> void:
	_power_running = false
	dialog.visible = false
	_buttons.clear()
	_main_button = null
	_clear(dialog_box)


func say(title: String, text: String, btn: String = "Continue") -> void:
	if auto.is_valid():
		auto.call("say", {"title": title, "text": text})
		return
	_show_dialog()
	dialog_box.add_child(_label(title, 28, Color("cfe0ff")))
	dialog_box.add_child(_rich(text, 20))
	var b := _btn(btn + "   [Enter]", true)
	b.pressed.connect(func(): _result.emit("ok"))
	dialog_box.add_child(b)
	_main_button = b
	await _result
	_hide_dialog()


func choose(id: String, title: String, text: String, options: Array) -> String:
	if auto.is_valid():
		return auto.call("choose", {"id": id, "title": title, "options": options})
	_show_dialog()
	dialog_box.add_child(_label(title, 28, Color("cfe0ff")))
	dialog_box.add_child(_rich(text, 19))
	var i := 0
	for o in options:
		i += 1
		var b := _btn("")
		var has_sub: bool = o.get("sub", "") != ""
		b.custom_minimum_size = Vector2(0, 74 if has_sub else 54)
		b.disabled = o.get("disabled", false)
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_right", 12)
		m.add_theme_constant_override("margin_top", 6)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := ""
		if o.has("dot"):
			dot = "[color=%s]●[/color] " % o.dot
		var bb := "%s[b]%d.  %s[/b]" % [dot, i, o.label]
		if has_sub:
			bb += "\n[color=#a9b9dd]%s[/color]" % o.sub
		var r := _rich(bb, 20)
		r.size_flags_vertical = Control.SIZE_EXPAND_FILL
		m.add_child(r)
		b.add_child(m)
		if b.disabled:
			b.modulate = Color(1, 1, 1, 0.45)
		var oid: String = o.id
		b.pressed.connect(func(): _result.emit(oid))
		dialog_box.add_child(b)
		_buttons.append(b)
	var pick = await _result
	_hide_dialog()
	return pick


## Power-drop panel: returns {chosen: Array, timed_out: bool}
func power_panel(units: int, systems: Array, seconds: float, intro: String) -> Dictionary:
	if auto.is_valid():
		return {"chosen": auto.call("power", {"units": units, "systems": systems}), "timed_out": false}
	_show_dialog()
	dialog.add_theme_stylebox_override("panel", _style(Color(0.16, 0.04, 0.04, 0.94), COL_BAD))
	dialog_box.add_child(_label("Sudden power drop!", 30, Color("ff9a8a")))
	dialog_box.add_child(_rich(intro, 19))
	var sel := {}
	var tally := _rich("", 22)
	dialog_box.add_child(tally)
	_power_total = seconds
	_power_left = seconds
	_power_bar = _bar(100, COL_BAD, 16)
	dialog_box.add_child(_power_bar)
	var upd := func():
		var used := 0
		for x in systems:
			if sel.has(x.id):
				used += x.cost
		var c := "#f06a5a" if used > units else "#5fd68a"
		tally.text = "Using [b][color=%s]%d[/color][/b] of [b]%d[/b] power units" % [c, used, units]
	var i := 0
	for x in systems:
		i += 1
		var b := _btn("%d.  %s   (%d units)" % [i, x.name, x.cost])
		b.toggle_mode = true
		var xid: String = x.id
		b.toggled.connect(func(on: bool):
			if on:
				sel[xid] = true
			else:
				sel.erase(xid)
			upd.call())
		dialog_box.add_child(b)
		_buttons.append(b)
	var go := _btn("Confirm   [Enter]", true)
	go.pressed.connect(func(): _result.emit("__confirm"))
	dialog_box.add_child(go)
	_main_button = go
	upd.call()
	_power_running = true
	var r = await _result
	_power_running = false
	_power_bar = null
	dialog.add_theme_stylebox_override("panel", _style(PANEL_BG))
	var chosen: Array = sel.keys()
	_hide_dialog()
	return {"chosen": chosen, "timed_out": r == "__timeout"}


# ---------------- full-screen overlay ----------------

func _overlay_card(width: float) -> VBoxContainer:
	_clear(overlay_center)
	overlay.visible = true
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.05, 0.08, 0.17, 0.97), Color(0.35, 0.55, 0.95), 14, 28))
	card.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	overlay_center.add_child(card)
	return box


func _close_overlay() -> void:
	_buttons.clear()
	_main_button = null
	overlay.visible = false
	_clear(overlay_center)


func title_screen(heading: String, bb: String, btn: String) -> void:
	if auto.is_valid():
		return
	while true:
		var box := _overlay_card(920)
		box.add_child(_label(heading, 40, Color("e6efff")))
		box.add_child(_rich(bb, 21))
		var b := _btn(btn + "   [Enter]", true)
		b.pressed.connect(func(): _result.emit("ok"))
		box.add_child(b)
		if history_provider.is_valid():
			var hb := _btn("High scores and history")
			hb.pressed.connect(func(): _result.emit("history"))
			box.add_child(hb)
		_main_button = b
		var r = await _result
		if r == "history":
			await history_screen(history_provider.call())
			continue
		break
	_close_overlay()


func history_screen(bb: String) -> void:
	var box := _overlay_card(960)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_rich(bb, 20))
	scroll.add_child(inner)
	box.add_child(scroll)
	var b := _btn("Back   [Enter]", true)
	b.pressed.connect(func(): _result.emit("ok"))
	box.add_child(b)
	_main_button = b
	await _result


const TIPS := [
	"Parker Solar Probe has no temperature sensor on the front of its heat shield. Engineers rely on models and careful checks.",
	"Signals from the outer planets take hours to reach Earth, so a spacecraft must make many decisions alone.",
	"A solar flare can arrive minutes after it leaves the Sun's surface. Early warning gives you time to protect the ship.",
	"Ceres has only about 3% of Earth's gravity. Astronauts there would hop, and a lander must anchor itself to the ground.",
	"Damage you take early does not go away. It carries into every later decision.",
	"Asteroid fields in the real Solar System are very sparse. Spacecraft almost never meet a rock by chance.",
	"Jupiter's magnetic field traps radiation that can damage electronics on a passing spacecraft.",
]
var history_provider: Callable
var loading_layer: CanvasLayer
var _load_fill: ColorRect
var _load_t0 := 0


func loading_show(title: String, sub: String = "") -> void:
	if loading_layer != null:
		loading_layer.queue_free()
	_load_t0 = Time.get_ticks_msec()
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 100
	add_child(loading_layer)
	var bg := ColorRect.new()
	bg.color = Color("02030a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_layer.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 140:
		var st := ColorRect.new()
		var k := rng.randf_range(0.3, 1.0)
		st.color = Color(k, k, k, 1)
		st.size = Vector2(2, 2) if rng.randf() < 0.85 else Vector2(3, 3)
		st.anchor_left = rng.randf()
		st.anchor_right = st.anchor_left
		st.anchor_top = rng.randf()
		st.anchor_bottom = st.anchor_top
		bg.add_child(st)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(c)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(760, 0)
	c.add_child(box)
	var t := _label(title, 52, Color("e6efff"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if sub != "":
		var sl := _label(sub, 24, Color("a9b9dd"))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sl)
	var bar := ColorRect.new()
	bar.color = Color(0.12, 0.17, 0.32)
	bar.custom_minimum_size = Vector2(760, 10)
	box.add_child(bar)
	_load_fill = ColorRect.new()
	_load_fill.color = Color("6cb4ff")
	_load_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fill.anchor_right = 0.02
	bar.add_child(_load_fill)
	var tw := create_tween()
	tw.tween_property(_load_fill, "anchor_right", 0.88, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var tip := _rich("[center][color=#8fa3cf]Did you know?[/color]\n%s[/center]" % TIPS[randi() % TIPS.size()], 20)
	tip.custom_minimum_size = Vector2(760, 90)
	box.add_child(tip)


## Finishes the bar and fades out. Stays up for at least min_ms so it can be read.
func loading_hide(min_ms: int = 1500) -> void:
	if loading_layer == null:
		return
	var left := min_ms - (Time.get_ticks_msec() - _load_t0)
	if left > 0:
		await get_tree().create_timer(left / 1000.0).timeout
	if _load_fill != null:
		_load_fill.anchor_right = 1.0
	await get_tree().create_timer(0.15).timeout
	var layer := loading_layer
	loading_layer = null
	var bg: Node = layer.get_child(0)
	var tw := create_tween()
	tw.tween_property(bg, "modulate:a", 0.0, 0.5)
	await tw.finished
	layer.queue_free()


func ship_builder(cfg: Dictionary, opts: Array, on_change: Callable) -> Dictionary:
	if auto.is_valid():
		return cfg
	_clear(overlay_center)
	overlay.visible = true
	var old_col := overlay.color
	overlay.color = Color(0.02, 0.03, 0.08, 0.0)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(1600, 880)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_center.add_child(holder)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.05, 0.08, 0.17, 0.95), Color(0.35, 0.55, 0.95), 14, 20))
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_bottom = -16
	card.custom_minimum_size = Vector2(1500, 0)
	holder.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(_label("Design your spacecraft", 30, Color("e6efff")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var rows := {}
	for o in opts:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		cell.add_child(_label(o.label, 17, Color("a9b9dd")))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		cell.add_child(hb)
		var key: String = o.key
		rows[key] = {}
		for ch in o.choices:
			var b := _btn(ch[1])
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 18)
			if ch.size() > 2:
				var col := Color(ch[2])
				b.add_theme_color_override("font_color", col)
				b.add_theme_color_override("font_pressed_color", col)
				b.add_theme_color_override("font_hover_color", col)
				b.add_theme_color_override("font_hover_pressed_color", col)
			var val: String = ch[0]
			b.button_pressed = str(cfg.get(key, "")) == val
			b.pressed.connect(func():
				cfg[key] = val
				for k2 in rows[key]:
					(rows[key][k2] as Button).set_pressed_no_signal(k2 == val)
				on_change.call(cfg))
			hb.add_child(b)
			rows[key][val] = b
		grid.add_child(cell)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	box.add_child(bottom)
	var rnd := _btn("Surprise me")
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rnd.pressed.connect(func():
		for o in opts:
			var ch: Array = o.choices[randi() % o.choices.size()]
			cfg[o.key] = ch[0]
			for k2 in rows[o.key]:
				(rows[o.key][k2] as Button).set_pressed_no_signal(k2 == ch[0])
		on_change.call(cfg))
	bottom.add_child(rnd)
	var go := _btn("Done   [Enter]", true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func(): _result.emit("__go"))
	bottom.add_child(go)
	_main_button = go
	on_change.call(cfg)
	await _result
	overlay.color = old_col
	_close_overlay()
	return cfg


func ship_select(ships: Array, current: String, on_preview: Callable) -> String:
	if auto.is_valid():
		return current
	_clear(overlay_center)
	overlay.visible = true
	var old_col := overlay.color
	overlay.color = Color(0.02, 0.03, 0.08, 0.0)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(1600, 880)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_center.add_child(holder)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.05, 0.08, 0.17, 0.95), Color(0.35, 0.55, 0.95), 14, 22))
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_bottom = -24
	card.custom_minimum_size = Vector2(1500, 0)
	holder.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(_label("Choose your spacecraft", 34, Color("e6efff")))
	box.add_child(_rich("All designs fly the same way. This only changes how your ship looks. Use 1-3 or click, then Enter.", 19))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var sel := [current]
	var btns := {}
	var i := 0
	for sh in ships:
		i += 1
		var b := _btn("")
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(280, 120)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left", 14)
		m.add_theme_constant_override("margin_top", 8)
		m.add_theme_constant_override("margin_right", 14)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(_rich("[b]%d.  %s[/b]\n[color=#a9b9dd]%s[/color]" % [i, sh.name, sh.desc], 17))
		b.add_child(m)
		var sid: String = sh.id
		b.button_pressed = sid == current
		b.pressed.connect(func():
			sel[0] = sid
			for k in btns:
				(btns[k] as Button).set_pressed_no_signal(k == sid)
			on_preview.call(sid))
		row.add_child(b)
		btns[sid] = b
		_buttons.append(b)
	var go := _btn("Continue   [Enter]", true)
	go.pressed.connect(func(): _result.emit("__go"))
	box.add_child(go)
	_main_button = go
	on_preview.call(current)
	await _result
	overlay.color = old_col
	_close_overlay()
	return sel[0]


func crew_select(crew: Array) -> Array:
	if auto.is_valid():
		return auto.call("crew", {})
	var box := _overlay_card(920)
	box.add_child(_label("Choose your crew", 40, Color("e6efff")))
	box.add_child(_rich("Pick 3 of 4 specialists. Each one changes how later events play out.", 21))
	var sel := {}
	var go := _btn("Launch (pick 3)", true)
	go.disabled = true
	var btns: Array = []
	var refresh := func():
		go.disabled = sel.size() != 3
		go.text = "Launch   [Enter]" if sel.size() == 3 else "Launch (pick %d more)" % (3 - sel.size())
	var i := 0
	for c in crew:
		i += 1
		var b := _btn("")
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 78)
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_top", 6)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(_rich("[b]%d.  %s[/b]\n[color=#a9b9dd]%s[/color]" % [i, c.name, c.desc], 21))
		b.add_child(m)
		var cid: String = c.id
		b.toggled.connect(func(on: bool):
			if on and sel.size() >= 3:
				b.set_pressed_no_signal(false)
				return
			if on:
				sel[cid] = true
			else:
				sel.erase(cid)
			refresh.call())
		box.add_child(b)
		btns.append(b)
		_buttons.append(b)
	var demo := _btn("Quick start: Pilot + Engineer + Medic")
	demo.pressed.connect(func(): _result.emit("__demo"))
	box.add_child(demo)
	go.pressed.connect(func(): _result.emit("__go"))
	box.add_child(go)
	_main_button = go
	var r = await _result
	var picked: Array = sel.keys()
	if r == "__demo":
		picked = ["pilot", "engineer", "medic"]
	_close_overlay()
	return picked


func report(bb: String, btn: String, on_press: Callable) -> void:
	var box := _overlay_card(980)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_rich(bb, 20))
	scroll.add_child(inner)
	box.add_child(scroll)
	var b := _btn(btn + "   [Enter]", true)
	b.pressed.connect(on_press)
	box.add_child(b)
	_main_button = b


func hide_all() -> void:
	_hide_dialog()
	mini_text("")


# ---------------- campaign screens ----------------

## A tall, scrollable menu on the overlay (level select, spacecraft design, Mission Lab, reports).
## options: [{id, label, sub?, disabled?, header?, on?, main?}]. Returns the picked id.
func big_choose(id: String, title: String, bb: String, options: Array, width: float = 1180.0) -> String:
	if auto.is_valid():
		var real: Array = options.filter(func(o): return not o.get("header", false))
		return auto.call("choose", {"id": id, "title": title, "options": real})
	var box := _overlay_card(width)
	box.add_theme_constant_override("separation", 10)
	box.add_child(_label(title, 32, Color("e6efff")))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	scroll.add_child(inner)
	var est := 0.0
	if bb != "":
		var r := _rich(bb, 19)
		inner.add_child(r)
		est += 30.0 + (float(bb.length()) / (width / 10.5) + float(bb.count("\n"))) * 27.0
	var bottom: Array = []
	var n := 0
	for o in options:
		if o.get("header", false):
			inner.add_child(_label(o.label, 18, Color("9db8ff")))
			est += 32.0
			continue
		var is_main: bool = o.get("main", false)
		var b := _btn("", is_main)
		var has_sub: bool = o.get("sub", "") != ""
		b.custom_minimum_size = Vector2(0, 64 if has_sub else 44)
		b.disabled = o.get("disabled", false)
		if o.get("on", false):
			b.add_theme_stylebox_override("normal", _style(Color(0.1, 0.3, 0.22, 1.0), COL_OK, 8, 12))
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left", 14)
		m.add_theme_constant_override("margin_right", 10)
		m.add_theme_constant_override("margin_top", 5)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var txt := "[b]%s[/b]" % o.label
		if has_sub:
			txt += "\n[color=#a9b9dd]%s[/color]" % o.sub
		var rl := _rich(txt, 18)
		rl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rl.clip_contents = true
		m.add_child(rl)
		b.add_child(m)
		if b.disabled:
			b.modulate = Color(1, 1, 1, 0.45)
		var oid: String = o.id
		b.pressed.connect(func(): _result.emit(oid))
		if is_main:
			bottom.append(b)
			_main_button = b
		else:
			inner.add_child(b)
			est += 70.0 if has_sub else 50.0
			n += 1
			if n <= 9:
				_buttons.append(b)
	var max_h: float = get_viewport().get_visible_rect().size.y - 230.0 - 60.0 * bottom.size()
	scroll.custom_minimum_size = Vector2(0, clampf(est, 60.0, maxf(200.0, max_h)))
	box.add_child(scroll)
	for b2 in bottom:
		box.add_child(b2)
	var pick = await _result
	_close_overlay()
	return pick


## HUD and systems panel for a campaign mission. rows: [[label, value 0..1, text]]; comps: [[name, value, class, tone]].
func update_campaign(rows: Array, lines: Array, comps: Array) -> void:
	_clear(hud_box)
	for row in rows:
		var h := HBoxContainer.new()
		var name_l := _label(row[0], 19)
		name_l.custom_minimum_size = Vector2(84, 0)
		h.add_child(name_l)
		var pct := clampf(float(row[1]) * 100.0, 0.0, 100.0)
		h.add_child(_bar(pct, _tone_color(pct if row.size() < 4 else 100.0), 14))
		var v := _label(str(row[2]), 19)
		v.custom_minimum_size = Vector2(62, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(v)
		hud_box.add_child(h)
	for l in lines:
		var ll := _label(l, 17, Color("c3cfe8"))
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size = Vector2(300, 0)
		hud_box.add_child(ll)
	_clear(subs_box)
	subs_box.add_child(_label("Spacecraft condition", 20, Color("9db8ff")))
	for c in comps:
		var row2 := HBoxContainer.new()
		var nm := _label(c[0], 17)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(nm)
		var col: Color = COL_OK if c[3] == "ok" else (COL_WARN if c[3] == "warn" else COL_BAD)
		row2.add_child(_label("%d%% %s" % [roundi(c[1]), c[2]], 17, col))
		subs_box.add_child(row2)
		subs_box.add_child(_bar(c[1], col, 8))


# ---------------- cinematic introductions ----------------

## Letterbox bars on, HUD panels off. cine_skip turns true when the player asks to skip.
func cinema_begin() -> void:
	cine_skip = false
	hide_all()
	cine_title.text = ""
	cine_sub.text = ""
	cine_title.modulate.a = 0.0
	cine_sub.modulate.a = 0.0
	_cine_hint.visible = not cine_passive
	cine.visible = true
	_hud_panel.visible = false
	_subs_panel.visible = false
	toasts.visible = false
	sound_btn.visible = false
	labels_host.visible = false


func cinema_caption(title: String, sub: String = "") -> void:
	if _cine_tween:
		_cine_tween.kill()
	cine_title.text = title
	cine_sub.text = sub
	cine_title.modulate.a = 0.0
	cine_sub.modulate.a = 0.0
	_cine_tween = create_tween()
	_cine_tween.tween_property(cine_title, "modulate:a", 1.0, 0.7)
	_cine_tween.parallel().tween_property(cine_sub, "modulate:a", 1.0, 1.1)


func cinema_end() -> void:
	if _cine_tween:
		_cine_tween.kill()
	cine.visible = false
	cine_skip = false
	_hud_panel.visible = true
	_subs_panel.visible = true
	toasts.visible = true
	sound_btn.visible = true
	labels_host.visible = true
