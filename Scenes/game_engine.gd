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
# TODO: Give conquering player losers cards if loser knocked out of game
# TODO: If upon conquering, player has 5+ cards, send them back to deploy stage
#
# TODO: Long Term
#
# TODO: Make territory cards part of a greater deck with assigned countries and country bonuses instead of randomly selected J,Q,K
# TODO: Add other victory conditions
# 
########################################################################################################################

signal turn_phase_updated(phase: TurnPhase)

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

var __active_turn_phase: TurnPhase = TurnPhase.START

# State machine metadata
const __SOURCE_COUNTRY_KEY = "src"
const __DESTINATION_COUNTRY_KEY = "dest"
const __NUM_UNITS_KEY = "troop_count"
const __REINFORCEMENTS_REMAINING_KEY = "reinforcements_remaining"
const __CARD_INDICES_SELECTED_KEY = "cards_selected"
const __NUM_ATTACKER_DICE_KEY = "num_attack_dice"
const __NUM_DEFENDER_DICE_KEY = "num_defense_dice"
const __NUM_TROOPS_TO_MOVE_KEY = "num_troops_to_move"
const __NUM_REINFORCE_MOVEMENTS_UTILIZED = "num_reinforces_utilized"
const __COUNTRIES_CONQUERED_KEY = "countries_counquered"
const __KNOCKED_OUT_PLAYER = "knocked_out_player"
var __state_machine_metadata: Dictionary[String, Variant] = {}

func _ready():
   var success: bool = CountrySpriteLoader.load_country_sprites_from_file(
         "res://Assets/Sprites/GameBoard/TEST_Countries_SpriteSheet2.png",
         "res://Assets/Sprites/GameBoard/TEST_Countries_SpriteSheet.json",
         $GameBoard.get_country_labels()
      )
   assert(success, "Failed to load country sprites from country sprite sheet!")
   
   success = $GameBoard.populate_country_sprites()
   assert(success, "Failed to populate country sprites on GameBoard!")
   
   $GameBoard.state_manager.initialize_with_random_deployments()
   $GameBoardHUD.initialize_player_leaderboard_table($GameBoard.state_manager)
   
   self.connect("turn_phase_updated", $GameBoardHUD._on_turn_phase_updated)
   $GameBoardHUD.connect("next_phase_requested", self._on_next_phase_requested)
    
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
   if PlayerManager.num_players_remaining() == 1:
      victor = PlayerManager.get_player_for_id(PlayerManager.get_last_remaining_player_id())
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
   if !PlayerManager.is_local_player_active():
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
            
         if PlayerManager.player_has_max_cards(PlayerManager.get_local_player_id()):
            Logger.log_error("_on_next_phase_requested: Local player requested next phase from deploy phase, but must play a territory card combo!")
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
   
   self.__log_phase_entered()
   
   self.turn_phase_updated.emit(self.__active_turn_phase)
   $PlayerTurnStateMachine.send_event("StartToDeploy")

## Deploy Phase ######################################################################################################## Deploy Phase
func _on_deploy_state_entered() -> void:
   self.__active_turn_phase = TurnPhase.DEPLOY
   self.__clear_interphase_state_machine_metadata()
   
   self.__log_phase_entered()
                     
   self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY] = Utilities.get_num_reinforcements_earned($GameBoard.CONTINENTS, 
                                                                                                                $GameBoard.CONTINENT_BONUSES, 
                                                                                                                $GameBoard.state_manager.get_player_countries(PlayerManager.get_active_player_id()))
   
   $GameBoardHUD.show_deploy_reinforcements_remaining(self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY])
   
   self.turn_phase_updated.emit(self.__active_turn_phase)
   
   var player = PlayerManager.get_active_player()
   if player.player_controller != null:
      player.player_controller.determine_desired_deployments($GameBoard.state_manager, 
                                                             self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY])
   
func _on_deploy_state_exited() -> void:
   $GameBoardHUD.hide_deploy_reinforcements_remaining()
   
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.enable_player_hand(false)
   
## Deploy (Idle) Subphase ############################################################################################## Deploy (Idle) Subphase
func _on_deploy_idle_state_entered() -> void:
   self.__log_subphase_entered(DeployTurnSubPhase.keys()[DeployTurnSubPhase.IDLE])
                     
   if PlayerManager.is_local_player_active():
      $GameBoard.connect("country_clicked", self._on_deploy_idle_country_clicked)
      $GameBoardHUD.connect("territory_card_toggled", self._on_first_territory_card_toggled)
      $GameBoardHUD.enable_player_hand(true)
      
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = PlayerManager.get_active_player()
   if player.player_controller != null:
      if !player.player_controller.handle_deploy_state_idle(self.__deploy_select_country):
         $PlayerTurnStateMachine.send_event("DeployToAttack")
   
func _on_deploy_idle_state_exited() -> void:
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.disconnect("territory_card_toggled", self._on_first_territory_card_toggled)
      $GameBoard.disconnect("country_clicked", self._on_deploy_idle_country_clicked)
      
func _on_deploy_idle_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_deploy_idle_country_clicked( " + $GameBoard.get_country_label(country) + ", " + action_tag + " )")
   self.__deploy_select_country(country)
   
