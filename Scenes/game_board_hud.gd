@icon("res://Assets/NodeIcons/GameBoardHUD.svg")

extends CanvasLayer

class_name GameBoardHUD

########################################################################################################################
# TODO: Short Term
#
# TODO: Remove cancel button from attack window, right-click rules all
#
# TODO: Long Term
#
# TODO: Make popups individual scenes
# TODO: Add drawn arrow from selected country to make right click requirement to cancel more obvious
# TODO: Get rid of debug label type, it is temporary
# 
########################################################################################################################

signal deploy_cancel_requested()
signal deploy_confirm_requested()
signal deploy_troop_count_change_requested(old_troop_count: int, new_troop_count: int)

signal attack_quit_requested()
signal attack_roll_requested()
signal attack_die_count_change_requested(old_num_dice: int, new_num_dice: int)

signal troop_movement_confirm_requested()
signal troop_movement_troop_count_change_requested(old_troop_count: int, new_troop_count: int)

signal territory_card_toggled(index: int, card: Types.CardType, toggled_on: bool)

const __DEFAULT_VALUE_STR = "-"
const __DEFAULT_VALUE_COLOR = Color.WHITE

const __VICTORY_TITLE_STR = "Victory!"
const __REINFORCE_TITLE_STR = "Reinforce"

@onready var __attack_die_nodes: Array[AnimatedSprite2D] = [$AttackPopupCanvasLayer/AttackerDie1, $AttackPopupCanvasLayer/AttackerDie2, $AttackPopupCanvasLayer/AttackerDie3]
@onready var __defend_die_nodes: Array[AnimatedSprite2D] = [$AttackPopupCanvasLayer/DefenderDie1, $AttackPopupCanvasLayer/DefenderDie2]

func _ready():
   $DebugLabel.visible = false
   self.hide_deploy_reinforcements_remaining()
   self.hide_deploy_popup()
   self.hide_attack_popup()
   self.hide_troop_movement_popup()
   self.enable_player_hand(false)
   
   $PlayerHand.connect("card_toggled", self._on_territory_card_toggled)
   
func show_debug_label(message: String) -> void:
   $DebugLabel.text = message
   $DebugLabel.visible = true
   
func hide_debug_label() -> void:
   $DebugLabel.visible = false
   $DebugLabel.text = self.__DEFAULT_VALUE_STR
   
## Player Leaderboard Table ############################################################################################
func initialize_player_leaderboard_table(players: Array[Player], deployments: Dictionary) -> void:
   const COLOR_INDEX = 0
   const NUM_COUNTRIES_INDEX = 1
   const NUM_ARMIES_INDEX = 2
   const NUM_REINFORCEMENTS_INDEX = 3
   const NUM_CARDS_INDEX = 4
   
   var table_rows: Array = []
   
   var current_index := 0
   var player_indices: Dictionary = {}
   for player in players:
      player_indices[player] = current_index
      table_rows.append([player.army_color, 0, 0, 0, 0])
      current_index += 1
      
   for deployment in deployments:
      current_index = player_indices[deployments[deployment].player]
      table_rows[current_index][NUM_COUNTRIES_INDEX] += 1
      table_rows[current_index][NUM_ARMIES_INDEX] += deployments[deployment].troop_count
      
   for table_row in table_rows:
      $PlayerLeaderboardTable.add_entry(table_row[COLOR_INDEX], 
                                        table_row[NUM_COUNTRIES_INDEX], 
                                        table_row[NUM_ARMIES_INDEX], 
                                        table_row[NUM_REINFORCEMENTS_INDEX],
                                        table_row[NUM_CARDS_INDEX])
   
## Deploy Reinforcements Remaining ##################################################################################### Deploy Reinforcements Remaining
func is_deploy_reinforcements_remaining_showing() -> bool:
   return $DeployReinforcementsRemainingCanvasLayer.visible
   
