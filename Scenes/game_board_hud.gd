@icon("res://Assets/NodeIcons/GameBoardHUD.svg")

extends CanvasLayer

class_name GameBoardHUD

signal deploy_quit_requested()
signal deploy_confirm_requested()
signal deploy_troop_count_change_requested(old_troop_count: int, new_troop_count: int)

signal attack_quit_requested()
signal attack_roll_requested()
signal attack_die_count_change_requested(old_num_dice: int, new_num_dice: int)

signal post_victory_troop_movement_confirm_requested()
signal post_victory_troop_count_change_requested(old_troop_count: int, new_troop_count: int)

const __DEFAULT_VALUE_STR = "-"
const __DEFAULT_VALUE_COLOR = Color.WHITE

@onready var __attack_die_nodes: Array[AnimatedSprite2D] = [$AttackPopupCanvasLayer/AttackerDie1, $AttackPopupCanvasLayer/AttackerDie2, $AttackPopupCanvasLayer/AttackerDie3]
@onready var __defend_die_nodes: Array[AnimatedSprite2D] = [$AttackPopupCanvasLayer/DefenderDie1, $AttackPopupCanvasLayer/DefenderDie2]

func _ready():
   self.hide_deploy_popup()
   self.hide_attack_popup()
   self.hide_victory_popup()
   
## Deploy Popup ######################################################################################################## Deploy Popup
func is_deploy_popup_showing() -> bool:
   return $DeployPopupCanvasLayer.visible
   
func show_deploy_popup(is_local_player: bool, player: Types.Player, deploy_country: Types.Country, troops_to_deploy: int, max_deployable_troops: int) -> void:
   $DeployPopupCanvasLayer/DeployArmiesToCountryLabel.text = Types.Country.keys()[deploy_country]
   $DeployPopupCanvasLayer/DeployArmiesToCountryLabel.label_settings.font_color = player.army_color
   
   $DeployPopupCanvasLayer/ArmiesToDeployCountLabel.text = str(troops_to_deploy)
   $DeployPopupCanvasLayer/ArmiesToDeployCountLabel.label_settings.font_color = player.army_color
   
   $DeployPopupCanvasLayer/ReduceTroopsButton.disabled = troops_to_deploy == 1
   $DeployPopupCanvasLayer/IncreaseTroopsButton.disabled = troops_to_deploy == max_deployable_troops
   
   $DeployPopupCanvasLayer.visible = true
   self.show_deploy_popup_user_inputs(is_local_player)

func hide_deploy_popup() -> void:
   $DeployPopupCanvasLayer.visible = false
   
   $DeployPopupCanvasLayer/DeployArmiesToCountryLabel.text = self.__DEFAULT_VALUE_STR
   $DeployPopupCanvasLayer/DeployArmiesToCountryLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $DeployPopupCanvasLayer/ArmiesToDeployCountLabel.text = self.__DEFAULT_VALUE_STR
   $DeployPopupCanvasLayer/ArmiesToDeployCountLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
func show_deploy_popup_user_inputs(i_visible: bool):
   $DeployPopupCanvasLayer/ReduceTroopsButton.visible = i_visible
   $DeployPopupCanvasLayer/IncreaseTroopsButton.visible = i_visible
   $DeployPopupCanvasLayer/CancelButton.visible = i_visible
   $DeployPopupCanvasLayer/ConfirmButton.visible = i_visible
   
## Attack Popup ######################################################################################################## Attack Popup
func is_attack_popup_showing() -> bool:
   return $AttackPopupCanvasLayer.visible
   
func show_attack_popup(is_local_player_attacking: bool, 
                       attacker: Types.Occupation, 
                       defender: Types.Occupation, 
                       attacker_num_dice: int, 
                       max_attacker_num_dice: int,
                       defender_num_dice: int) -> void:
                        
   var ATTACKER_COLOR = attacker.deployment.player.army_color
   var DEFENDER_COLOR = defender.deployment.player.army_color
   
   $AttackPopupCanvasLayer/AttackSourceCountryLabel.text = Types.Country.keys()[attacker.country]
   $AttackPopupCanvasLayer/AttackSourceCountryLabel.label_settings.font_color = ATTACKER_COLOR
   
   $AttackPopupCanvasLayer/AttackDestinationCountryLabel.text = Types.Country.keys()[defender.country]
   $AttackPopupCanvasLayer/AttackDestinationCountryLabel.label_settings.font_color = DEFENDER_COLOR
   
   $AttackPopupCanvasLayer/AttackingArmiesCountLabel.text = str(attacker.deployment.troop_count)
   $AttackPopupCanvasLayer/AttackingArmiesCountLabel.label_settings.font_color = ATTACKER_COLOR
   
   $AttackPopupCanvasLayer/DefendingArmiesCountLabel.text = str(defender.deployment.troop_count)
   $AttackPopupCanvasLayer/DefendingArmiesCountLabel.label_settings.font_color = DEFENDER_COLOR
   
   self.update_attack_die_count(attacker_num_dice, max_attacker_num_dice)
   $AttackPopupCanvasLayer/AttackerNumDiceCountLabel.label_settings.font_color = ATTACKER_COLOR
   
   self.update_defend_die_count(defender_num_dice)
   $AttackPopupCanvasLayer/DefenderNumDiceCountLabel.label_settings.font_color = DEFENDER_COLOR
   
   $AttackPopupCanvasLayer.visible = true
   self.show_attack_popup_user_inputs(is_local_player_attacking)
   
