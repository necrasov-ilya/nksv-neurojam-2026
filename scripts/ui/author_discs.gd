extends Button

const TEXTURE := preload("res://assets/ui/authors/nksv_disc.png")
const SPEED := TAU / 12.0
var _disc: TextureRect

func _ready() -> void:
	name = "AuthorDisc"
	custom_minimum_size = Vector2(64, 64)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "NKSV_ILYA · Telegram\nEsc — освободить курсор"
	for state in ["normal", "hover", "pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("5b4cff")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(32)
	add_theme_stylebox_override("focus", focus)
	pressed.connect(func(): OS.shell_open("https://t.me/nksv_ilya"))
	_disc = TextureRect.new()
	_disc.texture = TEXTURE
	_disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_disc.size = Vector2(64, 64)
	_disc.pivot_offset = _disc.size * 0.5
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_disc)

func _process(delta: float) -> void:
	if is_visible_in_tree() and not is_hovered() and not has_focus():
		_disc.rotation = fposmod(_disc.rotation + SPEED * delta, TAU)
