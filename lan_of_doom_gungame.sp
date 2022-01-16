#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

public const Plugin myinfo = {
    name = "LAN of DOOM GunGame",
    author = "LAN of DOOM",
    description = "Enables GunGame game mode",
    version = "0.1.0",
    url = "https://github.com/lanofdoom/counterstrike-gungame"};

//
// Buy Zones
//

static bool g_buyzones_enabled = true;

static const char kBuyZoneEntityName[] = "func_buyzone";

static void BuyZones_UpdateEntities(const char[] classname,
                                    const char[] action) {
  int index = FindEntityByClassname(INVALID_ENT_REFERENCE, classname);
  while (index != INVALID_ENT_REFERENCE) {
    AcceptEntityInput(index, action);
    index = FindEntityByClassname(index, classname)
  }
}

static void BuyZones_Disable() {
  if (g_buyzones_enabled) {
    BuyZones_UpdateEntities(kBuyZoneEntityName, "Disable");
  }
  g_buyzones_enabled = false;
}

static void BuyZones_Enable() {
  if (!g_buyzones_enabled) {
    BuyZones_UpdateEntities(kBuyZoneEntityName, "Enable");
  }
  g_buyzones_enabled = true;
}

//
// Game End
//

static bool g_game_end_triggered = false;

static void GameEnd_Trigger(int winner_userid) {
  if (g_game_end_triggered) {
    return;
  }

  CSRoundEndReason reason = CSRoundEnd_Draw;
  int client = GetClientOfUserId(winner_userid);
  if (client) {
    char name[PLATFORM_MAX_PATH];
    if (GetClientName(client, name, PLATFORM_MAX_PATH)) {
      PrintToChatAll("%s wins!", name);
    }

    int team = GetClientTeam(client);
    if (team == CS_TEAM_CT) {
      reason = CSRoundEnd_CTWin;
    } else if (team == CS_TEAM_T) {
      reason = CSRoundEnd_TerroristWin;
    }
  }

  CS_TerminateRound(2.0, reason);

  int entity = CreateEntityByName("game_end");
  DispatchSpawn(entity);
  AcceptEntityInput(entity, "EndGame");

  g_game_end_triggered = true;
}

static void GameEnd_OnMapStart() {
  g_game_end_triggered = false;
}

//
// Kill Tracking
//

static bool g_game_state_enable = false;

static ArrayList g_player_kills;

static void KillTracking_Initialize() { g_player_kills = CreateArray(1, 0); }

static KillTracking_OnPlayerDeath(int attacker_userid, int victim_userid) {
  if (!g_game_state_enable) {
    return;
  }

  int attacker_client = GetClientOfUserId(attacker_userid);
  if (!attacker_client) {
    return;
  }

  int victim_client = GetClientOfUserId(victim_userid);
  if (!victim_client) {
    return;
  }

  int attacker_team = GetClientTeam(attacker_client);
  int victim_team = GetClientTeam(victim_client);

  if (attacker_team == victim_team) {
    return;
  }

  while (g_player_kills.Length <= attacker_userid) {
    g_player_kills.Push(0);
  }

  int old_kills = g_player_kills.Get(attacker_userid);
  int new_kills = old_kills + 1;
  g_player_kills.Set(attacker_userid, new_kills);
}

static void KillTracking_Reset() { g_player_kills.Clear(); }

static void KillTracking_Enable() {
  KillTracking_Reset();
  g_game_state_enable = true;
}

static void KillTracking_Disable() { g_game_state_enable = false; }

static int KillTracking_Get(int userid) {
  if (userid <= g_player_kills.Length) {
    return g_player_kills.Get(userid);
  }

  return 0;
}

//
// Levels
//

static ConVar g_gungame_kills_per_level_cvar;

static ArrayList g_gungame_kills_per_level;

#define MAX_KILLS_PER_LEVEL_CHARS 6
#define MAX_NUM_LEVELS 100

static void Levels_Initialize() {
  g_gungame_kills_per_level = CreateArray(1, 0);
  g_gungame_kills_per_level_cvar =
      CreateConVar("sm_lanofdoom_gungame_kills_per_level", "",
                   "In gungame mode, how many kills are required in order " ...
                   "to advance past each level in the weapon order as a. " ...
                   "comma-separated list. Any values beyond the number of " ...
                   "weapons in the weapon order will be ignored. Further, " ...
                   "if there are fewer entries in this list than there are " ...
                   "in the weapon order a value of 1 kill per level is used.");
}

