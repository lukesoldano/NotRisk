extends Node

const __LOG_PREFIX: String = "-- "
const __WARNING_PREFIX: String = "!! "
const __SUCCESS_PREFIX: String = "++ "
const __ERROR_PREFIX: String = "xx "

func log_message(message: String) -> void:
   print(self.__LOG_PREFIX + message)
   
func log_indented_message(num_indents: int, message: String) -> void:
   var indents: String = ""
   for indent in num_indents:
      indents += "   "
   print(indents + self.__LOG_PREFIX + message)
   
func log_warning(message: String) -> void:
   print(self.__WARNING_PREFIX + message)
   
func log_success(message: String) -> void:
   print(self.__SUCCESS_PREFIX + message)

func log_error(message: String) -> void:
   print(self.__ERROR_PREFIX + message)
