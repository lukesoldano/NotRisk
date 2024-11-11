extends HBoxContainer

class_name PlayerLeaderboardTableRow

const __COLUMN_SPACING: int = 4

@export var player_color: Color = Color.WHITE
@export var num_countries: int = 999
@export var num_armies: int = 999
@export var num_reinforcements: int = 999
@export var num_cards: int = 0

func set_values(i_player_color: Color, i_num_countries: int, i_num_armies: int, i_num_reinforcements: int, i_num_cards: int) -> void:
   self.player_color = i_player_color
   self.num_countries = i_num_countries
   self.num_armies = i_num_armies
   self.num_reinforcements = i_num_reinforcements
   self.num_cards = i_num_cards
   
   match self.player_color:
      Color.DIM_GRAY:
         $PlayerTextureRect.texture = load("res://Assets/kenney_boardgame-pack/PNG/Pieces (Black)/pieceBlack_border00.png")
      Color.CYAN:
         $PlayerTextureRect.texture = load("res://Assets/kenney_boardgame-pack/PNG/Pieces (Blue)/pieceBlue_border01.png")
      Color.GREEN:
         $PlayerTextureRect.texture = load("res://Assets/kenney_boardgame-pack/PNG/Pieces (Green)/pieceGreen_border00.png")
      Color.PURPLE:
         $PlayerTextureRect.texture = load("res://Assets/kenney_boardgame-pack/PNG/Pieces (Purple)/piecePurple_border00.png")
      Color.RED:
         $PlayerTextureRect.texture = load("res://Assets/kenney_boardgame-pack/PNG/Pieces (Red)/pieceRed_border00.png")
      Color.YELLOW:
         $PlayerTextureRect.texture = load("res://Assets/kenney_boardgame-pack/PNG/Pieces (Yellow)/pieceYellow_border00.png")
      _:
         assert(false, "Invalid player color provided to PlayerLeaderboardTableRow!")
         
   self.__update_table_values()
         
func update_values(i_num_countries: int, i_num_armies: int, i_num_reinforcements: int, i_num_cards: int) -> void:
   self.num_countries = i_num_countries
   self.num_armies = i_num_armies
   self.num_reinforcements = i_num_reinforcements
   self.num_cards = i_num_cards
   
   self.__update_table_values()
   
func increment_num_cards(increment: int) -> void:
   self.num_cards += increment
   self.__update_table_values()
   
func decrement_num_cards(decrement: int) -> void:
   self.num_cards -= decrement
   self.__update_table_values()
   
func __update_table_values() -> void:
   $NumCountriesLabel.text = self.__format_string_to_length(str(self.num_countries), self.__COLUMN_SPACING)
   $NumArmiesLabel.text = self.__format_string_to_length(str(self.num_armies), self.__COLUMN_SPACING)
   $NumReinforcementsLabel.text = self.__format_string_to_length(str(self.num_reinforcements), self.__COLUMN_SPACING)
   $NumCardsLabel.text = self.__format_string_to_length(str(self.num_cards), self.__COLUMN_SPACING)
   
func __format_string_to_length(string: String, length: int) -> String:
   assert(length > 0, "Invalid length provided to PlayerLeaderBoardTableRow::__format_string_to_length")
   assert(string.length() <= length, "Provided length is less than size of string in PlayerLeaderBoardTableRow::__format_string_to_length")
   
   var prependSpace: bool = true
   while string.length() < length:
      if prependSpace:
         string = " " + string
      else:
         string = string + " "
         
      prependSpace = !prependSpace

   return string
