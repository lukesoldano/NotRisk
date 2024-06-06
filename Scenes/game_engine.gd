@icon("res://Assets/NodeIcons/GameEngine.svg")

extends Node

class_name GameEngine

########################################################################################################################
# TODO: Short Term
#
# TODO: It probably makes sense for PlayerTurnStateMachine to be internal to the InProgress state of GameStateMachine (ponder this)
# TODO: Rename next_phase_requested to be specific to player turn phase and all player turn state machine fns/vars that are named generally
# TODO: Prevent next phase from showing while any popups are active
# TODO: State machine/other solution for winning game or being knocked out
# TODO: Playing cards subphase of reinforce
# TODO: Logic to give user a card if countries captured > 0
# TODO: Give conquering player losers cards if loser knocked out of game
# TODO: If upon conquering, player has 5+ cards, send them back to reinforce stage
# TODO: Change name of __player_occupations member to something that doesn't clash with other definition of the term "occupation"
# TODO: Potentially rework terminology and types of occupations/deployments overall as it is not as simple as it could be at first glance
#
# TODO: Long Term
#
# TODO: Have GameEngine be initialized elsewhere instead of being filled with a dummy player list
# TODO: Make country type agnostic such that only GameBoard is aware (not an enum- maybe a string instead, figure out later), allows for different GameBoards/maps
# TODO: Add other victory conditions
# 
########################################################################################################################

signal turn_phase_updated(player: Player, phase: TurnPhase)

@export var __ai_delay_enabled = false
@export var __deploy_screen_ai_delay := 1
@export var __attack_screen_ai_delay := 2
@export var __victory_screen_ai_delay := 2

# Needed for signal output to UI
enum TurnPhase
{
   START = 0,
   DEPLOY = 1,
   ATTACK = 2,
   REINFORCE = 3,
   END = 4
}

# Needed for signal output to UI
enum DeployTurnSubPhase
{
   IDLE = 0,
   PLAYING_CARDS = 1,
   DEPLOYING = 2
}

# Needed for signal output to UI
enum AttackTurnSubPhase
{
   IDLE = 0,
   SOURCE_SELECTED = 1,
   DESTINATION_SELECTED = 2,
   ROLLING = 3,
   VICTORY = 4,
   OPPONENT_KNOCKED_OUT = 5
}

# Needed for signal output to UI
enum ReinforceTurnSubPhase
{
   IDLE = 0,
   SOURCE_SELECTED = 1,
   DESTINATION_SELECTED = 2
}

enum TroopMovementType
{
   POST_VICTORY = 0,
   REINFORCE = 1
}

const __DEPLOYMENT_LOGGING_ENABLED = false

var __local_player_index: int = 5
var __active_player_index: int = 0
var __active_turn_phase: TurnPhase = TurnPhase.START

var __players: Array[Player] = [
   Player.new(Player.PlayerType.AI, "Ben", Constants.SUPPORTED_ARMY_COLORS[0]),
   Player.new(Player.PlayerType.AI, "Sam", Constants.SUPPORTED_ARMY_COLORS[1]),
   Player.new(Player.PlayerType.AI, "Dennis", Constants.SUPPORTED_ARMY_COLORS[2]),
   Player.new(Player.PlayerType.AI, "Austin", Constants.SUPPORTED_ARMY_COLORS[3]),
   Player.new(Player.PlayerType.AI, "Mike", Constants.SUPPORTED_ARMY_COLORS[4]),
   Player.new(Player.PlayerType.HUMAN, "Luke", Constants.SUPPORTED_ARMY_COLORS[5])
]

var __player_cards: Dictionary = {}
var __player_occupations: Dictionary = {}
var __deployments: Dictionary = {}

# State machine metadata
const __SOURCE_COUNTRY_KEY = "src"
const __DESTINATION_COUNTRY_KEY = "dest"
const __NUM_UNITS_KEY = "troop_count"
const __REINFORCEMENTS_REMAINING_KEY = "reinforcements_remaining"
const __NUM_ATTACKER_DICE_KEY = "num_attack_dice"
const __NUM_DEFENDER_DICE_KEY = "num_defense_dice"
const __NUM_TROOPS_TO_MOVE_KEY = "num_troops_to_move"
const __NUM_REINFORCE_MOVEMENTS_UTILIZED = "num_reinforces_utilized"
const __COUNTRIES_CONQUERED_KEY = "countries_counquered"
const __KNOCKED_OUT_PLAYER = "knocked_out_player"
var __state_machine_metadata: Dictionary = {}

#func _init(players: Array[Player]):
   #self.__players = players

func _ready():
   # Validate player list
   assert(self.__players.size() >= Constants.MIN_NUM_PLAYERS && self.__players.size() <= Constants.MAX_NUM_PLAYERS, "Invalid player count!")
   assert(self.__players[self.__local_player_index].player_type == Player.PlayerType.HUMAN, "Local player can only be Human!")
   
   # Validate color selections
   for player in self.__players:
      assert(Constants.SUPPORTED_ARMY_COLORS.has(player.army_color), "Unsupported army color assigned to player!")
   
   # Assign players to cards dictionary
   for player in self.__players:
      self.__player_cards[player] = []
   
   self.__generate_random_deployments()
   self.__log_deployments()
   $GameBoard.populate(self.__deployments)
   $GameBoardHUD.initialize_player_leaderboard_table(self.__players, self.__deployments)
   
   self.connect("turn_phase_updated", $GameBoard._on_turn_phase_updated)
   $GameBoard.connect("next_phase_requested", self._on_next_phase_requested)
    
########################################################################################################################
## Game State Machine Logic ############################################################################################ Start Game State Machine Logic     
########################################################################################################################

## Start Phase ######################################################################################################### Start Phase
func _on_game_start_state_entered():
   Logger.log_message("GAME STARTED")
   $GameStateMachine.send_event("StartToInProgress")

## In Progress Phase ################################################################################################### In Progress Phase
func _on_game_in_progress_state_entered():
   Logger.log_message("GAME IN PROGRESS")

