## StageSelect.gd
## 10-floor run map. Start Run -> choose routes -> fight through procedurally generated floors.

class_name StageSelect
extends Control

const BG   := Color(0.04, 0.05, 0.08)
const FG   := Color(0.97, 0.94, 0.87)
const DIM  := Color(0.45, 0.42, 0.38)
const GOLD := Color(0.79, 0.65, 0.34)

# Design-system fonts
const _FONT_DISPLAY := preload("res://assets/fonts/TrajanPro-Regular.ttf")
const _FONT_HEADER  := preload("res://assets/fonts/Cinzel-Bold.ttf")
const _FONT_BODY    := preload("res://assets/fonts/IMFellEnglish-Regular.ttf")
const _FONT_UI      := preload("res://assets/fonts/CormorantGaramond-Regular.ttf")

const NODE_META: Dictionary = {
	"battle":      {"icon":"B", "color":Color(0.48,0.86,1.0),  "label":"Battle"},
	"elite":       {"icon":"E", "color":Color(1.0,0.50,0.18),  "label":"Elite"},
	"mystery":     {"icon":"?", "color":Color(0.72,0.58,1.0),  "label":"?"},
	"mystery_cache": {"icon":"$", "color":Color(0.96,0.78,0.28),  "label":"Cache"},
	"mystery_training": {"icon":"JP", "color":Color(0.48,0.86,1.0),  "label":"Training"},
	"mystery_shrine": {"icon":"+", "color":Color(0.79,0.65,0.34),  "label":"Shrine"},
	"mystery_ambush": {"icon":"!", "color":Color(0.93,0.27,0.27),  "label":"Ambush"},
	"boss":        {"icon":"!", "color":Color(0.93,0.27,0.27), "label":"Boss"},
	"boon_pick":   {"icon":"+", "color":Color(0.79,0.65,0.34), "label":"Boon"},
	"wanderer":    {"icon":"?", "color":Color(0.53,0.94,0.67), "label":"Wanderer"},
}

var _gs:  Node
var _bs:  BoonSystem

var _boon_overlay:  Control = null
var _loot_overlay:  Control = null
var _selected_vow_id: String = VowSigilSystem.DEFAULT_VOW_ID
var _selected_sigil_id: String = VowSigilSystem.DEFAULT_SIGIL_ID


func _ready() -> void:
	_gs = get_node_or_null("/root/GameState")
	_bs = BoonSystem.new()

	if _gs and _gs.pending_boon_offers.size() > 0:
		_build_ui(); _show_boon_pick(_gs.pending_boon_offers); return
	if _gs and _gs.pending_loot.size() > 0:
		_build_ui(); _show_loot(_gs.pending_loot); return
	_build_ui()


func _clean_ui_text(value: Variant, fallback: String = "") -> String:
	var text: String = str(value)
	for i in text.length():
		if text.unicode_at(i) > 127:
			return fallback
	return text

func _build_ui() -> void:
	for c in get_children(): c.queue_free()

	_bg(self)

	if not _gs or not _gs.active_run or _gs.active_run.completed:
		_build_start_screen()
	else:
		_build_run_screen(_gs.active_run)


#  Start screen

func _build_start_screen() -> void:
	var vbox := _vbox(self, true)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(460, 0)

	_lbl(vbox, "VAELTHAR / EIDOLON CHRONICLES", 12, DIM, true)
	_space(vbox, 8)
	_lbl(vbox, "The Roguelike Run", 34, FG, true)
	_space(vbox, 6)
	_lbl(vbox, "10 floors. Randomised maps. Five Guardians.", 14, DIM, true)
	_space(vbox, 28)

	# Heat level selector
	var meta: Node = get_node_or_null("/root/MetaProgression")
	var heat := 0
	if meta: heat = meta.selected_heat_level
	var max_heat := 0
	if meta: max_heat = meta.max_heat_unlocked

	if max_heat > 0:
		var heat_row := HBoxContainer.new()
		heat_row.alignment = BoxContainer.ALIGNMENT_CENTER
		heat_row.add_theme_constant_override("separation", 10)
		vbox.add_child(heat_row)
		_lbl(heat_row, "Heat Level:", 13, DIM)
		var heat_lbl := _lbl(heat_row, str(heat), 16, Color(1.0,0.5,0.2))
		var less := _btn("-", DIM); less.custom_minimum_size = Vector2(36,36)
		less.pressed.connect(func() -> void:
			if meta: meta.selected_heat_level = maxi(0, meta.selected_heat_level - 1)
			heat_lbl.text = str(meta.selected_heat_level if meta else 0))
		var more := _btn("+", Color(1.0,0.5,0.2)); more.custom_minimum_size = Vector2(36,36)
		more.pressed.connect(func() -> void:
			if meta: meta.selected_heat_level = mini(meta.max_heat_unlocked, meta.selected_heat_level + 1)
			heat_lbl.text = str(meta.selected_heat_level if meta else 0))
		heat_row.add_child(less); heat_row.add_child(more)
		_space(vbox, 8)

	_build_loadout_picker(vbox)
	_space(vbox, 18)

	var btn := _btn(">  Start New Run", GOLD)
	btn.custom_minimum_size = Vector2(300, 52)
	btn.pressed.connect(func() -> void: _on_start_run(meta.selected_heat_level if meta else 0))
	vbox.add_child(btn)
	_space(vbox, 12)

	if _gs:
		_lbl(vbox, "Gold: %dg" % _gs.gold, 14, GOLD, true)

	# Show meta currencies
	if meta:
		_lbl(vbox, "Soul Shards: %d / Obsidian: %d" % [meta.get_currency(Currency.SOUL_SHARDS), meta.get_currency(Currency.OBSIDIAN)], 12, DIM, true)


#  Run screen

