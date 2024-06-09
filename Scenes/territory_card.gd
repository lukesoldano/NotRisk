extends TextureButton

class_name TerritoryCard

signal card_toggled(index: int, card: Types.CardType, toggled_on: bool)

@export var index := 0
@export var card := Types.CardType.INFANTRY

func _ready():
   self.connect("toggled", self._on_toggled)

func with_data(i_index: int, i_card: Types.CardType) -> TerritoryCard:
   self.index = i_index
   self.card = i_card
   
   self.toggle_mode = true
   
   self.ignore_texture_size = true
   self.stretch_mode= TextureButton.STRETCH_KEEP_ASPECT_CENTERED
   self.size_flags_horizontal = Control.SIZE_FILL ^ Control.SIZE_EXPAND
   
   match self.card:
      Types.CardType.INFANTRY:
         var default_texture = load("res://Assets/kenney_boardgame-pack/PNG/Cards/cardSpadesJ.png")
         self.texture_normal = default_texture
         self.texture_disabled = default_texture
         self.texture_pressed = load("res://Assets/kenney_boardgame-pack/PNG/Cards/cardHeartsJ.png")
      Types.CardType.CAVALRY:
         var default_texture = load("res://Assets/kenney_boardgame-pack/PNG/Cards/cardSpadesQ.png")
         self.texture_normal = default_texture
         self.texture_disabled = default_texture
         self.texture_pressed = load("res://Assets/kenney_boardgame-pack/PNG/Cards/cardHeartsQ.png")
      Types.CardType.ARTILLERY:
         var default_texture = load("res://Assets/kenney_boardgame-pack/PNG/Cards/cardSpadesK.png")
         self.texture_normal = default_texture
         self.texture_disabled = default_texture
         self.texture_pressed = load("res://Assets/kenney_boardgame-pack/PNG/Cards/cardHeartsK.png")
      _:
         assert(false, "Invalid card type provided!")
         
   return self
   
func _on_toggled(toggled_on: bool) -> void:
   self.card_toggled.emit(self.index, self.card, toggled_on)