## End Phase ########################################################################################################### End Phase
func _on_game_end_state_entered():
   Logger.log_message("GAME ENDED")
   
   # Determine if victory goes to last remaining player or player with most countries
   var victor: Player
   if self.__num_players_remaining() == 1:
      victor = self.__get_last_remaining_player()
   else:
      # TODO: Add other victory conditions in case a game is quit before there is only one player left
      pass
      
   # TODO: Remove
   $GameBoardHUD.show_debug_label("Player: " + str(victor) + " is victorious!!!")
   #
   
########################################################################################################################
######################################################################################################################## End Game State Machine Logic    
########################################################################################################################
   
########################################################################################################################
## Player Turn State Machine Logic ##################################################################################### Start Player Turn State Machine Logic     
########################################################################################################################

# Clears all state machine metadata that shouldn't persist between phases of a turn
func __clear_interphase_state_machine_metadata():
   var countries_conquered: int = 0
   if self.__state_machine_metadata.has(self.__COUNTRIES_CONQUERED_KEY):
      countries_conquered = self.__state_machine_metadata[self.__COUNTRIES_CONQUERED_KEY]
      
   self.__state_machine_metadata.clear()
   self.__state_machine_metadata[self.__COUNTRIES_CONQUERED_KEY] = countries_conquered

func _on_next_phase_requested() -> void:
   if self.__local_player_index != self.__active_player_index:
      return
   
   match self.__active_turn_phase:
      TurnPhase.START:
         $PlayerTurnStateMachine.send_event("StartToDeploy")
         
      TurnPhase.DEPLOY:
         assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
         
         var REINFORCEMENTS_REMAINING: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
         if REINFORCEMENTS_REMAINING != 0:
            Logger.log_error("_on_next_phase_requested: Local player requested next phase from deploy phase, but reinforcements remaining: " + 
                             str(REINFORCEMENTS_REMAINING) + 
                             " does not equal zero")
            return
            
         $PlayerTurnStateMachine.send_event("DeployToAttack")
         
      TurnPhase.ATTACK:
         $PlayerTurnStateMachine.send_event("AttackToReinforce")
      TurnPhase.REINFORCE:
         $PlayerTurnStateMachine.send_event("ReinforceToEnd")
      TurnPhase.END:
         $PlayerTurnStateMachine.send_event("EndToStart")
      _:
         assert(false, "Invalid active turn phase!")

## Start Phase ######################################################################################################### Start Phase
func _on_start_state_entered() -> void:
   self.__active_turn_phase = TurnPhase.START
   
   # CLEAR ALL METADATA as we are entering a new player's turn
   self.__state_machine_metadata.clear()
   
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   $PlayerTurnStateMachine.send_event("StartToDeploy")

## Deploy Phase ######################################################################################################## Deploy Phase
func _on_deploy_state_entered() -> void:
   self.__active_turn_phase = TurnPhase.DEPLOY
   self.__clear_interphase_state_machine_metadata()
   
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY] = Utilities.get_num_reinforcements_earned($GameBoard.CONTINENTS, 
                                                                                                                $GameBoard.CONTINENT_BONUSES, 
                                                                                                                self.__player_occupations[self.__players[self.__active_player_index]])
   
   $GameBoardHUD.show_deploy_reinforcements_remaining(self.__players[self.__active_player_index], self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   
   var player = self.__players[self.__active_player_index]
   if player.player_controller != null:
      player.player_controller.determine_desired_deployments(self.__player_occupations, 
                                                             self.__deployments, 
                                                             self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY])
   
func _on_deploy_state_exited() -> void:
   $GameBoardHUD.hide_deploy_reinforcements_remaining()
   
## Deploy (Idle) Subphase ############################################################################################## Deploy (Idle) Subphase
func _on_deploy_idle_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + DeployTurnSubPhase.keys()[DeployTurnSubPhase.IDLE] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_deploy_idle_country_clicked)
      
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = self.__players[self.__active_player_index]
   if player.player_controller != null:
      if !player.player_controller.handle_deploy_state_idle(self.__deploy_select_country):
         $PlayerTurnStateMachine.send_event("DeployToAttack")
   
func _on_deploy_idle_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.disconnect("country_clicked", self._on_deploy_idle_country_clicked)
      
func _on_deploy_idle_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_deploy_idle_country_clicked( " + Types.Country.keys()[country] + ", " + action_tag + " )")
   self.__deploy_select_country(country)
   
func __deploy_select_country(country: Types.Country):
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   
   var REINFORCEMENTS_REMAINING: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
   
   if !self.__player_occupations[self.__players[self.__active_player_index]].has(country):
      Logger.log_error("DeployIdle: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not own it")
      assert(self.__active_player_index == self.__local_player_index, 
             "Non-local player selected a country to deploy to that they do not own!")
      return
   
   if REINFORCEMENTS_REMAINING <= 0:
      Logger.log_error("DeployIdle: Player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not have any reinforcements remaining")
      assert(self.__active_player_index == self.__local_player_index, 
             "Non-local player selected a country to deploy to without any remaining reinforcements!")
      return
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("IdleToDeploying")
   
## Deploy (Deploying) Subphase ######################################################################################### Deploy (Deploying) Subphase
func _on_deploy_deploying_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + DeployTurnSubPhase.keys()[DeployTurnSubPhase.DEPLOYING] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
   
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Deploy country not set previously!")
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   
   var DEPLOY_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   var REINFORCEMENTS_REMAINING: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
                    
   if self.__active_player_index == self.__local_player_index:
      $GameBoardHUD.connect("deploy_cancel_requested", self._on_deploy_cancel_requested)
      $GameBoardHUD.connect("deploy_confirm_requested", self._on_deploy_confirm_requested)
      $GameBoardHUD.connect("deploy_troop_count_change_requested", self._on_deploy_troop_count_change_requested)
      
   self.__state_machine_metadata[self.__NUM_UNITS_KEY] = REINFORCEMENTS_REMAINING
      
   $GameBoardHUD.show_deploy_popup(self.__active_player_index == self.__local_player_index, 
                                   self.__players[self.__active_player_index], 
                                   DEPLOY_COUNTRY, 
                                   REINFORCEMENTS_REMAINING, 
                                   REINFORCEMENTS_REMAINING)
                                 
   # If player is being controlled by AI, tell AI to make a move
   var player = self.__players[self.__active_player_index]
   if player.player_controller != null:
      player.player_controller.handle_deploy_state_deploying(self.__deploy_set_troop_count_and_confirm, DEPLOY_COUNTRY)

