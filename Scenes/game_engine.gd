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
const __NUM_ATTACKER_DICE_KEY = "num_attack_dice"
const __NUM_DEFENDER_DICE_KEY = "num_defense_dice"
var __state_machine_metadata: Dictionary = {}

#func _init(players: Array[Types.Player]):
   #self.__players = players

func _ready():
   assert(self.__players.size() >= 2 && self.__players.size() <= 6, "Invalid player count!")
   
   self.__generate_random_deployments()
   $GameBoard.populate(self.__deployments)
   
   self.connect("turn_phase_updated", $GameBoard._on_turn_phase_updated)
   $GameBoard.connect("next_phase_requested", self._on_next_phase_requested)

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

func _on_next_phase_requested() -> void:
   if self.__local_player_index != self.__active_player_index:
      return
   
   match self.__active_turn_phase:
      Types.TurnPhase.START:
         $PlayerTurnStateMachine.send_event("StartToDeploy")
      Types.TurnPhase.DEPLOY:
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
   self.__state_machine_metadata.clear()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)

## Attack Phase ######################################################################################################## Attack Phase
func _on_attack_state_entered() -> void:
   self.__active_turn_phase = Types.TurnPhase.ATTACK
   self.__state_machine_metadata.clear()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   
## Attack (Idle) Subphase ############################################################################################## Attack (Idle) Subphase
func _on_attack_idle_state_entered() -> void:
   self.__state_machine_metadata.clear()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered subphase: " + Types.AttackTurnSubPhase.keys()[Types.AttackTurnSubPhase.IDLE] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   $GameBoard.connect("country_clicked", self._on_attack_source_country_clicked)
   
func _on_attack_idle_state_exited() -> void:
   $GameBoard.disconnect("country_clicked", self._on_attack_source_country_clicked)
   
func _on_attack_source_country_clicked(country: Types.Country, action_tag: String) -> void:
   Logger.log_message("_on_attack_source_country_selected( " + Types.Country.keys()[country] + ", " + action_tag + " )")
   
   if self.__active_player_index != self.__local_player_index:
      Logger.log_error("AttackIdle: Local player selected country, but it is not their turn")
      return
      
   if self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY):
      self.__state_machine_metadata.erase(self.__SOURCE_COUNTRY_KEY)
      
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
   $GameBoard.connect("country_clicked", self._on_attack_source_selected_country_clicked)

func _on_attack_source_selected_state_exited() -> void:
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
      $GameBoardHUD.connect("quit_requested", self._on_attack_destination_selected_quit_requested)
      $GameBoardHUD.connect("roll_requested", self._on_attack_destination_selected_roll_requested)
      
   # Max out attacker and defender dice until user says otherwise
   var max_attacker_dice_count = 0
   if ATTACKING_OCCUPATION.deployment.troop_count == 2:
      max_attacker_dice_count = 1
   elif ATTACKING_OCCUPATION.deployment.troop_count == 3:
      max_attacker_dice_count = 2
   else:
      max_attacker_dice_count = 3
      
   var max_defender_dice_count = 1
   if DEFENDING_OCCUPATION.deployment.troop_count >= 2:
      max_defender_dice_count = 2
      
   if !self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY) or self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY] > max_attacker_dice_count:
      self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY] = max_attacker_dice_count
   
   if !self.__state_machine_metadata.has(self.__NUM_DEFENDER_DICE_KEY) or self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY] > max_defender_dice_count:
      self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY] = max_defender_dice_count
   
   $GameBoardHUD.show_attack_popup(self.__active_player_index == self.__local_player_index, 
                                   ATTACKING_OCCUPATION, 
                                   DEFENDING_OCCUPATION, 
                                   self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY], 
                                   self.__state_machine_metadata[self.__NUM_DEFENDER_DICE_KEY])

func _on_attack_destination_selected_state_exited() -> void:
   if self.__active_player_index == self.__local_player_index:
      $GameBoardHUD.disconnect("quit_requested", self._on_attack_destination_selected_quit_requested)
      $GameBoardHUD.disconnect("roll_requested", self._on_attack_destination_selected_roll_requested)
      
      if $GameBoardHUD.is_attack_popup_showing():
         $GameBoardHUD.enable_attack_popup_user_inputs(false)

func _on_attack_destination_selected_state_input(event) -> void:
   if self.__active_player_index == self.__local_player_index and event.is_action_pressed(UserInput.RIGHT_CLICK_ACTION_TAG):
      if UserInput.ActionTagToInputAction[UserInput.RIGHT_CLICK_ACTION_TAG] == UserInput.InputAction.CANCEL:
         self._on_attack_destination_selected_quit_requested()
         
func _on_attack_destination_selected_quit_requested() -> void:
   $GameBoardHUD.hide_attack_popup()
   $PlayerTurnStateMachine.send_event("DestinationSelectedToSourceSelected")
   
func _on_attack_destination_selected_roll_requested() -> void:
   $PlayerTurnStateMachine.send_event("DestinationSelectedToRolling")
   
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
   var ATTACKING_PLAYER = self.__players[self.__active_player_index]
   
   Logger.log_message("Player: " + 
                      ATTACKING_PLAYER.user_name + 
                      " entered subphase: " + Types.AttackTurnSubPhase.keys()[Types.AttackTurnSubPhase.VICTORY] + 
                      " of phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
                     
   assert(self.__state_machine_metadata.has(self.__SOURCE_COUNTRY_KEY), "Source country not set previously!")
   assert(self.__state_machine_metadata.has(self.__DESTINATION_COUNTRY_KEY), "Destination country not set previously!")
   assert(self.__state_machine_metadata.has(self.__NUM_ATTACKER_DICE_KEY), "Num attacker dice not set previously!")
   
   var ATTACKING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__SOURCE_COUNTRY_KEY]
   var DEFENDING_COUNTRY: Types.Country = self.__state_machine_metadata[self.__DESTINATION_COUNTRY_KEY]
   
   var NUM_ATTACKER_DICE: int = self.__state_machine_metadata[self.__NUM_ATTACKER_DICE_KEY]
   
   self.__player_occupations[ATTACKING_PLAYER].append(DEFENDING_COUNTRY)
   self.__player_occupations[self.__deployments[DEFENDING_COUNTRY].player].erase(DEFENDING_COUNTRY)
   
   self.__deployments[ATTACKING_COUNTRY].troop_count -= NUM_ATTACKER_DICE
   self.__deployments[DEFENDING_COUNTRY].player = ATTACKING_PLAYER
   self.__deployments[DEFENDING_COUNTRY].troop_count = NUM_ATTACKER_DICE
   
   $GameBoard.set_country_deployment(ATTACKING_COUNTRY, self.__deployments[ATTACKING_COUNTRY])
   $GameBoard.set_country_deployment(DEFENDING_COUNTRY, self.__deployments[DEFENDING_COUNTRY])
   
   $PlayerTurnStateMachine.send_event("VictoryToIdle")

## Reinforce Phase ##################################################################################################### Reinforce Phase
func _on_reinforce_state_entered() -> void:
   self.__active_turn_phase = Types.TurnPhase.REINFORCE
   self.__state_machine_metadata.clear()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)

## End Phase ########################################################################################################### End Phase
func _on_end_state_entered() -> void:
   self.__active_turn_phase = Types.TurnPhase.END
   self.__state_machine_metadata.clear()
   
   Logger.log_message("Player: " + 
                      self.__players[self.__active_player_index].user_name + 
                      " entered phase: " + 
                      Types.TurnPhase.keys()[self.__active_turn_phase])
   
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   $PlayerTurnStateMachine.send_event("EndToStart")

########################################################################################################################
