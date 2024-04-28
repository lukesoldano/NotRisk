@icon("res://Assets/NodeIcons/GameEngine.svg")

extends Node

class_name GameEngine

signal turn_phase_updated(player: Types.Player, phase: Types.TurnPhase)

var __local_player_index: int = 0
var __active_player_index: int = -1
var __active_turn_phase: Types.TurnPhase = Types.TurnPhase.START

var __players: Array = [
   Types.Player.new("Luke", Color.RED),
   Types.Player.new("Ben", Color.AQUA),
   Types.Player.new("Sam", Color.GREEN),
   Types.Player.new("Dennis", Color.YELLOW),
   Types.Player.new("Austin", Color.PURPLE)
]

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
var __state_machine_metadata: Dictionary = {}

#func _init(players: Array[Types.Player]):
   #self.__players = players

func _ready():
   assert(self.__players.size() >= 2 && self.__players.size() <= 6, "Invalid player count!")
   
   self.__generate_random_deployments()
   self.__log_deployments()
   $GameBoard.populate(self.__deployments)
   
   self.connect("turn_phase_updated", $GameBoard._on_turn_phase_updated)
   $GameBoard.connect("next_phase_requested", self._on_next_phase_requested)
   
func __log_deployments() -> void:
   Logger.log_message("-----------------------------------------------------------------------------------------------")
   Logger.log_message("CURRENT DEPLOYMENTS: ")
   for player in self.__players:
      Logger.log_indented_message(1, "Player: " + player.user_name)
      for occupied_country in self.__player_occupations[player]:
         Logger.log_indented_message(2, "Country: " + Types.Country.keys()[occupied_country] + " Troops: " + str(self.__deployments[occupied_country].troop_count))
   Logger.log_message("-----------------------------------------------------------------------------------------------")

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
    
########################################################################################################################
## State Machine Logic ################################################################################################# Start State Machine Logic     
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
      Types.TurnPhase.START:
         $PlayerTurnStateMachine.send_event("StartToDeploy")
         
      Types.TurnPhase.DEPLOY:
         assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
         
         var REINFORCEMENTS_REMAINING: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
         if REINFORCEMENTS_REMAINING != 0:
            Logger.log_error("_on_next_phase_requested: Local player requested next phase from deploy phase, but reinforcements remaining: " + 
                             str(REINFORCEMENTS_REMAINING) + 
                             " does not equal zero")
            return
            
         $PlayerTurnStateMachine.send_event("DeployToAttack")
         
      Types.TurnPhase.ATTACK:
         $PlayerTurnStateMachine.send_event("AttackToReinforce")
      Types.TurnPhase.REINFORCE:
         $PlayerTurnStateMachine.send_event("ReinforceToEnd")
      Types.TurnPhase.END:
         $PlayerTurnStateMachine.send_event("EndToStart")
      _:
         assert(false, "Invalid active turn phase!")

## Start Phase ######################################################################################################### Start Phase
func _on_start_state_entered() -> void:
   self.__active_player_index = (self.__active_player_index + 1) % self.__players.size()
   self.__active_turn_phase = Types.TurnPhase.START
   
   # CLEAR ALL METADATA as we are entering a new player's turn
   self.__state_machine_metadata.clear()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   $PlayerTurnStateMachine.send_event("StartToDeploy")

## Deploy Phase ######################################################################################################## Deploy Phase
func _on_deploy_state_entered() -> void:
   self.__active_turn_phase = Types.TurnPhase.DEPLOY
   self.__clear_interphase_state_machine_metadata()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
   self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY] = Utilities.get_num_reinforcements_earned($GameBoard.CONTINENTS, $GameBoard.CONTINENT_BONUSES, self.__player_occupations[self.__players[self.__active_player_index]])
   
   $GameBoardHUD.show_deploy_reinforcements_remaining(self.__players[self.__active_player_index], self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   
func _on_deploy_state_exited() -> void:
   $GameBoardHUD.hide_deploy_reinforcements_remaining()
   
# TODO: Playing cards logic 
   
## Deploy (Idle) Subphase ############################################################################################## Deploy (Idle) Subphase
func _on_deploy_idle_state_entered() -> void:
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.DeployTurnSubPhase.keys()[Types.DeployTurnSubPhase.IDLE] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_deploy_idle_country_clicked)
   
func _on_deploy_idle_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.disconnect("country_clicked", self._on_deploy_idle_country_clicked)
      
