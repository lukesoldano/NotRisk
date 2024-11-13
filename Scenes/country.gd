@icon("res://Assets/NodeIcons/Country.svg")

extends Node2D

class_name Country

signal clicked(country: Types.Country)

@export var country: Types.Country
@export var neighbors: Array[Types.Country] = []

var __is_mouse_hovering: bool = false
var __highlight_color: Color = Color.WHITE

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
   
# A color of white is the same as transparent
func set_highlight_color(color: Color) -> void:
   self.__highlight_color = color
   
   # If setting to white, only do so if the button is not currently hovered over, o/w use hover color
   if color == Color.WHITE and self.__is_mouse_hovering:
      $TextureButton.set_modulate(Color.GRAY)
      
   $TextureButton.set_modulate(color)
   
func set_deployment(deployment: Types.Deployment) -> void:   
   $OccupationWidget.set_color(PlayerManager.get_player_for_id(deployment.player_id).army_color)
   $OccupationWidget.set_count(deployment.troop_count)
   
func is_neighboring(i_country: Types.Country) -> bool:
   return self.neighbors.count(i_country)

func _on_occupation_widget_clicked() -> void:
   Logger.log_message("LocalPlayer clicked: " + Types.Country.keys()[country])
   self.clicked.emit(self.country)

func _on_texture_button_mouse_entered():
   self.__is_mouse_hovering = true
   if self.__highlight_color == Color.WHITE:
      $TextureButton.set_modulate(Color.GRAY)

func _on_texture_button_mouse_exited():
   if self.__highlight_color == Color.WHITE:
      $TextureButton.set_modulate(Color.WHITE)
   self.__is_mouse_hovering = false
