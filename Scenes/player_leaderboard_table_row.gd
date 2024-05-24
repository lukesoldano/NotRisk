extends HBoxContainer

class_name PlayerLeaderboardTableRow

@export var player_color: Color = Color.WHITE
@export var num_countries: int = 999
@export var num_armies: int = 999
@export var num_reinforcements: int = 999

func set_values(i_player_color: Color, i_num_countries: int, i_num_armies: int, i_num_reinforcements: int) -> void:
   self.player_color = i_player_color
   self.num_countries = i_num_countries
   self.num_armies = i_num_armies
   self.num_reinforcements = i_num_reinforcements
   
   var image = null
   match self.player_color:
      Color.DIM_GRAY:
         image = Image.load_from_file("res://Assets/kenney_boardgame-pack/PNG/Pieces (Black)/pieceBlack_border00.png")
      Color.BLUE:
         image = Image.load_from_file("res://Assets/kenney_boardgame-pack/PNG/Pieces (Blue)/pieceBlue_border01.png")
      Color.GREEN:
         image = Image.load_from_file("res://Assets/kenney_boardgame-pack/PNG/Pieces (Green)/pieceGreen_border00.png")
      Color.PURPLE:
         image = Image.load_from_file("res://Assets/kenney_boardgame-pack/PNG/Pieces (Purple)/piecePurple_border00.png")
      Color.RED:
         image = Image.load_from_file("res://Assets/kenney_boardgame-pack/PNG/Pieces (Red)/pieceRed_border00.png")
      Color.YELLOW:
         image = Image.load_from_file("res://Assets/kenney_boardgame-pack/PNG/Pieces (Yellow)/pieceYellow_border00.png")
      _:
         assert(false, "Invalid player color provided to PlayerLeaderboardTableRow!")
         
   assert(image != null, "Could not load player image!")
   
   $PlayerTextureRect.texture = ImageTexture.create_from_image(image)
         
   $NumCountriesLabel.text = str(self.num_countries)
   $NumArmiesLabel.text = str(self.num_armies)
   $NumReinforcementsLabel.text = str(self.num_reinforcements)
         
func update_values(i_num_countries: int, i_num_armies: int, i_num_reinforcements: int) -> void:
   self.num_countries = i_num_countries
   self.num_armies = i_num_armies
   self.num_reinforcements = i_num_reinforcements
   
   $NumCountriesLabel.text = str(self.num_countries)
   $NumArmiesLabel.text = str(self.num_armies)
   $NumReinforcementsLabel.text = str(self.num_reinforcements)
