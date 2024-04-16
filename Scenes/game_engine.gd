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
   Types.Player.new("Dennis", Color.YELLOW)
]

var __player_occupations: Dictionary = {}
var __deployments: Dictionary = {}

#func _init(players: Array[Types.Player]):
   #self.__players = players

func _ready():
   assert(self.__players.size() >= 2 && self.__players.size() <= 6, "Invalid player count!")
   
   self.generate_random_deployments()
   $GameBoard.populate(self.__deployments)
   
   self.connect("turn_phase_updated", $GameBoard._on_turn_phase_updated)
   $GameBoard.connect("next_phase_requested", self._on_next_phase_requested)

func generate_random_deployments() -> void:
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

func _on_start_state_entered() -> void:
   self.__active_player_index = (self.__active_player_index + 1) % self.__players.size()
   Logger.log_message("Player: " + self.__players[self.__active_player_index].user_name + " entering phase: START")
   self.__active_turn_phase = Types.TurnPhase.START
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   $PlayerTurnStateMachine.send_event("StartToDeploy")

func _on_deploy_state_entered():
   Logger.log_message("Player: " + self.__players[self.__active_player_index].user_name + " entering phase: DEPLOY")
   self.__active_turn_phase = Types.TurnPhase.DEPLOY
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)

func _on_attack_state_entered():
   Logger.log_message("Player: " + self.__players[self.__active_player_index].user_name + " entering phase: ATTACK")
   self.__active_turn_phase = Types.TurnPhase.ATTACK
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)

func _on_reinforce_state_entered():
   Logger.log_message("Player: " + self.__players[self.__active_player_index].user_name + " entering phase: REINFORCE")
   self.__active_turn_phase = Types.TurnPhase.REINFORCE
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)

func _on_end_state_entered():
   Logger.log_message("Player: " + self.__players[self.__active_player_index].user_name + " entering phase: END")
   self.__active_turn_phase = Types.TurnPhase.END
   self.turn_phase_updated.emit(self.__players[self.__active_player_index], self.__active_turn_phase)
   $PlayerTurnStateMachine.send_event("EndToStart")