func _build_run_screen(run: RunState) -> void:
	var root := _vbox(self)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)

	# Header
	var hdr := _panel(root, Color(0.07,0.08,0.12), Vector2(0, 68))
	var hh  := _hbox(hdr)
	hh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hh.add_theme_constant_override("margin_left", 24)
	hh.add_theme_constant_override("margin_right", 16)
	_lbl(hh, "Floor %d / 10" % run.current_floor, 22, FG)
	_stretch(hh)
	_lbl(hh, "Gold: %dg" % (_gs.gold if _gs else 0), 14, GOLD)
	_lbl(hh, "  Elites: %d" % run.elite_kills, 12, DIM)
	_lbl(hh, "  Boons: %d" % run.active_boons.size(), 12, DIM)
	_gap(hh, 12)
	# "Edit Formation" shortcut — always accessible so player isn't forced
	# to enter a battle node just to adjust positions.
	var formation_btn := _btn("⚔ Formation", Color(0.48, 0.72, 1.0))
	formation_btn.custom_minimum_size.x = 120
	formation_btn.pressed.connect(_on_edit_formation_from_run.bind(run))
	hh.add_child(formation_btn)
	_gap(hh, 8)

	var ab_btn := _btn("Abandon", Color(0.93,0.27,0.27))
	ab_btn.custom_minimum_size.x = 90
	ab_btn.pressed.connect(_on_abandon)
	hh.add_child(ab_btn)
	_gap(hh, 8)

	# Active boons row
	if run.active_boons.size() > 0:
		var bar := _panel(root, Color(0.05, 0.06, 0.09), Vector2(0, 50))
		var br  := _hbox(bar)
		br.add_theme_constant_override("margin_left", 24)
		br.add_theme_constant_override("margin_right", 16)
		br.set_anchors_and_offsets_preset(Control.PRESET_VCENTER_WIDE)
		br.add_theme_constant_override("separation", 6)
		var boons_title := Label.new()
		boons_title.text = "BLESSINGS"
		boons_title.add_theme_font_override("font", _FONT_HEADER)
		boons_title.add_theme_font_size_override("font_size", 9)
		boons_title.add_theme_color_override("font_color", GOLD.darkened(0.25))
		br.add_child(boons_title)
		_gap(br, 8)
		for boon in run.active_boons:
			var rd: Dictionary = BoonSystem.RARITIES.get(boon.get("rarity","common"), {})
			var bc: Color = rd.get("color", GOLD)
			_pill(br, "%s %s" % [str(boon.get("icon","+")), str(boon.get("name","?"))], bc)
		_stretch(br)
		var count_lbl := Label.new()
		count_lbl.text = "%d / ?" % run.active_boons.size()
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.add_theme_color_override("font_color", DIM)
		br.add_child(count_lbl)

	_build_run_build_panel(root, run)
	_space(root, 18)

	# Group floor_plan by floor number, then render one column per floor.
	# Each column shows 1-3 branch cards stacked vertically.
	var map_wrapper := PanelContainer.new()
	map_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var map_bg_st := StyleBoxFlat.new()
	map_bg_st.bg_color = Color(0.03, 0.035, 0.055, 0.85)
	map_bg_st.border_color = Color(1.0, 1.0, 1.0, 0.05)
	map_bg_st.set_border_width_all(1)
	map_bg_st.content_margin_left = 0
	map_bg_st.content_margin_right = 0
	map_bg_st.content_margin_top = 8
	map_bg_st.content_margin_bottom = 8
	map_wrapper.add_theme_stylebox_override("panel", map_bg_st)
	root.add_child(map_wrapper)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 320
	map_wrapper.add_child(scroll)

	var hmap := HBoxContainer.new()
	hmap.add_theme_constant_override("margin_left",  20)
	hmap.add_theme_constant_override("margin_right", 20)
	hmap.add_theme_constant_override("separation",    8)
	scroll.add_child(hmap)

	var by_floor: Dictionary = {}
	for node in run.floor_plan:
		var f: int = int(node.get("floor", 1))
		if not by_floor.has(f):
			by_floor[f] = []
		by_floor[f].append(node)

	var available_nodes := run.get_available_nodes()

	for f in range(1, RunState.TOTAL_FLOORS + 1):
		var branches: Array = by_floor.get(f, [])
		if branches.is_empty():
			continue

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		hmap.add_child(col)

		var is_past:    bool = f < run.current_floor
		var is_current: bool = f == run.current_floor
		var is_future:  bool = f > run.current_floor

		# Floor number label
		var floor_lbl := Label.new()
		floor_lbl.text = "F%d" % f
		floor_lbl.add_theme_font_override("font", _FONT_HEADER)
		floor_lbl.add_theme_font_size_override("font_size", 9)
		floor_lbl.add_theme_color_override("font_color",
			GOLD if is_current else (Color(0.4, 0.65, 0.4) if is_past else DIM.darkened(0.2)))
		floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(floor_lbl)

		# "CHOOSE" badge above current floor
		if is_current and branches.size() > 1:
			var choose_pc := PanelContainer.new()
			var choose_st := StyleBoxFlat.new()
			choose_st.bg_color = GOLD.darkened(0.7)
			choose_st.border_color = GOLD
			choose_st.set_border_width_all(1)
			choose_st.set_corner_radius_all(4)
			choose_st.content_margin_left = 6
			choose_st.content_margin_right = 6
			choose_st.content_margin_top = 2
			choose_st.content_margin_bottom = 2
			choose_pc.add_theme_stylebox_override("panel", choose_st)
			var choose_lbl := Label.new()
			choose_lbl.text = "CHOOSE"
			choose_lbl.add_theme_font_override("font", _FONT_HEADER)
			choose_lbl.add_theme_font_size_override("font_size", 8)
			choose_lbl.add_theme_color_override("font_color", GOLD)
			choose_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			choose_pc.add_child(choose_lbl)
			col.add_child(choose_pc)

		# Branch cards
		for node in branches:
			var is_done:    bool = node.get("completed", false) == true
			var is_skipped: bool = node.get("skipped",   false) == true
			var is_live:    bool = is_current and not is_done and not is_skipped
			var ntype:      String = str(node.get("type", "battle"))
			var meta:       Dictionary = NODE_META.get(ntype, NODE_META["battle"])

			var card := _node_card(meta, is_live, is_done, is_future, is_skipped, node)

			# Modulate future floors down
			if is_future:
				card.modulate.a = 0.38
			elif is_past and not is_done:
				card.modulate.a = 0.25  # skipped branch on a past floor

			if is_live:
				card.pressed.connect(_on_enter_node.bind(node))

			col.add_child(card)

		if f < RunState.TOTAL_FLOORS:
			var connector := _build_floor_connector(is_current, is_past)
			hmap.add_child(connector)

	_space(root, 12)

	# Route hint when a choice is available
	_space(root, 6)
	if available_nodes.size() > 1:
		var hint_pc := PanelContainer.new()
		hint_pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hint_bg := StyleBoxFlat.new()
		hint_bg.bg_color = GOLD.darkened(0.82)
		hint_bg.border_color = GOLD.darkened(0.4)
		hint_bg.set_border_width_all(1)
		hint_bg.set_corner_radius_all(4)
		hint_bg.content_margin_top = 6
		hint_bg.content_margin_bottom = 6
		hint_pc.add_theme_stylebox_override("panel", hint_bg)
		root.add_child(hint_pc)
		var hint_lbl := Label.new()
		hint_lbl.text = "▲  Select your path — unchosen routes will close forever."
		hint_lbl.add_theme_font_override("font", _FONT_UI)
		hint_lbl.add_theme_font_size_override("font_size", 12)
		hint_lbl.add_theme_color_override("font_color", GOLD.lightened(0.1))
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_pc.add_child(hint_lbl)
	elif available_nodes.size() == 1:
		var single := available_nodes[0]
		var nm: Dictionary = NODE_META.get(single.get("type","battle"), NODE_META["battle"])
		var reward_text := _clean_ui_text(single.get("reward_hint", ""), "")
		var hint_lbl := Label.new()
		hint_lbl.text = "▶  %s%s" % [nm["label"], ("  —  " + reward_text if not reward_text.is_empty() else "")]
		hint_lbl.add_theme_font_override("font", _FONT_UI)
		hint_lbl.add_theme_font_size_override("font_size", 12)
		hint_lbl.add_theme_color_override("font_color", nm["color"])
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(hint_lbl)


func _build_run_build_panel(parent: Control, run: RunState) -> void:
	var panel := _panel(parent, Color(0.050, 0.058, 0.082), Vector2(0, 74))
	# Thin gold top border on panel
	var panel_border := ColorRect.new()
	panel_border.color = GOLD.darkened(0.55)
	panel_border.custom_minimum_size = Vector2(0, 1)
	panel_border.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.add_child(panel_border)
	var row := _hbox(panel)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("margin_left", 24)
	row.add_theme_constant_override("margin_right", 18)
	row.add_theme_constant_override("margin_top", 10)
	row.add_theme_constant_override("margin_bottom", 10)
	row.add_theme_constant_override("separation", 14)

	var vow: Dictionary = VowSigilSystem.get_vow(run.equipped_vow_id)
	var sigil: Dictionary = VowSigilSystem.get_sigil(run.equipped_sigil_id)
	_build_loadout_status(row, "VOW", str(vow.get("short_name", vow.get("name", "Vow"))), run.equipped_vow_level, run.equipped_vow_xp, GOLD)
	_build_loadout_status(row, "SIGIL", str(sigil.get("short_name", sigil.get("name", "Sigil"))), run.equipped_sigil_level, run.equipped_sigil_xp, Color(0.48, 0.86, 1.0))
	_stretch(row)
	_build_lane_status(row, run)

func _build_loadout_status(parent: Control, label: String, loadout_name: String, level: int, xp: int, color: Color) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(210, 0)
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	_lbl(box, label, 9, DIM)
	_lbl(box, "%s  Lv.%d" % [loadout_name, level], 15, color)
	_lbl(box, VowSigilSystem.xp_progress_text(xp), 10, DIM)
	_lbl(box, VowSigilSystem.level_bonus_text(level, label == "VOW"), 10, color)

func _build_lane_status(parent: Control, run: RunState) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(230, 0)
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	_lbl(box, "BOON LANES", 9, DIM)
	var has_lane: bool = false
	for lane_key in BoonSystem.BOON_LANE_LIMITS.keys():
		var lane_name: String = str(lane_key)
		var count: int = BoonSystem.boons_in_lane(run.active_boons, lane_name).size()
		var limit: int = BoonSystem.boon_lane_limit(lane_name)
		var lane_color: Color = Color(1.0, 0.52, 0.34) if count >= limit else GOLD
		_lbl(box, "%s  %d/%d" % [lane_name.capitalize(), count, limit], 13, lane_color)
		has_lane = true
	if not has_lane:
		_lbl(box, "No limited lanes", 12, DIM)
#  Node entry

func _build_loadout_picker(parent: Control) -> void:
	var box := _panel(parent, Color(0.07, 0.08, 0.12), Vector2(460, 0))
	var inner := _vbox(box)
	inner.add_theme_constant_override("separation", 6)
	_lbl(inner, "Run Alignment", 13, GOLD, true)
	_add_loadout_row(inner, "Vow", VowSigilSystem.VOWS, true)
	_add_loadout_row(inner, "Sigil", VowSigilSystem.SIGILS, false)

func _add_loadout_row(parent: Control, label: String, items: Array[Dictionary], is_vow: bool) -> void:
	var row := _hbox(parent)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var current := VowSigilSystem.get_vow(_selected_vow_id) if is_vow else VowSigilSystem.get_sigil(_selected_sigil_id)
	var current_xp := _loadout_xp(str(current.get("id", "")), is_vow)
	var current_level := VowSigilSystem.level_for_xp(current_xp)
	var name_lbl := _lbl(row, "%s: %s  Lv.%d" % [label, current.get("short_name", current.get("name", "?")), current_level], 14, FG)
	name_lbl.custom_minimum_size.x = 190
	var theme_lbl := _lbl(parent, _loadout_picker_detail(current, is_vow), 11, DIM, true)
	var prev := _btn("<", DIM)
	prev.custom_minimum_size = Vector2(34, 30)
	var next := _btn(">", GOLD)
	next.custom_minimum_size = Vector2(34, 30)
	prev.pressed.connect(func() -> void: _cycle_loadout(items, is_vow, -1); _refresh_loadout_row(name_lbl, theme_lbl, label, is_vow))
	next.pressed.connect(func() -> void: _cycle_loadout(items, is_vow, 1); _refresh_loadout_row(name_lbl, theme_lbl, label, is_vow))
	row.add_child(prev)
	row.add_child(next)

func _cycle_loadout(items: Array[Dictionary], is_vow: bool, delta: int) -> void:
	var current_id := _selected_vow_id if is_vow else _selected_sigil_id
	var idx := 0
	for i in range(items.size()):
		if str(items[i].get("id", "")) == current_id:
			idx = i
			break
	idx = posmod(idx + delta, items.size())
	if is_vow:
		_selected_vow_id = str(items[idx].get("id", VowSigilSystem.DEFAULT_VOW_ID))
	else:
		_selected_sigil_id = str(items[idx].get("id", VowSigilSystem.DEFAULT_SIGIL_ID))

