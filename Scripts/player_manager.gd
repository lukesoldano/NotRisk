extends Node

########################################################################################################################

signal player_card_update(player_id: int, index: int, card_type: int, added: bool)

# Represents the id of the player who is local to this machine
var __local_player_id: int = 0

# Represents the id of the player who is currently the active player
var __active_player_id: int = 0

# The ids of all players in the turn order they will play in
var __player_ids: Array[int] = [0, 1, 2, 3, 4, 5]

# TODO: Have this initialized elsewhere
# key: PlayerId, value: PLayer
var __players: Dictionary[int, Player] = {
   0 : Player.new(0, Player.PlayerType.HUMAN, "Luke", Constants.SUPPORTED_ARMY_COLORS[5]),
   1 : Player.new(1, Player.PlayerType.AI, "Ben", Constants.SUPPORTED_ARMY_COLORS[0]),
   2 : Player.new(2, Player.PlayerType.AI, "Sam", Constants.SUPPORTED_ARMY_COLORS[1]),
   3 : Player.new(3, Player.PlayerType.AI, "Dennis", Constants.SUPPORTED_ARMY_COLORS[2]),
   4 : Player.new(4, Player.PlayerType.AI, "Austin", Constants.SUPPORTED_ARMY_COLORS[3]),
   5 : Player.new(5, Player.PlayerType.AI, "Mike", Constants.SUPPORTED_ARMY_COLORS[4])
}

# key: PlayerId, value: Array[CardType]
var __player_cards: Dictionary[int, Array] = {}

########################################################################################################################

func _ready():
   # Validate player list
   assert(self.__players.size() >= Constants.MIN_NUM_PLAYERS && self.__players.size() <= Constants.MAX_NUM_PLAYERS, "Invalid player count!")
   assert(self.__players[self.__local_player_id].player_type == Player.PlayerType.HUMAN, "Local player can only be Human!")
   
   # Validate player id uniqueness
   for player_id in self.__player_ids:
      assert(self.__player_ids.count(player_id) == 1, "Repeat player ids specified in __player_ids!")
   
   # Validate color selections
   for player_id in self.__players:
      assert(Constants.SUPPORTED_ARMY_COLORS.has(self.__players[player_id].army_color), "Unsupported army color assigned to player!")
      
   # Initialize cards struct
   for player_id in self.__player_ids:
      self.__player_cards[player_id] = []

func get_local_player_id() -> int:
   return self.__local_player_id
   
func get_active_player_id() -> int:
   return self.__active_player_id
   
func is_local_player_active() -> bool:
   return self.__local_player_id == self.__active_player_id
   
func progress_active_player_to_next_player() -> int:
   for x in self.__player_ids.size():
      if self.__player_ids[x] == self.__active_player_id:
         if x == self.__player_ids.size() - 1:
            self.__active_player_id = self.__player_ids[0]
            return self.__active_player_id
         else:
            self.__active_player_id = self.__player_ids[x+1]
            return self.__active_player_id
         
   assert(false, "Failed to find current active player in player id list!")
   return Constants.INVALID_ID

func get_all_player_ids() -> Array[int]:
   return self.__player_ids.duplicate()
   
func get_active_player() -> Player:
   return self.__players[self.__active_player_id]
   
func get_player_for_id(player_id: int) -> Player:
   assert(player_id != Constants.INVALID_ID, "Invalid player_id passed to PlayerManager::get_player_for_id")
   assert(self.__player_ids.has(player_id), "Unknown player_id provided to PlayerManager::get_player_for_id")
   assert(self.__players.has(player_id), "Unknown player_id provided to PlayerManager::get_player_for_id")
   
   return self.__players[player_id]
   
func get_player_turn_position(i_player_id: int) -> int:
   assert(i_player_id != Constants.INVALID_ID, "Invalid i_player_id passed to PlayerManager::get_player_turn_position")
   assert(self.__player_ids.has(i_player_id), "Unknown i_player_id provided to PlayerManager::get_player_turn_position")
   assert(self.__players.has(i_player_id), "Unknown i_player_id provided to PlayerManager::get_player_turn_position")
   
   var x = 0
   for player_id in self.__player_ids:
      if player_id == i_player_id:
         return x
      x += 1
      
   assert(false, "This should never happen! PlayerManager::get_player_turn_position")
   return -1

func is_player_with_id_knocked_out(player_id: int) -> bool:
   assert(player_id != Constants.INVALID_ID, "Invalid player_id passed to PlayerManager::is_player_with_id_knocked_out")
   assert(self.__player_ids.has(player_id), "Unknown player_id provided to PlayerManager::is_player_with_id_knocked_out")
   assert(self.__players.has(player_id), "Unknown player_id provided to PlayerManager::is_player_with_id_knocked_out")
   
   return self.__player_countries[player_id].size() == 0

