class_name NpcData
extends Resource

## Configuration for one NPC type (Ghost, Tired Vampire, Witch...).
## Saved as .tres files in data/npcs/. One NPC scene + different NpcData = different monster.

enum AfterScare {
	FLEE,        ## runs off and fades out (Ghost, Witch, Bat)
	FAINT,       ## falls over and naps (Vampire, Werewolf)
	FALL_APART,  ## pops into pieces (Jack-o'-lanterns)
}

@export var display_name: String = "Monster"
## Animation frames (the 4 PNGs from assets/sprites/entities/<name>/Png_animation/).
@export var frames: Array[Texture2D] = []
@export var anim_fps: float = 6.0
## Palette swap: multiplies the sprite colours.
@export var tint: Color = Color.WHITE
@export var sprite_scale: float = 1.0

@export_group("Movement")
@export var can_move: bool = true
@export var move_speed: float = 40.0
## How far from its start position the NPC wanders while idle.
@export var wander_radius: float = 64.0
## Ghost behaviour: backs away from the player instead of approaching.
@export var afraid_of_player: bool = false

@export_group("Scare duel")
## Harmless NPCs never wind up (training dummies).
@export var is_harmless: bool = false
## Starts winding up a scare when the player gets this close.
@export var notice_range: float = 120.0
## When the wind-up finishes, the player loses sanity if still within this range.
@export var scare_range: float = 95.0
## Seconds of visible wind-up. This is the player's window to honk first.
@export var windup_time: float = 1.6
@export var scare_damage: float = 20.0
@export var scare_cooldown: float = 2.5
## Text in the wind-up bubble, e.g. "BOO" or "HA".
@export var windup_text: String = "BOO"
## Sound name in assets/audio/sfx/ played when the scare lands.
@export var scare_sound: String = "boo"

@export_group("When scared by the player")
@export var after_scare: AfterScare = AfterScare.FAINT
## Every entry drops once (list the same prop several times for multiple drops).
@export var loot: Array[PropData] = []
## Scared NPCs scream; other NPCs within this many pixels panic too (chain reactions!). 0 = silent.
@export var scream_radius: float = 100.0
## Delay before the scream spreads, so the cascade is readable.
@export var scream_delay: float = 0.35
## Seconds of running around in panic. Panicking NPCs scare other NPCs they bump into.
@export var panic_time: float = 2.5
@export var panic_speed: float = 150.0
## Seconds until the NPC is back to normal and can be scared again.
@export var recover_time: float = 8.0
