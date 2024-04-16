@icon("res://Assets/NodeIcons/GameBoard.svg")

extends Node2D

class_name GameBoard

signal next_phase_requested()

@onready var __country_node_map: Dictionary = { 
   Types.Country.AFGHANISTAN: $Continents/Asia/Afghanistan,
   Types.Country.ALASKA: $Continents/NorthAmerica/Alaska,
   Types.Country.ALBERTA: $Continents/NorthAmerica/Alberta,
   Types.Country.ARGENTINA: $Continents/SouthAmerica/Argentina,
   Types.Country.BRAZIL: $Continents/SouthAmerica/Brazil,
   Types.Country.CENTRAL_AMERICA: $Continents/NorthAmerica/CentralAmerica,
   Types.Country.CHINA: $Continents/Asia/China,
   Types.Country.CONGO: $Continents/Africa/Congo,
   Types.Country.EAST_AFRICA: $Continents/Africa/EastAfrica,
   Types.Country.EASTERN_AUSTRALIA: $Continents/Australia/EasternAustralia,
   Types.Country.EASTERN_UNITED_STATES: $Continents/NorthAmerica/EasternUnitedStates,
   Types.Country.EGYPT: $Continents/Africa/Egypt,
   Types.Country.GREAT_BRITAIN: $Continents/Europe/GreatBritain,
   Types.Country.GREENLAND: $Continents/NorthAmerica/Greenland,
   Types.Country.ICELAND: $Continents/Europe/Iceland,
   Types.Country.INDIA: $Continents/Asia/India,
   Types.Country.INDONESIA: $Continents/Australia/Indonesia,
   Types.Country.IRKUTSK: $Continents/Asia/Irkutsk,
   Types.Country.JAPAN: $Continents/Asia/Japan,
   Types.Country.KAMCHATKA: $Continents/Asia/Kamchatka,
   Types.Country.MADAGASCAR: $Continents/Africa/Madagascar,
   Types.Country.MIDDLE_EAST: $Continents/Asia/MiddleEast,
   Types.Country.MONGOLIA: $Continents/Asia/Mongolia,
   Types.Country.NEW_GUINEA: $Continents/Australia/NewGuinea,
   Types.Country.NORTH_AFRICA: $Continents/Africa/NorthAfrica,
   Types.Country.NORTHERN_EUROPE: $Continents/Europe/NorthernEurope,
   Types.Country.NORTHWEST_TERRITORY: $Continents/NorthAmerica/NorthwestTerritory,
   Types.Country.ONTARIO: $Continents/NorthAmerica/Ontario,
   Types.Country.PERU: $Continents/SouthAmerica/Peru,
   Types.Country.QUEBEC: $Continents/NorthAmerica/Quebec,
   Types.Country.SCANDINAVIA: $Continents/Europe/Scandinavia,
   Types.Country.SIAM: $Continents/Asia/Siam,
   Types.Country.SIBERIA: $Continents/Asia/Siberia,
   Types.Country.SOUTH_AFRICA: $Continents/Africa/SouthAfrica,
   Types.Country.SOUTHERN_EUROPE: $Continents/Europe/SouthernEurope,
   Types.Country.UKRAINE: $Continents/Europe/Ukraine,
   Types.Country.URAL: $Continents/Asia/Ural,
   Types.Country.VENEZUELA: $Continents/SouthAmerica/Venezuela,
   Types.Country.WESTERN_AUSTRALIA: $Continents/Australia/WesternAustralia,
   Types.Country.WESTERN_EUROPE: $Continents/Europe/WesternEurope,
   Types.Country.WESTERN_UNITED_STATES: $Continents/NorthAmerica/WesternUnitedStates,
   Types.Country.YAKUTSK: $Continents/Asia/Yakutsk
}

func _ready():
   self.__validate_borders()

# Dictionary should be in format { country: Country, Deployment }
func populate(deployments: Dictionary) -> bool:
   for country in deployments:
      if not self.set_country_deployment(country, deployments[country]):
         assert(false, "Failed to populate country during initialization")
         return false
         
   return true
      
func set_country_deployment(country: Types.Country, deployment: Types.Deployment) -> bool:
   if self.__country_node_map.has(country) != true:
      assert(false, "Invalid country")
      return false

   self.__country_node_map[country].set_deployment(deployment)
   return true
   
func countries_are_neighbors(country1: Types.Country, country2: Types.Country) -> bool:
   if self.__country_node_map.has(country1) != true or self.__country_node_map.has(country2) != true:
      assert(self.__country_node_map.has(country1), "Invalid country1")
      assert(self.__country_node_map.has(country2), "Invalid country2")
      return false
      
   return self.__country_node_map[country1].has_border_with(country2)

func __validate_borders(): 
   for country in self.__country_node_map:
      for neighbor in self.__country_node_map[country].neighbors:
         assert(country != neighbor, "Country is neighboring itself!")
         assert(self.__country_node_map.has(neighbor), "Neighbor is not in node map!")
         assert(self.__country_node_map[neighbor].neighbors.count(country) != 0, "Neighbor does not have country as one if its neighbors!")

func _on_turn_phase_updated(player: Types.Player, phase: Types.TurnPhase) -> void:
   $Temp/PhaseInfoLabel.text = "Player: " + player.user_name + " - Phase: " + str(phase)

func _on_next_phase_button_pressed() -> void:
   Logger.log_message("Next phase requested")
   self.next_phase_requested.emit()
