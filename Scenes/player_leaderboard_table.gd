extends Control

class_name PlayerLeaderboardTable

var __entries: Array[PlayerLeaderboardTableRow] = []

func add_entry(player_color: Color, num_countries: int, num_armies: int, num_reinforcements: int, num_cards: int) -> void:
   assert(self.__entries.size() < Constants.MAX_NUM_PLAYERS, "Table already at max_num_players capacity!")
   
   var entry: PlayerLeaderboardTableRow = preload("res://Scenes/player_leaderboard_table_row.tscn").instantiate() as PlayerLeaderboardTableRow
   self.__entries.append(entry)
   $TableRowsMarginContainer/VBoxContainer.add_child(entry)
   entry.set_values(player_color, num_countries, num_armies, num_reinforcements, num_cards)
   
func update_entry(index: int, num_countries: int, num_armies: int, num_reinforcements: int, num_cards: int) -> void:
   assert(index < self.__entries.size(), "Invalid index, out of bounds of table")
   
   self.__entries[index].update_values(num_countries, num_armies, num_reinforcements, num_cards)
