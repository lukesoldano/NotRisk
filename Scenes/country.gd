extends Node2D

@export var country_label: String = ""

func _ready():
   $Label.text = self.country_label

func set_values(color: Color, troop_count: int):
   $OccupationWidget.set_color(color)
   $OccupationWidget.set_count(troop_count)
