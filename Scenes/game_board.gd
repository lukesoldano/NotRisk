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
signal country_clicked(country: Types.Country)

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

var __country_label_map: Dictionary[int, String] = {
   Types.Country.AFGHANISTAN : "Afghanistan",
   Types.Country.ALASKA : "Alaska",
   Types.Country.ALBERTA : "Alberta",
   Types.Country.ARGENTINA : "Argentina",
   Types.Country.BRAZIL : "Brazil",
   Types.Country.CENTRAL_AMERICA : "Central America",
   Types.Country.CHINA : "China",
   Types.Country.CONGO : "Congo",
   Types.Country.EAST_AFRICA : "East Africa",
   Types.Country.EASTERN_AUSTRALIA : "Eastern Australia",
   Types.Country.EASTERN_UNITED_STATES : "Eastern United States",
   Types.Country.EGYPT : "Egypt",
   Types.Country.GREAT_BRITAIN : "Great Britain",
   Types.Country.GREENLAND : "Greenland",
   Types.Country.ICELAND : "Iceland",
   Types.Country.INDIA : "India",
   Types.Country.INDONESIA : "Indonesia",
   Types.Country.IRKUTSK : "Irkutsk",
   Types.Country.JAPAN : "Japan",
   Types.Country.KAMCHATKA : "Kamchatka",
   Types.Country.MADAGASCAR : "Madagascar",
   Types.Country.MIDDLE_EAST : "Middle East",
   Types.Country.MONGOLIA : "Mongolia",
   Types.Country.NEW_GUINEA : "New Guinea",
   Types.Country.NORTH_AFRICA : "North Africa",
   Types.Country.NORTHERN_EUROPE : "Northern Europe",
   Types.Country.NORTHWEST_TERRITORY : "Northwest Territory",
   Types.Country.ONTARIO : "Ontario",
   Types.Country.PERU : "Peru",
   Types.Country.QUEBEC : "Quebec",
   Types.Country.SCANDINAVIA : "Scandinavia",
   Types.Country.SIAM : "Siam",
   Types.Country.SIBERIA : "Siberia",
   Types.Country.SOUTH_AFRICA : "South Africa",
   Types.Country.SOUTHERN_EUROPE : "Southern Europe",
   Types.Country.UKRAINE : "Ukraine",
   Types.Country.URAL : "Ural",
   Types.Country.VENEZUELA : "Venezuela",
   Types.Country.WESTERN_AUSTRALIA : "Western Australia",
   Types.Country.WESTERN_EUROPE : "Western Europe",
   Types.Country.WESTERN_UNITED_STATES : "Western United States",
   Types.Country.YAKUTSK : "Yakutsk"
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
   assert(self.__country_label_map.size() == self.__country_node_map.size(), "Country node map and country label map have differing sizes!")
   for country_id in self.__country_label_map:
      assert(self.__country_node_map.has(country_id), "Country node map does not contain country from country_label_map!")
   
   self.__validate_borders()
   
   for node in self.__country_node_map:
      self.__country_node_map[node].connect("clicked", self._on_country_clicked)
      
   state_manager.connect("country_occupation_update", self._on_country_occupation_updated)
   
# TODO: ALL OF THIS CODE NEEDS TO BE WAY CLEANER AND LESS STUPID
func populate_country_sprites() -> bool:
   const X_MARGIN = 100 * 1.5
   const Y_MARGIN = 75 * 1.5
   
   var X_SCALAR = 0.75 * (Constants.DISPLAY_WINDOW_WIDTH / (CountrySpriteLoader.GAME_BOARD_SPRITE_SHEET_SCALE * CountrySpriteLoader.GAME_BOARD_SOURCE_WIDTH))
   var Y_SCALAR = 0.75 * (Constants.DISPLAY_WINDOW_HEIGHT / (CountrySpriteLoader.GAME_BOARD_SPRITE_SHEET_SCALE * CountrySpriteLoader.GAME_BOARD_SOURCE_HEIGHT))
   
   for country_id in self.__country_node_map:
      var texture = CountrySpriteLoader.get_sprite(country_id)
      var source_sizing = CountrySpriteLoader.get_sprite_source_sizing(country_id)
      
      if texture == null or texture is not Texture2D or source_sizing == null or source_sizing is not Rect2:
         Logger.log_error(
            "Failed to populate country sprites, null texture or source_sizing for country: " + 
            self.get_country_label(country_id)
         )
         return false
         
      source_sizing.position.x *= X_SCALAR
      source_sizing.position.x -= (CountrySpriteLoader.GAME_BOARD_SOURCE_WIDTH - X_MARGIN)
      source_sizing.position.y *= Y_SCALAR
      source_sizing.position.y -= (CountrySpriteLoader.GAME_BOARD_SOURCE_HEIGHT - Y_MARGIN)
      
      self.__country_node_map[country_id].set_sprite(texture, Vector2(X_SCALAR, Y_SCALAR))
      self.__country_node_map[country_id].position = source_sizing.position
      
      continue
      
   return true
      
func _on_country_occupation_updated(country_id: int, _old_deployment: Types.Deployment, new_deployment: Types.Deployment) -> void:
   assert(country_id != Constants.INVALID_ID, "Country id was set to INVALID_ID in GameBoard::_on_country_occupation_updated()")
   assert(self.__country_node_map.has(country_id), "Invalid country provided to GameBoard::_on_country_occupation_updated()")
   self.__country_node_map[country_id].set_deployment(new_deployment)
   
func get_country_global_position(country_id: int) -> Vector2:
   assert(country_id != Constants.INVALID_ID, "Country id was set to INVALID_ID in GameBoard::get_country_global_position()")
   assert(self.__country_node_map.has(country_id), "Invalid country provided to GameBoard::get_country_global_position()")
   return self.__country_node_map[country_id].get_node("OccupationWidget").get_global_position()
   
func get_country_label(country_id: int) -> String:
   assert(country_id != Constants.INVALID_ID, "Country id was set to INVALID_ID in GameBoard::get_country_label()")
   assert(self.__country_label_map.has(country_id), "Invalid country")
   if self.__country_label_map.has(country_id):
      return self.__country_label_map[country_id]
   return ""
   
func get_country_labels() -> Dictionary[int, String]:
   return self.__country_label_map
   
func get_countries_that_neighbor(country_id: int) -> Array:
   assert(country_id != Constants.INVALID_ID, "Country id was set to INVALID_ID in GameBoard::get_countries_that_neighbor()")
   assert(self.__country_node_map.has(country_id), "Invalid country")
   return self.__country_node_map[country_id].neighbors
   
func countries_are_neighbors(country_id1: int, country_id2: int) -> bool:
   assert(country_id1 != Constants.INVALID_ID, "Country id was set to INVALID_ID in GameBoard::countries_are_neighbors()")
   assert(country_id2 != Constants.INVALID_ID, "Country id was set to INVALID_ID in GameBoard::countries_are_neighbors()")
   if self.__country_node_map.has(country_id1) != true or self.__country_node_map.has(country_id2) != true:
      assert(self.__country_node_map.has(country_id1), "Invalid country_id1")
      assert(self.__country_node_map.has(country_id2), "Invalid country_id2")
      return false
      
   return self.__country_node_map[country_id1].is_neighboring(country_id2)
   
# Perform a breadth first search to find if the destination country is connected to the source country via player occupations
func countries_connected_via_player_occupations(player_id: int, source_country_id: int, destination_country_id: int) -> bool:
   assert(source_country_id != Constants.INVALID_ID, "Country id was set to INVALID_ID in GameBoard::countries_connected_via_player_occupations()")
   assert(destination_country_id != Constants.INVALID_ID, "Country id was set to INVALID_ID in GameBoard::countries_connected_via_player_occupations()")
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
   
# Highlighting a country white is the equivalent of removing a highlight
func highlight_country(country_id: int, color: Color) -> void:
   assert(self.__country_node_map.has(country_id), "Invalid country provided to GameBoard::highlight_country()")
   self.__country_node_map[country_id].set_highlight_color(color)

func __validate_borders(): 
   for country in self.__country_node_map:
      for neighbor in self.__country_node_map[country].neighbors:
         assert(country != neighbor, "Country is neighboring itself!")
         assert(self.__country_node_map.has(neighbor), "Neighbor is not in node map!")
         assert(self.__country_node_map[neighbor].neighbors.count(country) != 0, "Neighbor does not have country as one if its neighbors!")
   
func _on_country_clicked(country: Types.Country) -> void:
   self.country_clicked.emit(country)
