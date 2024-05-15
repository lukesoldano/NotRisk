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

var __player: Player = null

var __desired_deployments: Dictionary = {}

# TODO: Remove, temp logic
const NUM_UNIQUE_ATTACKS_TO_MAKE = 3
var current_num_unique_attacks_made = 0
#

func _init(player: Player) -> void:
   self.__player = player

func determine_desired_deployments(player_occupations: Dictionary, 
                                   _deployments: Dictionary, 
                                   num_reinforcements: int) -> void:
                                    
   Logger.log_message("AI: determine_deployments()")
   
   assert(player_occupations.has(self.__player), "Player assigned to this player controller not present in player_occupations map!")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = player_occupations[self.__player]
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   
   # Randomly assign units to countries this player occupies
   for i in range(0, num_reinforcements):
      var country = CURRENTLY_OCCUPIED_COUNTRIES[randi() % CURRENTLY_OCCUPIED_COUNTRIES.size()]
      if __desired_deployments.has(country):
         __desired_deployments[country] += 1
      else:
         __desired_deployments[country] = 1

# Returns true if moves to be made, false if no further moves desired
func handle_deploy_state_idle(select_deployment_country_callable: Callable) -> bool:
   Logger.log_message("AI: handle_deploy_state_idle()")
   
   if self.__desired_deployments.is_empty():
      return false
      
   # Deploy to the first entry in the list then return
   for country in self.__desired_deployments:
      select_deployment_country_callable.call_deferred(country)
      break
      
   return true

func handle_deploy_state_deploying(select_deployment_count_callable: Callable, 
                                   country: Types.Country) -> void:
                                    
   Logger.log_message("AI: handle_deploy_state_deploying()")
   
   assert(self.__desired_deployments.has(country), "Invalid deployment country provided to PlayerController")
   
   select_deployment_count_callable.call_deferred(self.__desired_deployments[country])
   self.__desired_deployments.erase(country)

# Returns true if moves to be made, false if no further moves desired
func handle_attack_state_idle(select_attack_source_country_callable: Callable,
                              get_countries_that_neighbor_callable: Callable, 
                              player_occupations: Dictionary, 
                              deployments: Dictionary) -> bool:
                                 
   Logger.log_message("AI: handle_attack_state_idle()")
   
   assert(player_occupations.has(self.__player), "Player assigned to this player controller not present in player_occupations map!")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = player_occupations[self.__player]
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   
   # TODO: Remove - temp logic
   if self.NUM_UNIQUE_ATTACKS_TO_MAKE == self.current_num_unique_attacks_made:
      self.current_num_unique_attacks_made = 0
      return false
   #
      
   # Select country to attack from, iterate through list until a valid country is found
   var source_country = null
   for country in CURRENTLY_OCCUPIED_COUNTRIES:
      assert(deployments.has(country), "Occupied country does not exist in deployments map!")
      
      var COUNTRY_DEPLOYMENT = deployments[country]
      if COUNTRY_DEPLOYMENT.troop_count > 1:
         for neighboring_country in get_countries_that_neighbor_callable.call(country):
            if !CURRENTLY_OCCUPIED_COUNTRIES.has(neighboring_country):
               source_country = country
               break
               
      if source_country != null:
         break
         
   if source_country != null:
      self.current_num_unique_attacks_made += 1
      select_attack_source_country_callable.call_deferred(source_country)
      
   return source_country != null
   
func handle_attack_state_source_selected(select_attack_destination_country_callable: Callable,
                                         get_countries_that_neighbor_callable: Callable, 
                                         source_country: Types.Country,
                                         player_occupations: Dictionary, 
                                         deployments: Dictionary) -> void:
                                 
   Logger.log_message("AI: handle_attack_state_source_selected()")
   
   assert(player_occupations.has(self.__player), "Player assigned to this player controller not present in player_occupations map!")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = player_occupations[self.__player]
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   assert(CURRENTLY_OCCUPIED_COUNTRIES.has(source_country), "Player assigned to this player controller does not own the provided source_country!")
   assert(deployments.has(source_country), "Deployments map does not contain source_country!")
   assert(deployments[source_country].troop_count > 1, "source_country does not contain enough troops to attack with!")
   
   var destination_country = null
   for neighboring_country in get_countries_that_neighbor_callable.call(source_country):
      if !CURRENTLY_OCCUPIED_COUNTRIES.has(neighboring_country):
         destination_country = neighboring_country
         break
         
   assert(destination_country != null, "Could not find neighboring country to attack with given source_country!")
   
   select_attack_destination_country_callable.call_deferred(destination_country)
   
func handle_attack_state_destination_selected(set_die_count_and_roll_callable: Callable,
                                              source_country: Types.Country,
                                              destination_country: Types.Country,
                                              player_occupations: Dictionary, 
                                              deployments: Dictionary) -> void:
                                 
   Logger.log_message("AI: handle_attack_state_destination_selected()")
   
   assert(player_occupations.has(self.__player), "Player assigned to this player controller not present in player_occupations map!")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = player_occupations[self.__player]
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   assert(CURRENTLY_OCCUPIED_COUNTRIES.has(source_country), "Player assigned to this player controller does not own the provided source_country!")
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.has(destination_country), "Player assigned to this player controller already owns the provided destination_country!")
   assert(deployments.has(source_country), "Deployments map does not contain source_country!")
   assert(deployments[source_country].troop_count > 1, "source_country does not contain enough troops to attack with!")
   assert(deployments.has(destination_country), "Deployments map does not contain destination_country!")
   
   # This is all temporary logic, but we are going to attack until we win or can't fight anymore
   set_die_count_and_roll_callable.call_deferred(Utilities.get_max_attacker_die_count_for_troop_count(deployments[source_country].troop_count))
   
func handle_attack_state_victory(set_troop_count_and_confirm_callable: Callable,
                                 source_country: Types.Country,
                                 _destination_country: Types.Country,
                                 player_occupations: Dictionary, 
                                 deployments: Dictionary) -> void:
                                    
   Logger.log_message("AI: handle_attack_state_victory()")
   
   assert(player_occupations.has(self.__player), "Player assigned to this player controller not present in player_occupations map!")
   
   var CURRENTLY_OCCUPIED_COUNTRIES: Array = player_occupations[self.__player]
   
   assert(!CURRENTLY_OCCUPIED_COUNTRIES.is_empty(), "Player assigned to this player controller doesn't own any countries!")
   assert(CURRENTLY_OCCUPIED_COUNTRIES.has(source_country), "Player assigned to this player controller does not own the provided source_country!")
   assert(deployments.has(source_country), "Deployments map does not contain source_country!")
   
   # This is all temporary logic, but we are going to move the max armies possible
   set_troop_count_and_confirm_callable.call_deferred(deployments[source_country].troop_count - 1)

# Returns true if moves to be made, false if no further moves desired
func handle_reinforce_state_idle() -> bool:
   Logger.log_message("AI: handle_reinforce_state_idle()")
   return false
