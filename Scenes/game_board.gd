@icon("res://Assets/NodeIcons/GameBoard.svg")

extends Node2D

class_name GameBoard

########################################################################################################################
# TODO's
#
# TODO: Short Term
#
# Move next phase button into GameBoardHUD and out of GameBoard
#
# TODO: Long Term
#
# Make country type agnostic such that only GameBoard is aware (not an enum- maybe a string instead, figure out later), allows for different GameBoards/maps
# 
########################################################################################################################

signal next_phase_requested()
signal country_clicked(country: Types.Country, action_tag: String)

const CONTINENTS: Dictionary = {
   Types.Continent.AFRICA: [Types.Country.CONGO, Types.Country.EAST_AFRICA, Types.Country.EGYPT, Types.Country.MADAGASCAR, Types.Country.NORTH_AFRICA, Types.Country.SOUTH_AFRICA],
   Types.Continent.ASIA: [Types.Country.AFGHANISTAN, Types.Country.CHINA, Types.Country.INDIA, Types.Country.IRKUTSK, Types.Country.JAPAN, Types.Country.KAMCHATKA, Types.Country.MIDDLE_EAST, Types.Country.MONGOLIA, Types.Country.SIAM, Types.Country.SIBERIA, Types.Country.URAL, Types.Country.YAKUTSK],
   Types.Continent.AUSTRALIA: [Types.Country.EASTERN_AUSTRALIA, Types.Country.INDONESIA, Types.Country.NEW_GUINEA, Types.Country.WESTERN_AUSTRALIA],
   Types.Continent.EUROPE: [Types.Country.GREAT_BRITAIN, Types.Country.ICELAND, Types.Country.NORTHERN_EUROPE, Types.Country.SCANDINAVIA, Types.Country.SOUTHERN_EUROPE, Types.Country.UKRAINE, Types.Country.WESTERN_EUROPE],
   Types.Continent.NORTH_AMERICA: [Types.Country.ALASKA, Types.Country.ALBERTA, Types.Country.CENTRAL_AMERICA, Types.Country.EASTERN_UNITED_STATES, Types.Country.GREENLAND, Types.Country.NORTHWEST_TERRITORY, Types.Country.ONTARIO, Types.Country.QUEBEC, Types.Country.WESTERN_UNITED_STATES],
   Types.Continent.SOUTH_AMERICA: [Types.Country.ARGENTINA, Types.Country.BRAZIL, Types.Country.PERU, Types.Country.VENEZUELA]
}

const CONTINENT_BONUSES: Dictionary = {
   Types.Continent.AFRICA: 3,
   Types.Continent.ASIA: 7,
   Types.Continent.AUSTRALIA: 2,
   Types.Continent.EUROPE: 5,
   Types.Continent.NORTH_AMERICA: 5,
   Types.Continent.SOUTH_AMERICA: 2
}

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
   
   for node in self.__country_node_map:
      self.__country_node_map[node].connect("clicked", self._on_country_clicked)
      
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
      
   return self.__country_node_map[country1].is_neighboring(country2)
   
# Perform a breadth first search to find if the destination country is connected to the source country via player occupations
func countries_connected_via_player_occupations(player: Player, 
                                                occupations: Dictionary, 
                                                source_country: Types.Country, 
                                                destination_country: Types.Country) -> bool:
   if source_country == destination_country:
      return true
      
   assert(occupations.has(source_country), "Occupations map does not contain source country!")
   assert(occupations.has(destination_country), "Occupations map does not contain destination country!")
   
   assert(self.__country_node_map.has(source_country), "Country node map does not contain source country!")
   assert(self.__country_node_map.has(destination_country), "Country node map does not contain destination country!")
   
   var SOURCE_OCCUPATION = occupations[source_country]
   var DESTINATION_OCCUPATION = occupations[destination_country]
   
   if SOURCE_OCCUPATION.player != player:
      return false
      
   if DESTINATION_OCCUPATION.player != player:
      return false
      
   var countries_to_check: Array[Types.Country] = [source_country]
   var countries_already_checked: Array[Types.Country] = []
   
   return self.__dfs_country_connection_via_player_occupations(player, occupations, destination_country, countries_to_check, countries_already_checked)
   
# Recursively uses self to search for a connection to destination_country owned by neighboring player occupations
# Assumes that player does in fact own the destination country, returns true if path found; false o/w
func __dfs_country_connection_via_player_occupations(player: Player, 
                                                     occupations: Dictionary, 
                                                     destination_country: Types.Country,
                                                     countries_to_check: Array[Types.Country],
                                                     countries_already_checked: Array[Types.Country]) -> bool:
                               
   # Find first, yet to check country that is occupied by player
   var player_occupied_country_found: bool = false
   var unchecked_country: Types.Country        
               
   while !countries_to_check.is_empty():                                           
      unchecked_country = countries_to_check.pop_front()
      
      if !countries_already_checked.has(unchecked_country):
         assert(occupations.has(unchecked_country), "Country to check does not exist in occupations map")
         assert(self.__country_node_map.has(unchecked_country), "Country to check does not exist in node map")
         
         countries_already_checked.append(unchecked_country)
         
         if occupations[unchecked_country].player == player:
            player_occupied_country_found = true
            break
         
   if !player_occupied_country_found:
      return false
                                                   
   for neighbor in self.__country_node_map[unchecked_country].neighbors:
      if neighbor == destination_country:
         return true
         
      assert(occupations.has(neighbor), "Occupations map does not contain neighbor country!")
      assert(self.__country_node_map.has(neighbor), "Country node map does not contain neighbor country!")
         
      if occupations[neighbor].player == player:
         countries_to_check.append(neighbor)
      elif !countries_already_checked.has(neighbor):
         countries_already_checked.append(neighbor)
   
   return self.__dfs_country_connection_via_player_occupations(player, occupations, destination_country, countries_to_check, countries_already_checked)

func __validate_borders(): 
   for country in self.__country_node_map:
      for neighbor in self.__country_node_map[country].neighbors:
         assert(country != neighbor, "Country is neighboring itself!")
         assert(self.__country_node_map.has(neighbor), "Neighbor is not in node map!")
         assert(self.__country_node_map[neighbor].neighbors.count(country) != 0, "Neighbor does not have country as one if its neighbors!")

func _on_turn_phase_updated(player: Player, phase: GameEngine.TurnPhase) -> void:
   $Temp/PhaseInfoLabel.text = "Player: " + player.user_name + " - Phase: " + GameEngine.TurnPhase.keys()[phase]

func _on_next_phase_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Next phase requested")
   self.next_phase_requested.emit()
   
func _on_country_clicked(country: Types.Country, action_tag: String) -> void:
   self.country_clicked.emit(country, action_tag)
