@icon("res://Assets/NodeIcons/Country.svg")

extends Node2D

class_name Country

signal clicked(country: Types.Country, action_tag: String)

@export var country: Types.Country
@export var country_label: String = ""
@export var neighbors: Array[Types.Country] = []

func _ready():
   assert(self.neighbors.size() >= 1, "Country has no neighbors")
   for neighbor in self.neighbors:
      assert(self.neighbors.count(neighbor) == 1, "Repeat entry in neighbors list")
   
   $Label.text = self.country_label

func set_deployment(deployment: Types.Deployment) -> void:
   $OccupationWidget.set_color(deployment.player.army_color)
   $OccupationWidget.set_count(deployment.troop_count)
   
func is_neighboring(country: Types.Country) -> bool:
   return self.neighbors.count(country)

func _on_occupation_widget_clicked(action_tag):
   var message = Types.Country.keys()[country] + ": was clicked with type: " + action_tag
   Logger.log_message(message)
   
   self.clicked.emit(self.country, action_tag)