static void Levels_Reload() {
  char kills_per_level[MAX_KILLS_PER_LEVEL_CHARS * MAX_NUM_LEVELS];
  GetConVarString(g_gungame_kills_per_level_cvar, kills_per_level,
                  sizeof(kills_per_level));

  char split_kills_per_level[MAX_NUM_LEVELS][MAX_KILLS_PER_LEVEL_CHARS];
  int num_levels = ExplodeString(kills_per_level, ",", split_kills_per_level,
                                 MAX_NUM_LEVELS, MAX_KILLS_PER_LEVEL_CHARS);

  g_gungame_kills_per_level.Resize(num_levels);
  for (int i = 0; i < num_levels; i++) {
    int kills = StringToInt(split_kills_per_level[i]);
    if (kills <= 0) {
      kills = 1;
    }

    g_gungame_kills_per_level.Set(i, kills);
  }
}

static int Levels_GetLevel(int kills) {
  for (int i = 0; i < g_gungame_kills_per_level.Length; i++) {
    if (kills == 0) {
      return i;
    }

    kills -= g_gungame_kills_per_level.Get(i);

    if (kills < 0) {
      return i;
    }
  }

  return g_gungame_kills_per_level.Length + kills;
}

//
// Weapon Manager
//

static bool g_weapon_manager_enabled = false;

static ArrayList g_player_weapons;

static void WeaponManager_Initialize() { g_player_weapons = CreateArray(1, 0); }

static CSWeaponID WeaponManager_Get(int userid) {
  while (g_player_weapons.Length <= userid) {
    g_player_weapons.Push(WeaponOrder_GetLevel(0));
  }

  return g_player_weapons.Get(userid);
}

static void WeaponManager_RefreshWeapon(int userid) {
  int client = GetClientOfUserId(userid);
  if (!client) {
    return;
  }

  CSWeaponID weapon = WeaponManager_Get(userid);
  if (weapon == CSWeapon_NONE) {
    return;
  }

  int entity = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
  if (entity >= 0) {
    RemovePlayerItem(client, entity);
  }

  entity = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
  if (entity >= 0) {
    RemovePlayerItem(client, entity);
  }

  entity = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
  if (entity >= 0) {
    RemovePlayerItem(client, entity);
  }

  for (;;) {
    entity = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE);
    if (entity < 0) {
      break;
    }

    RemovePlayerItem(client, entity);
  }

  char weapon_alias[PLATFORM_MAX_PATH];
  CS_WeaponIDToAlias(weapon, weapon_alias, PLATFORM_MAX_PATH);

  char weapon_classname[PLATFORM_MAX_PATH];
  Format(weapon_classname, PLATFORM_MAX_PATH, "weapon_%s", weapon_alias);

  GivePlayerItem(client, weapon_classname);
}

static void WeaponManager_OnPlayerDeath(int attacker_userid) {
  if (!g_weapon_manager_enabled) {
    return;
  }

  CSWeaponID old_weapon = WeaponManager_Get(attacker_userid);
  int kills = KillTracking_Get(attacker_userid);
  int level = Levels_GetLevel(kills);
  CSWeaponID new_weapon = WeaponOrder_GetLevel(level);

  if (new_weapon == CSWeapon_NONE) {
    GameEnd_Trigger(attacker_userid);
  }

  g_player_weapons.Set(attacker_userid, new_weapon);

  if (old_weapon != new_weapon) {
    WeaponManager_RefreshWeapon(attacker_userid);
  }
}

static void WeaponManager_OnPlayerSpawn(int userid) {
  if (!g_weapon_manager_enabled) {
    return;
  }

  WeaponManager_RefreshWeapon(userid);
}

static Action WeaponManager_OnWeaponCanUse(int client, int weapon) {
  if (!g_weapon_manager_enabled) {
    return Plugin_Continue;
  }

  int userid = GetClientUserId(client);
  if (!userid) {
    return Plugin_Continue;
  }

  char alias[PLATFORM_MAX_PATH];
  if (!GetEntityClassname(weapon, alias, PLATFORM_MAX_PATH)) {
    return Plugin_Continue;
  }

  if (ReplaceString(alias, PLATFORM_MAX_PATH, "weapon_", "", false) != 1) {
    return Plugin_Continue;
  }

  CSWeaponID weapon_id = CS_AliasToWeaponID(alias);
  if (weapon_id == WeaponManager_Get(userid)) {
    return Plugin_Continue;
  }

  return Plugin_Stop;
}

static Action WeaponManager_OnWeaponDrop(int client, int weapon) {
  if (g_weapon_manager_enabled) {
    return Plugin_Stop;
  }

  return Plugin_Continue;
}

// TODO: Handle Grenades

