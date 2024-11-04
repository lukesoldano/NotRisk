extends Node

var __spritesheet_texture: CompressedTexture2D

# This will be the Aseprite metadata provided
var __spritesheet_metadata: Dictionary
var __country_id_to_texture_map: Dictionary[int, AtlasTexture] = {}

const __FRAMES_KEY := "frames"
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
      self.__spritesheet_texture.free()
      return false
      
   self.__spritesheet_metadata = json_data[self.__METADATA_KEY]
   
   if !json_data.has(self.__FRAMES_KEY):
      Logger.log_error("Attempt to load_country_sprites_from_file with json file: " + json_file_path + " - did not contain key: " + self.__FRAMES_KEY)
      self.__spritesheet_texture.free()
      self.__spritesheet_metadata.clear()
      return false
   
   ## Find and store AtlasTexture for each country known in country_id_to_name
   
   
   return true