func _refresh_loadout_row(name_lbl: Label, theme_lbl: Label, label: String, is_vow: bool) -> void:
	var current := VowSigilSystem.get_vow(_selected_vow_id) if is_vow else VowSigilSystem.get_sigil(_selected_sigil_id)
	var current_xp := _loadout_xp(str(current.get("id", "")), is_vow)
	var current_level := VowSigilSystem.level_for_xp(current_xp)
	name_lbl.text = "%s: %s  Lv.%d" % [label, current.get("short_name", current.get("name", "?")), current_level]
	theme_lbl.text = _loadout_picker_detail(current, is_vow)


func _loadout_xp(item_id: String, is_vow: bool) -> int:
	if not _gs:
		return 0
	if is_vow and _gs.has_method("get_vow_xp"):
		return _gs.get_vow_xp(item_id)
	if not is_vow and _gs.has_method("get_sigil_xp"):
		return _gs.get_sigil_xp(item_id)
	return 0


func _loadout_picker_detail(item: Dictionary, is_vow: bool) -> String:
	var item_id := str(item.get("id", ""))
	var xp := _loadout_xp(item_id, is_vow)
	var level := VowSigilSystem.level_for_xp(xp)
	return "%s  |  %s  |  %s" % [
		str(item.get("theme", "")),
		VowSigilSystem.xp_progress_text(xp),
		VowSigilSystem.next_unlock_text(level, is_vow),
	]
func _on_start_run(heat: int = 0) -> void:
	if not _gs: return
	var rm: Node = get_node_or_null("/root/RunManager")
	if rm:
		rm.start_new_run(heat, -1, _selected_vow_id, _selected_sigil_id)
	else:
		# Fallback: create RunState directly if RunManager not registered yet
		var run_seed: int = int(Time.get_unix_time_from_system()) & 0xffffff
		_gs.active_run = RunState.create(run_seed)
		_gs.active_run.equipped_vow_id = _selected_vow_id
		_gs.active_run.equipped_sigil_id = _selected_sigil_id
		if _gs.has_method("seed_run_loadout"):
			_gs.seed_run_loadout(_gs.active_run)
	_build_ui()

func _on_enter_node(node: Dictionary) -> void:
	if not _gs or not _gs.active_run: return
	var node_id := str(node.get("id", ""))
	if not node_id.is_empty():
		_gs.active_run.select_node(node_id)
	if node.get("type", "") == "mystery":
		# Before rolling an outcome, see if a Soul wants this "?".
		# Souls are optional, missable, and take priority over loot when present.
		var soul_id := _pick_available_soul()
		if soul_id != "":
			_show_soul_encounter(soul_id)
			return
		_show_mystery_node()
		return
	match node.get("type","battle"):
		"battle", "elite", "boss", "mystery_ambush":
			_open_deployment(node)
		"mystery_cache", "mystery_training":
			_show_mystery_event(node)
		"mystery_shrine":
			_show_mystery_shrine(node)
		"boon_pick":
			var owned: Array = _gs.active_run.active_boons.map(func(b: Dictionary) -> String: return b.get("id",""))
			var floor_num: int = int(_gs.active_run.current_floor)
			var offers := _bs.generate_offers(_gs.active_run.seed * 17 + floor_num * 3 + _gs.active_run.current_node, floor_num, owned, _gs.active_run.get_loadout_bonus())
			_show_boon_pick(offers)
		"wanderer":
			_show_wanderer_encounter(_gs.active_run)


## Resolve MapData for a run node — same logic used by both _open_deployment
## and the "Edit Formation" shortcut.
func _resolve_map_data(node: Dictionary) -> MapData:
	var map_id: String = str(node.get("map_id", ""))
	if not map_id.is_empty():
		var path := "res://data/maps/%s.tres" % map_id
		if ResourceLoader.exists(path):
			return load(path)
	var mg := MapGenerator.new()
	return mg.generate_floor(
		_gs.active_run.current_floor,
		_gs.active_run.seed,
		_gs.active_run.heat_level,
	)


func _open_deployment(node: Dictionary) -> void:
	if not _gs or not _gs.active_run:
		return
	_gs.active_run.set_meta("pending_node", node)
	var saved_deployment: Array = _gs.active_run.run_deployment.duplicate(true)
	var map_data: MapData = _resolve_map_data(node)

	# Skip deployment screen when the saved formation is still valid for this map.
	if not saved_deployment.is_empty():
		var errs := DeploymentScreen.validate_formation(saved_deployment, map_data)
		if errs.is_empty():
			_on_deployment_confirmed(saved_deployment)
			return

	_show_deployment_screen(saved_deployment, map_data)


func _show_deployment_screen(saved_deployment: Array, map_data: MapData) -> void:
	var ds := preload("res://scripts/ui/DeploymentScreen.gd").new()
	ds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ds.saved_formation = saved_deployment
	ds.saved_formation_loaded = not saved_deployment.is_empty()
	ds.map_data = map_data
	ds.battle_started.connect(_on_deployment_confirmed)
	ds.cancelled.connect(func() -> void: ds.queue_free(); _build_ui())
	get_tree().current_scene.add_child(ds)


func _on_deployment_confirmed(deployment: Array) -> void:
	# Save the player's formation for this run and use it for the incoming battle.
	if _gs and _gs.active_run:
		_gs.active_run.run_deployment = deployment.duplicate(true)
		_gs.active_run.set_meta("pending_deployment", deployment.duplicate(true))
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")


func _resolve_revealed_mystery(node: Dictionary) -> void:
	match node.get("type", ""):
		"mystery_ambush":
			_open_deployment(node)
		"mystery_shrine":
			_show_mystery_shrine(node)
		"mystery_cache", "mystery_training":
			_show_mystery_event(node)
		_:
			_build_ui()


func _show_mystery_shrine(_node: Dictionary) -> void:
	if not _gs or not _gs.active_run:
		return
	var owned: Array = _gs.active_run.active_boons.map(func(b: Dictionary) -> String: return b.get("id", ""))
	var floor_num: int = int(_gs.active_run.current_floor)
	var offers := _bs.generate_offers(_gs.active_run.seed * 29 + floor_num * 11 + _gs.active_run.current_node, floor_num, owned, _gs.active_run.get_loadout_bonus())
	_show_boon_pick(offers)


func _show_mystery_event(node: Dictionary) -> void:
	if _boon_overlay:
		_boon_overlay.queue_free()
	_boon_overlay = _overlay()
	add_child(_boon_overlay)
	var vbox := _vbox(_boon_overlay, true)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(620, 0)
	var event_type: String = str(node.get("type", ""))
	var is_cache := event_type == "mystery_cache"
	var title := "Hidden Cache" if is_cache else "Training Shrine"
	var body := "You find sealed coin and supplies tucked beneath old stone." if is_cache else "The party studies an old tactical mural. Everyone gains JP."
	var reward := "+%dg" % _mystery_gold_reward() if is_cache else "+%d JP to each unit" % _mystery_jp_reward()
	_lbl(vbox, "MYSTERY", 11, DIM, true)
	_space(vbox, 8)
	_lbl(vbox, title, 30, FG, true)
	_space(vbox, 8)
	_lbl(vbox, body, 13, DIM, true)
	_space(vbox, 8)
	_lbl(vbox, reward, 18, GOLD if is_cache else Color(0.48,0.86,1.0), true)
	_space(vbox, 22)
	var cont := _btn("Claim", GOLD)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func() -> void:
		_apply_mystery_event(event_type)
		if _boon_overlay:
			_boon_overlay.queue_free()
			_boon_overlay = null
		_build_ui())
	vbox.add_child(cont)


func _apply_mystery_event(event_type: String) -> void:
	if not _gs or not _gs.active_run:
		return
	match event_type:
		"mystery_cache":
			_gs.gold += _mystery_gold_reward()
		"mystery_training":
			_grant_party_jp(_mystery_jp_reward())
	_complete_current_node_with_loadout_xp(event_type)
	_gs.save()


#  Mystery node overlay  six-outcome event table

const MYSTERY_TABLE: Array = [
	{"id": "treasure", "eyebrow": "TREASURE", "title": "Forgotten Cache",
	 "body": "Beneath collapsed stone the party finds coin sealed in wax, untouched by the descent.",
	 "accent": Color(0.96, 0.78, 0.28)},
	{"id": "shrine", "eyebrow": "SHRINE", "title": "Shrine of the Quiet Light",
	 "body": "A worn altar still hums with old warmth. Wounds knit closed as the party kneels.",
	 "accent": Color(0.30, 0.86, 0.50)},
	{"id": "caravan", "eyebrow": "CARAVAN", "title": "Wayward Caravan",
	 "body": "A lone trader rests her oxen between floors. She unrolls a single bundle of cloth.",
	 "accent": Color(0.48, 0.78, 1.00)},
	{"id": "ambush", "eyebrow": "AMBUSH", "title": "Eyes in the Dark",
	 "body": "The silence breaks. Steel glints from the ruins ahead  the party is not alone.",
	 "accent": Color(0.93, 0.27, 0.27)},
	{"id": "trap", "eyebrow": "TRAP", "title": "Rune-Wired Floor",
	 "body": "A glyph flares underfoot before anyone can call a warning.",
	 "accent": Color(1.00, 0.50, 0.18)},
	{"id": "curse", "eyebrow": "CURSE SITE", "title": "Defiled Ground",
	 "body": "Something old and hungry was bound here. The binding has thinned.",
	 "accent": Color(0.72, 0.30, 0.62)},
]


