# Saved progress for the whole game: which levels are unlocked, coins, and what you bought
# in the shops. Everything is stored in user://progress.cfg, so it survives quitting.
# Tweak COIN_* and the prices in the SHOPS table to rebalance the economy.

const SAVE_PATH := "user://progress.cfg"

const COIN_CLEAR_BONUS := 10        # coins for beating a level (on top of 1 coin per book)
const COIN_FIRST_CLEAR_BONUS := 15  # extra coins the first time you beat a level

const LEVELS := [
	{"scene": "res://main.tscn", "name": "The Grand Library", "unit": "Books"},
	{"scene": "res://chase.tscn", "name": "The Getaway", "unit": "Books"},
	{"scene": "res://hideout.tscn", "name": "The Hideout", "unit": "Books"},
	{"scene": "res://hack.tscn", "name": "The Mainframe", "unit": "E-books"},
	{"scene": "res://crash.tscn", "name": "System Crash", "unit": "E-books"},
	{"scene": "res://time.tscn", "name": "Lost in Time", "unit": "Tablets"},
	{"scene": "res://future.tscn", "name": "The Year 3000", "unit": "Books"},
]

# Each shop item: id, name, description, kind, prices (one per level for upgrades).
#   kind "upgrade"    permanent, can be bought once per price
#   kind "consumable" used up at the start of your next level (carry up to `max`)
#   kind "scarf"      a new scarf color; buy once, then select it again to wear it
const SHOPS := {
	"quill": {
		"name": "THE INK & QUILL",
		"keeper": "owl",
		"greeting": "Hoo! Welcome, young librarian. Coins for courage, I always say.",
		"items": [
			{"id": "heart", "name": "Heart Container", "kind": "upgrade", "prices": [20, 40, 60],
				"desc": "+1 max heart in every level."},
			{"id": "ink", "name": "Bigger Ink Pouch", "kind": "upgrade", "prices": [15, 30, 45],
				"desc": "Carry 2 more blobs of ink."},
			{"id": "mushroom", "name": "Growing Mushroom", "kind": "consumable", "prices": [10], "max": 3,
				"desc": "Start your next level BIG (blocks one hit)."},
		],
	},
	"bazaar": {
		"name": "TICK-TOCK BAZAAR",
		"keeper": "robot",
		"greeting": "BEEP. GREETINGS, TIME TRAVELER. ALL SALES ARE FINAL. ACROSS ALL TIMELINES.",
		"items": [
			{"id": "star", "name": "Star Candy", "kind": "consumable", "prices": [15], "max": 3,
				"desc": "Start your next level invincible."},
			{"id": "scarf_blue", "name": "Ocean Scarf", "kind": "scarf", "prices": [20],
				"desc": "A cool blue scarf.", "color": Color(0.25, 0.55, 1.0)},
			{"id": "scarf_gold", "name": "Golden Scarf", "kind": "scarf", "prices": [40],
				"desc": "Shiny! Very heroic.", "color": Color(1.0, 0.8, 0.2)},
			{"id": "scarf_rainbow", "name": "Rainbow Scarf", "kind": "scarf", "prices": [80],
				"desc": "Every color at once!", "color": Color(1, 1, 1)},
			{"id": "scarf_red", "name": "Classic Red Scarf", "kind": "scarf", "prices": [0],
				"desc": "Your trusty old scarf.", "color": Color(0.85, 0.2, 0.25)},
		],
	},
}

static var coins := 0
static var unlocked := 1                 # highest level you can play (1-7)
static var cleared := _filled(false)
static var best_books := _filled(0)
static var upgrades := {"heart": 0, "ink": 0}
static var items := {"mushroom": 0, "star": 0}
static var scarves := ["scarf_red"]
static var scarf := "scarf_red"
static var current_level := 0            # 1-7 while playing a level from the map


static func _filled(value) -> Array:
	var a := []
	a.resize(LEVELS.size())
	a.fill(value)
	return a


static func _static_init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = int(cfg.get_value("p", "coins", 0))
	var old_unlocked := int(cfg.get_value("p", "unlocked", 1))
	var old_cleared = cfg.get_value("p", "cleared", cleared)
	var old_best = cfg.get_value("p", "best_books", best_books)
	var version := int(cfg.get_value("p", "version", 1))
	if version < 2:
		# Saves from before the Hideout (new Level 3) had 5 levels. Shift levels 3-5 up one,
		# and count the Hideout as beaten if you'd beaten the old Level 2 (which had that boss).
		var beat_2: bool = old_cleared is Array and old_cleared.size() > 1 and old_cleared[1]
		if old_cleared is Array:
			old_cleared = Array(old_cleared)
			old_cleared.insert(2, beat_2)
		if old_best is Array:
			old_best = Array(old_best)
			old_best.insert(2, 0)
		if old_unlocked >= 3:
			old_unlocked += 1
	if version < 3:
		# Saves from before System Crash (new Level 5) had 6 levels. Shift levels 5-6 up one,
		# and count System Crash as beaten if you'd already gone past the Mainframe.
		var past_4: bool = old_unlocked >= 5
		if old_cleared is Array:
			old_cleared = Array(old_cleared)
			old_cleared.insert(4, past_4)
		if old_best is Array:
			old_best = Array(old_best)
			old_best.insert(4, 0)
		if old_unlocked >= 5:
			old_unlocked += 1
	unlocked = clampi(old_unlocked, 1, LEVELS.size())
	cleared = _fit(old_cleared, false)
	best_books = _fit(old_best, 0)
	var u: Dictionary = cfg.get_value("p", "upgrades", {})
	for k in upgrades:
		upgrades[k] = int(u.get(k, 0))
	var it: Dictionary = cfg.get_value("p", "items", {})
	for k in items:
		items[k] = int(it.get(k, 0))
	scarves = Array(cfg.get_value("p", "scarves", scarves))
	if not scarves.has("scarf_red"):
		scarves.append("scarf_red")
	scarf = str(cfg.get_value("p", "scarf", "scarf_red"))


