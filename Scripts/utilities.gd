extends Node

class_name Utilities

# Assumes countries_occupied is an array with unique entries
static func get_num_reinforcements_earned(continents: Dictionary, continent_bonuses: Dictionary, countries_occupied: Array) -> int:
   # Casting to floats removes integer division warning
   var num_reinforcements: int = floor(float(countries_occupied.size()) / float(Constants.COUNTRY_REINFORCEMENTS_DIVISOR))
   num_reinforcements = max(Constants.MIN_NUM_REINFORCEMENTS, num_reinforcements)
   
   # Check for continent bonuses (Ugliest way possible)
   for continent in continents:
      if countries_occupied.size() >= continents[continent].size():
         var num = 0
         for country in continents[continent]:
            if !countries_occupied.has(country):
               break
            num += 1
            
         if num == continents[continent].size():
            assert(continent_bonuses.has(continent), "Continent bonuses array does not contain all continents")
            num_reinforcements += continent_bonuses[continent]
            
   return num_reinforcements

static func get_max_attacker_die_count_for_troop_count(troop_count: int) -> int:
   assert(troop_count > 1, "Invalid troop count provided!")
   if troop_count > Constants.MAX_NUM_ATTACK_DIE:
      return Constants.MAX_NUM_ATTACK_DIE
   return troop_count - 1

static func get_max_defender_die_count_for_troop_count(troop_count: int) -> int:
   assert(troop_count > 0, "Invalid troop count provided!")
   if troop_count > Constants.MAX_NUM_DEFEND_DIE:
      return Constants.MAX_NUM_DEFEND_DIE
   return troop_count