func _on_deploy_deploying_state_exited() -> void:
   if self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY):
      self.__state_machine_metadata.erase(self.__DESTINATION_COUNTRY_KEY)
      
   if self.__state_machine_metadata.has(self.__NUM_UNITS_KEY):
      self.__state_machine_metadata.erase(self.__NUM_UNITS_KEY)
   
   if self.__active_player_index == self.__local_player_index:
      $GameBoardHUD.disconnect("deploy_cancel_requested", self._on_deploy_cancel_requested)
      $GameBoardHUD.disconnect("deploy_confirm_requested", self._on_deploy_confirm_requested)
      $GameBoardHUD.disconnect("deploy_troop_count_change_requested", self._on_deploy_troop_count_change_requested)
      
   $GameBoardHUD.hide_deploy_popup()
   
func _on_deploy_deploying_state_input(event: InputEvent) -> void:
   if self.__active_player_index == self.__local_player_index and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         $PlayerTurnStateMachine.send_event("DeployingToIdle")
         
func _on_deploy_cancel_requested() -> void:
   $PlayerTurnStateMachine.send_event("DeployingToIdle")
   
func _on_deploy_confirm_requested() -> void:
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Deploy country not set previously!")
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_UNITS_KEY), "Deploy troop count not set previously!")
   
   var reinforcements_remaining: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
   var DEPLOY_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   var UNITS_TO_DEPLOY: int = self.__state_machine_metadata[self.__NUM_UNITS_KEY]
   
   assert(reinforcements_remaining >= UNITS_TO_DEPLOY, "More units to be deployed than reinforcements remaining!")
   
   reinforcements_remaining -= UNITS_TO_DEPLOY
   
   self.__deployments[DEPLOY_COUNTRY].troop_count += UNITS_TO_DEPLOY
   $GameBoard.set_country_deployment(DEPLOY_COUNTRY, self.__deployments[DEPLOY_COUNTRY])
   
   self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY] = reinforcements_remaining
   
   $GameBoardHUD.show_deploy_reinforcements_remaining(self.__players[self.__active_player_index], reinforcements_remaining)
   
   Logger.log_message("Deploying: " + 
                      str(UNITS_TO_DEPLOY) + 
                      " troops to: " + 
                      Types.Country.keys()[DEPLOY_COUNTRY] +
                      ", Reinforcements remaining: " + 
                      str(reinforcements_remaining))
   
   $PlayerTurnStateMachine.send_event("DeployingToIdle")
   
func _on_deploy_troop_count_change_requested(old_troop_count: int, new_troop_count: int) -> void:
   if old_troop_count == new_troop_count or new_troop_count == 0:
      return
   
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Deploy country not set previously!")
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_UNITS_KEY), "Deploy troop count not set previously!")
   
   var DEPLOY_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   var REINFORCEMENTS_REMAINING: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
   var UNITS_TO_DEPLOY: int = self.__state_machine_metadata[self.__NUM_UNITS_KEY]
   
   if UNITS_TO_DEPLOY == new_troop_count:
      return
      
   if REINFORCEMENTS_REMAINING < new_troop_count:
      Logger.log_error("DeployTroopCountChangeRequested: New troop count: " + 
                       str(new_troop_count) + 
                       " is greater than reinforcements remaining: " +
                       str(REINFORCEMENTS_REMAINING))
      assert(self.__active_player_index == self.__local_player_index, 
             "Non-local player selected a deployment count higher than their available reinforcements!")
      return
      
   self.__state_machine_metadata[self.__NUM_UNITS_KEY] = new_troop_count
   
   $GameBoardHUD.show_deploy_popup(self.__active_player_index == self.__local_player_index, 
                                   self.__players[self.__active_player_index], 
                                   DEPLOY_COUNTRY, 
                                   new_troop_count, 
                                   REINFORCEMENTS_REMAINING)
                                 
func __deploy_set_troop_count_and_confirm(troop_count: int):
   assert(self.__state_machine_metadata.has(self.__NUM_UNITS_KEY), "Deploy troop count not set previously!")
   
   self._on_deploy_troop_count_change_requested(self.__state_machine_metadata[self.__NUM_UNITS_KEY], troop_count)
   # Add delay if player is being controlled by AI
   if self.__ai_delay_enabled and self.__players[self.__active_player_index].player_controller != null:
      var ai_delay_timer := Types.StartAndForgetTimer.new(self._on_deploy_confirm_requested)
      ai_delay_timer.name = "AiDelayTimer"
      self.add_child(ai_delay_timer)
      ai_delay_timer.start(self.__deploy_screen_ai_delay)
   else:
      self._on_deploy_confirm_requested()
   
## Attack Phase ######################################################################################################## Attack Phase
func _on_attack_state_entered() -> void:
   self.__active_turn_phase = TurnPhase.ATTACK
   self.__clear_interphase_state_machine_metadata()
   
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   
## Attack (Idle) Subphase ############################################################################################## Attack (Idle) Subphase
func _on_attack_idle_state_entered() -> void:
   self.__clear_interphase_state_machine_metadata()
   
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + AttackTurnSubPhase.keys()[AttackTurnSubPhase.IDLE] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_attack_source_country_clicked)
      
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = self.__players[self.__active_player_index]
   if player.player_controller != null:
      if !player.player_controller.handle_attack_state_idle(self.__attack_select_source_country, 
                                                            $GameBoard.get_countries_that_neighbor, 
                                                            self.__player_occupations, 
                                                            self.__deployments):
         $PlayerTurnStateMachine.send_event("AttackToReinforce")
   
func _on_attack_idle_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.disconnect("country_clicked", self._on_attack_source_country_clicked)
   