func _on_deploy_idle_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_deploy_idle_country_clicked( " + Types.Country.keys()[country] + ", " + action_tag + " )")
   
   assert(self.__state_machine_metadata.has(self.__REINFORCEMENTS_REMAINING_KEY), "Deploy reinforcements not set previously!")
   
   var REINFORCEMENTS_REMAINING: int = self.__state_machine_metadata[self.__REINFORCEMENTS_REMAINING_KEY]
      
   if !self.__player_occupations[self.__players[self.__local_player_index]].has(country):
      Logger.log_error("DeployIdle: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not own it")
      return
   
   if REINFORCEMENTS_REMAINING <= 0:
      Logger.log_error("DeployIdle: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not have any reinforcements remaining")
      return
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("IdleToDeploying")
   
## Deploy (Deploying) Subphase ######################################################################################### Deploy (Deploying) Subphase
func _on_deploy_deploying_state_entered() -> void:
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.DeployTurnSubPhase.keys()[Types.DeployTurnSubPhase.DEPLOYING] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
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
      return
      
   self.__state_machine_metadata[self.__NUM_UNITS_KEY] = new_troop_count
   
   $GameBoardHUD.show_deploy_popup(self.__active_player_index == self.__local_player_index, 
                                   self.__players[self.__active_player_index], 
                                   DEPLOY_COUNTRY, 
                                   new_troop_count, 
                                   REINFORCEMENTS_REMAINING)
   
## Attack Phase ######################################################################################################## Attack Phase
func _on_attack_state_entered() -> void:
   self.__active_turn_phase = Types.TurnPhase.ATTACK
   self.__clear_interphase_state_machine_metadata()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   
## Attack (Idle) Subphase ############################################################################################## Attack (Idle) Subphase
func _on_attack_idle_state_entered() -> void:
   self.__clear_interphase_state_machine_metadata()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.AttackTurnSubPhase.keys()[Types.AttackTurnSubPhase.IDLE] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_attack_source_country_clicked)
   
func _on_attack_idle_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.disconnect("country_clicked", self._on_attack_source_country_clicked)
   
func _on_attack_source_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_attack_source_country_selected( " + Types.Country.keys()[country] + ", " + action_tag + " )")
      
   if !self.__player_occupations[self.__players[self.__local_player_index]].has(country):
      Logger.log_error("AttackIdle: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not own it")
      return
      
   if self.__deployments[country].troop_count < 2:
      Logger.log_error("AttackIdle: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not have enough attackers")
      return
      
   self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("IdleToSourceSelected")
   
## Attack (Source Selected) Subphase ################################################################################### Attack (Source Selected) Subphase
func _on_attack_source_selected_state_entered() -> void:
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.AttackTurnSubPhase.keys()[Types.AttackTurnSubPhase.SOURCE_SELECTED] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_attack_source_selected_country_clicked)

func _on_attack_source_selected_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.disconnect("country_clicked", self._on_attack_source_selected_country_clicked)
   
func _on_attack_source_selected_state_input(event: InputEvent) -> void:
   if self.__active_player_index == self.__local_player_index and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         $PlayerTurnStateMachine.send_event("SourceSelectedToIdle")
   
func _on_attack_source_selected_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_attack_destination_country_selected( " + Types.Country.keys()[country] + ", " + action_tag + " )")
   
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   var SOURCE_COUNTRY = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   
   if self.__active_player_index != self.__local_player_index:
      Logger.log_error("AttackSourceSelected: Local player selected country, but it is not their turn")
      return
      
   if self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY):
      self.__state_machine_metadata.erase(self.__DESTINATION_COUNTRY_KEY)
      
   if self.__player_occupations[self.__players[self.__local_player_index]].has(country):
      Logger.log_error("AttackSourceSelected: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do already own it")
      return
      
   if !$GameBoard.countries_are_neighbors(SOURCE_COUNTRY, country):
      Logger.log_error("AttackSourceSelected: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but it does not neighbor: " +
                       Types.Country.keys()[SOURCE_COUNTRY])
      return
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("SourceSelectedToDestinationSelected")
   
## Attack (Destination Selected) Subphase ############################################################################## Attack (Destination Selected) Subphase
func _on_attack_destination_selected_state_entered() -> void:
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.AttackTurnSubPhase.keys()[Types.AttackTurnSubPhase.DESTINATION_SELECTED] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
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
   
