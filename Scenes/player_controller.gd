extends Node2D

class_name PlayerController

########################################################################################################################
# TODO: Short Term
#
# 
#
# TODO: Long Term
#
# TODO: Make logic for deploy, attack, and reinforce smarter (reinforce currently does nothing)
# TODO: Add weights to create personas for the player controller that can be used in helping make decisions
# 
########################################################################################################################

var __player_id: int = Constants.INVALID_ID

# key: CountryId, value: TroopCount
var __desired_deployments: Dictionary[int, int] = {}

# TODO: Remove, temp logic
const NUM_UNIQUE_ATTACKS_TO_MAKE = 3
var current_num_unique_attacks_made = 0
#

func _init(player_id: int) -> void:
   assert(player_id != Constants.INVALID_ID, "Invalid player id provided to player controller!")
   self.__player_id = player_id

func determine_desired_deployments(game_board_state_manager: GameBoardStateManager, num_reinforcements: int) -> void:
                                    
   Logger.log_message("AI: determine_deployments()")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = game_board_state_manager.get_player_countries(self.__player_id)
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   
   # Randomly assign units to countries this player occupies
   for i in range(0, num_reinforcements):
      var country_id = CURRENTLY_OCCUPIED_COUNTRIES[randi() % CURRENTLY_OCCUPIED_COUNTRIES.size()]
      if self.__desired_deployments.has(country_id):
         self.__desired_deployments[country_id] += 1
      else:
         self.__desired_deployments[country_id] = 1

# Returns true if moves to be made, false if no further moves desired
func handle_deploy_state_idle(select_deployment_country_callable: Callable) -> bool:
   Logger.log_message("AI: handle_deploy_state_idle()")
   
   if self.__desired_deployments.is_empty():
      return false
      
   # Deploy to the first entry in the list then return
   for country_id in self.__desired_deployments:
      select_deployment_country_callable.call_deferred(country_id)
      break
      
   return true

func handle_deploy_state_deploying(select_deployment_count_callable: Callable, country_id: int) -> void:
                                    
   Logger.log_message("AI: handle_deploy_state_deploying()")
   
   assert(self.__desired_deployments.has(country_id), "Invalid deployment country_id provided to PlayerController")
   
   select_deployment_count_callable.call_deferred(self.__desired_deployments[country_id])
   self.__desired_deployments.erase(country_id)

# Returns true if moves to be made, false if no further moves desired
func handle_attack_state_idle(select_attack_source_country_callable: Callable,
                              get_countries_that_neighbor_callable: Callable, 
                              game_board_state_manager: GameBoardStateManager) -> bool:
                                 
   Logger.log_message("AI: handle_attack_state_idle()")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = game_board_state_manager.get_player_countries(self.__player_id)
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   
   # TODO: Remove - temp logic
   if self.NUM_UNIQUE_ATTACKS_TO_MAKE == self.current_num_unique_attacks_made:
      self.current_num_unique_attacks_made = 0
      return false
   #
      
   # Select country to attack from, iterate through list until a valid country is found
   var source_country_id = null
   for country_id in CURRENTLY_OCCUPIED_COUNTRIES:
      var COUNTRY_DEPLOYMENT: Types.Deployment = game_board_state_manager.get_deployment_for_country(country_id)
      if COUNTRY_DEPLOYMENT.troop_count > 1:
         for neighboring_country_id in get_countries_that_neighbor_callable.call(country_id):
            if !CURRENTLY_OCCUPIED_COUNTRIES.has(neighboring_country_id):
               source_country_id = country_id
               break
               
      if source_country_id != null:
         break
         
   if source_country_id != null:
      self.current_num_unique_attacks_made += 1
      select_attack_source_country_callable.call_deferred(source_country_id)
      
   return source_country_id != null
   
func handle_attack_state_source_selected(select_attack_destination_country_callable: Callable,
                                         get_countries_that_neighbor_callable: Callable, 
                                         source_country_id: int,
                                         game_board_state_manager: GameBoardStateManager) -> void:
                                 
   Logger.log_message("AI: handle_attack_state_source_selected()")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = game_board_state_manager.get_player_countries(self.__player_id)
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   assert(CURRENTLY_OCCUPIED_COUNTRIES.has(source_country_id), "Player assigned to this player controller does not own the provided source_country!")
   
   var destination_country_id = null
   for neighboring_country_id in get_countries_that_neighbor_callable.call(source_country_id):
      if !CURRENTLY_OCCUPIED_COUNTRIES.has(neighboring_country_id):
         destination_country_id = neighboring_country_id
         break
         
   assert(destination_country_id != null, "Could not find neighboring country to attack with given source_country_id!")
   
   select_attack_destination_country_callable.call_deferred(destination_country_id)
   
func handle_attack_state_destination_selected(set_die_count_and_roll_callable: Callable,
                                              source_country_id: int,
                                              destination_country_id: int,
                                              game_board_state_manager: GameBoardStateManager) -> void:
                                 
   Logger.log_message("AI: handle_attack_state_destination_selected()")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = game_board_state_manager.get_player_countries(self.__player_id)
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   assert(CURRENTLY_OCCUPIED_COUNTRIES.has(source_country_id), "Player assigned to this player controller does not own the provided source_country_id!")
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.has(destination_country_id), "Player assigned to this player controller already owns the provided destination_country_id!")
   
   # This is all temporary logic, but we are going to attack until we win or can't fight anymore
   set_die_count_and_roll_callable.call_deferred(
      Utilities.get_max_attacker_die_count_for_troop_count(
         game_board_state_manager.get_deployment_for_country(source_country_id).troop_count
      )
   )
   
func handle_attack_state_victory(set_troop_count_and_confirm_callable: Callable,
                                 source_country_id: int,
                                 _destination_country_id: int,
                                 game_board_state_manager: GameBoardStateManager) -> void:
                                    
   Logger.log_message("AI: handle_attack_state_victory()")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = game_board_state_manager.get_player_countries(self.__player_id)
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   assert(CURRENTLY_OCCUPIED_COUNTRIES.has(source_country_id), "Player assigned to this player controller does not own the provided source_country!")
   
   # This is all temporary logic, but we are going to move the max armies possible
   set_troop_count_and_confirm_callable.call_deferred(
      game_board_state_manager.get_deployment_for_country(source_country_id).troop_count - 1
   )

# Returns true if moves to be made, false if no further moves desired
func handle_reinforce_state_idle() -> bool:
   Logger.log_message("AI: handle_reinforce_state_idle()")
   return false
