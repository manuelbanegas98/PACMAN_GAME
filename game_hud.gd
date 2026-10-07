extends CanvasLayer
class_name GameHUD

var score_label: Label
var lives_label: Label
var level_label: Label
var pellet_label: Label
var power_label: Label
var message_label: Label
var debug_panel: ColorRect
var debug_label: Label


func _ready() -> void:
	var title := _make_label("AI FOR GAMES MAZE", Vector2(28, 13), Vector2(220, 34), 20, Color("eafaff"))
	title.add_theme_font_size_override("font_size", 20)
	score_label = _make_label("SCORE  00000", Vector2(256, 19), Vector2(145, 26), 18, Color("7ce8ff"))
	lives_label = _make_label("LIVES  3", Vector2(420, 19), Vector2(100, 26), 18, Color("ff7b91"))
	level_label = _make_label("LEVEL  1", Vector2(545, 19), Vector2(105, 26), 18, Color("e8edff"))
	pellet_label = _make_label("ORB  0", Vector2(685, 19), Vector2(108, 26), 18, Color("ffd166"))
	power_label = _make_label("WASD / ARROWS  MOVE     P  PAUSE     F3  AI TRACE", Vector2(30, 54), Vector2(610, 21), 13, Color("8ca6b8"))
	message_label = _make_label("", Vector2(176, 291), Vector2(608, 62), 25, Color("f4fbff"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.visible = false
	debug_panel = ColorRect.new()
	debug_panel.position = Vector2(800, 112)
	debug_panel.size = Vector2(148, 164)
	debug_panel.color = Color(0.025, 0.055, 0.09, 0.9)
	debug_panel.visible = false
	add_child(debug_panel)
	debug_label = _make_label("", Vector2(810, 120), Vector2(132, 148), 13, Color("9defff"))
	debug_label.visible = false


func update_status(score: int, lives: int, level: int, remaining: int, power_seconds: float, ai_state: StringName, target_name: String, path_length: int, prediction: int, difficulty: float, adaptive: float = 0.0) -> void:
	score_label.text = "SCORE  %05d" % score
	lives_label.text = "LIVES  %d" % lives
	level_label.text = "LEVEL  %d" % level
	pellet_label.text = "ORB  %d" % remaining
	power_label.text = "WASD / ARROWS  MOVE     P  PAUSE     F3  AI TRACE"
	if power_seconds > 0.0:
		power_label.text += "     SHIELD  %.1fs" % power_seconds
	power_label.text += "     ADAPT  %+.2f" % adaptive
	if debug_panel.visible:
		debug_label.text = "AI STATE\n%s\n\nTARGET\n%s\n\nPATH\n%d tiles\n\nPREDICTION\n%d tiles\n\nDIFFICULTY\n%.1f" % [ai_state, target_name, path_length, prediction, difficulty]


func set_debug_visible(visible: bool) -> void:
	debug_panel.visible = visible
	debug_label.visible = visible


func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = not text.is_empty()


func _make_label(text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
