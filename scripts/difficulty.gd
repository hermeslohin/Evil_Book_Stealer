# Difficulty settings for the whole game. Pick EASY, NORMAL or HARD on the title screen
# (Left / Right). The choice is saved, so the game remembers it next time.
# Tweak the numbers in PRESETS to rebalance a mode.

const SAVE_PATH := "user://settings.cfg"
const MODES := ["easy", "normal", "hard"]

const PRESETS := {
	"easy": {
		"PLAYER_MAX_HP": 6,        # hearts you start with
		"MAX_INK": 12,             # ink you can carry
		"INVULN_TIME": 1.6,        # seconds of blinking safety after a hit
		"ENEMY_HP_BONUS": 0,       # extra hits every regular enemy takes
		"ENEMY_SPEED": 0.85,       # how fast enemies walk and charge
		"ENEMY_TEMPO": 0.8,        # how fast enemies think, aim and fire
		"ENEMY_SHOT_SPEED": 0.85,  # speed of bolts, bits and fists aimed at you
		"BOSS_HP": 0.75,           # boss health multiplier
		"BOSS_TEMPO": 0.85,        # how quickly bosses chain their attacks
		"LASER_WARN": 0.8,         # seconds a ceiling laser flickers before firing
	},
	"normal": {
		"PLAYER_MAX_HP": 4,
		"MAX_INK": 8,
		"INVULN_TIME": 0.9,
		"ENEMY_HP_BONUS": 1,
		"ENEMY_SPEED": 1.3,
		"ENEMY_TEMPO": 1.25,
		"ENEMY_SHOT_SPEED": 1.25,
		"BOSS_HP": 1.35,
		"BOSS_TEMPO": 1.2,
		"LASER_WARN": 0.4,
	},
	"hard": {
		"PLAYER_MAX_HP": 3,
		"MAX_INK": 6,
		"INVULN_TIME": 0.7,
		"ENEMY_HP_BONUS": 2,
		"ENEMY_SPEED": 1.55,
		"ENEMY_TEMPO": 1.5,
		"ENEMY_SHOT_SPEED": 1.45,
		"BOSS_HP": 1.8,
		"BOSS_TEMPO": 1.45,
		"LASER_WARN": 0.3,
	},
}

static var mode := "normal"
static var PLAYER_MAX_HP := 4
static var MAX_INK := 8
static var INVULN_TIME := 0.9
static var ENEMY_HP_BONUS := 1
static var ENEMY_SPEED := 1.3
static var ENEMY_TEMPO := 1.25
static var ENEMY_SHOT_SPEED := 1.25
static var BOSS_HP := 1.35
static var BOSS_TEMPO := 1.2
static var LASER_WARN := 0.4


static func _static_init() -> void:
	var cfg := ConfigFile.new()
	var saved := "normal"
	if cfg.load(SAVE_PATH) == OK:
		saved = str(cfg.get_value("game", "difficulty", "normal"))
	_apply(saved)


static func _apply(m: String) -> void:
	if not PRESETS.has(m):
		m = "normal"
	mode = m
	var p: Dictionary = PRESETS[m]
	PLAYER_MAX_HP = p.PLAYER_MAX_HP
	MAX_INK = p.MAX_INK
	INVULN_TIME = p.INVULN_TIME
	ENEMY_HP_BONUS = p.ENEMY_HP_BONUS
	ENEMY_SPEED = p.ENEMY_SPEED
	ENEMY_TEMPO = p.ENEMY_TEMPO
	ENEMY_SHOT_SPEED = p.ENEMY_SHOT_SPEED
	BOSS_HP = p.BOSS_HP
	BOSS_TEMPO = p.BOSS_TEMPO
	LASER_WARN = p.LASER_WARN


## Switch modes (step -1 = easier, +1 = harder) and remember the choice.
static func cycle(step: int) -> void:
	var i := clampi(MODES.find(mode) + step, 0, MODES.size() - 1)
	set_mode(MODES[i])


static func set_mode(m: String) -> void:
	_apply(m)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("game", "difficulty", mode)
	cfg.save(SAVE_PATH)


static func label() -> String:
	return mode.to_upper()


static func color() -> Color:
	match mode:
		"easy":
			return Color(0.45, 1.0, 0.55)
		"hard":
			return Color(1.0, 0.35, 0.35)
	return Color(1.0, 0.85, 0.4)