static void WeaponManager_OnPlayerActivate(int client) {
  SDKHook(client, SDKHook_WeaponCanUse, WeaponManager_OnWeaponCanUse);
  SDKHook(client, SDKHook_WeaponDrop, WeaponManager_OnWeaponDrop);
}

static void WeaponManager_Reset() {
  KillTracking_Reset();
  g_player_weapons.Clear();
}

static void WeaponManager_Enable() {
  g_weapon_manager_enabled = true;
  KillTracking_Enable();

  WeaponManager_Reset();
  for (int client = 1; client <= MaxClients; client++) {
    if (IsClientInGame(client) && IsPlayerAlive(client)) {
      int userid = GetClientUserId(client);
      if (!userid) {
        continue;
      }

      WeaponManager_RefreshWeapon(userid);
    }
  }
}

static void WeaponManager_Disable() { g_weapon_manager_enabled = false; }

//
// Weapon Order
//

static ConVar g_gungame_weapon_order_cvar;

static ArrayList g_gungame_weapon_order;

#define MAX_WEAPON_NAME_LENGTH 50
#define MAX_NUM_WEAPONS 100

#define CSS_DEF_WEAPON_ORDER_SIZE 23
static const CSWeaponID kCssDefaultWeaponOrder[CSS_DEF_WEAPON_ORDER_SIZE] = {
    CSWeapon_GLOCK,     CSWeapon_USP,       CSWeapon_P228,    CSWeapon_DEAGLE,
    CSWeapon_FIVESEVEN, CSWeapon_ELITE,     CSWeapon_M3,      CSWeapon_XM1014,
    CSWeapon_TMP,       CSWeapon_MAC10,     CSWeapon_MP5NAVY, CSWeapon_UMP45,
    CSWeapon_P90,       CSWeapon_GALIL,     CSWeapon_FAMAS,   CSWeapon_AK47,
    CSWeapon_SCOUT,     CSWeapon_M4A1,      CSWeapon_SG552,   CSWeapon_AUG,
    CSWeapon_M249,      CSWeapon_HEGRENADE, CSWeapon_KNIFE};

#define CSGO_DEF_WEAPON_ORDER_SIZE 31
static const CSWeaponID kCsgoDefaultWeaponOrder[CSGO_DEF_WEAPON_ORDER_SIZE] = {
    CSWeapon_GLOCK, CSWeapon_P250,      CSWeapon_FIVESEVEN, CSWeapon_HKP2000,
    CSWeapon_TEC9,  CSWeapon_ELITE,     CSWeapon_DEAGLE,    CSWeapon_SSG08,
    CSWeapon_NOVA,  CSWeapon_XM1014,    CSWeapon_SAWEDOFF,  CSWeapon_M249,
    CSWeapon_NEGEV, CSWeapon_MAG7,      CSWeapon_MP7,       CSWeapon_UMP45,
    CSWeapon_P90,   CSWeapon_BIZON,     CSWeapon_MP9,       CSWeapon_MAC10,
    CSWeapon_FAMAS, CSWeapon_GALILAR,   CSWeapon_AUG,       CSWeapon_SG556,
    CSWeapon_M4A1,  CSWeapon_AK47,      CSWeapon_SCAR20,    CSWeapon_G3SG1,
    CSWeapon_AWP,   CSWeapon_HEGRENADE, CSWeapon_KNIFE};

static void WeaponOrder_Initialize() {
  static bool initialized = false;
  if (initialized) {
    return;
  }

  if (!CS_IsValidWeaponID(CSWeapon_GLOCK)) {
    return;
  }

  char folder_name[PLATFORM_MAX_PATH];
  GetGameFolderName(folder_name, PLATFORM_MAX_PATH);

  int weapon_order_size;
  if (StrEqual(folder_name, "cstrike")) {
    weapon_order_size = CSS_DEF_WEAPON_ORDER_SIZE;
  } else if (StrEqual(folder_name, "csgo")) {
    weapon_order_size = CSGO_DEF_WEAPON_ORDER_SIZE;
  } else {
    LogError("ERROR: Unsupported game %s", folder_name);
    weapon_order_size = 0;
  }

  char default_cvar[PLATFORM_MAX_PATH] = "";
  g_gungame_weapon_order = CreateArray(1, weapon_order_size);
  for (int i = 0; i < weapon_order_size; i++) {
    if (i != 0) {
      StrCat(default_cvar, PLATFORM_MAX_PATH, ",");
    }

    CSWeaponID weapon_id;
    if (StrEqual(folder_name, "cstrike")) {
      weapon_id = kCssDefaultWeaponOrder[i];
    } else {
      weapon_id = kCsgoDefaultWeaponOrder[i];
    }

    g_gungame_weapon_order.Set(i, weapon_id);

    char weapon_alias[PLATFORM_MAX_PATH];
    CS_WeaponIDToAlias(weapon_id, weapon_alias, PLATFORM_MAX_PATH);

    StrCat(default_cvar, PLATFORM_MAX_PATH, weapon_alias);
  }

  g_gungame_weapon_order_cvar =
      CreateConVar("sm_lanofdoom_gungame_weapon_order", default_cvar,
                   "In gungame mode, defines the order of the weapons.");

  initialized = true;
}

