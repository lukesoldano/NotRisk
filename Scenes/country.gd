@icon("res://Assets/NodeIcons/Country.svg")

extends Node2D

class_name Country

signal clicked(country: Types.Country, action_tag: String)

@export var country: Types.Country
@export var neighbors: Array[Types.Country] = []

func _ready():
   assert(self.neighbors.size() >= 1, "Country has no neighbors")
   for neighbor in self.neighbors:
      assert(self.neighbors.count(neighbor) == 1, "Repeat entry in neighbors list")
   
func set_sprite(texture: Texture2D, scale: Vector2) -> void:
   $TextureButton.scale = scale
   $TextureButton.texture_normal = texture

   # Create clickable space bitmap from texture alpha
   var image: Image = $TextureButton.texture_normal.get_image()
   var bitmap := BitMap.new()
   bitmap.create_from_image_alpha(image)
   $TextureButton.texture_click_mask = bitmap
   
   # Center OccupationWidget on texture
   $OccupationWidget.position.x += image.get_width()
   $OccupationWidget.position.y += image.get_height()
   
func set_deployment(deployment: Types.Deployment) -> void:   
   $OccupationWidget.set_color(PlayerManager.get_player_for_id(deployment.player_id).army_color)
   $OccupationWidget.set_count(deployment.troop_count)
   
func is_neighboring(i_country: Types.Country) -> bool:
   return self.neighbors.count(i_country)

func _on_occupation_widget_clicked() -> void:
   var action_tag = UserInput.LEFT_CLICK_ACTION_TAG
   var message = "LocalPlayer: " + Types.Country.keys()[country] + ": was clicked with type: " + action_tag
   Logger.log_message(message)
   
   self.clicked.emit(self.country, action_tag)

func _on_texture_button_mouse_entered():
   $TextureButton.set_modulate(Color.GRAY)

func _on_texture_button_mouse_exited():
   $TextureButton.set_modulate(Color.WHITE)
