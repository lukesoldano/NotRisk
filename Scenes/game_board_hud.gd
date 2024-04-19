@icon("res://Assets/NodeIcons/GameBoardHUD.svg")

extends CanvasLayer

class_name GameBoardHUD

signal quit_requested()
signal roll_requested()

const __DEFAULT_VALUE_STR = "-"
const __DEFAULT_VALUE_COLOR = Color.WHITE

@onready var __attack_die_nodes: Array[AnimatedSprite2D] = [$AttackPopupCanvasLayer/AttackerDie1, $AttackPopupCanvasLayer/AttackerDie2, $AttackPopupCanvasLayer/AttackerDie3]
@onready var __defend_die_nodes: Array[AnimatedSprite2D] = [$AttackPopupCanvasLayer/DefenderDie1, $AttackPopupCanvasLayer/DefenderDie2]

func _ready():
   self.hide_attack_popup()
   
func is_attack_popup_showing() -> bool:
   return $AttackPopupCanvasLayer.visible
   
func show_attack_popup(is_local_player_attacking: bool, attacker: Types.Occupation, defender: Types.Occupation, attacker_num_dice: int, defender_num_dice: int) -> void:
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
   
   $AttackPopupCanvasLayer/AttackerNumDiceCountLabel.text = str(attacker_num_dice)
   $AttackPopupCanvasLayer/AttackerNumDiceCountLabel.label_settings.font_color = ATTACKER_COLOR
   
   $AttackPopupCanvasLayer/DefenderNumDiceCountLabel.text = str(defender_num_dice)
   $AttackPopupCanvasLayer/DefenderNumDiceCountLabel.label_settings.font_color = DEFENDER_COLOR
   
   for attack_die_num in self.__attack_die_nodes.size():
      if attacker_num_dice > attack_die_num:
         self.__attack_die_nodes[attack_die_num].visible = true
      else:
         self.__attack_die_nodes[attack_die_num].visible = false
         
   for defend_die_num in self.__defend_die_nodes.size():
      if defender_num_dice > defend_die_num:
         self.__defend_die_nodes[defend_die_num].visible = true
      else:
         self.__defend_die_nodes[defend_die_num].visible = false
         
   if is_local_player_attacking:
      $AttackPopupCanvasLayer/QuitButton.visible = true
      $AttackPopupCanvasLayer/RollButton.visible = true
   else:
      $AttackPopupCanvasLayer/QuitButton.visible = false
      $AttackPopupCanvasLayer/RollButton.visible = false
   
   $AttackPopupCanvasLayer.visible = true
   self.enable_attack_popup_user_inputs(true)
   
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
   
func enable_attack_popup_user_inputs(enable: bool) -> void:
   if $AttackPopupCanvasLayer.visible:
      $AttackPopupCanvasLayer/QuitButton.visible = enable
      $AttackPopupCanvasLayer/RollButton.visible = enable

func _on_attack_quit_button_pressed() -> void:
   Logger.log_message("Quit attack requested")
   self.quit_requested.emit()

func _on_attack_roll_button_pressed() -> void:
   Logger.log_message("Attack roll requested")
   self.roll_requested.emit()