func show_deploy_reinforcements_remaining(player: Player, reinforcements_remaining: int) -> void:
   $DeployReinforcementsRemainingCanvasLayer/ReinforcementsRemainingCountLabel.text = str(reinforcements_remaining)
   $DeployReinforcementsRemainingCanvasLayer/ReinforcementsRemainingCountLabel.label_settings.font_color = player.army_color
   
   $DeployReinforcementsRemainingCanvasLayer.visible = true
   
func hide_deploy_reinforcements_remaining() -> void:
   $DeployReinforcementsRemainingCanvasLayer.visible = false
   
   $DeployReinforcementsRemainingCanvasLayer/ReinforcementsRemainingCountLabel.text = self.__DEFAULT_VALUE_STR
   $DeployReinforcementsRemainingCanvasLayer/ReinforcementsRemainingCountLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
## Deploy Popup ######################################################################################################## Deploy Popup
func is_deploy_popup_showing() -> bool:
   return $DeployPopupCanvasLayer.visible
   
func show_deploy_popup(is_local_player: bool, player: Player, deploy_country: Types.Country, troops_to_deploy: int, max_deployable_troops: int) -> void:
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
   
func _on_deploy_reduce_troops_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Reduce troop deployment count requested")
   var current_troop_count = int($DeployPopupCanvasLayer/ArmiesToDeployCountLabel.text)
   self.deploy_troop_count_change_requested.emit(current_troop_count, current_troop_count - 1)

func _on_deploy_increase_troops_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Increase troop deployment count requested")
   var current_troop_count = int($DeployPopupCanvasLayer/ArmiesToDeployCountLabel.text)
   self.deploy_troop_count_change_requested.emit(current_troop_count, current_troop_count + 1)

func _on_deploy_cancel_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Cancel deploy requested")
   self.deploy_cancel_requested.emit()

func _on_deploy_confirm_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Confirm deploy requested")
   self.deploy_confirm_requested.emit()
   
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
   self.show_troop_movement_user_inputs(is_local_player_attacking)
   
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
   
func show_troop_movement_user_inputs(i_visible: bool) -> void:
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
   $AttackPopupCanvasLayer/ReduceAttackDieButton.disabled = current_num_dice == 1
   $AttackPopupCanvasLayer/IncreaseAttackDieButton.disabled = max_possible_dice == current_num_dice

func _on_attack_quit_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Quit attack requested")
   self.attack_quit_requested.emit()

func _on_attack_roll_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Attack roll requested")
   self.attack_roll_requested.emit()

func _on_reduce_attack_die_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Attack die decrease requested")
   
   var old_count = 0
   for die_num in self.__attack_die_nodes.size():
      if self.__attack_die_nodes[die_num].visible:
         old_count += 1
      else:
         break
         
   self.attack_die_count_change_requested.emit(old_count, old_count - 1)

func _on_increase_attack_die_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Attack die increase requested")
   
   var old_count = 0
   for die_num in self.__attack_die_nodes.size():
      if self.__attack_die_nodes[die_num].visible:
         old_count += 1
      else:
         break
         
   self.attack_die_count_change_requested.emit(old_count, old_count + 1)

## Troop Movement Popup ############################################################################ Troop Movement Popup
func is_troop_movement_popup_showing() -> bool:
   return $TroopMovementPopupCanvasLayer.visible
   
