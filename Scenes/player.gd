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

func _init(i_player_type: PlayerType, i_user_name: String, i_army_color: Color):
   self.player_type = i_player_type
   self.user_name = i_user_name
   self.army_color = i_army_color
      
func _to_string() -> String:
   return "Player: [" + PlayerType.keys()[player_type] + ", " + user_name + "]"
