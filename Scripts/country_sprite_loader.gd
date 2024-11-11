extends Node

const GAME_BOARD_SOURCE_WIDTH := 320
const GAME_BOARD_SOURCE_HEIGHT := 180
const GAME_BOARD_SPRITE_SHEET_SCALE := 2

var __spritesheet_texture = null

# This will be the Aseprite metadata provided
var __spritesheet_metadata: Dictionary
var __country_sprite_frames = null
var __country_sprite_source_sizing: Dictionary[int, Rect2]

const __FRAMES_KEY := "frames"
const __FRAME_KEY := "frame"
const __SPRITE_SOURCE_SIZE_KEY := "spriteSourceSize"
const __X_POS_KEY := "x"
const __Y_POS_KEY := "y"
const __WIDTH_KEY := "w"
const __HEIGHT_KEY := "h"
const __METADATA_KEY := "meta"

const __COUNTRY_KEY_PREPEND := "GameBoard ("
const __COUNTRY_KEY_APPEND := ").aseprite"

# Takes as input a path to a spritesheet file as well as a JSON metadata file that should match the contents of Aseprite
# generated JSON files from exports, this JSON will contain relevant metadata and information on how the spritesheet
# should be split up into individual frames, countries should be identified with the key 
# "GameBoard (CountryNameNoSpaces).aseprite" under a root level key "frames", there should also be a "meta" key
# EG:
# { "frames": {
#   "GameBoard (Alaska).aseprite": {
#    "frame": { "x": 209, "y": 120, "w": 28, "h": 31 },
#    "rotated": false,
#    "trimmed": true,
#    "spriteSourceSize": { "x": 2, "y": 8, "w": 28, "h": 31 },
#    "sourceSize": { "w": 320, "h": 180 },
#    "duration": 100
#   },
#   ...
#   },
#   "meta": {
#   "app": "https://www.aseprite.org/",
#   "version": "1.3.9.2-x64",
#   "image": "Countries_SpriteSheet.png",
#   "format": "RGBA8888",
#   "size": { "w": 296, "h": 179 },
#   "scale": "1",
#   "frameTags": [
#   ],
#   "layers": [
#    { "name": "Ontario", "opacity": 255, "blendMode": "normal" },
#    ...
#   ],
#   "slices": [
#   ]
#  }
# }
# Returns true if sprites loaded successfully, false if files did not exist, or all country ids in the 
# country_id_to_name map did not have an associated entry in the json file
func load_country_sprites_from_file(
   spritesheet_file_path: String, 
   json_file_path: String, 
   country_id_to_name: Dictionary[int, String]
) -> bool:
   Logger.log_error("Entry load_country_sprites_from_file(" + spritesheet_file_path + ",  " + json_file_path + ", ...)")
   
   if !FileAccess.file_exists(spritesheet_file_path):
      Logger.log_error("Attempt to load_country_sprites_from_file with spritesheet: " + spritesheet_file_path + " - that does not exist")
      return false
      
   if !FileAccess.file_exists(json_file_path):
      Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - that does not exist")
      return false
      
   self.__spritesheet_texture = load(spritesheet_file_path)
   
   # Parse JSON data, free texture if any failures occur
   var json_data: Dictionary = JSON.parse_string(FileAccess.open(json_file_path, FileAccess.READ).get_as_text())
   
   if !json_data.has(self.__METADATA_KEY):
      Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - did not contain key: " + self.__METADATA_KEY)
      self.__spritesheet_texture = null
      return false
      
   self.__spritesheet_metadata = json_data[self.__METADATA_KEY]
   
   if !json_data.has(self.__FRAMES_KEY):
      Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - did not contain key: " + self.__FRAMES_KEY)
      self.__spritesheet_texture = null
      self.__spritesheet_metadata.clear()
      return false
   
   ## Find and store AtlasTexture for each country known in country_id_to_name
   self.__country_sprite_frames = SpriteFrames.new()
   for country_id in country_id_to_name:
      
      var country_sprite_key: String = self.__COUNTRY_KEY_PREPEND + \
                                       country_id_to_name[country_id].replace(" ", "") + \
                                       self.__COUNTRY_KEY_APPEND
                                       
      if !json_data[self.__FRAMES_KEY].has(country_sprite_key):
         Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - did not contain key: " + country_sprite_key)
         self.__spritesheet_texture = null
         self.__spritesheet_metadata.clear()
         self.__country_sprite_frames = null
         return false
         
      var country_sprite_json_data: Dictionary = json_data[self.__FRAMES_KEY][country_sprite_key]
      
      if !country_sprite_json_data.has(self.__SPRITE_SOURCE_SIZE_KEY):
         Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - did not contain 'spriteSourceSize' key in: " + country_sprite_key)
         self.__spritesheet_texture = null
         self.__spritesheet_metadata.clear()
         self.__country_sprite_frames = null
         return false
         
      var country_sprite_source_size_json_data: Dictionary = country_sprite_json_data[self.__SPRITE_SOURCE_SIZE_KEY]
      
      if !country_sprite_source_size_json_data.has(self.__X_POS_KEY) or \
         !country_sprite_source_size_json_data.has(self.__Y_POS_KEY) or \
         !country_sprite_source_size_json_data.has(self.__WIDTH_KEY) or \
         !country_sprite_source_size_json_data.has(self.__HEIGHT_KEY):
            
         Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - did not contain spriteSourceSize x, y, w, and/or h key in: " + country_sprite_key)
         self.__spritesheet_texture = null
         self.__spritesheet_metadata.clear()
         self.__country_sprite_frames = null
         return false
         
      self.__country_sprite_source_sizing[country_id] = \
         Rect2( \
            country_sprite_source_size_json_data[self.__X_POS_KEY] * self.GAME_BOARD_SPRITE_SHEET_SCALE, \
            country_sprite_source_size_json_data[self.__Y_POS_KEY] * self.GAME_BOARD_SPRITE_SHEET_SCALE, \
            country_sprite_source_size_json_data[self.__WIDTH_KEY] * self.GAME_BOARD_SPRITE_SHEET_SCALE, \
            country_sprite_source_size_json_data[self.__HEIGHT_KEY] * self.GAME_BOARD_SPRITE_SHEET_SCALE \
         )
      
      if !country_sprite_json_data.has(self.__FRAME_KEY):
         Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - did not contain 'frame' key in: " + country_sprite_key)
         self.__spritesheet_texture = null
         self.__spritesheet_metadata.clear()
         self.__country_sprite_frames = null
         return false
         
      var country_sprite_frame_json_data: Dictionary = country_sprite_json_data[self.__FRAME_KEY]
      
      if !country_sprite_frame_json_data.has(self.__X_POS_KEY) or \
         !country_sprite_frame_json_data.has(self.__Y_POS_KEY) or \
         !country_sprite_frame_json_data.has(self.__WIDTH_KEY) or \
         !country_sprite_frame_json_data.has(self.__HEIGHT_KEY):
            
         Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - did not contain frame x, y, w, and/or h key in: " + country_sprite_key)
         self.__spritesheet_texture = null
         self.__spritesheet_metadata.clear()
         self.__country_sprite_frames = null
         return false
         
      var atlas_texture := AtlasTexture.new()
      atlas_texture.set_atlas(self.__spritesheet_texture)
      atlas_texture.set_region(
         Rect2(
            country_sprite_frame_json_data[self.__X_POS_KEY] * self.GAME_BOARD_SPRITE_SHEET_SCALE, 
            country_sprite_frame_json_data[self.__Y_POS_KEY] * self.GAME_BOARD_SPRITE_SHEET_SCALE, 
            country_sprite_frame_json_data[self.__WIDTH_KEY] * self.GAME_BOARD_SPRITE_SHEET_SCALE, 
            country_sprite_frame_json_data[self.__HEIGHT_KEY] * self.GAME_BOARD_SPRITE_SHEET_SCALE
         )
      )
      
      self.__country_sprite_frames.add_animation(str(country_id))
      self.__country_sprite_frames.add_frame(str(country_id), atlas_texture, 1.0, 0)
   
   return true
   
# Returns Texture2D on success, null o/w
func get_sprite(country_id: int):
   if self.__country_sprite_frames.has_animation(str(country_id)):
      return self.__country_sprite_frames.get_frame_texture(str(country_id), 0)
   return null
   
# Returns Rect2 on success, null o/w
func get_sprite_source_sizing(country_id: int):
   if self.__country_sprite_source_sizing.has(country_id):
      return self.__country_sprite_source_sizing[country_id]
   return null