func _show_mystery_node() -> void:
	if not _gs or not _gs.active_run:
		return
	var run: RunState = _gs.active_run
	var roll := int(abs(run.seed * 131 + run.current_floor * 59 + run.current_node * 23)) % MYSTERY_TABLE.size()
	var outcome: Dictionary = MYSTERY_TABLE[roll]
	var outcome_id := str(outcome.get("id", "treasure"))
	var accent: Color = outcome.get("accent", GOLD)

	if _boon_overlay:
		_boon_overlay.queue_free()
	_boon_overlay = _overlay()
	add_child(_boon_overlay)
	var vbox := _vbox(_boon_overlay, true)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(640, 0)

	_lbl(vbox, "MYSTERY  --  %s" % str(outcome.get("eyebrow", "")), 11, accent, true)
	_space(vbox, 8)
	_lbl(vbox, str(outcome.get("title", "?")), 30, FG, true)
	_space(vbox, 8)
	_lbl(vbox, str(outcome.get("body", "")), 13, DIM, true)
	_space(vbox, 14)

	match outcome_id:
		"treasure":
			var gold_gain := _mystery_gold_reward()
			_lbl(vbox, "+%dg" % gold_gain, 18, GOLD, true)
			_mystery_confirm(vbox, "Claim", accent, func() -> void:
				_gs.gold += gold_gain
				_finish_mystery("treasure"))
		"shrine":
			_lbl(vbox, "The party is restored to full HP.", 18, accent, true)
			_mystery_confirm(vbox, "Kneel", accent, func() -> void:
				_restore_party_hp()
				_finish_mystery("shrine"))
		"caravan":
			var ls := LootSystem.new()
			var rarity_bonus := minf(0.6, float(run.current_floor) * 0.06)
			var item: Dictionary = ls.generate_item(run.seed * 773 + run.current_node * 101, rarity_bonus)
			var price := _caravan_price(item)
			_lbl(vbox, "%s  --  %s" % [str(item.get("name", "?")), str(item.get("label", "Common"))], 17, item.get("color", FG), true)
			for affix: Dictionary in item.get("affixes", []):
				_lbl(vbox, str(affix.get("label", "")), 12, DIM, true)
			_space(vbox, 4)
			var buy := _mystery_confirm(vbox, "Buy for %dg" % price, accent, func() -> void:
				_gs.gold -= price
				_gs.run_inventory.append(item)
				run.inventory.append(item)
				_gs.pending_loot.append(item)
				_finish_mystery("caravan"))
			if _gs.gold < price:
				buy.disabled = true
				_lbl(vbox, "Not enough gold (%dg held)." % _gs.gold, 12, DIM, true)
			_space(vbox, 6)
			var pass_btn := _btn("Walk Away", DIM)
			pass_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			pass_btn.pressed.connect(func() -> void: _finish_mystery("caravan"))
			vbox.add_child(pass_btn)
		"ambush":
			_lbl(vbox, "Fight, or slip back into the dark.", 18, accent, true)
			_mystery_confirm(vbox, "To Arms", accent, func() -> void:
				var cur: Dictionary = run.get_current_node()
				cur["type"] = "mystery_ambush"
				if _boon_overlay:
					_boon_overlay.queue_free()
					_boon_overlay = null
				_open_deployment(cur))
			_space(vbox, 6)
			var flee := _btn("Slip Away  (no reward)", DIM)
			flee.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			flee.pressed.connect(func() -> void: _finish_mystery("ambush"))
			vbox.add_child(flee)
		"trap":
			var victim_id := _pick_trap_victim()
			var dmg := _trap_damage(victim_id)
			_lbl(vbox, "%s takes %d damage." % [_unit_display_name(victim_id), dmg], 18, accent, true)
			_mystery_confirm(vbox, "Endure", accent, func() -> void:
				_apply_trap_damage(victim_id, dmg)
				_finish_mystery("trap"))
		"curse":
			var cs := CurseSystem.new()
			var owned: Array = run.active_curses.map(func(c: Dictionary) -> String: return c.get("id", ""))
			var curse: Dictionary = cs.generate_curse_offer(run.seed + run.current_node * 47, run.current_floor, owned)
			if curse.is_empty():
				_lbl(vbox, "The binding holds. Nothing stirs.", 18, DIM, true)
				_mystery_confirm(vbox, "Move On", accent, func() -> void: _finish_mystery("curse"))
			else:
				_lbl(vbox, "%s  %s" % [str(curse.get("icon", "!")), str(curse.get("name", "?"))], 18, accent, true)
				_lbl(vbox, "PENALTY - %s" % str(curse.get("penalty", "")), 12, Color(1.0, 0.66, 0.62), true)
				_lbl(vbox, "REWARD - %s" % str(curse.get("unlock", "")), 12, Color(0.82, 0.92, 1.0), true)
				_mystery_confirm(vbox, "Accept the Mark", accent, func() -> void:
					run.active_curses.append(curse)
					_finish_mystery("curse"))


## Append the confirm button shared by every mystery outcome.
func _mystery_confirm(parent: Control, label: String, accent: Color, on_confirm: Callable) -> Button:
	_space(parent, 16)
	var btn := _btn(label, accent)
	btn.custom_minimum_size = Vector2(240, 46)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(on_confirm)
	parent.add_child(btn)
	return btn


func _finish_mystery(outcome_id: String) -> void:
	if not _gs or not _gs.active_run:
		return
	_complete_current_node_with_loadout_xp("mystery_" + outcome_id)
	_gs.save()
	if _boon_overlay:
		_boon_overlay.queue_free()
		_boon_overlay = null
	_build_ui()


func _restore_party_hp() -> void:
	if not _gs:
		return
	for uid in _gs.unit_registry:
		var reg: Dictionary = _gs.unit_registry[uid]
		reg["current_hp"] = int(reg.get("base_hp", 200))


func _caravan_price(item: Dictionary) -> int:
	match str(item.get("rarity", "common")):
		"uncommon": return 70
		"rare":     return 160
		"resonant": return 400
		_:          return 30


func _pick_trap_victim() -> String:
	var run: RunState = _gs.active_run
	var ids: Array = []
	for d: Dictionary in run.run_deployment:
		var uid := str(d.get("unit_id", ""))
		if not uid.is_empty():
			ids.append(uid)
	if ids.is_empty():
		ids = _gs.unit_registry.keys()
	if ids.is_empty():
		return ""
	return str(ids[int(abs(run.seed * 37 + run.current_node * 13)) % ids.size()])


func _trap_damage(uid: String) -> int:
	var reg: Dictionary = _gs.unit_registry.get(uid, {})
	var max_hp := int(reg.get("base_hp", 200))
	return maxi(20, int(float(max_hp) * 0.25))


func _apply_trap_damage(uid: String, dmg: int) -> void:
	if not _gs.unit_registry.has(uid):
		return
	var reg: Dictionary = _gs.unit_registry[uid]
	var cur := int(reg.get("current_hp", reg.get("base_hp", 200)))
	reg["current_hp"] = maxi(1, cur - dmg)


func _unit_display_name(uid: String) -> String:
	var chars: Node = get_node_or_null("/root/Characters")
	if chars and chars.has_method("get_character"):
		var data: Dictionary = chars.get_character(uid)
		if not data.is_empty():
			return str(data.get("human_name", uid.capitalize()))
	return uid.capitalize()


func _complete_current_node_with_loadout_xp(node_type_override: String = "") -> Dictionary:
	if not _gs or not _gs.active_run:
		return {}
	var node: Dictionary = _gs.active_run.get_current_node()
	var node_type := node_type_override if not node_type_override.is_empty() else str(node.get("type", "battle"))
	var amount := VowSigilSystem.xp_for_floor_clear(int(_gs.active_run.current_floor), node_type)
	var progress: Dictionary = {}
	if _gs.has_method("apply_loadout_xp"):
		progress = _gs.apply_loadout_xp(amount, node_type)
	else:
		_gs.active_run.grant_loadout_xp(amount)
		progress = {"amount": amount, "reason": node_type}
	_gs.active_run.complete_current_node()
	return progress


func _mystery_gold_reward() -> int:
	return 80 + int(_gs.active_run.current_floor) * 24 if _gs and _gs.active_run else 80


func _mystery_jp_reward() -> int:
	return 12 + int(_gs.active_run.current_floor) * 4 if _gs and _gs.active_run else 12


func _grant_party_jp(amount: int) -> void:
	if not _gs:
		return
	for uid in _gs.unit_registry:
		var reg: Dictionary = _gs.unit_registry[uid]
		reg["jp"] = int(reg.get("jp", 0)) + amount
	_gs.run_jp_earned += amount

func _on_edit_formation_from_run(run: RunState) -> void:
	"""Open the deployment editor without committing to a battle node."""
	if not _gs or not run:
		return
	# Use the next available node's map data if possible, otherwise a generic floor.
	var available := run.get_available_nodes()
	var map_data: MapData
	if available.size() > 0:
		map_data = _resolve_map_data(available[0])
	else:
		var mg := MapGenerator.new()
		map_data = mg.generate_floor(run.current_floor, run.seed, run.heat_level)

	var saved: Array = run.run_deployment.duplicate(true)
	var ds := preload("res://scripts/ui/DeploymentScreen.gd").new()
	ds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ds.saved_formation = saved
	ds.saved_formation_loaded = not saved.is_empty()
	ds.map_data = map_data
	# On confirm: save formation to run but do NOT start battle yet.
	ds.battle_started.connect(func(deployment: Array) -> void:
		run.run_deployment = deployment.duplicate(true)
		if _gs:
			_gs.save()
		ds.queue_free()
		_build_ui()
	)
	ds.cancelled.connect(func() -> void: ds.queue_free(); _build_ui())
	get_tree().current_scene.add_child(ds)


func _on_abandon() -> void:
	var rm: Node = get_node_or_null("/root/RunManager")
	if rm and rm.is_run_active: rm.end_run(false)
	elif _gs: _gs.active_run = null
	_build_ui()

