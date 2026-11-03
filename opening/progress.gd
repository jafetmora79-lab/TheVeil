extends RefCounted

# Small independent state model; opening actions are idempotent and order-safe.
var fridge_checked := false
var has_keys := false
var departed := false
var driving := false
var complete := false

func can_leave() -> bool:
	return fridge_checked and has_keys

func objective() -> String:
	if complete:
		return "Arrived at the supermarket parking area. Opening complete."
	if driving:
		return "Drive to the supermarket • W accelerate / S brake • guided steering"
	if departed:
		return "Get into the car at the driveway marker."
	if not fridge_checked:
		return "Check the kitchen fridge."
	if not has_keys:
		return "Get some groceries • Collect your keys from the coat rack by the front door."
	return "Get some groceries • Leave through the front door."
