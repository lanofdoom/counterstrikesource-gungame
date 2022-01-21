## Releases

* [Latest](https://lanofdoom.github.io/counterstrike-gungame/releases/latest/lan_of_doom_gungame.tar.gz) ([Source](https://lanofdoom.github.io/counterstrike-gungame/releases/latest/lanofdoom_gungame_source.tar.gz)) (1.0.1)
* [Nightly](https://lanofdoom.github.io/counterstrike-gungame/releases/nightly/lan_of_doom_gungame.tar.gz) ([Source](https://lanofdoom.github.io/counterstrike-gungame/releases/nightly/lanofdoom_gungame_source.tar.gz))

## Installation
Extract ``lan_of_doom_gungame.tar.gz`` to your server's ``css/cstrike`` directory.

# Console Variables

``sm_lanofdoom_gungame_enabled`` If ``1``, gungame mode is enabled. ``0``
by default.

``sm_lanofdoom_gungame_weapon_order`` In gungame mode, controls order of weapon
progression. Set as an ordered, comma-separated list of guns. The default value
of this CVAR is undefined and may vary by game.

``sm_lanofdoom_gungame_kills_per_level`` In gungame mode, specifies how many
kills are required in order to advance past each level in the weapon order as a
comma-separated list. Any values beyond the number of weapons in the weapon
order will be ignored. Further, if there are fewer entries in this list than
there are in ``sm_lanofdoom_gungame_weapon_order`` a value of 1 kill per level
is used for the unspecified levels. The default value of this CVAR is undefined
and may vary by game.

## Version History

### 1.0.1 ([Download](https://lanofdoom.github.io/counterstrike-gungame/releases/v1.0.1/lan_of_doom_gungame.tar.gz)) ([Source](https://lanofdoom.github.io/counterstrike-gungame/releases/v1.0.1/lanofdoom_gungame_source.tar.gz)) 
* Populate ``sm_lanofdoom_gungame_weapon_order`` by default
* Default to two kills per level for all levels except for last level
* Decrement level if player falls to their death

### 1.0.0 ([Download](https://lanofdoom.github.io/counterstrike-gungame/releases/v1.0.0/lan_of_doom_gungame.tar.gz)) ([Source](https://lanofdoom.github.io/counterstrike-gungame/releases/v1.0.0/lanofdoom_gungame_source.tar.gz)) 
* Initial Release