func _on_boon_picked(boon: Dictionary) -> void:
	if not _gs or not _gs.active_run:
		return
	if BoonSystem.needs_lane_replacement(_gs.active_run.active_boons, boon):
		_show_boon_replacement(boon)
		return
	_accept_boon(boon)

func _accept_boon(boon: Dictionary, replaced_boon_id: String = "") -> void:
	if not _gs or not _gs.active_run:
		return
	if not replaced_boon_id.is_empty():
		for i in range(_gs.active_run.active_boons.size() - 1, -1, -1):
			if str(_gs.active_run.active_boons[i].get("id", "")) == replaced_boon_id:
				_gs.active_run.active_boons.remove_at(i)
				break
	_gs.active_run.active_boons.append(boon)
	_gs.pending_boon_offers.clear()
	_complete_current_node_with_loadout_xp("boon_pick")
	_apply_between_battle_heal()
	if _boon_overlay:
		_boon_overlay.queue_free()
		_boon_overlay = null
	_build_ui()

func _show_boon_replacement(incoming_boon: Dictionary) -> void:
	if not _gs or not _gs.active_run:
		return
	if _boon_overlay:
		_boon_overlay.queue_free()
	_boon_overlay = _overlay()
	add_child(_boon_overlay)

	var lane := BoonSystem.boon_lane(incoming_boon)
	var existing := BoonSystem.boons_in_lane(_gs.active_run.active_boons, lane)
	var vbox := _vbox(_boon_overlay, true)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(760, 0)
	_lbl(vbox, "BOON LIMIT", 11, GOLD, true)
	_space(vbox, 8)
	_lbl(vbox, "Choose What To Give Up", 30, FG, true)
	_space(vbox, 8)
	var incoming_name := str(incoming_boon.get("name", "new boon"))
	var lane_label := lane.capitalize()
	_lbl(vbox, "%s boons are limited to %d. Take %s by replacing one below." % [lane_label, BoonSystem.boon_lane_limit(lane), incoming_name], 13, DIM, true)
	_space(vbox, 18)

	var row := _hbox(vbox)
	row.add_theme_constant_override("separation", 14)
	for old_boon: Dictionary in existing:
		var rd: Dictionary = BoonSystem.RARITIES.get(old_boon.get("rarity", "common"), {})
		var col: Color = rd.get("color", Color.WHITE)
		var card := _boon_card(old_boon, col)
		card.custom_minimum_size = Vector2(240, 320)
		card.pressed.connect(_accept_boon.bind(incoming_boon, str(old_boon.get("id", ""))))
		row.add_child(card)

	_space(vbox, 16)
	var keep := _btn("Keep current boons", DIM)
	keep.custom_minimum_size = Vector2(240, 44)
	keep.pressed.connect(func() -> void: _show_boon_pick(_gs.pending_boon_offers))
	vbox.add_child(keep)

func _on_boon_skip() -> void:
	if _gs: _gs.pending_boon_offers.clear()
	if _gs and _gs.active_run: _complete_current_node_with_loadout_xp("boon_pick")
	_apply_between_battle_heal()
	if _boon_overlay: _boon_overlay.queue_free(); _boon_overlay = null
	_build_ui()

## Apply Swift Recovery and other between-battle heals from boons.
func _apply_between_battle_heal() -> void:
	if not _gs or not _gs.active_run: return
	var bonuses := RunBonuses.for_current_run()
	var pct: float = bonuses.get("between_battle_heal", 0.0)
	if pct <= 0.0: return
	var gs: Node = get_node_or_null("/root/GameState")
	if not gs: return
	for uid in gs.unit_registry:
		var reg: Dictionary = gs.unit_registry[uid]
		var max_hp: int = reg.get("base_hp", 200)
		var heal: int   = int(float(max_hp) * pct)
		if heal > 0:
			reg["current_hp"] = min(max_hp, reg.get("current_hp", max_hp) + heal)

func _on_loot_continue() -> void:
	if _gs: _gs.pending_loot.clear()
	if _loot_overlay: _loot_overlay.queue_free(); _loot_overlay = null
	_build_ui()


#  Boon pick overlay

func _show_boon_pick(offers: Array) -> void:
	if _boon_overlay: _boon_overlay.queue_free()
	_boon_overlay = _overlay()
	add_child(_boon_overlay)

	var vbox := _vbox(_boon_overlay, true)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(900, 0)

	var pick_eyebrow := Label.new()
	pick_eyebrow.text = "CHOOSE A BOON"
	pick_eyebrow.add_theme_font_override("font", _FONT_HEADER)
	pick_eyebrow.add_theme_font_size_override("font_size", 11)
	pick_eyebrow.add_theme_color_override("font_color", DIM)
	pick_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pick_eyebrow)
	_space(vbox, 6)
	var pick_title := Label.new()
	pick_title.text = "Power grows with every choice."
	pick_title.add_theme_font_override("font", _FONT_DISPLAY)
	pick_title.add_theme_font_size_override("font_size", 26)
	pick_title.add_theme_color_override("font_color", FG)
	pick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pick_title)
	_space(vbox, 20)

	var hbox := _hbox(vbox)
	hbox.add_theme_constant_override("separation", 16)

	for boon in offers:
		var rd: Dictionary = BoonSystem.RARITIES.get(boon.get("rarity","common"), {})
		var col: Color = rd.get("color", Color.WHITE)
		var card := _boon_card(boon, col)
		card.pressed.connect(_on_boon_picked.bind(boon))
		hbox.add_child(card)

	_space(vbox, 16)

	#  Curse offer (Returnal-style tradeoff)
	if _gs and _gs.active_run:
		var cs := CurseSystem.new()
		var owned_curse_ids: Array = _gs.active_run.active_curses.map(
			func(c: Dictionary) -> String: return c.get("id",""))
		var curse_offer := cs.generate_curse_offer(
			_gs.active_run.seed + _gs.active_run.current_node * 31,
			_gs.active_run.current_floor, owned_curse_ids)
		if not curse_offer.is_empty():
			var divider := HSeparator.new()
			vbox.add_child(divider)
			_space(vbox, 8)
			_lbl(vbox, "-- OR ACCEPT A CURSE --", 11, Color(0.65,0.25,0.25), true)
			_space(vbox, 8)
			vbox.add_child(_curse_card(curse_offer))

	_space(vbox, 10)
	var skip := _btn("Decline all", DIM)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(_on_boon_skip)
	vbox.add_child(skip)


func _boon_card(boon: Dictionary, accent: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(280, 360)
	_style_card(btn, accent)

	var top_bar := ColorRect.new()
	top_bar.color = accent.lerp(Color.TRANSPARENT, 0.45)
	top_bar.custom_minimum_size = Vector2(0, 3)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	btn.add_child(top_bar)

	var inner := _vbox(btn, true)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left",   20)
	inner.add_theme_constant_override("margin_right",  20)
	inner.add_theme_constant_override("margin_top",    16)
	inner.add_theme_constant_override("margin_bottom", 16)
	inner.add_theme_constant_override("separation",     6)

	var rarity_lbl := Label.new()
	rarity_lbl.text = boon.get("rarity","?").to_upper()
	rarity_lbl.add_theme_font_override("font", _FONT_HEADER)
	rarity_lbl.add_theme_font_size_override("font_size", 10)
	rarity_lbl.add_theme_color_override("font_color", accent)
	rarity_lbl.add_theme_constant_override("outline_size", 0)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(rarity_lbl)

	var icon_ctrl := _boon_icon_widget(
		str(boon.get("id","")), str(boon.get("icon","+")), accent)
	inner.add_child(icon_ctrl)

	var name_lbl := Label.new()
	name_lbl.text = str(boon.get("name","?")).to_upper()
	name_lbl.add_theme_font_override("font", _FONT_DISPLAY)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", FG)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(name_lbl)

	var guardian: String = str(boon.get("guardian",""))
	if not guardian.is_empty():
		var g_lbl := Label.new()
		g_lbl.text = _guardian_label(guardian)
		g_lbl.add_theme_font_override("font", _FONT_UI)
		g_lbl.add_theme_font_size_override("font_size", 10)
		g_lbl.add_theme_color_override("font_color", accent.lerp(FG, 0.5))
		g_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(g_lbl)

	_space(inner, 4)

	var desc := RichTextLabel.new()
	desc.bbcode_enabled = false
	desc.text = str(boon.get("desc",""))
	desc.add_theme_font_override("normal_font", _FONT_BODY)
	desc.add_theme_font_size_override("normal_font_size", 12)
	desc.add_theme_color_override("default_color", Color(0.86, 0.83, 0.77))
	desc.custom_minimum_size = Vector2(0, 72)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)

	var impact := _boon_impact_text(boon)
	if not impact.is_empty():
		var sep := HSeparator.new()
		var sep_st := StyleBoxFlat.new()
		sep_st.bg_color = accent.lerp(Color.TRANSPARENT, 0.7)
		sep.add_theme_stylebox_override("separator", sep_st)
		inner.add_child(sep)
		var impact_lbl := Label.new()
		impact_lbl.text = "NEXT FIGHT: " + impact
		impact_lbl.add_theme_font_override("font", _FONT_UI)
		impact_lbl.add_theme_font_size_override("font_size", 11)
		impact_lbl.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.3))
		impact_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(impact_lbl)

	var flavour: String = str(boon.get("flavour",""))
	if not flavour.is_empty():
		_space(inner, 4)
		var fl := RichTextLabel.new()
		fl.bbcode_enabled = false
		fl.text = '"%s"' % flavour
		fl.add_theme_font_override("normal_font", _FONT_BODY)
		fl.add_theme_font_size_override("normal_font_size", 10)
		fl.add_theme_color_override("default_color", Color(0.42, 0.39, 0.34))
		fl.custom_minimum_size = Vector2(0, 52)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(fl)

	return btn