func __deploy_select_country(country: Types.Country):
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   
   var REINFORCEMENTS_REMAINING: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
   
   if !$GameBoard.state_manager.player_occupies_country(PlayerManager.get_active_player_id(), country):
      Logger.log_error("DeployIdle: Local player selected country: " + 
                       $GameBoard.get_country_label(country) + 
                       ", but they do not own it")
      return
   
   if REINFORCEMENTS_REMAINING <= 0:
      Logger.log_error("DeployIdle: Player selected country: " + 
                       $GameBoard.get_country_label(country) + 
                       ", but they do not have any reinforcements remaining")
      return
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("IdleToDeploying")
   
func _on_first_territory_card_toggled(index: int, card: Types.CardType, toggled_on: bool) -> void:
   var ACTIVE_PLAYER_ID = PlayerManager.get_active_player_id()
   
   assert(index < PlayerManager.get_num_player_cards(ACTIVE_PLAYER_ID), "Invalid index for player's card list!")
   assert(PlayerManager.get_player_card_at_index(ACTIVE_PLAYER_ID, index) == card, "Card at index does not match card passed in!")

   if toggled_on:
      var selected_indices: Array[int] = [index]
      self.__state_machine_metadata[self.__CARD_INDICES_SELECTED_KEY] = selected_indices
      $PlayerTurnStateMachine.send_event("IdleToPlayingCards")
   
## Deploy (Deploying) Subphase ######################################################################################### Deploy (Deploying) Subphase
func _on_deploy_deploying_state_entered() -> void:
   self.__log_subphase_entered(DeployTurnSubPhase.keys()[DeployTurnSubPhase.DEPLOYING])
   
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Deploy country not set previously!")
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   
   var DEPLOY_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   var REINFORCEMENTS_REMAINING: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
                    
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.enable_player_hand(false)
      $GameBoardHUD.connect("deploy_cancel_requested", self._on_deploy_cancel_requested)
      $GameBoardHUD.connect("deploy_confirm_requested", self._on_deploy_confirm_requested)
      $GameBoardHUD.connect("deploy_troop_count_change_requested", self._on_deploy_troop_count_change_requested)
      
   self.__state_machine_metadata[self.__NUM_UNITS_KEY] = REINFORCEMENTS_REMAINING
      
   $GameBoardHUD.show_deploy_popup(DEPLOY_COUNTRY, REINFORCEMENTS_REMAINING, REINFORCEMENTS_REMAINING)
                                 
   # If player is being controlled by AI, tell AI to make a move
   var player = PlayerManager.get_active_player()
   if player.player_controller != null:
      player.player_controller.handle_deploy_state_deploying(self.__deploy_set_troop_count_and_confirm, DEPLOY_COUNTRY)

func _on_deploy_deploying_state_exited() -> void:
   if self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY):
      self.__state_machine_metadata.erase(self.__DESTINATION_COUNTRY_KEY)
      
   if self.__state_machine_metadata.has(self.__NUM_UNITS_KEY):
      self.__state_machine_metadata.erase(self.__NUM_UNITS_KEY)
   
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.disconnect("deploy_cancel_requested", self._on_deploy_cancel_requested)
      $GameBoardHUD.disconnect("deploy_confirm_requested", self._on_deploy_confirm_requested)
      $GameBoardHUD.disconnect("deploy_troop_count_change_requested", self._on_deploy_troop_count_change_requested)
      
   $GameBoardHUD.hide_deploy_popup()
   
func _on_deploy_deploying_state_input(event: InputEvent) -> void:
   if PlayerManager.is_local_player_active() and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
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
   
   $GameBoard.state_manager.add_troops_to_deployment(DEPLOY_COUNTRY, UNITS_TO_DEPLOY)
   
   self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY] = reinforcements_remaining
   
   $GameBoardHUD.show_deploy_reinforcements_remaining(reinforcements_remaining)
   
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
      assert(PlayerManager.is_local_player_active(), 
             "Non-local player selected a deployment count higher than their available reinforcements!")
      return
      
   self.__state_machine_metadata[self.__NUM_UNITS_KEY] = new_troop_count
   
   $GameBoardHUD.show_deploy_popup(DEPLOY_COUNTRY, new_troop_count, REINFORCEMENTS_REMAINING)
                                 
func __deploy_set_troop_count_and_confirm(troop_count: int) -> void:
   assert(self.__state_machine_metadata.has(self.__NUM_UNITS_KEY), "Deploy troop count not set previously!")
   
   self._on_deploy_troop_count_change_requested(self.__state_machine_metadata[self.__NUM_UNITS_KEY], troop_count)

   # Add delay if player is being controlled by AI
   if Config.AI_DELAY_ENABLED and PlayerManager.get_active_player().player_controller != null:
      var ai_delay_timer := Types.StartAndForgetTimer.new(self._on_deploy_confirm_requested)
      ai_delay_timer.name = "AiDelayTimer"
      self.add_child(ai_delay_timer)
      ai_delay_timer.start(self.__deploy_screen_ai_delay)
   else:
      self._on_deploy_confirm_requested()
      
## Deploy (Playing Cards) Subphase ##################################################################################### Deploy (Playing Cards) Subphase
func _on_deploy_playing_cards_state_entered() -> void:
   self.__log_subphase_entered(DeployTurnSubPhase.keys()[DeployTurnSubPhase.PLAYING_CARDS])
   
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   assert(self.__state_machine_metadata.has(self.__CARD_INDICES_SELECTED_KEY), "Territory card indices not set previously!")
   
   $GameBoardHUD.enable_next_phase_button(false)
   
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.connect("territory_card_toggled", self._on_deploy_playing_cards_territory_card_toggled)

