extends Object

class_name GameBoardStateManager

########################################################################################################################
# TODO: Short Term
#
# TODO: Use a PlayerManager to validate players and a GameBoardGeographyManager to provide and validate countries
#
# TODO: Long Term
#
# 
########################################################################################################################

signal country_occupation_update(country_id: int, old_deployment: Types.Deployment, new_deployment: Types.Deployment)

# key = CountryId, value = Deployment
var __country_deployments: Dictionary[int, Types.Deployment] = {}

# key = PlayerId, value = Array[CountryId (int)]
var __player_countries: Dictionary[int, Array] = {}

# key = PlayerId, value = TroopCount
var __player_troop_counts: Dictionary[int, int] = {}

########################################################################################################################

func initialize_with_random_deployments() -> bool:   
   self.__country_deployments.clear()
   self.__player_countries.clear()
   self.__player_troop_counts.clear()
   
   var player_ids = PlayerManager.get_all_player_ids()
   
   var remaining_troop_count: Dictionary[int, int] = {}
   for player_id in player_ids:
      self.__player_countries[player_id] = []
      self.__player_troop_counts[player_id] = Constants.STARTING_TROOP_COUNTS[player_ids.size()]
      remaining_troop_count[player_id] = Constants.STARTING_TROOP_COUNTS[player_ids.size()]
   
   # First assign countries
   var NUM_COUNTRIES = Types.Country.size()
   var num_countries_assigned = 0
   
   while num_countries_assigned != NUM_COUNTRIES:
      for player_id in player_ids:
         var country_id = randi() % NUM_COUNTRIES
         while self.__country_deployments.has(country_id):
            country_id = randi() % NUM_COUNTRIES
         
         self.__player_countries[player_id].append(country_id)
         self.__country_deployments[country_id] = Types.Deployment.new(player_id, 1)
      
         num_countries_assigned += 1
         remaining_troop_count[player_id] -= 1
         assert(remaining_troop_count[player_id] >= 0, "Over-assigned troops in country selection!")
      
         if num_countries_assigned == NUM_COUNTRIES:
            break
            
   # Now reinforce owned countries
   for player_id in player_ids:
      while remaining_troop_count[player_id] > 0:
         self.__country_deployments[self.__player_countries[player_id][randi() % self.__player_countries[player_id].size()]].troop_count += 1
         remaining_troop_count[player_id] -= 1
         
   # Notify susbcribers of initialized values
   for country_id in self.__country_deployments:
      var null_deployment := Types.Deployment.new(Constants.INVALID_ID , 0)
      self.country_occupation_update.emit(country_id, null_deployment, self.__country_deployments[country_id].duplicate())
         
   self.__log_country_deployments()
         
   return true
   
func add_troops_to_deployment(country_id: int, troops_to_add: int) -> bool:
   assert(country_id != Constants.INVALID_ID, "Invalid country id provided to GameBoardStateManager::add_troops_to_deployment()")
   assert(troops_to_add > 0, "Invalid troop count provided to GameBoardStateManager::add_troops_to_deployment()")
   assert(self.__country_deployments.has(country_id), "Invalid country id provided to GameBoardStateManager::add_troops_to_deployment()")
   
   var updated_deployment = self.__country_deployments[country_id].duplicate()
   updated_deployment.troop_count += troops_to_add
   
   return self.update_deployment(country_id, updated_deployment)
   
func remove_troops_from_deployment(country_id: int, troops_to_remove: int) -> bool:
   assert(country_id != Constants.INVALID_ID, "Invalid country id provided to GameBoardStateManager::remove_troops_from_deployment()")
   assert(troops_to_remove > 0, "Invalid troop count provided to GameBoardStateManager::remove_troops_from_deployment()")
   assert(self.__country_deployments.has(country_id), "Invalid country id provided to GameBoardStateManager::remove_troops_from_deployment()")
   assert(self.__country_deployments[country_id].troop_count >= troops_to_remove, "Invalid troops_to_remove (must be less than total troop count in deployment) provided to GameBoardStateManager::remove_troops_from_deployment()")
   
   var updated_deployment = self.__country_deployments[country_id].duplicate()
   updated_deployment.troop_count -= troops_to_remove
   
   return self.update_deployment(country_id, updated_deployment)
   
