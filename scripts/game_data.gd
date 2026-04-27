class_name GameData

static var wave_reached: int = 1
static var current_level: int = 1
static var money: int = 0
# slot 0 = arme legere (pistolet), slot 1 = arme lourde (fusil a pompe / fusil d'assaut)
static var weapon_slots: Array[String] = ["pistol", ""]
static var active_slot: int = 0
static var active_weapon: String = "pistol"