func hide_attack_popup() -> void:
   $AttackPopupCanvasLayer.visible = false
   
   $AttackPopupCanvasLayer/AttackSourceCountryLabel.text = self.__DEFAULT_VALUE_STR
   $AttackPopupCanvasLayer/AttackSourceCountryLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $AttackPopupCanvasLayer/AttackDestinationCountryLabel.text = self.__DEFAULT_VALUE_STR
   $AttackPopupCanvasLayer/AttackDestinationCountryLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $AttackPopupCanvasLayer/AttackingArmiesCountLabel.text = self.__DEFAULT_VALUE_STR
   $AttackPopupCanvasLayer/AttackingArmiesCountLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $AttackPopupCanvasLayer/DefendingArmiesCountLabel.text = self.__DEFAULT_VALUE_STR
   $AttackPopupCanvasLayer/DefendingArmiesCountLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $AttackPopupCanvasLayer/AttackerNumDiceCountLabel.text = self.__DEFAULT_VALUE_STR
   $AttackPopupCanvasLayer/AttackerNumDiceCountLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $AttackPopupCanvasLayer/DefenderNumDiceCountLabel.text = self.__DEFAULT_VALUE_STR
   $AttackPopupCanvasLayer/DefenderNumDiceCountLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
func show_attack_popup_user_inputs(i_visible: bool) -> void:
   if $AttackPopupCanvasLayer.visible:
      $AttackPopupCanvasLayer/QuitButton.visible = i_visible
      $AttackPopupCanvasLayer/RollButton.visible = i_visible
      $AttackPopupCanvasLayer/ReduceAttackDieButton.visible = i_visible
      $AttackPopupCanvasLayer/IncreaseAttackDieButton.visible = i_visible
      
func set_die_rolls(attack_rolls: Array[int], defend_rolls: Array[int]) -> void:
   for roll in attack_rolls.size():
      self.__attack_die_nodes[roll].visible = true
      self.__attack_die_nodes[roll].frame = attack_rolls[roll] - 1
      
   for roll in defend_rolls.size():
      self.__defend_die_nodes[roll].visible = true
      self.__defend_die_nodes[roll].frame = defend_rolls[roll] - 1
      
func update_attack_die_count(current_num_dice: int, max_possible_dice: int) -> void:
   $AttackPopupCanvasLayer/AttackerNumDiceCountLabel.text = str(current_num_dice)
   for die_num in self.__attack_die_nodes.size():
      if current_num_dice > die_num:
         self.__attack_die_nodes[die_num].visible = true
         if !$AttackPopupCanvasLayer.visible: # If updating a showing window, don't reset these as they show previous rolls
            self.__attack_die_nodes[die_num].frame = die_num
      else:
         self.__attack_die_nodes[die_num].visible = false
         
   self.__update_attack_die_arrows(current_num_dice, max_possible_dice)
         
func update_defend_die_count(count: int) -> void:
   $AttackPopupCanvasLayer/DefenderNumDiceCountLabel.text = str(count)
   for die_num in self.__defend_die_nodes.size():
      if count > die_num:
         self.__defend_die_nodes[die_num].visible = true
         if !$AttackPopupCanvasLayer.visible: # If updating a showing window, don't reset these as they show previous rolls
            self.__defend_die_nodes[die_num].frame = die_num
      else:
         self.__defend_die_nodes[die_num].visible = false
         
func __update_attack_die_arrows(current_num_dice: int, max_possible_dice: int) -> void:
   if current_num_dice == 1:
      $AttackPopupCanvasLayer/ReduceAttackDieButton.disabled = true
      $AttackPopupCanvasLayer/IncreaseAttackDieButton.disabled = false
   elif current_num_dice == 2:
      $AttackPopupCanvasLayer/ReduceAttackDieButton.disabled = false
      $AttackPopupCanvasLayer/IncreaseAttackDieButton.disabled = false
   else:
      $AttackPopupCanvasLayer/ReduceAttackDieButton.disabled = false
      $AttackPopupCanvasLayer/IncreaseAttackDieButton.disabled = true