## Attack (Rolling) Subphase ########################################################################################### Attack (Rolling) Subphase
func _on_attack_rolling_state_entered() -> void:
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.AttackTurnSubPhase.keys()[Types.AttackTurnSubPhase.ROLLING] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_DEFENDER_DICE_KEY), "Num defender dice not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_ATTACKER_DICE: int = self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY]
   var NUM_DEFENDER_DICE: int = self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY]
   
   Logger.log_message("Player: " +
                      self.__players[self.__active_player_index].user_name +
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
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.AttackTurnSubPhase.keys()[Types.AttackTurnSubPhase.VICTORY] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
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
                                              Types.TroopMovementType.POST_VICTORY,
                                              Types.Occupation.new(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY]), 
                                              DEFENDING_COUNTRY, 
                                              NUM_ATTACKER_DICE,
                                              NUM_ATTACKER_DICE,
                                              self.__deployments[ATTACKING_COUNTRY].troop_count - 1)
   else:
      self.__attack_victory_move_conquering_armies()
      $PlayerTurnStateMachine.send_event("VictoryToIdle")
   
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
                                           Types.TroopMovementType.POST_VICTORY,
                                           Types.Occupation.new(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY]), 
                                           DEFENDING_COUNTRY, 
                                           new_troop_count,
                                           NUM_ATTACKER_DICE,
                                           self.__deployments[ATTACKING_COUNTRY].troop_count - 1)
   
func _on_attack_victory_troop_movement_confirm_requested() -> void:
   self.__attack_victory_move_conquering_armies()
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

## Reinforce Phase ##################################################################################################### Reinforce Phase
func _on_reinforce_state_entered() -> void:
   self.__active_turn_phase = Types.TurnPhase.REINFORCE
   self.__clear_interphase_state_machine_metadata()
   
   self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED] = 0
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   
## Reinforce (Idle) Subphase ########################################################################################### Reinforce (Idle) Subphase
func _on_reinforce_idle_state_entered() -> void:
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.ReinforceTurnSubPhase.keys()[Types.ReinforceTurnSubPhase.IDLE] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
   if self.__active_player_index == self.__local_player_index:
      $GameBoard.connect("country_clicked", self._on_reinforce_source_country_clicked)
      
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
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.ReinforceTurnSubPhase.keys()[Types.ReinforceTurnSubPhase.SOURCE_SELECTED] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
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
      
   if !self.__player_occupations[self.__players[self.__local_player_index]].has(country):
      Logger.log_error("ReinforceSourceSelected: Local player selected country: " + 
                       Types.Country.keys()[country] + 
                       ", but they do not own it")
      return
      
   # TODO: Verify that countries are connected via player occupied countries
      
   self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY] = country
   
   $PlayerTurnStateMachine.send_event("SourceSelectedToDestinationSelected")

## Reinforce (Destination Selected) Subphase ########################################################################### Reinforce (Destination Selected) Subphase
func _on_reinforce_destination_selected_state_entered() -> void:
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.ReinforceTurnSubPhase.keys()[Types.ReinforceTurnSubPhase.DESTINATION_SELECTED] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
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
                                             Types.TroopMovementType.REINFORCE,
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
                                           Types.TroopMovementType.REINFORCE,
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
   
   var ACTIVE_PLAYER = self.__players[self.__active_player_index]
   
   self.__deployments[SOURCE_COUNTRY].troop_count -= NUM_TROOPS_TO_MOVE
   self.__deployments[DESTINATION_COUNTRY].troop_count += NUM_TROOPS_TO_MOVE
   
   $GameBoard.set_country_deployment(SOURCE_COUNTRY, self.__deployments[SOURCE_COUNTRY])
   $GameBoard.set_country_deployment(DESTINATION_COUNTRY, self.__deployments[DESTINATION_COUNTRY])
   
   self.__state_machine_metadata[self.__NUM_REINFORCE_MOVEMENTS_UTILIZED] += 1
   
   $PlayerTurnStateMachine.send_event("DestinationSelectedToIdle")

## End Phase ########################################################################################################### End Phase
func _on_end_state_entered() -> void:
   self.__active_turn_phase = Types.TurnPhase.END
   self.__clear_interphase_state_machine_metadata()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
   # TODO: Logic to give user a card if countries captured > 0
                     
   self.__log_deployments()
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   $PlayerTurnStateMachine.send_event("EndToStart")

########################################################################################################################
########################################################################################################################