#  Loot overlay

func _boon_impact_text(boon: Dictionary) -> String:
	var fx: Dictionary = boon.get("effect", {})
	match fx.get("type", ""):
		"stat_bonus":
			var parts: Array[String] = []
			if fx.get("stat", "") in ["move", "movement"]:
				parts.append("party gains +%d Move" % int(fx.get("amount", 0)))
			if fx.get("stat", "") in ["temper", "max_temper"]:
				parts.append("party gains +%d Temper" % int(fx.get("amount", 0)))
			if int(fx.get("move_bonus", 0)) != 0:
				parts.append("party gains +%d Move" % int(fx.get("move_bonus", 0)))
			return ", ".join(parts)
		"elemental_bonus", "elemental_damage_bonus":
			var el := str(fx.get("element", "elemental")).capitalize()
			var pct := int(round(float(fx.get("bonus", 0.0)) * 100.0))
			if int(fx.get("heal_bonus", 0)) > 0:
				return "%s +%d%% damage, heals +%d HP" % [el, pct, int(fx.get("heal_bonus", 0))]
			return "%s +%d%% damage" % [el, pct]
		"between_battle_heal":
			return "after battles, party restores %d%% HP" % int(round(float(fx.get("percent", 0.0)) * 100.0))
		"jp_multiplier":
			return "JP gains are x%.1f" % float(fx.get("mult", 1.0))
		"reaction_echo":
			return "%d%% chance for elemental reactions to trigger twice" % int(round(float(fx.get("chance", 0.0)) * 100.0))
		"once_per_battle":
			if fx.get("outcome", "") == "survive_at_1_hp":
				return "first 0-HP party member survives at 1 HP once per battle"
		"on_elite_kill":
			return "elite kills heal %d HP and %d Temper" % [int(fx.get("heal_hp", 0)), int(fx.get("heal_temper", 0))]
		"battle_start":
			if fx.get("trigger", "") == "vaelthorn_bargain":
				return "party trades HP for +%d%% damage" % int(round(float(fx.get("damage_bonus", 0.0)) * 100.0))
			if fx.get("trigger", "") in ["ignite_all_terrain", "ignite_all"]:
				return "the battlefield starts burning"
			if fx.get("trigger", "") == "summon_tide":
				return "water rises in the center of the map"
			if fx.get("trigger", "") in ["vaelthorn_curse_all", "curse_all"]:
				return "all enemies start cursed"
		"passive":
			match fx.get("id", ""):
				"brand": return "burning enemies take +%d%% physical damage" % int(round(float(fx.get("bonus", 0.0)) * 100.0))
				"double_strike": return "basic attacks can strike twice"
				"first_hit_guard": return "first lethal hit leaves the unit at 1 HP"
				"luminarch_covenant": return "single hits cannot drop party below 1 HP"
				"death_flare": return "enemy deaths splash holy damage"
		"tactical":
			match fx.get("id", ""):
				"cleave":
					return "every attack also hits the two tiles flanking target"
				"piercing_line":
					return "attacks pierce through to the unit standing directly behind target"
				"knockback":
					return "%d%% chance to push target 1 tile away on hit" % int(fx.get("chance", 0.0) * 100.0)
				"echo_strike":
					return "%d%% chance to strike the same target a second time" % int(fx.get("chance", 0.0) * 100.0)
				"battle_fury":
					return "+%d%% damage when you moved before attacking this turn" % int(fx.get("bonus", 0.0) * 100.0)
				"coup_de_grace":
					return "+%d%% damage vs enemies below %d%% HP" % [
						int(fx.get("bonus", 0.0) * 100.0),
						int(fx.get("threshold", 0.0) * 100.0)]
				"sundering":
					return "each hit permanently reduces target's max Temper by %d" % int(fx.get("amount", 0))
				"bloodthirst":
					return "recover %d%% of all damage dealt as HP" % int(fx.get("percent", 0.0) * 100.0)
				"ruinous_field":
					return "every %d hits ignites the ground under your target" % int(fx.get("interval", 3))
				"reaping_step":
					return "kills grant a free %d-tile move toward the next enemy" % int(fx.get("range", 3))
				"iron_momentum":
					return "+30%% damage when moving %d+ tiles before attacking" % int(fx.get("min_move", 3))
				"wrath_crescendo":
					return "+%d%% damage per kill this battle (stacks up to x10)" % int(fx.get("per_kill", 0.0) * 100.0)
	return ""
func _curse_card(curse: Dictionary) -> Button:
	var accent := Color(0.92, 0.24, 0.24)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(620, 190)
	_style_card(btn, accent)

	# Crimson top stripe
	var top_bar := ColorRect.new()
	top_bar.color = accent.lerp(Color.TRANSPARENT, 0.55)
	top_bar.custom_minimum_size = Vector2(0, 3)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	btn.add_child(top_bar)

	var inner := _vbox(btn, false)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left",   20)
	inner.add_theme_constant_override("margin_right",  20)
	inner.add_theme_constant_override("margin_top",    14)
	inner.add_theme_constant_override("margin_bottom", 14)
	inner.add_theme_constant_override("separation",     5)

	var eyebrow := Label.new()
	eyebrow.text = "CURSE TRADE"
	eyebrow.add_theme_font_override("font", _FONT_HEADER)
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", accent)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(eyebrow)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [str(curse.get("icon","!")), str(curse.get("name","?")).to_upper()]
	name_lbl.add_theme_font_override("font", _FONT_DISPLAY)
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", FG)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_lbl)

	_space(inner, 6)

	var penalty_lbl := Label.new()
	penalty_lbl.text = "PENALTY - %s" % str(curse.get("penalty",""))
	penalty_lbl.add_theme_font_override("font", _FONT_UI)
	penalty_lbl.add_theme_font_size_override("font_size", 11)
	penalty_lbl.add_theme_color_override("font_color", Color(1.0, 0.66, 0.62))
	penalty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(penalty_lbl)

	var unlock_lbl := Label.new()
	unlock_lbl.text = "REWARD - %s" % str(curse.get("unlock",""))
	unlock_lbl.add_theme_font_override("font", _FONT_UI)
	unlock_lbl.add_theme_font_size_override("font_size", 11)
	unlock_lbl.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	unlock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(unlock_lbl)

	btn.pressed.connect(_on_curse_picked.bind(curse))
	return btn


func _on_curse_picked(curse: Dictionary) -> void:
	if _gs and _gs.active_run:
		_gs.active_run.active_curses.append(curse)
	if _gs:
		_gs.pending_boon_offers.clear()
	if _gs and _gs.active_run:
		_complete_current_node_with_loadout_xp("boon_pick")
	_apply_between_battle_heal()
	if _boon_overlay:
		_boon_overlay.queue_free()
		_boon_overlay = null
	_build_ui()


func _show_wanderer_encounter(run: RunState) -> void:
	if _boon_overlay:
		_boon_overlay.queue_free()
	_boon_overlay = _overlay()
	add_child(_boon_overlay)

	var met_before: bool = _gs != null and _gs.story_flags.has("met_orren")
	var title := "Orren of the Lower Stair" if not met_before else "Orren's Second Mark"
	var body := "A lantern flickers beside a broken stair. Orren, a vault-runner with a silver map case, raises one hand before your party reaches for steel."
	if met_before:
		body = "Orren finds you again between two impossible doors. His map has changed since the last floor, and one route now burns gold-bright."

	var vbox := _vbox(_boon_overlay, true)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(760, 0)
	_lbl(vbox, "STORY ENCOUNTER", 11, Color(0.53,0.94,0.67), true)
	_space(vbox, 8)
	_lbl(vbox, title, 30, FG, true)
	_space(vbox, 8)
	var story := RichTextLabel.new()
	story.bbcode_enabled = false
	story.text = body + "\n\n\"The Anchor rearranges the floors when it feels watched,\" he says. \"Let me mark one truth before it lies again.\""
	story.add_theme_font_size_override("normal_font_size", 13)
	story.add_theme_color_override("default_color", Color(0.82,0.80,0.76))
	story.custom_minimum_size = Vector2(700, 112)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(story)
	_space(vbox, 16)

	var choices := _hbox(vbox)
	choices.add_theme_constant_override("separation", 14)
	var map_btn := _btn("Trust His Map  +%dg" % _wanderer_gold_reward(), GOLD)
	map_btn.custom_minimum_size = Vector2(260, 54)
	map_btn.pressed.connect(_apply_wanderer_choice.bind("map", run))
	choices.add_child(map_btn)
	var train_btn := _btn("Train At The Stair  +%d JP" % _wanderer_jp_reward(), Color(0.48,0.86,1.0))
	train_btn.custom_minimum_size = Vector2(260, 54)
	train_btn.pressed.connect(_apply_wanderer_choice.bind("training", run))
	choices.add_child(train_btn)

	_space(vbox, 12)
	_lbl(vbox, "Orren will remember which help you accepted.", 11, DIM, true)


func _apply_wanderer_choice(choice_id: String, _run: RunState) -> void:
	if not _gs:
		return
	if not _gs.story_flags.has("met_orren"):
		_gs.story_flags.append("met_orren")
	var choice_flag := "orrens_%s" % choice_id
	if not _gs.story_flags.has(choice_flag):
		_gs.story_flags.append(choice_flag)
	match choice_id:
		"map":
			_gs.gold += _wanderer_gold_reward()
		"training":
			_grant_party_jp(_wanderer_jp_reward())
	_complete_current_node_with_loadout_xp("wanderer")
	_gs.save()
	if _boon_overlay:
		_boon_overlay.queue_free()
		_boon_overlay = null
	_build_ui()