func _on_deploy_playing_cards_state_exited() -> void:
   $GameBoardHUD.enable_player_hand(false)
   $GameBoardHUD.enable_next_phase_button(true)
   
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.disconnect("territory_card_toggled", self._on_deploy_playing_cards_territory_card_toggled)
      
func _on_deploy_playing_cards_territory_card_toggled(index: int, _card: Types.CardType, toggled_on: bool) -> void:
   var ACTIVE_PLAYER_ID = PlayerManager.get_active_player_id()
   var NUM_PLAYER_CARDS = PlayerManager.get_num_player_cards(ACTIVE_PLAYER_ID)
   
   assert(NUM_PLAYER_CARDS > 0, "Current player does not have any cards!")
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   assert(self.__state_machine_metadata.has(self.__CARD_INDICES_SELECTED_KEY), "Territory card indices not set previously!")
   
   var INDEX_ALREADY_EXISTS = self.__state_machine_metadata[self.__CARD_INDICES_SELECTED_KEY].has(index)
   
   assert(INDEX_ALREADY_EXISTS != toggled_on, "Somehow a card was already known even though it was just toggled on or wasn't known and was toggled off")
   
   # Handle card removed from hand
   if INDEX_ALREADY_EXISTS and !toggled_on:
      self.__state_machine_metadata[self.__CARD_INDICES_SELECTED_KEY].erase(index)
      
      if self.__state_machine_metadata[self.__CARD_INDICES_SELECTED_KEY].size() <= 0:
         self.__state_machine_metadata.erase(self.__CARD_INDICES_SELECTED_KEY)
         $PlayerTurnStateMachine.send_event("PlayingCardsToIdle")
         
      return
      
   # Handle card added to hand
   else:
      self.__state_machine_metadata[self.__CARD_INDICES_SELECTED_KEY].append(index)
      
   # Sort selected indices for easier handling
   var SELECTED_INDICES = self.__state_machine_metadata[self.__CARD_INDICES_SELECTED_KEY]
   SELECTED_INDICES.sort()
   
   # See if this is a complete hand
   if SELECTED_INDICES.size() == Constants.NUM_TERRITORY_CARDS_IN_PLAYABLE_HAND:
      assert(NUM_PLAYER_CARDS >= SELECTED_INDICES.size(), "Somehow there are less territory cards than selected card indices")
      assert(NUM_PLAYER_CARDS > SELECTED_INDICES[0], "Selected index 0 is out of bounds!")
      assert(NUM_PLAYER_CARDS > SELECTED_INDICES[1], "Selected index 0 is out of bounds!")
      assert(NUM_PLAYER_CARDS > SELECTED_INDICES[2], "Selected index 0 is out of bounds!")
      
      var hand_played = false

      var FIRST_PLAYER_CARD = PlayerManager.get_player_card_at_index(ACTIVE_PLAYER_ID, SELECTED_INDICES[0])
      var SECOND_PLAYER_CARD = PlayerManager.get_player_card_at_index(ACTIVE_PLAYER_ID, SELECTED_INDICES[1])
      var THIRD_PLAYER_CARD = PlayerManager.get_player_card_at_index(ACTIVE_PLAYER_ID, SELECTED_INDICES[2])
      
      # Is hand three of a kind?
      if FIRST_PLAYER_CARD == SECOND_PLAYER_CARD and SECOND_PLAYER_CARD == THIRD_PLAYER_CARD:
            
            self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY] += Utilities.get_territory_card_reward_for_all_of_a_kind(FIRST_PLAYER_CARD)
            hand_played = true
            
      # Is hand one of each?
      elif FIRST_PLAYER_CARD != SECOND_PLAYER_CARD and \
           SECOND_PLAYER_CARD != THIRD_PLAYER_CARD and \
           FIRST_PLAYER_CARD != THIRD_PLAYER_CARD: 
            
            self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY] += Utilities.get_territory_card_reward_for_one_of_each()
            hand_played = true
         
      # If hand was played, now remove all cards and leave playing cards phase   
      if hand_played:
         # Update reinforcements remaining label
         $GameBoardHUD.hide_deploy_reinforcements_remaining()
         $GameBoardHUD.show_deploy_reinforcements_remaining(self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY])
         
         # Cards are sorted by indice, remove them in reverse order so that we do not have to do indice handling
         PlayerManager.remove_player_card_at_index(ACTIVE_PLAYER_ID, SELECTED_INDICES[2])
         PlayerManager.remove_player_card_at_index(ACTIVE_PLAYER_ID, SELECTED_INDICES[1])
         PlayerManager.remove_player_card_at_index(ACTIVE_PLAYER_ID, SELECTED_INDICES[0])
         
         $PlayerTurnStateMachine.send_event("PlayingCardsToIdle")
         
## Attack Phase ######################################################################################################## Attack Phase
func _on_attack_state_entered() -> void:
   self.__active_turn_phase = TurnPhase.ATTACK
   self.__clear_interphase_state_machine_metadata()
   
   self.__log_phase_entered()
   
   self.turn_phase_updated.emit(self.__active_turn_phase)
   
