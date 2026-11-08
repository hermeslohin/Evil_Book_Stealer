extends "res://scripts/main.gd"
## Level 3: the Book Stealer's hideout, the last stop in Book Town. A short run through his
## dusty old bookshop, then the World 1 boss fight against the Evil Book Stealer himself.
## Everything else (tiles, enemies, checkpoints, the boss) works just like Level 1.

const HideoutData := preload("res://scripts/hideout_data.gd")


func _init() -> void:
	level_num = 3
	has_boss = true


func _map_data() -> Array:
	return HideoutData.MAP


func _show_title() -> void:
	hud.show_message("LEVEL 3: THE HIDEOUT",
		"After the chase, the Book Stealer ducked into his secret hideout:\n" +
		"a dusty old bookshop at the edge of Book Town.\n\n" +
		"Fight your way through the shop, then face the thief himself!\n" +
		"Stomp him or hit him with ink. He takes extra damage when he's dizzy.\n\n" +
		"Press Space to begin     (Esc: back to the map)")


func _show_boss_win(reward: String) -> void:
	hud.show_message("WORLD 1 COMPLETE!",
		"You defeated the Evil Book Stealer and his sack is empty!\n" +
		"But wait... where are all the E-BOOKS he stole?\n" +
		"\"Ha! They're locked inside my SUPERCOMPUTER!\" he cackles.\n\n" +
		"Books you rescued along the way: %d / %d\n\n" % [books_collected, books_total] +
		reward + "\n\nPress Enter to return to the world map")