func _on_attack_source_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_attack_source_country_selected( " + Types.Country.keys()[country] + ", " + action_tag + " )")
   
   if self.__active_player_index != self.__local_player_index:
      Logger.log_error("AttackIdle: Local player selected country, but it is not their turn")
      return
      
   self.__attack_select_source_country(country)
   
func __attack_select_source_country(country: Types.Country) -> void:
   if !self.__player_occupations[self.__players[self.__active_player_index]].has(country):
      Logger.log_error("AttackIdle: Player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not own it")
      assert(self.__active_player_index == self.__local_player_index, 
             "Non-local player selected a country to attack from that they do not own!")
      return
   
   if self.__deployments[country].troop_count < 2:
      Logger.log_error("AttackIdle: Player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not have enough attackers")
      assert(self.__active_player_index == self.__local_player_index, 
             "Non-local player selected a country to attack from without enough attackers available!")
      return
      
   self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("IdleToSourceSelected")
   
## Attack (Source Selected) Subphase ################################################################################### Attack (Source Selected) Subphase
func _on_attack_source_selected_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + AttackTurnSubPhase.keys()[AttackTurnSubPhase.SOURCE_SELECTED] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_attack_source_selected_country_clicked)
      
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = self.__players[self.__active_player_index]
   if player.player_controller != null:
      player.player_controller.handle_attack_state_source_selected(self.__attack_select_destination_country, 
                                                                   $GameBoard.get_countries_that_neighbor, 
                                                                   self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY],
                                                                   self.__player_occupations, 
                                                                   self.__deployments)

func _on_attack_source_selected_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.disconnect("country_clicked", self._on_attack_source_selected_country_clicked)
   
func _on_attack_source_selected_state_input(event: InputEvent) -> void:
   if self.__active_player_index == self.__local_player_index and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         $PlayerTurnStateMachine.send_event("SourceSelectedToIdle")
   
func _on_attack_source_selected_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_attack_destination_country_selected( " + Types.Country.keys()[country] + ", " + action_tag + " )")
   
   if self.__active_player_index != self.__local_player_index:
      Logger.log_error("AttackSourceSelected: Local player selected country, but it is not their turn")
      return
      
   self.__attack_select_destination_country(country)
   
func __attack_select_destination_country(country: Types.Country) -> void:
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   
   var SOURCE_COUNTRY = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   
   if self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY):
      self.__state_machine_metadata.erase(self.__DESTINATION_COUNTRY_KEY)
      
   if self.__player_occupations[self.__players[self.__active_player_index]].has(country):
      Logger.log_error("AttackSourceSelected: Player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do already own it")
      assert(self.__active_player_index == self.__local_player_index, 
             "Non-local player selected a country to attack that they already own!")
      return
      
   if !$GameBoard.countries_are_neighbors(SOURCE_COUNTRY, country):
      Logger.log_error("AttackSourceSelected: Player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but it does not neighbor: " +
                       Types.Country.keys()[SOURCE_COUNTRY])
      assert(self.__active_player_index == self.__local_player_index, 
             "Non-local player selected a country to attack that does not border their source country!")
      return
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("SourceSelectedToDestinationSelected")
   
## Attack (Destination Selected) Subphase ############################################################################## Attack (Destination Selected) Subphase
func _on_attack_destination_selected_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + AttackTurnSubPhase.keys()[AttackTurnSubPhase.DESTINATION_SELECTED] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var ATTACKING_OCCUPATION = Types.Occupation.new(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY])
   var DEFENDING_OCCUPATION = Types.Occupation.new(DEFENDING_COUNTRY, self.__deployments[DEFENDING_COUNTRY])
              
   if self.__active_player_index == self.__local_player_index:       
      $GameBoardHUD.connect("attack_quit_requested", self._on_attack_destination_selected_quit_requested)
      $GameBoardHUD.connect("attack_roll_requested", self._on_attack_destination_selected_roll_requested)
      $GameBoardHUD.connect("attack_die_count_change_requested", self._on_attack_destination_selected_die_count_change_requested)
      
   # Max out attacker and defender dice until user says otherwise
   var max_attacker_die_count = Utilities.get_max_attacker_die_count_for_troop_count(ATTACKING_OCCUPATION.deployment.troop_count)
   var max_defender_die_count = Utilities.get_max_defender_die_count_for_troop_count(DEFENDING_OCCUPATION.deployment.troop_count)
      
   if !self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY) or self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY] > max_attacker_die_count:
      self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY] = max_attacker_die_count
   
   if !self.__state_machine_metadata.has(self.__NUM_DEFENDER_DICE_KEY) or self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY] > max_defender_die_count:
      self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY] = max_defender_die_count
   
   $GameBoardHUD.show_attack_popup(self.__active_player_index == self.__local_player_index, 
                                   ATTACKING_OCCUPATION, 
                                   DEFENDING_OCCUPATION, 
                                   self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY],
                                   max_attacker_die_count, 
                                   self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY])
                                 
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = self.__players[self.__active_player_index]
   if player.player_controller != null:
      player.player_controller.handle_attack_state_destination_selected(self.__attack_set_die_count_and_roll, 
                                                                        ATTACKING_COUNTRY,
                                                                        DEFENDING_COUNTRY,
                                                                        self.__player_occupations, 
                                                                        self.__deployments)

func _on_attack_destination_selected_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoardHUD.disconnect("attack_quit_requested", self._on_attack_destination_selected_quit_requested)
      $GameBoardHUD.disconnect("attack_roll_requested", self._on_attack_destination_selected_roll_requested)
      $GameBoardHUD.disconnect("attack_die_count_change_requested", self._on_attack_destination_selected_die_count_change_requested)
      
      if $GameBoardHUD.is_attack_popup_showing():
         $GameBoardHUD.show_troop_movement_user_inputs(false)

func _on_attack_destination_selected_state_input(event) -> void:
   if self.__active_player_index == self.__local_player_index and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         self._on_attack_destination_selected_quit_requested()
         
