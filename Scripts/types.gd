class_name Types

enum CardType
{
   INFANTRY = 0,
   CAVALRY = 1,
   ARTILLERY = 2
}

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

class Deployment:
   var player: Player = null
   var troop_count: int = 0
   
   func _init(i_player: Player, i_troop_count: int):
      self.player = i_player
      self.troop_count = i_troop_count
      
class Occupation:
   var country: Types.Country
   var deployment: Types.Deployment
   
   func _init(i_country: Types.Country, i_deployment: Types.Deployment):
      self.country = i_country
      self.deployment = i_deployment
      
class StartAndForgetTimer extends Node:
   var __timer := Timer.new()
   var __callable: Callable
   
   func _init(callable: Callable, one_shot: bool = true):
      self.__callable = callable
      
      self.__timer.one_shot = one_shot
      self.__timer.connect("timeout", self._on_timeout)
      self.add_child(self.__timer)
      
   func start(time_sec: int) -> void:
      self.__timer.start(time_sec)
      
   func _on_timeout() -> void:
      self.__callable.call()
      if self.__timer.one_shot:
         self.remove_child(self.__timer)
         queue_free()