func _on_attack_state_exited():
   pass
   
## Attack (Idle) Subphase ############################################################################################## Attack (Idle) Subphase
func _on_attack_idle_state_entered() -> void:
   self.__clear_interphase_state_machine_metadata()
   
   self.__log_subphase_entered(AttackTurnSubPhase.keys()[AttackTurnSubPhase.IDLE])
                     
   if PlayerManager.is_local_player_active():
      $GameBoard.connect("country_clicked", self._on_attack_source_country_clicked)
      
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = PlayerManager.get_active_player()
   if player.player_controller != null:
      if !player.player_controller.handle_attack_state_idle(self.__attack_select_source_country, 
                                                            $GameBoard.get_countries_that_neighbor, 
                                                            $GameBoard.state_manager):
         $PlayerTurnStateMachine.send_event("AttackToReinforce")
   
func _on_attack_idle_state_exited() -> void:
   if PlayerManager.is_local_player_active():
      $GameBoard.disconnect("country_clicked", self._on_attack_source_country_clicked)
   
func _on_attack_source_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_attack_source_country_selected( " + $GameBoard.get_country_label(country) + ", " + action_tag + " )")
   
   if !PlayerManager.is_local_player_active():
      Logger.log_error("AttackIdle: Local player selected country, but it is not their turn")
      return
      
   self.__attack_select_source_country(country)
   
func __attack_select_source_country(country_id: int) -> void:
   if !$GameBoard.state_manager.player_occupies_country(PlayerManager.get_active_player_id(), country_id):
      Logger.log_error("AttackIdle: Player selected country: " + 
                       $GameBoard.get_country_label(country_id) + 
                       ", but they do not own it")
      assert(PlayerManager.is_local_player_active(), 
             "Non-local player selected a country to attack from that they do not own!")
      return
   
   if $GameBoard.state_manager.get_num_troops_deployed_to_country(country_id) < 2:
      Logger.log_error("AttackIdle: Player selected country: " + 
                       $GameBoard.get_country_label(country_id) + 
                       ", but they do not have enough attackers")
      assert(PlayerManager.is_local_player_active(), 
             "Non-local player selected a country to attack from without enough attackers available!")
      return
      
   self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY] = country_id
   
   $PlayerTurnStateMachine.send_event("IdleToSourceSelected")
   
## Attack (Source Selected) Subphase ################################################################################### Attack (Source Selected) Subphase
func _on_attack_source_selected_state_entered() -> void:
   self.__log_subphase_entered(AttackTurnSubPhase.keys()[AttackTurnSubPhase.SOURCE_SELECTED])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   
   if PlayerManager.is_local_player_active():
      $GameBoard.connect("country_clicked", self._on_attack_source_selected_country_clicked)
      
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = PlayerManager.get_active_player()
   if player.player_controller != null:
      player.player_controller.handle_attack_state_source_selected(self.__attack_select_destination_country, 
                                                                   $GameBoard.get_countries_that_neighbor, 
                                                                   self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY],
                                                                   $GameBoard.state_manager)

func _on_attack_source_selected_state_exited() -> void:
   if PlayerManager.is_local_player_active():
      $GameBoard.disconnect("country_clicked", self._on_attack_source_selected_country_clicked)
   
func _on_attack_source_selected_state_input(event: InputEvent) -> void:
   if PlayerManager.is_local_player_active() and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         $PlayerTurnStateMachine.send_event("SourceSelectedToIdle")
   
func _on_attack_source_selected_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_attack_destination_country_selected( " + $GameBoard.get_country_label(country) + ", " + action_tag + " )")
   
   if !PlayerManager.is_local_player_active():
      Logger.log_error("AttackSourceSelected: Local player selected country, but it is not their turn")
      return
      
   self.__attack_select_destination_country(country)
   
func __attack_select_destination_country(country_id: int) -> void:
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   
   var SRC_COUNTRY = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   
   if self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY):
      self.__state_machine_metadata.erase(self.__DESTINATION_COUNTRY_KEY)
      
   if $GameBoard.state_manager.player_occupies_country(PlayerManager.get_active_player_id(), country_id):
      Logger.log_error("AttackSourceSelected: Player selected country: " + 
                       $GameBoard.get_country_label(country_id) + 
                       ", but they do already own it")
      assert(PlayerManager.is_local_player_active(), 
             "Non-local player selected a country to attack that they already own!")
      return
      
   if !$GameBoard.countries_are_neighbors(SRC_COUNTRY, country_id):
      Logger.log_error("AttackSourceSelected: Player selected country: " + 
                       $GameBoard.get_country_label(country_id) + 
                       ", but it does not neighbor: " +
                       Types.Country.keys()[SRC_COUNTRY])
      assert(PlayerManager.is_local_player_active(), 
             "Non-local player selected a country to attack that does not border their source country!")
      return
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = country_id
   
   $PlayerTurnStateMachine.send_event("SourceSelectedToDestinationSelected")
   