func show_troop_movement_popup(is_local_player: bool, 
                               movement_type: GameEngine.TroopMovementType,
                               src_occupation: Types.Occupation, 
                               dest_country: Types.Country, 
                               troops_to_move: int,
                               min_troops_moveable: int,
                               max_troops_moveable: int) -> void:

   match movement_type:
      GameEngine.TroopMovementType.POST_VICTORY:
         $TroopMovementPopupCanvasLayer/TitleLabel.text = self.__VICTORY_TITLE_STR
      GameEngine.TroopMovementType.REINFORCE:
         $TroopMovementPopupCanvasLayer/TitleLabel.text = self.__REINFORCE_TITLE_STR
      _:
         assert(false, "Invalid movement type provided!")
         return
                           
   $TroopMovementPopupCanvasLayer/MoveFromCountryLabel.text = Types.Country.keys()[src_occupation.country]
   $TroopMovementPopupCanvasLayer/MoveFromCountryLabel.label_settings.font_color = src_occupation.deployment.player.army_color
   
   $TroopMovementPopupCanvasLayer/MoveToCountryLabel.text = Types.Country.keys()[dest_country]
   $TroopMovementPopupCanvasLayer/MoveToCountryLabel.label_settings.font_color = src_occupation.deployment.player.army_color
   
   $TroopMovementPopupCanvasLayer/ArmiesToMoveCountLabel.text = str(troops_to_move)
   $TroopMovementPopupCanvasLayer/ArmiesToMoveCountLabel.label_settings.font_color = src_occupation.deployment.player.army_color
   
   $TroopMovementPopupCanvasLayer/ReduceTroopsButton.disabled = troops_to_move == min_troops_moveable
   $TroopMovementPopupCanvasLayer/IncreaseTroopsButton.disabled = troops_to_move == max_troops_moveable
   
   $TroopMovementPopupCanvasLayer.visible = true
   self.show_troop_movement_popup_user_inputs(is_local_player)

func hide_troop_movement_popup() -> void:
   $TroopMovementPopupCanvasLayer.visible = false

   $TroopMovementPopupCanvasLayer/TitleLabel.text = self.__DEFAULT_VALUE_STR
   
   $TroopMovementPopupCanvasLayer/MoveFromCountryLabel.text = self.__DEFAULT_VALUE_STR
   $TroopMovementPopupCanvasLayer/MoveFromCountryLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $TroopMovementPopupCanvasLayer/MoveToCountryLabel.text = self.__DEFAULT_VALUE_STR
   $TroopMovementPopupCanvasLayer/MoveToCountryLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
   $TroopMovementPopupCanvasLayer/ArmiesToMoveCountLabel.text = self.__DEFAULT_VALUE_STR
   $TroopMovementPopupCanvasLayer/ArmiesToMoveCountLabel.label_settings.font_color = self.__DEFAULT_VALUE_COLOR
   
func show_troop_movement_popup_user_inputs(i_visible: bool):
   $TroopMovementPopupCanvasLayer/ReduceTroopsButton.visible = i_visible
   $TroopMovementPopupCanvasLayer/IncreaseTroopsButton.visible = i_visible
   $TroopMovementPopupCanvasLayer/ConfirmButton.visible = i_visible

func _on_troop_movement_reduce_troops_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Reduce post-victory troop movement requested")
   var current_troop_count = int($TroopMovementPopupCanvasLayer/ArmiesToMoveCountLabel.text)
   self.troop_movement_troop_count_change_requested.emit(current_troop_count, current_troop_count - 1)

func _on_troop_movement_increase_troops_button_pressed() -> void:
   Logger.log_message("LocalPlayer: Increase post-victory troop movement requested")
   var current_troop_count = int($TroopMovementPopupCanvasLayer/ArmiesToMoveCountLabel.text)
   self.troop_movement_troop_count_change_requested.emit(current_troop_count, current_troop_count + 1)

func _on_troop_movement_confirm_button_pressed() -> void:
   var troop_count = $TroopMovementPopupCanvasLayer/ArmiesToMoveCountLabel.text
   Logger.log_message("LocalPlayer: Confirm post-victory troop movement requested with troop count: " + troop_count)
   self.troop_movement_confirm_requested.emit()

## Player Hand #########################################################################################################
func add_card_to_hand(card: Types.CardType) -> void:
   $PlayerHand.add_card(card)
   
func remove_cards_from_hand(indices: Array[int]) -> void:
   $PlayerHand.remove_cards(indices)
   
func enable_player_hand(enable: bool) -> void:
   $PlayerHand.enable_hand(enable)

func _on_territory_card_toggled(index: int, card: Types.CardType, toggled_on: bool) -> void:
   self.territory_card_toggled.emit(index, card, toggled_on)