static void WeaponOrder_OnMapStart() {
  WeaponOrder_Initialize();
}

static void WeaponOrder_Reload() {
  char weapon_order[MAX_WEAPON_NAME_LENGTH * MAX_NUM_WEAPONS];
  GetConVarString(g_gungame_weapon_order_cvar, weapon_order,
                  sizeof(weapon_order));

  char split_weapon_order[MAX_NUM_WEAPONS][MAX_WEAPON_NAME_LENGTH];
  int num_weapons = ExplodeString(weapon_order, ",", split_weapon_order,
                                  MAX_NUM_WEAPONS, MAX_WEAPON_NAME_LENGTH);

  ArrayList new_weapon_order = CreateArray(1, num_weapons);
  for (int i = 0; i < num_weapons; i++) {
    CSWeaponID id = CS_AliasToWeaponID(split_weapon_order[i]);
    if (id == CSWeapon_NONE || !CS_IsValidWeaponID(id)) {
      LogError("ERROR: Invalid weapon %s", split_weapon_order[i]);
      CloseHandle(new_weapon_order);
    }

    new_weapon_order.Set(i, id);
  }

  CloseHandle(g_gungame_weapon_order);

  g_gungame_weapon_order = new_weapon_order;
}

static CSWeaponID WeaponOrder_GetLevel(int level) {
  if (level >= g_gungame_weapon_order.Length) {
    return CSWeapon_NONE;
  }

  return g_gungame_weapon_order.Get(level);
}

//
// GunGame Toggle
//

static bool g_gungame_enabled = false;

static ConVar g_gungame_enabled_cvar;

static void GunGame_Initialize() {
  g_gungame_enabled_cvar = CreateConVar("sm_lanofdoom_gungame_enabled", "0",
                                        "If true, gungame mode is enabled.");
  GunGame_UpdateFromCvar();

  g_gungame_enabled_cvar.AddChangeHook(GunGame_OnCvarChanged);
}

static void GunGame_OnCvarChanged(ConVar convar, char[] old_value,
                                  char[] new_value) {
  GunGame_UpdateFromCvar();
}

static void GunGame_UpdateFromCvar() {
  bool enabled = GetConVarBool(g_gungame_enabled_cvar);
  if (enabled == g_gungame_enabled) {
    return;
  }

  if (enabled) {
    BuyZones_Disable();
    KillTracking_Enable();
    Levels_Reload();
    WeaponManager_Enable();
    WeaponOrder_Reload();

    PrintHintTextToAll("GunGame Started");
  } else {
    BuyZones_Enable();
    KillTracking_Disable();
    WeaponManager_Disable();

    PrintHintTextToAll("GunGame Stopped");
  }

  g_gungame_enabled = enabled;
}

//
// Hooks
//

static Action OnPlayerActivate(Event event, const char[] name,
                               bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(userid);
  if (!userid) {
    return Plugin_Continue;
  }

  WeaponManager_OnPlayerActivate(client);

  return Plugin_Continue;
}

static Action OnPlayerSpawn(Event event, const char[] name,
                            bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  WeaponManager_OnPlayerSpawn(userid);

  return Plugin_Continue;
}

static Action OnPlayerDeath(Event event, const char[] name,
                            bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  int attacker = GetEventInt(event, "attacker");
  if (!attacker) {
    return Plugin_Continue;
  }

  KillTracking_OnPlayerDeath(attacker, userid);
  WeaponManager_OnPlayerDeath(attacker);

  return Plugin_Continue;
}

//
// Forwards
//

public void OnPluginStart() {
  KillTracking_Initialize();
  Levels_Initialize();
  WeaponManager_Initialize();
  WeaponOrder_Initialize();

  HookEvent("player_activate", OnPlayerActivate);
  HookEvent("player_death", OnPlayerDeath);
  HookEvent("player_spawn", OnPlayerSpawn);

  // Initialize GunGame Last
  GunGame_Initialize();
}

public void OnMapStart() {
  GameEnd_OnMapStart();
  WeaponOrder_OnMapStart();
}