## Attack (Destination Selected) Subphase ############################################################################## Attack (Destination Selected) Subphase
func _on_attack_destination_selected_state_entered() -> void:
   self.__log_subphase_entered(AttackTurnSubPhase.keys()[AttackTurnSubPhase.DESTINATION_SELECTED])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   if PlayerManager.is_local_player_active():       
      $GameBoardHUD.connect("attack_quit_requested", self._on_attack_destination_selected_quit_requested)
      $GameBoardHUD.connect("attack_roll_requested", self._on_attack_destination_selected_roll_requested)
      $GameBoardHUD.connect("attack_die_count_change_requested", self._on_attack_destination_selected_die_count_change_requested)
      
   # Max out attacker and defender dice until user says otherwise
   var max_attacker_die_count = Utilities.get_max_attacker_die_count_for_troop_count($GameBoard.state_manager.get_num_troops_deployed_to_country(ATTACKING_COUNTRY))
   var max_defender_die_count = Utilities.get_max_defender_die_count_for_troop_count($GameBoard.state_manager.get_num_troops_deployed_to_country(DEFENDING_COUNTRY))
      
   if !self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY) or self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY] > max_attacker_die_count:
      self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY] = max_attacker_die_count
   
   if !self.__state_machine_metadata.has(self.__NUM_DEFENDER_DICE_KEY) or self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY] > max_defender_die_count:
      self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY] = max_defender_die_count
   
   $GameBoardHUD.show_attack_popup($GameBoard.state_manager, 
                                   ATTACKING_COUNTRY, 
                                   DEFENDING_COUNTRY, 
                                   self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY],
                                   max_attacker_die_count, 
                                   self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY])
                                 
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = PlayerManager.get_active_player()
   if player.player_controller != null:
      player.player_controller.handle_attack_state_destination_selected(self.__attack_set_die_count_and_roll, 
                                                                        ATTACKING_COUNTRY,
                                                                        DEFENDING_COUNTRY,
                                                                        $GameBoard.state_manager)

func _on_attack_destination_selected_state_exited() -> void:
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.disconnect("attack_quit_requested", self._on_attack_destination_selected_quit_requested)
      $GameBoardHUD.disconnect("attack_roll_requested", self._on_attack_destination_selected_roll_requested)
      $GameBoardHUD.disconnect("attack_die_count_change_requested", self._on_attack_destination_selected_die_count_change_requested)
      
      if $GameBoardHUD.is_attack_popup_showing():
         $GameBoardHUD.show_troop_movement_user_inputs(false)

func _on_attack_destination_selected_state_input(event) -> void:
   if PlayerManager.is_local_player_active() and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
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
   
   var ATTACKING_COUNTRY: int = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var NUM_ATTACKER_DICE: int = self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY]
   
   if NUM_ATTACKER_DICE == new_num_dice:
      return
   
   var MAX_DIE_COUNT = Utilities.get_max_attacker_die_count_for_troop_count($GameBoard.state_manager.get_num_troops_deployed_to_country(ATTACKING_COUNTRY))
   if new_num_dice < old_num_dice or MAX_DIE_COUNT >= new_num_dice:
      self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY] = new_num_dice
      $GameBoardHUD.update_attack_die_count(new_num_dice, MAX_DIE_COUNT) 
      
func __attack_set_die_count_and_roll(die_count: int):
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   
   self._on_attack_destination_selected_die_count_change_requested(self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY], die_count)
   
   # Add delay if player is being controlled by AI
   if Config.AI_DELAY_ENABLED and PlayerManager.get_active_player().player_controller != null:
      var ai_delay_timer := Types.StartAndForgetTimer.new(self._on_attack_destination_selected_roll_requested)
      ai_delay_timer.name = "AiDelayTimer"
      self.add_child(ai_delay_timer)
      ai_delay_timer.start(self.__attack_screen_ai_delay)
   else:
      self._on_attack_destination_selected_roll_requested()
   
