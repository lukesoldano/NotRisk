extends Node

func log_message(message: String) -> void:
   print("-- " + message)
   
func log_warning(message: String) -> void:
   print("!! " + message)
   
func log_success(message: String) -> void:
   print("++ " + message)

func log_error(message: String) -> void:
   print("xx " + message)