func _on_attack_quit_button_pressed() -> void:
   Logger.log_message("Quit attack requested")
   self.attack_quit_requested.emit()

func _on_attack_roll_button_pressed() -> void:
   Logger.log_message("Attack roll requested")
   self.attack_roll_requested.emit()

func _on_reduce_attack_die_button_pressed() -> void:
   Logger.log_message("Attack die decrease requested")
   
   var old_count = 0
   for die_num in self.__attack_die_nodes.size():
      if self.__attack_die_nodes[die_num].visible:
         old_count += 1
      else:
         break
         
   self.attack_die_count_change_requested.emit(old_count, old_count - 1)

func _on_increase_attack_die_button_pressed() -> void:
   Logger.log_message("Attack die increase requested")
   
   var old_count = 0
   for die_num in self.__attack_die_nodes.size():
      if self.__attack_die_nodes[die_num].visible:
         old_count += 1
      else:
         break
         
   self.attack_die_count_change_requested.emit(old_count, old_count + 1)

## Victory Popup ####################################################################################################### Victory Popup
func is_victory_popup_showing() -> bool:
   return $VictoryPopupCanvasLayer.visible
   
func show_victory_popup(is_local_player: bool, 
                        attacking_occupation: Types.Occupation, 
                        conquered_country: Types.Country, 
                        troops_to_move: int,
                        min_troops_to_move: int,
                        max_troops_to_move: int) -> void:
                           
   $VictoryPopupCanvasLayer/MoveFromCountryLabel.text = Types.Country.keys()[attacking_occupation.country]
   $VictoryPopupCanvasLayer/MoveFromCountryLabel.label_settings.font_color = attacking_occupation.deployment.player.army_color
   
   $VictoryPopupCanvasLayer/MoveToCountryLabel.text = Types.Country.keys()[conquered_country]
   $VictoryPopupCanvasLayer/MoveToCountryLabel.label_settings.font_color = attacking_occupation.deployment.player.army_color
   
   $VictoryPopupCanvasLayer/ArmiesToMoveCountLabel.text = str(troops_to_move)
   $VictoryPopupCanvasLayer/ArmiesToMoveCountLabel.label_settings.font_color = attacking_occupation.deployment.player.army_color
   
   $VictoryPopupCanvasLayer/ReduceTroopsButton.disabled = troops_to_move == min_troops_to_move
   $VictoryPopupCanvasLayer/IncreaseTroopsButton.disabled = troops_to_move == max_troops_to_move
   
   $VictoryPopupCanvasLayer.visible = true
   self.show_victory_popup_user_inputs(is_local_player)

func hide_victory_popup() -> void:
   $VictoryPopupCanvasLayer.visible = false
   
   $VictoryPopupCanvasLayer/MoveFromCountryLabel.text = self.__DEFAULT_VALUE_STR
   $VictoryPopupCanvasLayer/MoveFromCountryLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $VictoryPopupCanvasLayer/MoveToCountryLabel.text = self.__DEFAULT_VALUE_STR
   $VictoryPopupCanvasLayer/MoveToCountryLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $VictoryPopupCanvasLayer/ArmiesToMoveCountLabel.text = self.__DEFAULT_VALUE_STR
   $VictoryPopupCanvasLayer/ArmiesToMoveCountLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
func show_victory_popup_user_inputs(i_visible: bool):
   $VictoryPopupCanvasLayer/ReduceTroopsButton.visible = i_visible
   $VictoryPopupCanvasLayer/IncreaseTroopsButton.visible = i_visible
   $VictoryPopupCanvasLayer/ConfirmButton.visible = i_visible

func _on_victory_reduce_troops_button_pressed() -> void:
   Logger.log_message("Reduce post-victory troop movement requested")
   var current_troop_count = int($VictoryPopupCanvasLayer/ArmiesToMoveCountLabel.text)
   self.post_victory_troop_count_change_requested.emit(current_troop_count, current_troop_count - 1)

func _on_victory_increase_troops_button_pressed() -> void:
   Logger.log_message("Increase post-victory troop movement requested")
   var current_troop_count = int($VictoryPopupCanvasLayer/ArmiesToMoveCountLabel.text)
   self.post_victory_troop_count_change_requested.emit(current_troop_count, current_troop_count + 1)

func _on_victory_confirm_button_pressed() -> void:
   var troop_count = $VictoryPopupCanvasLayer/ArmiesToMoveCountLabel.text
   Logger.log_message("Confirm post-victory troop movement requested with troop count: " + troop_count)
   self.post_victory_troop_movement_confirm_requested.emit()