func _on_attack_destination_selected_quit_requested() -> void:
   $GameBoardHUD.hide_attack_popup()
   $PlayerTurnStateMachine.send_event("DestinationSelectedToSourceSelected")
   
func _on_attack_destination_selected_roll_requested() -> void:
   $PlayerTurnStateMachine.send_event("DestinationSelectedToRolling")
   
func _on_attack_destination_selected_die_count_change_requested(old_num_dice: int, new_num_dice: int) -> void:
   if old_num_dice == new_num_dice or new_num_dice < 1 or new_num_dice > Constants.MAX_NUM_ATTACK_DIE:
      return
   
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var NUM_ATTACKER_DICE: int = self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY]
   
   var ATTACKING_OCCUPATION = Types.Occupation.new(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY])
   
   if NUM_ATTACKER_DICE == new_num_dice:
      return
   
   var MAX_DIE_COUNT = Utilities.get_max_attacker_die_count_for_troop_count(ATTACKING_OCCUPATION.deployment.troop_count)
   if new_num_dice < old_num_dice or MAX_DIE_COUNT >= new_num_dice:
      self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY] = new_num_dice
      $GameBoardHUD.update_attack_die_count(new_num_dice, MAX_DIE_COUNT) 
      
func __attack_set_die_count_and_roll(die_count: int):
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   
   self._on_attack_destination_selected_die_count_change_requested(self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY], die_count)
   
   # Add delay if player is being controlled by AI
   if self.__ai_delay_enabled and self.__players[self.__active_player_index].player_controller != null:
      var ai_delay_timer := Types.StartAndForgetTimer.new(self._on_attack_destination_selected_roll_requested)
      ai_delay_timer.name = "AiDelayTimer"
      self.add_child(ai_delay_timer)
      ai_delay_timer.start(self.__attack_screen_ai_delay)
   else:
      self._on_attack_destination_selected_roll_requested()
   
## Attack (Rolling) Subphase ########################################################################################### Attack (Rolling) Subphase
func _on_attack_rolling_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + AttackTurnSubPhase.keys()[AttackTurnSubPhase.ROLLING] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_DEFENDER_DICE_KEY), "Num defender dice not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_ATTACKER_DICE: int = self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY]
   var NUM_DEFENDER_DICE: int = self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY]
   
   Logger.log_message(str(self.__players[self.__active_player_index]) +
                      " rolling from: " +
                      Types.Country.keys()[ATTACKING_COUNTRY] +
                      " with: " +
                      str(NUM_ATTACKER_DICE) +
                      " dice, against Player: " +
                      self.__deployments[DEFENDING_COUNTRY].player.user_name +
                      " who occupies: " +
                      Types.Country.keys()[DEFENDING_COUNTRY] +
                      " and is rolling with: " +
                      str(NUM_DEFENDER_DICE) +
                      " dice")
   
   var attacker_rolls: Array[int] = []
   var defender_rolls: Array[int] = []
   
   for x in NUM_ATTACKER_DICE:
      attacker_rolls.append((randi() % 6) + 1)
   for x in NUM_DEFENDER_DICE:
      defender_rolls.append((randi() % 6) + 1)
      
   attacker_rolls.sort_custom(func(a, b): return a > b)
   defender_rolls.sort_custom(func(a, b): return a > b)
   
   # Create strings after sort, as the sorted array is used by index for battles
   var attacker_rolls_str: String = ""
   var defender_rolls_str: String = ""
   
   for x in NUM_ATTACKER_DICE:
      attacker_rolls_str += str(attacker_rolls[x]) + " "
   for x in NUM_DEFENDER_DICE:
      defender_rolls_str += str(defender_rolls[x]) + " "
   
   var attacking_units_lost = 0
   var defending_units_lost = 0
   
   for roll in (NUM_DEFENDER_DICE if NUM_DEFENDER_DICE <= NUM_ATTACKER_DICE else NUM_ATTACKER_DICE):
      if defender_rolls[roll] >= attacker_rolls[roll]:
         attacking_units_lost += 1
      else:
         defending_units_lost += 1
         
   if attacking_units_lost > 0:
      self.__deployments[ATTACKING_COUNTRY].troop_count -= attacking_units_lost
      $GameBoard.set_country_deployment(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY])
      
   if defending_units_lost > 0:
      self.__deployments[DEFENDING_COUNTRY].troop_count -= defending_units_lost
      $GameBoard.set_country_deployment(DEFENDING_COUNTRY, self.__deployments[DEFENDING_COUNTRY])
      
   $GameBoardHUD.set_die_rolls(attacker_rolls, defender_rolls)
      
   Logger.log_message("Attacker rolled: " + 
                      attacker_rolls_str + 
                      "Defender rolled: " + 
                      defender_rolls_str + 
                      "Attacker lost: " + 
                      str(attacking_units_lost) + 
                      " units, Defender lost: " +
                      str(defending_units_lost) +
                      " units")
      
   # Check if no attackers left
   if self.__deployments[ATTACKING_COUNTRY].troop_count <= 1:
      $GameBoardHUD.hide_attack_popup()
      $PlayerTurnStateMachine.send_event("RollingToIdle")
   elif self.__deployments[DEFENDING_COUNTRY].troop_count <= 0:
      $GameBoardHUD.hide_attack_popup()
      $PlayerTurnStateMachine.send_event("RollingToVictory")
   else:
      $PlayerTurnStateMachine.send_event("RollingToDestinationSelected")
      
