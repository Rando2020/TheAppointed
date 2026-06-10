## TimingWindow.gd
## UI overlay for SURGE/DEFLECT timed inputs. Visual port of the archived
## SurgeWindow.jsx, driven entirely by TimingResolver — this node never
## computes gameplay results itself.
##
## Usage (from BattleScene/BattleManager):
##   var w := TimingWindow.new()
##   add_child(w)
##   w.start("surge", ability_element, run_bonuses)
##   var result: Dictionary = await w.finished
##
## Input action: uses ui_accept (Space/Enter/gamepad A) — controller-ready
## for the Steam-first target.

class_name TimingWindow
extends Control

signal finished(result: Dictionary)

const ELEMENT_COLORS: Dictionary = {
	"fire": Color("f97316"), "ice": Color("67e8f9"), "thunder": Color("fde047"),
	"water": Color("38bdf8"), "holy": Color("fef08a"), "dark": Color("a855f7"),
	"earth": Color("a3a3a3"), "none": Color("c9a756"),
}
const COL_SUCCESS := Color("4ade80")
const COL_PERFECT := Color("fde047")
const COL_MISS := Color("f87171")
const TRACK_SIZE := Vector2(300, 12)

var _kind: String = "surge"
var _bonuses: Dictionary = {}
var _accent: Color = ELEMENT_COLORS["none"]
var _elapsed_ms: float = 0.0
var _running: bool = false
var _result: Dictionary = {}

var _label: Label
var _hint: Label
var _track: ColorRect
var _zone_rect: ColorRect
var _perfect_rect: ColorRect
var _fill: ColorRect
var _cursor: ColorRect


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	_build_ui()
	visible = false


func start(kind: String, ability_element: String = "none", bonuses: Dictionary = {}) -> void:
	_kind = kind
	_bonuses = bonuses
	_accent = ELEMENT_COLORS.get(ability_element, ELEMENT_COLORS["none"])
	_elapsed_ms = 0.0
	_result = {}
	_running = true
	_layout_zones()
	_label.text = "SURGE Window" if _kind == "surge" else "DEFLECT!"
	_label.add_theme_color_override("font_color", Color.WHITE)
	_hint.text = "Press at the right moment — perfect center for the strongest result"
	visible = true
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed_ms += delta * 1000.0
	var pct: float = minf(_elapsed_ms / TimingResolver.WINDOW_DURATION_MS, 1.0)
	_fill.size.x = TRACK_SIZE.x * pct
	_cursor.position.x = TRACK_SIZE.x * pct - _cursor.size.x * 0.5
	var in_zone := TimingResolver.classify(pct, _window_bonus()) != "miss"
	_fill.color = COL_SUCCESS if in_zone else _accent
	if pct >= 1.0:
		_finish(TimingResolver.resolve_expired(_kind))


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var pct: float = _elapsed_ms / TimingResolver.WINDOW_DURATION_MS
		var result := TimingResolver.resolve_surge(pct, _bonuses) if _kind == "surge" \
				else TimingResolver.resolve_deflect(pct, _bonuses)
		_finish(result)


func _finish(result: Dictionary) -> void:
	_running = false
	set_process(false)
	set_process_unhandled_input(false)
	_result = result
	match result["tier"]:
		"perfect":
			_label.text = "✦ PERFECT!"
			_label.add_theme_color_override("font_color", COL_PERFECT)
			_fill.color = COL_PERFECT
		"good":
			_label.text = "⚡ SURGE!" if _kind == "surge" else "🛡 DEFLECTED!"
			_label.add_theme_color_override("font_color", COL_SUCCESS)
			_fill.color = COL_SUCCESS
		_:
			_label.text = "✕ Missed"
			_label.add_theme_color_override("font_color", COL_MISS)
			_fill.color = COL_MISS
	_hint.text = _result_hint(result)
	# Brief hold so the player reads the outcome, then emit and hide.
	await get_tree().create_timer(0.45).timeout
	visible = false
	finished.emit(result)


func _result_hint(result: Dictionary) -> String:
	if _kind == "surge":
		match result["tier"]:
			"perfect": return "Massive bonus — break and buildup surge!"
			"good": return "+%d%% damage" % int(round((result["damage_mult"] - 1.0) * 100.0))
			_: return "Normal damage"
	match result["tier"]:
		"perfect": return "No break damage taken!"
		"good": return "Damage reduced"
		_: return "Full hit taken"


func _window_bonus() -> float:
	var key := "surge_window_bonus" if _kind == "surge" else "deflect_window_bonus"
	return _bonuses.get(key, 0.0)


func _layout_zones() -> void:
	var zone := TimingResolver.good_zone(_window_bonus())
	_zone_rect.position.x = TRACK_SIZE.x * zone[0]
	_zone_rect.size.x = TRACK_SIZE.x * (zone[1] - zone[0])
	_perfect_rect.position.x = TRACK_SIZE.x * TimingResolver.PERFECT_START
	_perfect_rect.size.x = TRACK_SIZE.x * (TimingResolver.PERFECT_END - TimingResolver.PERFECT_START)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	position.y -= 120.0
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.027, 0.078, 0.95)
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(TRACK_SIZE.x, 0)
	panel.add_child(vbox)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_label)

	var track_holder := Control.new()
	track_holder.custom_minimum_size = TRACK_SIZE
	vbox.add_child(track_holder)

	_track = ColorRect.new()
	_track.color = Color(1, 1, 1, 0.12)
	_track.size = TRACK_SIZE
	track_holder.add_child(_track)

	_zone_rect = ColorRect.new()
	_zone_rect.color = Color(COL_SUCCESS, 0.25)
	_zone_rect.size = Vector2(0, TRACK_SIZE.y)
	track_holder.add_child(_zone_rect)

	_perfect_rect = ColorRect.new()
	_perfect_rect.color = Color(COL_PERFECT, 0.35)
	_perfect_rect.size = Vector2(0, TRACK_SIZE.y)
	track_holder.add_child(_perfect_rect)

	_fill = ColorRect.new()
	_fill.size = Vector2(0, TRACK_SIZE.y)
	track_holder.add_child(_fill)

	_cursor = ColorRect.new()
	_cursor.color = Color.WHITE
	_cursor.size = Vector2(3, TRACK_SIZE.y + 8)
	_cursor.position.y = -4
	track_holder.add_child(_cursor)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(0.97, 0.96, 1.0, 0.55))
	_hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_hint)
