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

func initialize_with_random_deployments(player_ids: Array[int]) -> bool:
   assert(player_ids.size() >= 2, "Invalid player count provided to GameBoardManager::initialize_with_random_deployments()")
   for player_id in player_ids:
      assert(player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardManager::initialize_with_random_deployments()")
   
   self.__country_deployments.clear()
   self.__player_countries.clear()
   self.__player_troop_counts.clear()
   
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
            
   ## Now reinforce owned countries
   for player_id in player_ids:
      while remaining_troop_count[player_id] > 0:
         self.__country_deployments[self.__player_countries[player_id][randi() % self.__player_countries[player_id].size()]].troop_count += 1
         remaining_troop_count[player_id] -= 1
         
   return true

func get_player_countries(player_id: int) -> Array[int]:
   assert(player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::get_player_countries()")
   assert(self.__player_countries.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_countries()")
   assert(self.__player_troop_counts.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_countries()")
   
   return self.__player_countries[player_id].duplicate()
   
func get_player_countries_count(player_id: int) -> int:
   assert(player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::get_player_countries_count()")
   assert(self.__player_countries.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_countries_count()")
   assert(self.__player_troop_counts.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_countries_count()")
   
   return self.__player_countries[player_id].size()

func get_player_troop_count(player_id: int) -> int:
   assert(player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::get_player_troop_count()")
   assert(self.__player_countries.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_troop_count()")
   assert(self.__player_troop_counts.has(player_id), "Unknown player id provided to GameBoardStateManager::get_player_troop_count()")
   
   return self.__player_troop_counts[player_id]
   
func update_deployment(country_id: int, new_deployment: Types.Deployment) -> bool:
   assert(country_id != Constants.INVALID_ID, "Invalid country id provided to GameBoardStateManager::update_deployment()")
   assert(new_deployment.player_id != Constants.INVALID_ID, "Invalid player id provided to GameBoardStateManager::update_deployment()")
   assert(new_deployment.troop_count > 0, "Invalid troop count provided to GameBoardStateManager::update_deployment()")
   
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