## Attack (Victory) Subphase ########################################################################################### Attack (Victory) Subphase
func _on_attack_victory_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + AttackTurnSubPhase.keys()[AttackTurnSubPhase.VICTORY] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_ATTACKER_DICE: int = self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY]
   
   self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY] = NUM_ATTACKER_DICE
   
   if self.__state_machine_metadata.has(self.__COUNTRIES_CONQUERED_KEY):
      self.__state_machine_metadata[self.__COUNTRIES_CONQUERED_KEY] += 1
   else:
      self.__state_machine_metadata[self.__COUNTRIES_CONQUERED_KEY] = 1
      
   # Only show popup if there is a choice to be made, otherwise just auto redeploy troops
   if self.__deployments[ATTACKING_COUNTRY].troop_count > (NUM_ATTACKER_DICE + 1):
      if self.__active_player_index == self.__local_player_index:
         $GameBoardHUD.connect("troop_movement_troop_count_change_requested", self._on_attack_victory_troop_count_change_requested)
         $GameBoardHUD.connect("troop_movement_confirm_requested", self._on_attack_victory_troop_movement_confirm_requested)
         
      $GameBoardHUD.show_troop_movement_popup(self.__active_player_index == self.__local_player_index, 
                                              TroopMovementType.POST_VICTORY,
                                              Types.Occupation.new(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY]), 
                                              DEFENDING_COUNTRY, 
                                              NUM_ATTACKER_DICE,
                                              NUM_ATTACKER_DICE,
                                              self.__deployments[ATTACKING_COUNTRY].troop_count - 1)
                                             
      # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
      var player = self.__players[self.__active_player_index]
      if player.player_controller != null:
         player.player_controller.handle_attack_state_victory(self.__attack_victory_set_troop_count_and_confirm, 
                                                              ATTACKING_COUNTRY,
                                                              DEFENDING_COUNTRY,
                                                              self.__player_occupations, 
                                                              self.__deployments)
                                                                        
   else:
      self._on_attack_victory_troop_movement_confirm_requested()
   
func _on_attack_victory_state_exited() -> void:
   if $GameBoardHUD.is_troop_movement_popup_showing():
      $GameBoardHUD.hide_troop_movement_popup()
      if self.__active_player_index == self.__local_player_index:
            $GameBoardHUD.disconnect("troop_movement_troop_count_change_requested", self._on_attack_victory_troop_count_change_requested)
            $GameBoardHUD.disconnect("troop_movement_confirm_requested", self._on_attack_victory_troop_movement_confirm_requested)
   
func _on_attack_victory_troop_count_change_requested(old_troop_count: int, new_troop_count: int) -> void:
   if old_troop_count == new_troop_count or new_troop_count < 1:
      return
   
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_ATTACKER_DICE: int = self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY]
   
   if new_troop_count < NUM_ATTACKER_DICE or new_troop_count > (self.__deployments[ATTACKING_COUNTRY].troop_count - 1):
      return
      
   self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY] = new_troop_count
   
   $GameBoardHUD.show_troop_movement_popup(self.__active_player_index == self.__local_player_index,
                                           TroopMovementType.POST_VICTORY,
                                           Types.Occupation.new(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY]), 
                                           DEFENDING_COUNTRY, 
                                           new_troop_count,
                                           NUM_ATTACKER_DICE,
                                           self.__deployments[ATTACKING_COUNTRY].troop_count - 1)
   
func _on_attack_victory_troop_movement_confirm_requested() -> void:
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   
   var DEFENDING_PLAYER = self.__deployments[self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]].player
   
   self.__attack_victory_move_conquering_armies()
   
   if self.__is_player_knocked_out(DEFENDING_PLAYER):
      self.__state_machine_metadata[self.__KNOCKED_OUT_PLAYER] = DEFENDING_PLAYER
      $PlayerTurnStateMachine.send_event("VictoryToOpponentKnockedOut")
   else:
      $PlayerTurnStateMachine.send_event("VictoryToIdle")
   
func __attack_victory_move_conquering_armies():
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_TROOPS_TO_MOVE_KEY), "Num attackers to move not set previously")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_ATTACKERS_TO_MOVE: int = self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY]
   
   var ATTACKING_PLAYER = self.__players[self.__active_player_index]
   
   self.__player_occupations[ATTACKING_PLAYER].append(DEFENDING_COUNTRY)
   self.__player_occupations[self.__deployments[DEFENDING_COUNTRY].player].erase(DEFENDING_COUNTRY)
   
   self.__deployments[ATTACKING_COUNTRY].troop_count -= NUM_ATTACKERS_TO_MOVE
   self.__deployments[DEFENDING_COUNTRY].player = ATTACKING_PLAYER
   self.__deployments[DEFENDING_COUNTRY].troop_count = NUM_ATTACKERS_TO_MOVE
   
   $GameBoard.set_country_deployment(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY])
   $GameBoard.set_country_deployment(DEFENDING_COUNTRY, self.__deployments[DEFENDING_COUNTRY])
   
func __attack_victory_set_troop_count_and_confirm(troop_count: int) -> void:
   assert(self.__state_machine_metadata.has(self.__NUM_TROOPS_TO_MOVE_KEY), "Num attackers to move not set previously")
   
   self._on_attack_victory_troop_count_change_requested(self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY], troop_count)
   
   # Add delay if player is being controlled by AI
   if self.__ai_delay_enabled and self.__players[self.__active_player_index].player_controller != null:
      var ai_delay_timer := Types.StartAndForgetTimer.new(self._on_attack_victory_troop_movement_confirm_requested)
      ai_delay_timer.name = "AiDelayTimer"
      self.add_child(ai_delay_timer)
      ai_delay_timer.start(self.__victory_screen_ai_delay)
   else:
      self._on_attack_victory_troop_movement_confirm_requested()
      
## Attack (Victory) Subphase ########################################################################################### Attack (Victory) Subphase
func _on_attack_opponent_knocked_out_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + AttackTurnSubPhase.keys()[AttackTurnSubPhase.OPPONENT_KNOCKED_OUT] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   assert(self.__state_machine_metadata.has(self.__KNOCKED_OUT_PLAYER), "Knocked out player was not set previously")
   
   var KNOCKED_OUT_PLAYER: Player = self.__state_machine_metadata[self.__KNOCKED_OUT_PLAYER]
                     
   Logger.log_message("Player: " + str(KNOCKED_OUT_PLAYER) + " was knocked out!")
   
   # TODO: Remove
   $GameBoardHUD.show_debug_label("Player: " + str(KNOCKED_OUT_PLAYER) + " was knocked out!")
   
   var transition_func = func():
      $GameBoardHUD.hide_debug_label()
      if self.__num_players_remaining() == 1:
         $GameStateMachine.send_event("InProgressToEnd")
      else:
         $PlayerTurnStateMachine.send_event("OpponentKnockedOutToIdle")
      
   var player_knocked_out_timer := Types.StartAndForgetTimer.new(transition_func)
   player_knocked_out_timer.name = "PlayerKnockedOutTimer"
   self.add_child(player_knocked_out_timer)
   player_knocked_out_timer.start(5)
   #

