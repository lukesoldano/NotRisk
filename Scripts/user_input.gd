extends Node

class_name UserInput

const LEFT_CLICK_ACTION_TAG = "left_click"
const RIGHT_CLICK_ACTION_TAG = "right_click"

enum InputAction
{
   CANCEL = -1,
   SELECT = 0
}

const ActionTagToInputAction: Dictionary = {
   LEFT_CLICK_ACTION_TAG: InputAction.SELECT,
   RIGHT_CLICK_ACTION_TAG: InputAction.CANCEL
}