## Attack (Rolling) Subphase ########################################################################################### Attack (Rolling) Subphase
func _on_attack_rolling_state_entered() -> void:
   self.__log_subphase_entered(AttackTurnSubPhase.keys()[AttackTurnSubPhase.ROLLING])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_DEFENDER_DICE_KEY), "Num defender dice not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_ATTACKER_DICE: int = self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY]
   var NUM_DEFENDER_DICE: int = self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY]
   
   Logger.log_message(str(PlayerManager.get_active_player()) +
                      " rolling from: " +
                      Types.Country.keys()[ATTACKING_COUNTRY] +
                      " with: " +
                      str(NUM_ATTACKER_DICE) +
                      " dice, against " +
                      str(PlayerManager.get_player_for_id($GameBoard.state_manager.who_owns_country(DEFENDING_COUNTRY))) +
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
      $GameBoard.state_manager.remove_troops_from_deployment(ATTACKING_COUNTRY, attacking_units_lost)
      
   if defending_units_lost > 0:
      $GameBoard.state_manager.remove_troops_from_deployment(DEFENDING_COUNTRY, defending_units_lost)
      
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
   if $GameBoard.state_manager.get_num_troops_deployed_to_country(ATTACKING_COUNTRY) <= 1:
      $GameBoardHUD.hide_attack_popup()
      $PlayerTurnStateMachine.send_event("RollingToIdle")
      
   elif $GameBoard.state_manager.get_num_troops_deployed_to_country(DEFENDING_COUNTRY) <= 0:
      $GameBoardHUD.hide_attack_popup()
      $PlayerTurnStateMachine.send_event("RollingToVictory")
      
   else:
      $PlayerTurnStateMachine.send_event("RollingToDestinationSelected")
      
## Attack (Victory) Subphase ########################################################################################### Attack (Victory) Subphase
func _on_attack_victory_state_entered() -> void:
   self.__log_subphase_entered(AttackTurnSubPhase.keys()[AttackTurnSubPhase.VICTORY])
                     
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
   var ATTACKING_TROOP_COUNT = $GameBoard.state_manager.get_num_troops_deployed_to_country(ATTACKING_COUNTRY)
   if ATTACKING_TROOP_COUNT > (NUM_ATTACKER_DICE + 1):
      if PlayerManager.is_local_player_active():
         $GameBoardHUD.connect("troop_movement_troop_count_change_requested", self._on_attack_victory_troop_count_change_requested)
         $GameBoardHUD.connect("troop_movement_confirm_requested", self._on_attack_victory_troop_movement_confirm_requested)
         
      $GameBoardHUD.show_troop_movement_popup(TroopMovementType.POST_VICTORY,
                                              ATTACKING_COUNTRY, 
                                              DEFENDING_COUNTRY, 
                                              NUM_ATTACKER_DICE,
                                              NUM_ATTACKER_DICE,
                                              ATTACKING_TROOP_COUNT - 1)
                                             
      # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
      var player = PlayerManager.get_active_player()
      if player.player_controller != null:
         player.player_controller.handle_attack_state_victory(self.__attack_victory_set_troop_count_and_confirm, 
                                                              ATTACKING_COUNTRY,
                                                              DEFENDING_COUNTRY,
                                                              $GameBoard.state_manager)
                                                                        
   else:
      self._on_attack_victory_troop_movement_confirm_requested()
   
func _on_attack_victory_state_exited() -> void:
   if $GameBoardHUD.is_troop_movement_popup_showing():
      $GameBoardHUD.hide_troop_movement_popup()
      if PlayerManager.is_local_player_active():
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
   
   if new_troop_count < NUM_ATTACKER_DICE or new_troop_count > ($GameBoard.state_manager.get_num_troops_deployed_to_country(ATTACKING_COUNTRY) - 1):
      return
      
   self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY] = new_troop_count
   
   $GameBoardHUD.show_troop_movement_popup(TroopMovementType.POST_VICTORY,
                                           ATTACKING_COUNTRY, 
                                           DEFENDING_COUNTRY, 
                                           new_troop_count,
                                           NUM_ATTACKER_DICE,
                                           $GameBoard.state_manager.get_num_troops_deployed_to_country(ATTACKING_COUNTRY) - 1)
   
func _on_attack_victory_troop_movement_confirm_requested() -> void:
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   
   var DEFENDING_PLAYER = $GameBoard.state_manager.who_owns_country(self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY])
   
   self.__attack_victory_move_conquering_armies()
   
   if $GameBoard.state_manager.get_player_num_countries(DEFENDING_PLAYER) <= 0:
      self.__state_machine_metadata[self.__KNOCKED_OUT_PLAYER] = DEFENDING_PLAYER
      $PlayerTurnStateMachine.send_event("VictoryToOpponentKnockedOut")
   else:
      $PlayerTurnStateMachine.send_event("VictoryToIdle")
   
func __attack_victory_move_conquering_armies():
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_TROOPS_TO_MOVE_KEY), "Num attackers to move not set previously")
   
   var ATTACKING_COUNTRY: int = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: int = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_ATTACKERS_TO_MOVE: int = self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY]
   
   var ATTACKING_PLAYER = PlayerManager.get_active_player_id()
   
   $GameBoard.state_manager.remove_troops_from_deployment(ATTACKING_COUNTRY, NUM_ATTACKERS_TO_MOVE)
   $GameBoard.state_manager.update_deployment(DEFENDING_COUNTRY, Types.Deployment.new(ATTACKING_PLAYER, NUM_ATTACKERS_TO_MOVE))
   
func __attack_victory_set_troop_count_and_confirm(troop_count: int) -> void:
   assert(self.__state_machine_metadata.has(self.__NUM_TROOPS_TO_MOVE_KEY), "Num attackers to move not set previously")
   
   self._on_attack_victory_troop_count_change_requested(self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY], troop_count)
   
   # Add delay if player is being controlled by AI
   if Config.AI_DELAY_ENABLED and PlayerManager.get_active_player().player_controller != null:
      var ai_delay_timer := Types.StartAndForgetTimer.new(self._on_attack_victory_troop_movement_confirm_requested)
      ai_delay_timer.name = "AiDelayTimer"
      self.add_child(ai_delay_timer)
      ai_delay_timer.start(self.__victory_screen_ai_delay)
   else:
      self._on_attack_victory_troop_movement_confirm_requested()
      