func update_deployment(country_id: int, new_deployment: Types.Deployment) -> bool:
   assert(country_id != Constants.INVALID_ID, "Invalid country id provided to GameBoardStateManager::update_deployment()")
   assert(new_deployment.player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::update_deployment()")
   assert(new_deployment.troop_count >= 0, "Invalid troop count provided to GameBoardStateManager::update_deployment()")
   
   assert(self.__player_countries.has(new_deployment.player_id), "Unknown player id provided to GameBoardStateManager::update_deployment()")
   assert(self.__player_troop_counts.has(new_deployment.player_id), "Unknown player id provided to GameBoardStateManager::update_deployment()")
   assert(self.__country_deployments.has(country_id), "Invalid country id provided to GameBoardStateManager::update_deployment()")
   
   var OLD_DEPLOYMENT = self.__country_deployments[country_id]
   if new_deployment == OLD_DEPLOYMENT:
      return true
      
   self.__country_deployments[country_id] = new_deployment
   
   # Look out world, this country has a new owner
   if OLD_DEPLOYMENT.player_id != new_deployment.player_id:
      self.__player_countries[OLD_DEPLOYMENT.player_id].erase(country_id)
      self.__player_countries[new_deployment.player_id].append(country_id)
      
      self.__player_troop_counts[OLD_DEPLOYMENT.player_id] -= OLD_DEPLOYMENT.troop_count
      self.__player_troop_counts[new_deployment.player_id] += new_deployment.troop_count
      
   else: # Same owner, different day
      self.__player_troop_counts[new_deployment.player_id] += (new_deployment.troop_count - OLD_DEPLOYMENT.troop_count)
      
   self.country_occupation_update.emit(country_id, OLD_DEPLOYMENT, new_deployment)
   
   return true

# TODO: Should I not return duplicate here? Don't want users to edit this, but refs are more efficient if passed a lot   
func get_country_deployments() -> Dictionary[int, Types.Deployment]:
   return self.__country_deployments.duplicate()
   
func get_deployment_for_country(country_id: int) -> Types.Deployment:
   assert(self.__country_deployments.has(country_id), "Invalid country id provided to GameBoardStateManager::get_deployment_for_country()")
   
   return self.__country_deployments[country_id].duplicate()
   
func get_num_troops_deployed_to_country(country_id: int) -> int:
   assert(self.__country_deployments.has(country_id), "Invalid country id provided to GameBoardStateManager::get_deployment_for_country()")
   
   return self.__country_deployments[country_id].troop_count

# TODO: Should I not return duplicate here? Don't want users to edit this, but refs are more efficient if passed a lot
func get_player_countries(player_id: int) -> Array:
   assert(player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::get_player_countries()")
   assert(self.__player_countries.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_countries()")
   assert(self.__player_troop_counts.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_countries()")
   
   return self.__player_countries[player_id].duplicate()
   
func player_occupies_country(player_id: int, country_id: int) -> bool:
   assert(player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::player_occupies_country()")
   assert(self.__player_countries.has(player_id), "Unknown player id provided to GameBoardStateManager::player_occupies_country()")
   
   assert(country_id != Constants.INVALID_ID, "Invalid country id provided to GameBoardStateManager::player_occupies_country()")
   assert(self.__country_deployments.has(country_id), "Invalid country id provided to GameBoardStateManager::player_occupies_country()")
   
   return self.__player_countries[player_id].has(country_id)
   
func who_owns_country(country_id: int) -> int:
   assert(country_id != Constants.INVALID_ID, "Invalid country id provided to GameBoardStateManager::player_occupies_country()")
   assert(self.__country_deployments.has(country_id), "Invalid country id provided to GameBoardStateManager::player_occupies_country()")
   
   return self.__country_deployments[country_id].player_id
   
func num_players_with_nonzero_countries() -> int:
   var count: int = 0
   for player_id in self.__player_countries:
      count += (1 if self.__player_countries[player_id].size() > 0 else 0)
   return count
   
func get_player_num_countries(player_id: int) -> int:
   assert(player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::get_player_num_countries()")
   assert(self.__player_countries.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_num_countries()")
   
   return self.__player_countries[player_id].size()
   
func get_player_troop_count(player_id: int) -> int:
   assert(player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::get_player_troop_count()")
   assert(self.__player_countries.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_troop_count()")
   assert(self.__player_troop_counts.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_troop_count()")
   
   return self.__player_troop_counts[player_id]

func __log_country_deployments() -> void:
   if Config.DEPLOYMENT_LOGGING_ENABLED:
      Logger.log_message("-----------------------------------------------------------------------------------------------")
      Logger.log_message("CURRENT DEPLOYMENTS: ")
      for player_id in PlayerManager.get_all_player_ids():
         Logger.log_indented_message(1, str(PlayerManager.get_player_for_id(player_id)))
         for occupied_country in self.__player_countries[player_id]:
            Logger.log_indented_message(2, "Country: " + Types.Country.keys()[occupied_country] + " Troops: " + str(self.__country_deployments[occupied_country].troop_count))
      Logger.log_message("-----------------------------------------------------------------------------------------------")