func num_players_remaining() -> int:
   var num_players_remaining := 0
   for player_id in self.__player_ids:
      if !self.is_player_with_id_knocked_out(player_id):
         num_players_remaining += 1
      
   assert(num_players_remaining != 0, "Somehow, no players are still remaining in the game")
   
   return num_players_remaining
   
func get_last_remaining_player_id() -> int:
   assert(self.num_players_remaining() == 1, "Can't get last remaining player as there are multiple left!")
   
   for player_id in self.__player_ids:
      if !self.is_player_with_id_knocked_out(player_id):
         return player_id
         
   assert(false, "Could not find the last remaining player!")
   return Constants.INVALID_ID

func get_num_player_cards(player_id: int) -> int:
   assert(player_id != Constants.INVALID_ID, "Invalid player_id passed to PlayerManager::get_num_player_cards")
   assert(self.__player_ids.has(player_id), "Unknown player_id provided to PlayerManager::get_num_player_cards")
   assert(self.__players.has(player_id), "Unknown player_id provided to PlayerManager::get_num_player_cards")
   assert(self.__player_cards.has(player_id), "Unknown player_id provided to PlayerManager::get_num_player_cards")
   
   return self.__player_cards[player_id].size()

func get_player_card_at_index(player_id: int, index: int) -> int:
   assert(player_id != Constants.INVALID_ID, "Invalid player_id passed to PlayerManager::get_player_card_at_index")
   assert(self.__player_ids.has(player_id), "Unknown player_id provided to PlayerManager::get_player_card_at_index")
   assert(self.__players.has(player_id), "Unknown player_id provided to PlayerManager::get_player_card_at_index")
   assert(self.__player_cards.has(player_id), "Unknown player_id provided to PlayerManager::get_player_card_at_index")
   assert(index >= 0 && index < self.__player_cards[player_id].size(), "Invalid index provided to PlayerManager::get_player_card_at_index")
   
   return self.__player_cards[player_id][index]

func add_player_card(player_id: int, card_type: int) -> void:
   assert(player_id != Constants.INVALID_ID, "Invalid player_id passed to PlayerManager::add_player_card")
   assert(self.__player_ids.has(player_id), "Unknown player_id provided to PlayerManager::add_player_card")
   assert(self.__players.has(player_id), "Unknown player_id provided to PlayerManager::add_player_card")
   assert(self.__player_cards.has(player_id), "Unknown player_id provided to PlayerManager::add_player_card")
   assert(self.__player_cards[player_id].size() < Constants.MAX_TERRITORY_CARDS_IN_HAND, "Player already has max cards!")
   assert(card_type >= 0 && card_type < Constants.NUM_TERRITORY_CARD_TYPES, "Invalid card_type provided to PlayerManager::add_player_card")
   
   self.__player_cards[player_id].append(card_type)
   
   self.player_card_update.emit(player_id, self.__player_cards[player_id].size() - 1, card_type, true)

func remove_player_card_at_index(player_id: int, index: int) -> void:
   assert(player_id != Constants.INVALID_ID, "Invalid player_id passed to PlayerManager::remove_player_card_at_index")
   assert(self.__player_ids.has(player_id), "Unknown player_id provided to PlayerManager::remove_player_card_at_index")
   assert(self.__players.has(player_id), "Unknown player_id provided to PlayerManager::remove_player_card_at_index")
   assert(self.__player_cards.has(player_id), "Unknown player_id provided to PlayerManager::remove_player_card_at_index")
   assert(index >= 0 && index < self.__player_cards[player_id].size(), "Invalid index provided to PlayerManager::remove_player_card_at_index")
   
   var CARD_TYPE = self.__player_cards[player_id][index]
   self.__player_cards[player_id].remove_at(index)
   
   self.player_card_update.emit(player_id, index, CARD_TYPE, false)

func player_has_max_cards(player_id: int) -> bool:
   assert(player_id != Constants.INVALID_ID, "Invalid player_id passed to PlayerManager::player_has_max_cards")
   assert(self.__player_ids.has(player_id), "Unknown player_id provided to PlayerManager::player_has_max_cards")
   assert(self.__players.has(player_id), "Unknown player_id provided to PlayerManager::player_has_max_cards")
   assert(self.__player_cards.has(player_id), "Unknown player_id provided to PlayerManager::player_has_max_cards")
   
   return self.__player_cards[player_id].size() >= Constants.MAX_TERRITORY_CARDS_IN_HAND
