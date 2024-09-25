@icon("res://Assets/NodeIcons/PlayerHand.svg")

extends Control

class_name PlayerHand

########################################################################################################################
# TODO: Short Term
#
#
# TODO: Long Term
#
# TODO: Add card assets that aren't just playing cards
# TODO: Once cards are unique to a deck, they will not be assigned an index at construction and the index will instead
#       be determined dynamically by looking for the index based on a unique id that helps differentiate cards of the same
#       type (infantry, cavalry, etc)
# 
########################################################################################################################

signal card_toggled(index: int, card: Types.CardType, toggled_on: bool)

var __TERRITORY_CARD_SCENE = preload("res://Scenes/territory_card.tscn")

func enable_hand(enable: bool) -> void:
   for i in $HMarginContainer.get_child_count():
      $HMarginContainer.get_children()[i].disabled = !enable

func add_card(card: Types.CardType) -> void:
   var territory_card = self.__TERRITORY_CARD_SCENE.instantiate().with_data($HMarginContainer.get_child_count(), card)
   territory_card.connect("card_toggled", self._on_card_toggled)
   territory_card.disabled = true
   $HMarginContainer.add_child(territory_card)
   
func remove_cards(card_indices: Array[int]) -> void:
   assert(card_indices.size() <= $HMarginContainer.get_child_count(), "More indices provided than cards!")
   
   var nodes_to_remove: Array[Node] = []
   
   for i in $HMarginContainer.get_child_count():
      if card_indices.has(i):
         nodes_to_remove.append($HMarginContainer.get_children()[i])
         
   for node in nodes_to_remove:
      node.disconnect("card_toggled", self._on_card_toggled)
      $HMarginContainer.remove_child(node)
      node.queue_free()
      
   # TODO: Remove - For now we manually update card indices
   for i in $HMarginContainer.get_child_count():
      $HMarginContainer.get_children()[i].index = i
      
func toggle_card(index: int) -> void:
   assert(index < $HMarginContainer.get_child_count(), "Invalid card index provided")
   
   var button = $HMarginContainer.get_children()[index]
   button.button_pressed = !button.button_pressed
      
func _on_card_toggled(index: int, card: Types.CardType, toggled_on: bool) -> void:
   self.card_toggled.emit(index, card, toggled_on)
