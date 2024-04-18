@icon("res://Assets/NodeIcons/OccupationWidget.svg")

extends Node2D

class_name OccupationWidget

signal clicked(click_type: String)

func _ready():
   $Label.text = ""

func set_color(color: Color) -> void:
   $InnerRect.color = color

func set_count(count: int) -> void:
   $Label.text = str(count)

func _on_texture_rect_gui_input(event: InputEvent) -> void:
   if event.is_action_pressed(UserInput.LEFT_CLICK_ACTION_TAG):
      self.clicked.emit(UserInput.LEFT_CLICK_ACTION_TAG)
   elif event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      self.clicked.emit(UserInput.RIGHT_CLICK_ACTION_TAG)