func _wanderer_gold_reward() -> int:
	return 70 + int(_gs.active_run.current_floor) * 30 if _gs and _gs.active_run else 100


func _wanderer_jp_reward() -> int:
	return 18 + int(_gs.active_run.current_floor) * 5 if _gs and _gs.active_run else 24

func _show_loot(items: Array) -> void:
	if _loot_overlay: _loot_overlay.queue_free()
	_loot_overlay = _overlay()
	add_child(_loot_overlay)

	var vbox := _vbox(_loot_overlay, true)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(800, 0)

	_lbl(vbox, "BATTLE COMPLETE", 11, DIM, true)
	_space(vbox, 6)
	_lbl(vbox, "%d item%s found." % [items.size(), "s" if items.size() != 1 else ""], 24, FG, true)
	_space(vbox, 20)

	if items.size() > 0:
		var hbox := _hbox(vbox)
		hbox.add_theme_constant_override("separation", 14)
		for item in items:
			hbox.add_child(_item_card(item))
	else:
		_lbl(vbox, "The enemies carried nothing of value.", 14, DIM, true)

	_space(vbox, 20)
	var cont := _btn("Continue  ->", GOLD)
	cont.custom_minimum_size = Vector2(200, 44)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(_on_loot_continue)
	vbox.add_child(cont)


func _item_card(item: Dictionary) -> PanelContainer:
	var pc  := PanelContainer.new()
	pc.custom_minimum_size = Vector2(200, 240)
	_style_panel(pc, item.get("color", Color.WHITE))

	var inner := _vbox(pc, false)
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_top",  14)
	inner.add_theme_constant_override("margin_bottom",14)
	inner.add_theme_constant_override("separation", 5)

	_lbl(inner, item.get("label","").to_upper(), 9, item.get("color", Color.WHITE), false)
	_lbl(inner, item.get("icon",""), 28, Color.WHITE, true)
	_lbl(inner, item.get("name","?"), 13, FG, true)
	_lbl(inner, item.get("slot","").to_upper(), 9, DIM, true)
	_space(inner, 4)
	for affix in item.get("affixes", []):
		_lbl(inner, "- " + affix.get("label",""), 11, Color(0.85,0.82,0.77), false)
	return pc


#  Widget helpers

func _lbl(parent: Control, text: String, font_size: int, color: Color, centered: bool = false) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if centered: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l); return l

func _lbl_widget(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _space(parent: Control, h: int = 8) -> void:
	var s := Control.new(); s.custom_minimum_size = Vector2(0, h); parent.add_child(s)

func _gap(parent: Control, w: int = 8) -> void:
	var s := Control.new(); s.custom_minimum_size = Vector2(w, 0); parent.add_child(s)

func _stretch(parent: Control) -> void:
	var s := Control.new(); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(s)

func _vbox(parent: Control, centered: bool = false) -> VBoxContainer:
	var v := VBoxContainer.new()
	if centered: v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v); return v

func _hbox(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	parent.add_child(h); return h

func _bg(parent: Control) -> void:
	var rect := ColorRect.new(); rect.color = BG
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.z_index = -1; parent.add_child(rect)

func _btn(text: String, color: Color) -> Button:
	var btn := Button.new(); btn.text = text
	var st := StyleBoxFlat.new()
	st.bg_color = color.darkened(0.55); st.border_color = color.lerp(Color.TRANSPARENT, 0.3)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		st.set_border_width(side, 1)
		st.set_corner_radius(CORNER_TOP_LEFT, 10); st.set_corner_radius(CORNER_TOP_RIGHT, 10)
		st.set_corner_radius(CORNER_BOTTOM_LEFT, 10); st.set_corner_radius(CORNER_BOTTOM_RIGHT, 10)
	btn.add_theme_stylebox_override("normal", st); btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_font_size_override("font_size", 14); return btn

func _panel(parent: Control, color: Color, min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var pc := PanelContainer.new()
	if min_size != Vector2.ZERO: pc.custom_minimum_size = min_size
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new(); st.bg_color = color
	pc.add_theme_stylebox_override("panel", st); parent.add_child(pc); return pc

func _style_card(btn: Button, accent: Color) -> void:
	# Iron-plate aesthetic: no rounded corners, thin accent border, void background.
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.067, 0.063, 0.047)   # --surface-1 slab
	st.border_color = accent.lerp(Color.TRANSPARENT, 0.35)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		st.set_border_width(side, 1)
	var hover := st.duplicate() as StyleBoxFlat
	hover.border_color = accent.lerp(Color.WHITE, 0.15)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		hover.set_border_width(side, 2)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover",  hover)

func _style_panel(pc: PanelContainer, accent: Color) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04,0.05,0.09); st.border_color = accent.lerp(Color.TRANSPARENT, 0.35)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: st.set_border_width(side, 2)
	for c in [CORNER_TOP_LEFT,CORNER_TOP_RIGHT,CORNER_BOTTOM_LEFT,CORNER_BOTTOM_RIGHT]:
		st.set_corner_radius(c, 14)
	pc.add_theme_stylebox_override("panel", st)

func _overlay() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st := StyleBoxFlat.new(); st.bg_color = Color(0.02,0.03,0.06,0.93)
	pc.add_theme_stylebox_override("panel", st); return pc

func _pill(parent: Control, text: String, color: Color) -> void:
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = color.darkened(0.7); st.border_color = color.lerp(Color.TRANSPARENT, 0.4)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: st.set_border_width(side, 1)
	st.content_margin_left = 6; st.content_margin_right = 8
	st.content_margin_top = 2; st.content_margin_bottom = 2
	for c in [CORNER_TOP_LEFT,CORNER_TOP_RIGHT,CORNER_BOTTOM_LEFT,CORNER_BOTTOM_RIGHT]:
		st.set_corner_radius(c, 5)
	pc.add_theme_stylebox_override("panel", st)
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	pc.add_child(l); parent.add_child(pc)

