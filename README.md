# The Evil Book Stealer

**A hooded thief has stolen every book from the Grand Library, and you're the only librarian brave enough to get them back.**

The Evil Book Stealer is a 2D platformer made with Godot. You chase the thief through the library, across the city on a skateboard, inside his evil supercomputer, back to the age of dinosaurs, and forward to the year 3000. On the way you jump, stomp enemies and throw blobs of ink, and you rescue every book you can find.

![The Grand Library: dodge the spikes, grab the star, and stomp the bookworms](docs/screenshots/level1-library.png)

## The story, level by level

1. **The Grand Library.** Climb the bookshelves, stomp the bookworms, and collect the stolen books. Then face the Book Stealer himself and knock him out the library window.
2. **The Getaway.** He lands on his feet and runs off with one last sack of books. Grab your skateboard and chase him through the city: hop the traffic cones, grind the rails, and launch off ramps.
3. **The Mainframe.** His sack was empty because he uploaded everything as e-books. Hack into his supercomputer, shut down the firewalls, dodge the security lasers, and destroy the core.
4. **Lost in Time.** The crashing computer opens a time portal and flings you back to the age of dinosaurs. The thief is stealing the very first stories ever carved in stone. Warp through glowing time portals, outrun charging raptors, dodge meteors, and take on the Book Stealer riding his tamed T-Rex.
5. **The Year 3000.** He escapes into the future ahead of you, rebuilds himself as a cyborg, crowns himself King of the World and bans books forever. Bounce on jump pads, ride hover platforms over bottomless drops, and bring down the Cyborg Book Stealer to free the world.

![Lost in Time: a smoking volcano, time portals, raptors and a pterodactyl](docs/screenshots/level4-lost-in-time.png)

## Features

- **5 levels**, each with its own look, enemies and boss fight
- **Different ways to play:** platforming, a skateboard chase, hacking terminals, time travel and jump pads
- **Ink-throwing combat:** stomp enemies or hit them with ink, and refill at ink wells
- **Power-ups:** a mushroom that makes you big, invincibility stars, hearts and ink bottles
- **Checkpoints** in every level
- **Easy, Normal and Hard modes**
- Keyboard and gamepad support

![The Year 3000: the Cyborg Book Stealer fires homing missiles in his neon kingdom](docs/screenshots/level5-cyborg-boss.png)

## How to play

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | Arrow keys / A D | D-pad / left stick |
| Jump | Space / W / Up / Z | A |
| Throw ink | J / X / K | X / B |
| Restart the level | R | Start |

On the title screen, press **Left / Right** to choose **Easy, Normal or Hard**. The game remembers your choice. Press **2–5** to skip straight to a level.

**Tips:** jumping on most enemies defeats them. Bosses take extra damage when they're dizzy or overheated. Touch the flags to save your checkpoint.

## Download

Get the latest version for **Windows, macOS and Linux** from the [Releases page](https://github.com/hermeslohin/Evil_Book_Stealer/releases).

- **Windows:** unzip and run `EvilBookStealer.exe`. If SmartScreen warns you, click *More info*, then *Run anyway*.
- **macOS:** unzip, then right-click **The Evil Book Stealer.app** and choose **Open** the first time. The app isn't notarized by Apple.
- **Linux:** unzip, run `chmod +x EvilBookStealer.x86_64`, then run `./EvilBookStealer.x86_64`.

## Run it from the source code

1. Install [Godot 4.7](https://godotengine.org/download).
2. Clone this repository and open `project.godot` in Godot.
3. Press **F5** to play.

All the art is drawn in code, so there are no image files to import. The levels are text maps in `scripts/*_data.gd`, so you can edit the characters to change a layout. Difficulty settings are in `scripts/difficulty.gd`.
