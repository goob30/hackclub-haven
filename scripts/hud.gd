extends CanvasLayer

var combo_label: Label

func _ready():
	var health_label: Label = $Health
	combo_label = Label.new()
	combo_label.name = "Combo"
	combo_label.label_settings = health_label.label_settings
	combo_label.position = health_label.position + Vector2(0, -50)
	combo_label.visible = false
	add_child(combo_label)

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("combo_changed"):
		player.combo_changed.connect(_on_combo_changed)

func _on_health_updated(health):
	$Health.text = str(health) + "%"

func _on_combo_changed(combo: int):
	combo_label.text = "x" + str(combo) + " COMBO"
	combo_label.visible = combo > 0