## Reinforce Phase ##################################################################################################### Reinforce Phase
func _on_reinforce_state_entered() -> void:
   self.__active_turn_phase = TurnPhase.REINFORCE
   self.__clear_interphase_state_machine_metadata()
   
   self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED] = 0
   
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   
## Reinforce (Idle) Subphase ########################################################################################### Reinforce (Idle) Subphase
func _on_reinforce_idle_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + ReinforceTurnSubPhase.keys()[ReinforceTurnSubPhase.IDLE] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_reinforce_source_country_clicked)
      
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = self.__players[self.__active_player_index]
   if player.player_controller != null:
      if !player.player_controller.handle_reinforce_state_idle():
         $PlayerTurnStateMachine.send_event("ReinforceToEnd")
      
func _on_reinforce_idle_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.disconnect("country_clicked", self._on_reinforce_source_country_clicked)
      
func _on_reinforce_source_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_reinforce_source_country_clicked( " + Types.Country.keys()[country] + ", " + action_tag + " )")
   
   assert(self.__state_machine_metadata.has(self.__NUM_REINFORCE_MOVEMENTS_UTILIZED), "Num reinforce movements not set previously")
   
   if self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED] >= Constants.MAX_REINFORCES_ALLOWED:
      Logger.log_error("ReinforceIdle: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they have no more reinforce movements remaining as they have already used: " +
                       str(self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED]))
      return
      
   if !self.__player_occupations[self.__players[self.__local_player_index]].has(country):
      Logger.log_error("ReinforceIdle: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not own it")
      return
      
   if self.__deployments[country].troop_count <= 1:
      Logger.log_error("ReinforceIdle: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not have any moveable troops")
      return
      
   self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("IdleToSourceSelected")

## Reinforce (Source Selected) Subphase ################################################################################ Reinforce (Source Selected) Subphase
func _on_reinforce_source_selected_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + ReinforceTurnSubPhase.keys()[ReinforceTurnSubPhase.SOURCE_SELECTED] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_reinforce_destination_country_clicked)
      
func _on_reinforce_source_selected_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.disconnect("country_clicked", self._on_reinforce_destination_country_clicked)
      
func _on_reinforce_source_selected_state_input(event: InputEvent) -> void:
   if self.__active_player_index == self.__local_player_index and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         $PlayerTurnStateMachine.send_event("SourceSelectedToIdle")
      
func _on_reinforce_destination_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_reinforce_source_country_clicked( " + Types.Country.keys()[country] + ", " + action_tag + " )")
   
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   var SOURCE_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   
   if country == SOURCE_COUNTRY:
      Logger.log_error("ReinforceSourceSelected: Local player selected destination country: " + 
                       Types.Country.keys()[country] + 
                       ", but that was the source country they already selected")
      return
      
   if !self.__player_occupations[self.__players[self.__local_player_index]].has(country):
      Logger.log_error("ReinforceSourceSelected: Local player selected destination country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not own it")
      return
      
   if not $GameBoard.countries_connected_via_player_occupations(self.__players[self.__active_player_index], self.__deployments, SOURCE_COUNTRY, country):
      Logger.log_error("ReinforceSourceSelected: Local player selected destination country: " + 
                       Types.Country.keys()[country] + 
                       ", but it is not connected to: " +
                       Types.Country.keys()[SOURCE_COUNTRY] +
                       " via player occupations")
      return
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("SourceSelectedToDestinationSelected")

## Reinforce (Destination Selected) Subphase ########################################################################### Reinforce (Destination Selected) Subphase
func _on_reinforce_destination_selected_state_entered() -> void:
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered subphase: " + ReinforceTurnSubPhase.keys()[ReinforceTurnSubPhase.DESTINATION_SELECTED] + 
                      " of phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   
   var SOURCE_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DESTINATION_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var SOURCE_OCCUPATION: Types.Occupation = Types.Occupation.new(SOURCE_COUNTRY, self.__deployments[SOURCE_COUNTRY])
   
   self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY] = SOURCE_OCCUPATION.deployment.troop_count - 1
  
   if self.__active_player_index == self.__local_player_index:
      $GameBoardHUD.connect("troop_movement_troop_count_change_requested", self._on_reinforce_troop_count_change_requested)
      $GameBoardHUD.connect("troop_movement_confirm_requested", self._on_reinforce_troop_movement_confirm_requested)
      
   $GameBoardHUD.show_troop_movement_popup(self.__active_player_index == self.__local_player_index, 
                                             TroopMovementType.REINFORCE,
                                             SOURCE_OCCUPATION, 
                                             DESTINATION_COUNTRY, 
                                             self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY],
                                             1,
                                             SOURCE_OCCUPATION.deployment.troop_count - 1)

func _on_reinforce_destination_selected_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoardHUD.disconnect("troop_movement_troop_count_change_requested", self._on_reinforce_troop_count_change_requested)
      $GameBoardHUD.disconnect("troop_movement_confirm_requested", self._on_reinforce_troop_movement_confirm_requested)
      
   $GameBoardHUD.hide_troop_movement_popup()
   
func _on_reinforce_destination_selected_state_input(event: InputEvent) -> void:
   if self.__active_player_index == self.__local_player_index and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         $PlayerTurnStateMachine.send_event("DestinationSelectedToSourceSelected")
         
