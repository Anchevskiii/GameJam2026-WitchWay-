class_name NpcData
extends Resource

## Configuration for one NPC type (Ghost, Tired Vampire, Witch...).
## Saved as .tres files in data/npcs/. One NPC scene + different NpcData = different monster.

enum AfterScare {
	FLEE,        ## runs off and fades out (Ghost, Witch, Bat)
	FAINT,       ## falls over and naps (Vampire, Werewolf)
	FALL_APART,  ## pops into pieces (Jack-o'-lanterns)
}

enum Behavior {
	PASSIVE,   ## always visible, slow/stationary, FOV cone always shown
	AGGRESSIVE, ## lurks in corners/doorways, invisible until lit, FOV-triggered scare
	HIDDEN,    ## hides inside furniture and ambushes when the player opens / hides
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
## Rush speed when aggressively dashing towards player upon spotting them.
@export var rush_speed: float = 135.0
## How far from its start position the NPC wanders while idle.
@export var wander_radius: float = 64.0
## Ghost behaviour: backs away from the player instead of approaching.
@export var afraid_of_player: bool = false
## Ghost attributes: passes through walls and periodically phases in/out.
@export var is_ghost: bool = false
@export var can_pass_walls: bool = false

@export_group("Behavior type")
## Which of the three playstyles this monster uses (see the enum above).
@export var behavior: Behavior = Behavior.PASSIVE

@export_group("Scare duel")
## Harmless NPCs never wind up (training dummies).
@export var is_harmless: bool = false
## How far the NPC can see (pixels). It only notices the player inside its view cone,
## with no walls/furniture in between, and never while the player is hidden.
@export var notice_range: float = 120.0
## Half-width of the view cone in degrees (50 = 100 degree cone in the direction it faces).
@export var view_half_angle: float = 50.0
## While standing around, it turns to look the other way every min..max seconds.
@export var look_around_min: float = 2.0
@export var look_around_max: float = 4.5
## When the wind-up finishes, the player loses sanity if still within this range.
@export var scare_range: float = 95.0
## Seconds of visible wind-up. The player's window to hide or get out of range.
@export var windup_time: float = 1.6
@export var scare_damage: float = 20.0
@export var scare_cooldown: float = 2.5
## Text in the wind-up bubble, e.g. "BOO" or "HA".
@export var windup_text: String = "BOO"
## Sound name in assets/audio/sfx/ played when the scare lands.
@export var scare_sound: String = "boo"

@export_group("Hiding & ambush")
## Sneaks into free cupboards/couches and jumps out at a player who comes close.
## Its head peeks out now and then - BOO the hiding spot first and IT gets the surprise.
@export var hides_in_furniture: bool = false
## Stalks or waits in dark corners or doorways to jump out at the player.
@export var hides_in_corners: bool = true
## Jumps out when the player gets this close to its hiding spot.
@export var ambush_range: float = 70.0
## Wind-up after jumping out (short: that's the point of an ambush).
@export var ambush_windup: float = 0.4
## Higher damage applied when player is caught by surprise ambush.
@export var ambush_damage: float = 28.0
## Gives up and comes out after this many seconds of nobody walking by.
@export var hide_time: float = 12.0
## Seconds to wander around before looking for a hiding spot again.
@export var hide_cooldown: float = 6.0
## Only considers hiding spots within this distance.
@export var hide_search_radius: float = 260.0

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