func _node_card(meta: Dictionary, is_cur: bool, is_done: bool, _is_future: bool, is_skipped: bool, node: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 116)
	var accent := meta["color"] as Color

	var st := StyleBoxFlat.new()
	var hover_st := StyleBoxFlat.new()
	if is_cur:
		st.bg_color = accent.darkened(0.62)
		st.border_color = accent
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: st.set_border_width(side, 2)
		hover_st.bg_color = accent.darkened(0.45)
		hover_st.border_color = accent.lightened(0.2)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: hover_st.set_border_width(side, 2)
	elif is_done:
		st.bg_color = Color(0.09, 0.14, 0.09, 0.80)
		st.border_color = Color(0.28, 0.60, 0.28, 0.55)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: st.set_border_width(side, 1)
		hover_st = st.duplicate()
	elif is_skipped:
		st.bg_color = Color(0.04, 0.04, 0.06, 0.40)
		st.border_color = Color(1, 1, 1, 0.04)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: st.set_border_width(side, 1)
		hover_st = st.duplicate()
	else:
		st.bg_color = Color(0.07, 0.08, 0.11, 0.55)
		st.border_color = Color(1, 1, 1, 0.07)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: st.set_border_width(side, 1)
		hover_st = st.duplicate()
	for c in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		st.set_corner_radius(c, 8)
		hover_st.set_corner_radius(c, 8)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hover_st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_stylebox_override("focus", st)
	btn.disabled = not is_cur

	# Colored top accent strip
	var top_bar := ColorRect.new()
	top_bar.color = accent if is_cur else (Color(0.28, 0.60, 0.28, 0.4) if is_done else Color(1,1,1,0.04))
	top_bar.custom_minimum_size = Vector2(0, 3)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	btn.add_child(top_bar)

	# Node type label (top center, small caps)
	var type_lbl := Label.new()
	type_lbl.text = meta["label"].to_upper() if not is_done and not is_skipped else ("DONE" if is_done else "SKIPPED")
	type_lbl.add_theme_font_override("font", _FONT_HEADER)
	type_lbl.add_theme_font_size_override("font_size", 8)
	type_lbl.add_theme_color_override("font_color", accent if is_cur else (Color(0.35, 0.70, 0.35) if is_done else DIM.darkened(0.3)))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	type_lbl.offset_top = 7
	type_lbl.offset_bottom = 22
	btn.add_child(type_lbl)

	# Center icon
	var ic: Control
	if is_done:
		var done_lbl := Label.new()
		done_lbl.text = "✓"
		done_lbl.add_theme_font_size_override("font_size", 26)
		done_lbl.add_theme_color_override("font_color", Color(0.35, 0.75, 0.35, 0.9))
		done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic = done_lbl
	elif is_skipped:
		var skip_lbl := Label.new()
		skip_lbl.text = "✗"
		skip_lbl.add_theme_font_size_override("font_size", 20)
		skip_lbl.add_theme_color_override("font_color", DIM.darkened(0.4))
		skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic = skip_lbl
	else:
		var ntype: String = str(node.get("type", "battle"))
		ic = _node_icon_widget(ntype, str(meta["icon"]),
			accent if is_cur else DIM.darkened(0.15), Vector2(38, 38))
	ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ic.offset_top = 2
	btn.add_child(ic)

	# Reward hint at bottom
	var reward_hint := _clean_ui_text(node.get("reward_hint", ""), "")
	if reward_hint.length() > 14:
		reward_hint = reward_hint.substr(0, 14)
	if not reward_hint.is_empty():
		var hint := Label.new()
		hint.text = reward_hint
		hint.add_theme_font_size_override("font_size", 8)
		hint.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.2) if is_cur else DIM.darkened(0.15))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_top = -26
		hint.offset_bottom = -8
		btn.add_child(hint)

	# Animated glow ring for current node
	if is_cur:
		var glow := ColorRect.new()
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glow.color = Color(accent.r, accent.g, accent.b, 0.0)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(glow)
		var tween := btn.create_tween()
		tween.set_loops()
		tween.tween_property(glow, "color:a", 0.12, 0.9).set_trans(Tween.TRANS_SINE)
		tween.tween_property(glow, "color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)

	return btn


func _build_floor_connector(is_current: bool, is_past: bool) -> Control:
	"""Visual connector between floor columns with line + arrowhead."""
	var container := Control.new()
	container.custom_minimum_size = Vector2(28, 96)

	# Horizontal line
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(18, 2)
	var line_color: Color
	if is_current:
		line_color = GOLD.lerp(Color.TRANSPARENT, 0.35)
	elif is_past:
		line_color = Color(0.3, 0.58, 0.3, 0.55)
	else:
		line_color = Color(0.22, 0.22, 0.28, 0.35)
	line.color = line_color
	line.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	line.offset_left = -9
	line.offset_right = 9
	line.offset_top = -1
	line.offset_bottom = 1
	container.add_child(line)

	# Arrowhead label
	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", line_color.lightened(0.15))
	arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	arrow.offset_left = 2
	arrow.offset_top = -11
	container.add_child(arrow)

	return container


func _node_hint(ntype: String) -> String:
	match ntype:
		"boss":      return "Final floor - all elite enemies."
		"elite":     return "Hard fight, better loot odds."
		"mystery":   return "Unknown event. Could be reward, danger, or help."
		"mystery_cache": return "Claim gold without a fight."
		"mystery_training": return "Gain JP without a fight."
		"mystery_shrine": return "Choose a surprise Guardian boon."
		"mystery_ambush": return "Ambush battle with better spoils."
		"boon_pick": return "Choose one Guardian boon."
		"wanderer":  return "A named character waits here."
		_:           return "Procedurally generated battle."


func _available_route_hint(nodes: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for node in nodes:
		var meta: Dictionary = NODE_META.get(node.get("type", "battle"), NODE_META["battle"])
		var reward_hint := _clean_ui_text(node.get("reward_hint", ""), "")
		parts.append("%s %s" % [meta.get("label", "Battle"), reward_hint])
	return "Pick one path: " + "  /  ".join(parts)


## Returns a TextureRect if a PNG icon exists for this boon, else a Label with the emoji.
func _boon_icon_widget(boon_id: String, emoji: String, accent: Color) -> Control:
	var icon_path: String = AssetRegistry.get_boon_icon(boon_id)
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return icon_rect
	var lbl := Label.new()
	lbl.text = emoji
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", accent)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

## Returns a TextureRect for a run-node type, or null if no PNG registered.
func _node_icon_widget(ntype: String, fallback_text: String, color: Color, icon_size: Vector2) -> Control:
	var icon_path: String = AssetRegistry.get_run_node_icon(ntype)
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.custom_minimum_size = icon_size
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return icon_rect
	var lbl := Label.new()
	lbl.text = fallback_text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _guardian_label(g: String) -> String:
	var labels := {"ignareth":"The Eternal Flame","nerevan":"The Tide Eternal",
				   "torvahk":"The Storm Father","luminarch":"The Sacred Light","vaelthorn":"The Shadow That Was"}
	return labels.get(g, g.capitalize())


# ============================================================
#  SOUL ENCOUNTERS — minimal overlay that renders a resolved beat
#  and, on a COURIER_CHOICE beat, shows deliver/withhold buttons.
#  Follows the code-built-overlay pattern used by mystery events.
# ============================================================

var _soul_overlay: Control = null

# Returns the id of an available Soul to surface at this "?", or "" if none.
# A Soul is eligible if Souls.is_soul_available() passes AND the resolver would
# actually return a beat (not departed / not on cooldown). We peek without
# committing by checking availability + non-departed; the resolve call commits.
func _pick_available_soul() -> String:
	if not Engine.has_singleton("Souls") or not Engine.has_singleton("SoulResolver"):
		return ""
	if _gs == null or _gs.active_run == null:
		return ""
	var party := _current_party_ids()
	var floor_num: int = int(_gs.active_run.current_floor)
	var run_seed: int = int(_gs.active_run.seed)
	var node_idx: int = int(_gs.active_run.current_node)

	# Build the eligible pool with per-soul weights (floor fit x affinity).
	# A soul whose trigger_condition is *specifically* met takes priority — e.g.
	# Job appears when someone's costume has cracked, rather than competing.
	var pool: Array = []          # [{id, weight}]
	var total_weight: int = 0
	var priority: String = ""
	for sid in Souls.all_ids():
		if not Souls.is_soul_available(sid):
			continue
		var st: Dictionary = GameState.soul_encounters.get(sid, {})
		if st.get("departed", false):
			continue
		if not Souls.trigger_condition_met(sid, party):
			continue
		var w: int = Souls.floor_weight(sid, floor_num)
		if w <= 0:
			continue
		# Souls with an explicit trigger_condition that is now satisfied jump the queue.
		if Souls.has_priority_trigger(sid):
			priority = sid
		pool.append({"id": sid, "weight": w})
		total_weight += w
	if pool.is_empty():
		return ""
	if priority != "":
		GameState.narrative_flags["soul_seen_this_run"] = true
		return priority

	# Frequency gate: ~55% of eligible "?" nodes become Souls — UNLESS the player
	# hasn't met a soul yet this run, in which case guarantee one (at-least-once).
	var seen_this_run: bool = GameState.narrative_flags.get("soul_seen_this_run", false)
	var rng_gate: float = _seeded_unit(run_seed, floor_num, node_idx, 7)
	if seen_this_run and rng_gate > 0.55:
		return ""   # this "?" stays a loot/cache node

	# Weighted pick, deterministic from the run seed + node position.
	var roll: int = int(_seeded_unit(run_seed, floor_num, node_idx, 13) * float(total_weight))
	var acc: int = 0
	var chosen: String = pool[0]["id"]
	for entry in pool:
		acc += int(entry["weight"])
		if roll < acc:
			chosen = entry["id"]
			break

	GameState.narrative_flags["soul_seen_this_run"] = true
	return chosen

# Deterministic [0,1) value from the run seed and node coordinates. Mirrors the
# seed idiom RunState uses (seed*97 + floor*53 + node*17) with a salt per use.
func _seeded_unit(run_seed: int, floor_num: int, node_idx: int, salt: int) -> float:
	var h: int = abs(run_seed * 97 + floor_num * 53 + node_idx * 17 + salt * 9311)
	return float(h % 100000) / 100000.0

func _current_party_ids() -> Array:
	if _gs and _gs.active_run and _gs.active_run.has_method("get_party_ids"):
		return _gs.active_run.get_party_ids()
	# Fallback: the seven are always "around"; narrative_flags may hold the run party.
	return GameState.narrative_flags.get("current_party", [])

func _show_soul_encounter(soul_id: String) -> void:
	var party := _current_party_ids()
	# Record party so SoulSystemWiring can credit runs_together on run end.
	GameState.narrative_flags["current_party"] = party
	var beat: Dictionary = SoulResolver.resolve_visit(soul_id, party)
	if beat.get("kind", SoulResolver.Beat.NONE) == SoulResolver.Beat.NONE:
		# Soul had nothing to say (cooldown / exhausted) — fall back to loot.
		var node_id := str(_gs.active_run.get_current_node().get("id", ""))
		var node := _gs.active_run.resolve_mystery_node(node_id)
		_resolve_revealed_mystery(node)
		return
	_render_soul_beat(soul_id, beat)

func _render_soul_beat(soul_id: String, beat: Dictionary) -> void:
	_clear_soul_overlay()
	var soul: Dictionary = Souls.get_soul(soul_id)

	var layer := CanvasLayer.new()
	layer.layer = 50
	_soul_overlay = Control.new()
	_soul_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_soul_overlay)
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_soul_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.position = Vector2(280, 120)
	_soul_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [soul.get("name", "?"), soul.get("known_as", "")]
	name_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_lbl)

	for line in beat.get("dialogue", []):
		var l := Label.new()
		l.text = str(line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(680, 0)
		vbox.add_child(l)

	if beat.get("kind") == SoulResolver.Beat.COURIER_CHOICE and not beat.has("delivered"):
		# This is the OFFER. Show deliver / withhold.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		vbox.add_child(row)
		var courier_id: String = beat.get("courier_id", "")
		var deliver_btn := Button.new()
		deliver_btn.text = "Give it to her"
		deliver_btn.pressed.connect(func() -> void: _on_courier_choice(soul_id, courier_id, true))
		row.add_child(deliver_btn)
		var withhold_btn := Button.new()
		withhold_btn.text = "Say nothing"
		withhold_btn.pressed.connect(func() -> void: _on_courier_choice(soul_id, courier_id, false))
		row.add_child(withhold_btn)
	else:
		var close_btn := Button.new()
		close_btn.text = "..."
		close_btn.pressed.connect(_on_soul_closed)
		vbox.add_child(close_btn)

func _on_courier_choice(soul_id: String, courier_id: String, deliver: bool) -> void:
	var result: Dictionary = SoulResolver.resolve_courier_choice(soul_id, courier_id, deliver)
	SoulResolver.mark_courier_resolved(soul_id, courier_id)
	# Render the consequence beat (her response), then a close button.
	_render_soul_beat(soul_id, result)

func _on_soul_closed() -> void:
	_clear_soul_overlay()
	_build_ui()

func _clear_soul_overlay() -> void:
	if _soul_overlay and is_instance_valid(_soul_overlay):
		var parent := _soul_overlay.get_parent()
		if parent and is_instance_valid(parent):
			parent.queue_free()
	_soul_overlay = null
