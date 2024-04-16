@icon("res://Assets/NodeIcons/OccupationWidget.svg")

extends Node2D

class_name OccupationWidget

func _ready():
   $Label.text = ""

func set_color(color: Color) -> void:
   $InnerRect.color = color

func set_count(count: int) -> void:
   $Label.text = str(count)

func _on_texture_rect_gui_input(event: InputEvent) -> void:
   if event.is_action_pressed("left_click"):
      print("I WAS CLICKED!")