## Attack (Victory) Subphase ########################################################################################### Attack (Victory) Subphase
func _on_attack_opponent_knocked_out_state_entered() -> void:
   self.__log_subphase_entered(AttackTurnSubPhase.keys()[AttackTurnSubPhase.OPPONENT_KNOCKED_OUT])
                     
   assert(self.__state_machine_metadata.has(self.__KNOCKED_OUT_PLAYER), "Knocked out player was not set previously")
   
   var KNOCKED_OUT_PLAYER: int = self.__state_machine_metadata[self.__KNOCKED_OUT_PLAYER]
                     
   Logger.log_message("Player: " + str(PlayerManager.get_player(KNOCKED_OUT_PLAYER)) + " was knocked out!")
   
   # TODO: Remove
   $GameBoardHUD.show_debug_label("Player: " + str(KNOCKED_OUT_PLAYER) + " was knocked out!")
   
   var transition_func = func():
      $GameBoardHUD.hide_debug_label()
      if $GameBoard.state_manager.num_players_with_nonzero_countries() == 1:
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
   
   self.__log_phase_entered()
   
   self.turn_phase_updated.emit(self.__active_turn_phase)
   
func _on_reinforce_state_exited():
   pass
   
## Reinforce (Idle) Subphase ########################################################################################### Reinforce (Idle) Subphase
func _on_reinforce_idle_state_entered() -> void:
   self.__log_subphase_entered(ReinforceTurnSubPhase.keys()[ReinforceTurnSubPhase.IDLE])
                     
   if PlayerManager.is_local_player_active():
      $GameBoard.connect("country_clicked", self._on_reinforce_source_country_clicked)
      
   # If player is being controlled by AI, tell AI to make a move, if AI has no moves remaining, move to the next phase
   var player = PlayerManager.get_active_player()
   if player.player_controller != null:
      if !player.player_controller.handle_reinforce_state_idle():
         $PlayerTurnStateMachine.send_event("ReinforceToEnd")
      
func _on_reinforce_idle_state_exited() -> void:
   if PlayerManager.is_local_player_active():
      $GameBoard.disconnect("country_clicked", self._on_reinforce_source_country_clicked)
      
func _on_reinforce_source_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_reinforce_source_country_clicked( " + $GameBoard.get_country_label(country) + ", " + action_tag + " )")
   
   assert(self.__state_machine_metadata.has(self.__NUM_REINFORCE_MOVEMENTS_UTILIZED), "Num reinforce movements not set previously")
   
   if self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED] >= Constants.MAX_REINFORCES_ALLOWED:
      Logger.log_error("ReinforceIdle: Local player selected country: " + 
                       $GameBoard.get_country_label(country) + 
                       ", but they have no more reinforce movements remaining as they have already used: " +
                       str(self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED]))
      return
      
   if !$GameBoard.state_manager.player_occupies_country(PlayerManager.get_active_player_id(), country):
      Logger.log_error("ReinforceIdle: Local player selected country: " + 
                       $GameBoard.get_country_label(country) + 
                       ", but they do not own it")
      return
      
   if $GameBoard.state_manager.get_num_troops_deployed_to_country(country) <= 1:
      Logger.log_error("ReinforceIdle: Local player selected country: " + 
                       $GameBoard.get_country_label(country) + 
                       ", but they do not have any moveable troops")
      return
      
   self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("IdleToSourceSelected")

## Reinforce (Source Selected) Subphase ################################################################################ Reinforce (Source Selected) Subphase
func _on_reinforce_source_selected_state_entered() -> void:
   self.__log_subphase_entered(ReinforceTurnSubPhase.keys()[ReinforceTurnSubPhase.SOURCE_SELECTED])
   
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
                     
   if PlayerManager.is_local_player_active():
      $GameBoard.connect("country_clicked", self._on_reinforce_destination_country_clicked)
      
func _on_reinforce_source_selected_state_exited() -> void:
   if PlayerManager.is_local_player_active():
      $GameBoard.disconnect("country_clicked", self._on_reinforce_destination_country_clicked)
      
func _on_reinforce_source_selected_state_input(event: InputEvent) -> void:
   if PlayerManager.is_local_player_active() and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         $PlayerTurnStateMachine.send_event("SourceSelectedToIdle")
      
func _on_reinforce_destination_country_clicked(dest_country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_reinforce_source_country_clicked( " + Types.Country.keys()[dest_country] + ", " + action_tag + " )")
   
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   var SRC_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   
   if dest_country == SRC_COUNTRY:
      Logger.log_error("ReinforceSourceSelected: Local player selected destination country: " + 
                       Types.Country.keys()[dest_country] + 
                       ", but that was the source country they already selected")
      return
      
   if !$GameBoard.state_manager.player_occupies_country(PlayerManager.get_active_player_id(), dest_country):
      Logger.log_error("ReinforceSourceSelected: Local player selected destination country: " + 
                       Types.Country.keys()[dest_country] + 
                       ", but they do not own it")
      return
      
   if not $GameBoard.countries_connected_via_player_occupations(PlayerManager.get_active_player_id(), SRC_COUNTRY, dest_country):
      Logger.log_error("ReinforceSourceSelected: Local player selected destination country: " + 
                       Types.Country.keys()[dest_country] + 
                       ", but it is not connected to: " +
                       Types.Country.keys()[SRC_COUNTRY] +
                       " via player occupations")
      return
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = dest_country
   
   $PlayerTurnStateMachine.send_event("SourceSelectedToDestinationSelected")

## Reinforce (Destination Selected) Subphase ########################################################################### Reinforce (Destination Selected) Subphase
func _on_reinforce_destination_selected_state_entered() -> void:
   self.__log_subphase_entered(ReinforceTurnSubPhase.keys()[ReinforceTurnSubPhase.DESTINATION_SELECTED])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   
   var SRC_COUNTRY: int = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEST_COUNTRY: int = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var SRC_COUNTRY_TROOPS = $GameBoard.state_manager.get_num_troops_deployed_to_country(SRC_COUNTRY)
   
   self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY] = SRC_COUNTRY_TROOPS - 1
  
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.connect("troop_movement_troop_count_change_requested", self._on_reinforce_troop_count_change_requested)
      $GameBoardHUD.connect("troop_movement_confirm_requested", self._on_reinforce_troop_movement_confirm_requested)
      
   $GameBoardHUD.show_troop_movement_popup(TroopMovementType.REINFORCE,
                                           SRC_COUNTRY, 
                                           DEST_COUNTRY, 
                                           self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY],
                                           1,
                                           SRC_COUNTRY_TROOPS - 1)

