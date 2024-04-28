class_name Types

enum Continent
{
   AFRICA = 0,
   ASIA = 1,
   AUSTRALIA = 2,
   EUROPE = 3,
   NORTH_AMERICA = 4,
   SOUTH_AMERICA = 5
}
   
enum Country
{
   AFGHANISTAN = 0,
   ALASKA = 1,
   ALBERTA = 2,
   ARGENTINA = 3,
   BRAZIL = 4,
   CENTRAL_AMERICA = 5,
   CHINA = 6,
   CONGO = 7,
   EAST_AFRICA = 8,
   EASTERN_AUSTRALIA = 9,
   EASTERN_UNITED_STATES = 10,
   EGYPT = 11,
   GREAT_BRITAIN = 12,
   GREENLAND = 13,
   ICELAND = 14,
   INDIA = 15,
   INDONESIA = 16,
   IRKUTSK = 17,
   JAPAN = 18,
   KAMCHATKA = 19,
   MADAGASCAR = 20,
   MIDDLE_EAST = 21,
   MONGOLIA = 22,
   NEW_GUINEA = 23,
   NORTH_AFRICA = 24,
   NORTHERN_EUROPE = 25,
   NORTHWEST_TERRITORY = 26,
   ONTARIO = 27,
   PERU = 28,
   QUEBEC = 29,
   SCANDINAVIA = 30,
   SIAM = 31,
   SIBERIA = 32,
   SOUTH_AFRICA = 33,
   SOUTHERN_EUROPE = 34,
   UKRAINE = 35,
   URAL = 36,
   VENEZUELA = 37,
   WESTERN_AUSTRALIA = 38,
   WESTERN_EUROPE = 39,
   WESTERN_UNITED_STATES = 40,
   YAKUTSK = 41
}

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
   VICTORY = 4
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

class Player:
   var user_name: String = "DEFAULT NAME"
   var army_color: Color = Color.WHITE
   
   func _init(i_user_name: String, i_army_color: Color):
      self.user_name = i_user_name
      self.army_color = i_army_color

class Deployment:
   var player: Types.Player = null
   var troop_count: int = 0
   
   func _init(i_player: Types.Player, i_troop_count: int):
      self.player = i_player
      self.troop_count = i_troop_count
      
class Occupation:
   var country: Types.Country
   var deployment: Types.Deployment
   
   func _init(i_country: Types.Country, i_deployment: Types.Deployment):
      self.country = i_country
      self.deployment = i_deployment
