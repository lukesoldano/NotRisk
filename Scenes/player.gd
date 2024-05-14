extends Node2D

class_name Player

enum PlayerType
{
   HUMAN = 0,
   AI = 1
}

var player_type: PlayerType = PlayerType.HUMAN
var user_name: String = "DEFAULT NAME"
var army_color: Color = Color.WHITE

var player_controller: PlayerController = null

func _init(i_player_type: PlayerType, i_user_name: String, i_army_color: Color) -> void:
   self.player_type = i_player_type
   self.user_name = i_user_name
   self.army_color = i_army_color
   
   match self.player_type:
      PlayerType.HUMAN:
         self.player_controller = null
      PlayerType.AI:
         self.player_controller = PlayerController.new(self)
      _:
         assert(false, "Invalid player type passed to Player!")
      
func _to_string() -> String:
   return "Player: [" + PlayerType.keys()[player_type] + ", " + user_name + "]"