static func _fit(value, fill) -> Array:
	var a := Array(value) if value is Array else []
	a.resize(LEVELS.size())
	for i in a.size():
		if a[i] == null:
			a[i] = fill
	return a


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "version", 3)
	cfg.set_value("p", "coins", coins)
	cfg.set_value("p", "unlocked", unlocked)
	cfg.set_value("p", "cleared", cleared)
	cfg.set_value("p", "best_books", best_books)
	cfg.set_value("p", "upgrades", upgrades)
	cfg.set_value("p", "items", items)
	cfg.set_value("p", "scarves", scarves)
	cfg.set_value("p", "scarf", scarf)
	cfg.save(SAVE_PATH)


## True if there's a save worth continuing (anything beaten, earned or bought).
static func has_progress() -> bool:
	if unlocked > 1 or coins > 0 or cleared.has(true) or scarves.size() > 1:
		return true
	for k in upgrades:
		if upgrades[k] > 0:
			return true
	for k in items:
		if items[k] > 0:
			return true
	return false


static func reset() -> void:
	coins = 0
	unlocked = 1
	cleared = _filled(false)
	best_books = _filled(0)
	upgrades = {"heart": 0, "ink": 0}
	items = {"mushroom": 0, "star": 0}
	scarves = ["scarf_red"]
	scarf = "scarf_red"
	save()


# ---------------------------------------------------------------- used by the levels

static func bonus_hp() -> int:
	return upgrades.heart


static func bonus_ink() -> int:
	return upgrades.ink * 2


static func scarf_color(t: float) -> Color:
	if scarf == "scarf_rainbow":
		return Color.from_hsv(fmod(t * 0.6, 1.0), 0.75, 1.0)
	var item = find_item(scarf)
	return item.color if item else Color(0.85, 0.2, 0.25)


## Called when a level is beaten. Returns a line describing the coins you earned.
static func complete_level(level: int, books: int, total: int) -> String:
	var i := level - 1
	var earned := books + COIN_CLEAR_BONUS
	var first: bool = not cleared[i]
	if first:
		earned += COIN_FIRST_CLEAR_BONUS
	cleared[i] = true
	best_books[i] = maxi(best_books[i], mini(books, total))
	unlocked = clampi(maxi(unlocked, level + 1), 1, LEVELS.size())
	coins += earned
	save()
	var line := "Coins earned: +%d   (you have %d)" % [earned, coins]
	if first:
		line += "\nFirst clear bonus included!"
	return line


# ---------------------------------------------------------------- shops

static func find_item(id: String):
	for shop in SHOPS.values():
		for item in shop.items:
			if item.id == id:
				return item
	return null


## Price of the next purchase, or -1 if it's sold out / maxed.
static func price(item: Dictionary) -> int:
	match item.kind:
		"upgrade":
			var lvl: int = upgrades[item.id]
			return item.prices[lvl] if lvl < item.prices.size() else -1
		"consumable":
			return item.prices[0] if items[item.id] < item.max else -1
		"scarf":
			return 0 if scarves.has(item.id) else item.prices[0]
	return -1


static func status(item: Dictionary) -> String:
	match item.kind:
		"upgrade":
			return "Lv %d/%d" % [upgrades[item.id], item.prices.size()]
		"consumable":
			return "Have %d/%d" % [items[item.id], item.max]
		"scarf":
			if scarf == item.id:
				return "WEARING"
			return "Owned" if scarves.has(item.id) else ""
	return ""


## Try to buy (or wear) an item. Returns a message for the shopkeeper to say.
static func buy(item: Dictionary) -> String:
	var cost := price(item)
	if cost < 0:
		return "Sold out! You can't carry any more of that."
	if item.kind == "scarf" and scarves.has(item.id):
		scarf = item.id
		save()
		return "Looking sharp in the %s!" % item.name
	if coins < cost:
		return "You need %d more coins for that." % (cost - coins)
	coins -= cost
	match item.kind:
		"upgrade":
			upgrades[item.id] += 1
		"consumable":
			items[item.id] += 1
		"scarf":
			scarves.append(item.id)
			scarf = item.id
	save()
	return "Thank you! Enjoy your %s." % item.name


# ---------------------------------------------------------------- scene flow

const MAP_SCENE := "res://world_map.tscn"

static var run_items := {}   # power-ups packed for the level you're playing right now


## Start a level from the world map. Packed power-ups are taken out of your bag now and
## given to you every time you (re)start the level from the beginning.
static func launch_level(tree: SceneTree, level: int) -> void:
	current_level = level
	run_items = {}
	for k in items:
		if items[k] > 0:
			items[k] -= 1
			run_items[k] = true
	save()
	tree.change_scene_to_file(LEVELS[level - 1].scene)


## Give the player the power-ups packed for this run. Returns a banner line ("" if none).
static func apply_run_items(player) -> String:
	var used := []
	if run_items.has("mushroom"):
		player.grow()
		used.append("BIG")
	if run_items.has("star"):
		player.start_invincible()
		used.append("INVINCIBLE")
	return " + ".join(used)


static func go_to_map(tree: SceneTree) -> void:
	run_items = {}
	tree.change_scene_to_file(MAP_SCENE)
