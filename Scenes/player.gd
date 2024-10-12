extends Object

class_name Player

enum PlayerType
{
   HUMAN = 0,
   AI = 1
}

var player_id: int = Constants.INVALID_ID
var player_type: PlayerType = PlayerType.HUMAN
var user_name: String = "DEFAULT NAME"
var army_color: Color = Color.WHITE

var player_controller: PlayerController = null

func _init(i_player_id: int, i_player_type: PlayerType, i_user_name: String, i_army_color: Color) -> void:
   self.player_id = i_player_id
   self.player_type = i_player_type
   self.user_name = i_user_name
   self.army_color = i_army_color
   
   match self.player_type:
      PlayerType.HUMAN:
         self.player_controller = null
      PlayerType.AI:
         self.player_controller = PlayerController.new(self.player_id)
      _:
         assert(false, "Invalid player type passed to Player!")
         
func duplicate() -> Player:
   return Player.new(self.player_id, self.player_type, self.user_name, self.army_color)
      
func _to_string() -> String:
   return "Player: [" + str(self.player_id) + ", " + PlayerType.keys()[self.player_type] + ", " + self.user_name + "]"
