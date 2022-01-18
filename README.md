# LAN of DOOM GunGame plugin
A SourceMod GunGame plugin for CS:S and CS:GO servers.

# Building
Check out the repository and run the ``./build.sh`` script.

# Installation
Copy ``lan_of_doom_gungame.smx`` to your server's
``css/cstrike/addons/sourcemod/plugins`` directory.

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
is used for the unspecified levels. Empty by default.
