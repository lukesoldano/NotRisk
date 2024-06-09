class_name Constants

const MIN_NUM_PLAYERS:int = 2
const MAX_NUM_PLAYERS:int = 6

const MAX_TERRITORY_CARDS_IN_HAND: int = 5

const MIN_NUM_REINFORCEMENTS: int = 3
const COUNTRY_REINFORCEMENTS_DIVISOR: int = 3

const MAX_NUM_ATTACK_DIE: int = 3
const MAX_NUM_DEFEND_DIE: int = 2

const MAX_REINFORCES_ALLOWED: int = 1

const SUPPORTED_ARMY_COLORS: Array[Color] = [Color.DIM_GRAY, Color.CYAN, Color.GREEN, Color.PURPLE, Color.RED, Color.YELLOW]

# Index correlates to number of players
const STARTING_TROOP_COUNTS = [
   null, # Can't have 0 players
   null, # Can't have 1 player
   40,
   35,
   30,
   25,
   20
]
