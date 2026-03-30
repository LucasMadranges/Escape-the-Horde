extends RefCounted


static func build_player_id() -> String:
	var pattern := "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	var out := ""

	for i in pattern.length():
		var ch := pattern[i]
		if ch == "x":
			out += "%x" % (randi() % 16)
		elif ch == "y":
			out += "%x" % ((randi() % 4) + 8)
		else:
			out += ch

	return out
