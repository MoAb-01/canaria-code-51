class_name WeaponData
extends Resource
## Reusable weapon configuration resource.
## Decouples weapon ballistics, capacity, and noise parameters from actors.

@export var weapon_name: String = "9mm Service Pistol"
@export var damage: float = 25.0
@export var bullet_speed: float = 950.0
@export var fire_cooldown: float = 0.24
@export var mag_size: int = 8
@export var max_reserve: int = 32
@export var reload_duration: float = 1.1
@export var noise_radius: float = 420.0