func _on_reinforce_troop_count_change_requested(old_troop_count: int, new_troop_count: int) -> void:
   if old_troop_count == new_troop_count or new_troop_count < 1:
      return
   
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_TROOPS_TO_MOVE_KEY), "Num troops to move not set previously!")
   
   var SOURCE_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DESTINATION_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_TROOPS_TO_MOVE: int = self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY]
   
   var SOURCE_COUNTRY_OCCUPATION: Types.Occupation = Types.Occupation.new(SOURCE_COUNTRY, self.__deployments[SOURCE_COUNTRY])
   
   if new_troop_count == NUM_TROOPS_TO_MOVE or new_troop_count > (SOURCE_COUNTRY_OCCUPATION.deployment.troop_count - 1):
      return
      
   self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY] = new_troop_count
   
   $GameBoardHUD.show_troop_movement_popup(self.__active_player_index == self.__local_player_index,
                                           TroopMovementType.REINFORCE,
                                           SOURCE_COUNTRY_OCCUPATION, 
                                           DESTINATION_COUNTRY, 
                                           new_troop_count,
                                           1,
                                           SOURCE_COUNTRY_OCCUPATION.deployment.troop_count - 1)
   
func _on_reinforce_troop_movement_confirm_requested() -> void:
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_TROOPS_TO_MOVE_KEY), "Num troops to move not set previously")
   
   var SOURCE_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DESTINATION_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_TROOPS_TO_MOVE: int = self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY]
   
   self.__deployments[SOURCE_COUNTRY].troop_count -= NUM_TROOPS_TO_MOVE
   self.__deployments[DESTINATION_COUNTRY].troop_count += NUM_TROOPS_TO_MOVE
   
   $GameBoard.set_country_deployment(SOURCE_COUNTRY, self.__deployments[SOURCE_COUNTRY])
   $GameBoard.set_country_deployment(DESTINATION_COUNTRY, self.__deployments[DESTINATION_COUNTRY])
   
   self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED] += 1
   
   $PlayerTurnStateMachine.send_event("DestinationSelectedToIdle")

## End Phase ########################################################################################################### End Phase
func _on_end_state_entered() -> void:
   self.__active_turn_phase = TurnPhase.END
   self.__clear_interphase_state_machine_metadata()
   
   Logger.log_message(str(self.__players[self.__active_player_index]) + 
                      " entered phase: " + 
                      TurnPhase.keys()[self.__active_turn_phase])
                     
   self.__log_deployments()
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   
   var countries_conquered: int = 0
   if self.__state_machine_metadata.has(self.__COUNTRIES_CONQUERED_KEY):
      countries_conquered = self.__state_machine_metadata[self.__COUNTRIES_CONQUERED_KEY]
      
   # If player conquered any countries, give them a card
   if countries_conquered > 0:
      var random_card: Types.CardType = Types.CardType.values().pick_random()
      self.__player_cards[self.__players[self.__active_player_index]].append(random_card)
      
      if self.__local_player_index == self.__active_player_index:
         $GameBoardHUD.add_card_to_hand(random_card)
   
   $PlayerTurnStateMachine.send_event("EndToStart")
   
func _on_end_state_exited() -> void:
   # Determine next player, skip any players who have been knocked out
   var next_player_index = (self.__active_player_index + 1) % self.__players.size()
   while self.__is_player_index_knocked_out(next_player_index):
      next_player_index = (next_player_index + 1) % self.__players.size()
      assert(next_player_index != self.__active_player_index, 
             "Could not find another player remaining except for current player: " + str(self.__players[self.__active_player_index]))
      
   self.__active_player_index = next_player_index

########################################################################################################################
######################################################################################################################## End Player Turn State Machine Logic    
########################################################################################################################

func __is_player_index_knocked_out(player_index: int) -> bool:
   assert(player_index < self.__players.size(), "Invalid player index provided")
   return self.__is_player_knocked_out(self.__players[player_index])

func __is_player_knocked_out(player: Player) -> bool:
   assert(self.__player_occupations.has(player), "Invalid player provided")
   return self.__player_occupations[player].size() == 0
   
func __num_players_remaining() -> int:
   var num_players_remaining := 0
   for player in self.__players:
      if !self.__is_player_knocked_out(player):
         num_players_remaining += 1
      
   assert(num_players_remaining != 0, "Somehow, no players are still remaining in the game")
   
   return num_players_remaining
   
func __get_last_remaining_player() -> Player:
   assert(self.__num_players_remaining() == 1, "Can't get last remaining player as there are multiple left!")
   
   for player in self.__players:
      if !self.__is_player_knocked_out(player):
         return player
         
   assert(false, "Could not find the last remaining player!")
   return null

func __generate_random_deployments() -> void:
   self.__player_occupations.clear()
   
   var remaining_troop_count: Dictionary = {}
   for player in self.__players:
      self.__player_occupations[player] = []
      remaining_troop_count[player] = Constants.STARTING_TROOP_COUNTS[self.__players.size()]
   
   # First assign countries
   var num_countries = Types.Country.size()
   var num_countries_assigned = 0
   
   while num_countries_assigned != num_countries:
      for player in self.__players:
         var country = randi() % num_countries
         while self.__deployments.has(country):
            country = randi() % num_countries
         
         self.__player_occupations[player].append(country)
         self.__deployments[country] = Types.Deployment.new(player, 1)
      
         num_countries_assigned += 1
         remaining_troop_count[player] -= 1
         assert(remaining_troop_count[player] >= 0, "Ran out of troop assignments in country selection!")
      
         if num_countries_assigned == num_countries:
            break
            
   # Now reinforce owned countries
   for player in self.__players:
      while remaining_troop_count[player] > 0:
         self.__deployments[self.__player_occupations[player][randi() % self.__player_occupations[player].size()]].troop_count += 1
         remaining_troop_count[player] -= 1

func __log_deployments() -> void:
   if self.__DEPLOYMENT_LOGGING_ENABLED:
      Logger.log_message("-----------------------------------------------------------------------------------------------")
      Logger.log_message("CURRENT DEPLOYMENTS: ")
      for player in self.__players:
         Logger.log_indented_message(1, str(player))
         for occupied_country in self.__player_occupations[player]:
            Logger.log_indented_message(2, "Country: " + Types.Country.keys()[occupied_country] + " Troops: " + str(self.__deployments[occupied_country].troop_count))
      Logger.log_message("-----------------------------------------------------------------------------------------------")
