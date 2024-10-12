@icon("res://Assets/NodeIcons/GameBoard.svg")

extends Node2D

class_name GameBoard

########################################################################################################################
# TODO: Short Term
#
# TODO: Long Term
#
# TODO: Implement game board geography manager
# 
########################################################################################################################

# TODO: Change this to use int for country_id instead of enum
signal country_clicked(country: Types.Country, action_tag: String)

const CONTINENTS: Dictionary[Types.Continent, Array] = {
   Types.Continent.AFRICA: [Types.Country.CONGO, Types.Country.EAST_AFRICA, Types.Country.EGYPT, Types.Country.MADAGASCAR, Types.Country.NORTH_AFRICA, Types.Country.SOUTH_AFRICA],
   Types.Continent.ASIA: [Types.Country.AFGHANISTAN, Types.Country.CHINA, Types.Country.INDIA, Types.Country.IRKUTSK, Types.Country.JAPAN, Types.Country.KAMCHATKA, Types.Country.MIDDLE_EAST, Types.Country.MONGOLIA, Types.Country.SIAM, Types.Country.SIBERIA, Types.Country.URAL, Types.Country.YAKUTSK],
   Types.Continent.AUSTRALIA: [Types.Country.EASTERN_AUSTRALIA, Types.Country.INDONESIA, Types.Country.NEW_GUINEA, Types.Country.WESTERN_AUSTRALIA],
   Types.Continent.EUROPE: [Types.Country.GREAT_BRITAIN, Types.Country.ICELAND, Types.Country.NORTHERN_EUROPE, Types.Country.SCANDINAVIA, Types.Country.SOUTHERN_EUROPE, Types.Country.UKRAINE, Types.Country.WESTERN_EUROPE],
   Types.Continent.NORTH_AMERICA: [Types.Country.ALASKA, Types.Country.ALBERTA, Types.Country.CENTRAL_AMERICA, Types.Country.EASTERN_UNITED_STATES, Types.Country.GREENLAND, Types.Country.NORTHWEST_TERRITORY, Types.Country.ONTARIO, Types.Country.QUEBEC, Types.Country.WESTERN_UNITED_STATES],
   Types.Continent.SOUTH_AMERICA: [Types.Country.ARGENTINA, Types.Country.BRAZIL, Types.Country.PERU, Types.Country.VENEZUELA]
}

const CONTINENT_BONUSES: Dictionary[Types.Continent, int] = {
   Types.Continent.AFRICA: 3,
   Types.Continent.ASIA: 7,
   Types.Continent.AUSTRALIA: 2,
   Types.Continent.EUROPE: 5,
   Types.Continent.NORTH_AMERICA: 5,
   Types.Continent.SOUTH_AMERICA: 2
}

@onready var __country_node_map: Dictionary[Types.Country, Country] = { 
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

# TODO: Move above logic into GeographyManager
var geography_manager: GameBoardGeographyManager = GameBoardGeographyManager.new()
var state_manager: GameBoardStateManager = GameBoardStateManager.new()

func _ready():
   self.__validate_borders()
   
   for node in self.__country_node_map:
      self.__country_node_map[node].connect("clicked", self._on_country_clicked)
      
   state_manager.connect("country_occupation_update", self._on_country_occupation_updated)
      
func _on_country_occupation_updated(country_id: int, old_deployment: Types.Deployment, new_deployment: Types.Deployment) -> void:
   assert(self.__country_node_map.has(country_id), "Invalid country provided to GameBoard::_on_country_occupation_updated()")
   self.__country_node_map[country_id].set_deployment(new_deployment)
   
func get_countries_that_neighbor(country_id: int) -> Array:
   assert(self.__country_node_map.has(country_id), "Invalid country")
   return self.__country_node_map[country_id].neighbors
   
func countries_are_neighbors(country_id1: int, country_id2: int) -> bool:
   if self.__country_node_map.has(country_id1) != true or self.__country_node_map.has(country_id2) != true:
      assert(self.__country_node_map.has(country_id1), "Invalid country_id1")
      assert(self.__country_node_map.has(country_id2), "Invalid country_id2")
      return false
      
   return self.__country_node_map[country_id1].is_neighboring(country_id2)
   
# Perform a breadth first search to find if the destination country is connected to the source country via player occupations
func countries_connected_via_player_occupations(player_id: int, source_country_id: int, destination_country_id: int) -> bool:
   if source_country_id == destination_country_id:
      return true
      
   assert(self.__country_node_map.has(source_country_id), "Country node map does not contain source country!")
   assert(self.__country_node_map.has(destination_country_id), "Country node map does not contain destination country!")
   
   if !state_manager.player_occupies_country(player_id, source_country_id):
      return false
      
   if !state_manager.player_occupies_country(player_id, destination_country_id):
      return false
      
   var countries_to_check: Array[int] = [source_country_id]
   var countries_already_checked: Array[int] = []
   
   return self.__dfs_country_connection_via_player_occupations(player_id, destination_country_id, countries_to_check, countries_already_checked)
   
# Recursively uses self to search for a connection to destination_country owned by neighboring player occupations
# Assumes that player does in fact own the destination country, returns true if path found; false o/w
func __dfs_country_connection_via_player_occupations(player_id: int, 
                                                     destination_country_id: int,
                                                     countries_to_check: Array[int],
                                                     countries_already_checked: Array[int]) -> bool:
                               
   # Find first, yet to check country that is occupied by player
   var player_occupied_country_found: bool = false
   var unchecked_country_id: int        
               
   while !countries_to_check.is_empty():                                           
      unchecked_country_id = countries_to_check.pop_front()
      
      if !countries_already_checked.has(unchecked_country_id):
         assert(self.__country_node_map.has(unchecked_country_id), "Country to check does not exist in node map")
         
         countries_already_checked.append(unchecked_country_id)
         
         if state_manager.player_occupies_country(player_id, unchecked_country_id):
            player_occupied_country_found = true
            break
         
   if !player_occupied_country_found:
      return false
                                                   
   for neighbor_id in self.__country_node_map[unchecked_country_id].neighbors:
      if neighbor_id == destination_country_id:
         return true
         
      assert(self.__country_node_map.has(neighbor_id), "Country node map does not contain neighbor country!")
         
      if state_manager.player_occupies_country(player_id, neighbor_id):
         countries_to_check.append(neighbor_id)
      elif !countries_already_checked.has(neighbor_id):
         countries_already_checked.append(neighbor_id)
   
   return self.__dfs_country_connection_via_player_occupations(player_id, destination_country_id, countries_to_check, countries_already_checked)

func __validate_borders(): 
   for country in self.__country_node_map:
      for neighbor in self.__country_node_map[country].neighbors:
         assert(country != neighbor, "Country is neighboring itself!")
         assert(self.__country_node_map.has(neighbor), "Neighbor is not in node map!")
         assert(self.__country_node_map[neighbor].neighbors.count(country) != 0, "Neighbor does not have country as one if its neighbors!")
   
func _on_country_clicked(country: Types.Country, action_tag: String) -> void:
   self.country_clicked.emit(country, action_tag)
