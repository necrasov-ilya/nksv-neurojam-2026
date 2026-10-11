extends CanvasLayer

const GAMMA_SHADER := preload("res://assets/shaders/display_gamma.gdshader")


func _ready() -> void:
	# Above the existing UI, transition curtains, and native browser layer (40).
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := ColorRect.new()
	overlay.name = "DisplayGamma"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.focus_mode = Control.FOCUS_NONE
	overlay.color = Color.WHITE
	var gamma_material := ShaderMaterial.new()
	gamma_material.shader = GAMMA_SHADER
	overlay.material = gamma_material
	# Refresh after earlier screen-reading effects instead of reusing their copy.
	# As a behind-parent child, the copy runs immediately before this rect and
	# shares its neutral-gamma visibility bypass.
	var screen_copy := BackBufferCopy.new()
	screen_copy.name = "FinalScreenCopy"
	screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	screen_copy.show_behind_parent = true
	overlay.add_child(screen_copy)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameSettings.register_gamma_overlay(overlay)


func _exit_tree() -> void:
	GameSettings.register_gamma_overlay(null)