func _on_reinforce_destination_selected_state_exited() -> void:
   if PlayerManager.is_local_player_active():
      $GameBoardHUD.disconnect("troop_movement_troop_count_change_requested", self._on_reinforce_troop_count_change_requested)
      $GameBoardHUD.disconnect("troop_movement_confirm_requested", self._on_reinforce_troop_movement_confirm_requested)
      
   $GameBoardHUD.hide_troop_movement_popup()
   
func _on_reinforce_destination_selected_state_input(event: InputEvent) -> void:
   if PlayerManager.is_local_player_active() and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         $PlayerTurnStateMachine.send_event("DestinationSelectedToSourceSelected")
         
func _on_reinforce_troop_count_change_requested(old_troop_count: int, new_troop_count: int) -> void:
   if old_troop_count == new_troop_count or new_troop_count < 1:
      return
   
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_TROOPS_TO_MOVE_KEY), "Num troops to move not set previously!")
   
   var SRC_COUNTRY: int = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEST_COUNTRY: int = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_TROOPS_TO_MOVE: int = self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY]
   
   var SRC_COUNTRY_TROOPS = $GameBoard.state_manager.get_num_troops_deployed_to_country(SRC_COUNTRY)
   
   if new_troop_count == NUM_TROOPS_TO_MOVE or new_troop_count > (SRC_COUNTRY_TROOPS - 1):
      return
      
   self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY] = new_troop_count
   
   $GameBoardHUD.show_troop_movement_popup(TroopMovementType.REINFORCE,
                                           SRC_COUNTRY, 
                                           DEST_COUNTRY, 
                                           new_troop_count,
                                           1,
                                           SRC_COUNTRY_TROOPS - 1)
   
func _on_reinforce_troop_movement_confirm_requested() -> void:
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_TROOPS_TO_MOVE_KEY), "Num troops to move not set previously")
   
   var SRC_COUNTRY: int = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEST_COUNTRY: int = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_TROOPS_TO_MOVE: int = self.__state_machine_metadata[self.__NUM_TROOPS_TO_MOVE_KEY]
   
   $GameBoard.state_manager.remove_troops_from_deployment(SRC_COUNTRY, NUM_TROOPS_TO_MOVE)
   $GameBoard.state_manager.add_troops_to_deployment(DEST_COUNTRY, NUM_TROOPS_TO_MOVE)
   
   self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED] += 1
   
   $PlayerTurnStateMachine.send_event("DestinationSelectedToIdle")

## End Phase ########################################################################################################### End Phase
func _on_end_state_entered() -> void:
   self.__active_turn_phase = TurnPhase.END
   self.__clear_interphase_state_machine_metadata()
   
   self.__log_phase_entered()
   
   self.turn_phase_updated.emit(self.__active_turn_phase)
   
   var countries_conquered: int = 0
   if self.__state_machine_metadata.has(self.__COUNTRIES_CONQUERED_KEY):
      countries_conquered = self.__state_machine_metadata[self.__COUNTRIES_CONQUERED_KEY]
      
   # If player conquered any countries, give them a card
   if countries_conquered > 0:
      var random_card: Types.CardType = Types.CardType.values().pick_random()
      PlayerManager.add_player_card(PlayerManager.get_active_player_id(), random_card)
      
   $PlayerTurnStateMachine.send_event("EndToStart")
   
func _on_end_state_exited() -> void:
   # Determine next player, skip any players who have been knocked out
   var current_player_id = PlayerManager.get_active_player_id()
   var next_player_id = PlayerManager.progress_active_player_to_next_player()
   
   while $GameBoard.state_manager.get_player_num_countries(next_player_id) == 0:
      next_player_id = PlayerManager.progress_active_player_to_next_player()
      assert(next_player_id != current_player_id, 
             "Could not find another player remaining except for current player: " + str(PlayerManager.get_active_player()))
      
########################################################################################################################
######################################################################################################################## End Player Turn State Machine Logic    
########################################################################################################################

func __log_phase_entered() -> void:
   if Config.TURN_PHASE_LOGGING_ENABLED:
      Logger.log_message(str(PlayerManager.get_active_player()) + 
                         " entered phase: " + 
                         TurnPhase.keys()[self.__active_turn_phase])

func __log_subphase_entered(subphase: String) -> void:
   if Config.TURN_SUBPHASE_LOGGING_ENABLED:
      Logger.log_message (str(PlayerManager.get_active_player()) + 
                          " entered subphase: " + 
                          subphase + 
                          " of phase: " + 
                          TurnPhase.keys()[self.__active_turn_phase])
