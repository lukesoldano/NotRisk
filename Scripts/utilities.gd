extends Node

class_name Utilities

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
