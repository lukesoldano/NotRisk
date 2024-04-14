extends Node2D

func _ready():
   $Label.text = ""

func set_color(color: Color) -> void:
   $InnerRect.color = color

func set_count(count: int) -> void:
   $Label.text = str(count)
