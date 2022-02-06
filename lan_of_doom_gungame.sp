#include <cstrike>
#include <mapchooser>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

public const Plugin myinfo = {
    name = "GunGame", author = "LAN of DOOM",
    description = "Enables GunGame game mode", version = "1.1.0",
    url = "https://github.com/lanofdoom/counterstrike-gungame"};

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

static void GameEnd_OnMapStart() { g_game_end_triggered = false; }

//
// Levels
//

static ConVar g_gungame_kills_per_level_cvar;

static ArrayList g_gungame_kills_per_level;

#define DEAFULT_WEAPON_ORDER_SIZE 24

#define DEAFULT_KILLS_ON_LAST_LEVEL "1"
#define DEFAULT_KILLS_ON_OTHER_LEVELS "2,"

#define MAX_KILLS_PER_LEVEL_CHARS 6
#define MAX_NUM_LEVELS 100

static void Levels_Initialize() {
  g_gungame_kills_per_level = CreateArray(1, 0);

  char default_cvar[PLATFORM_MAX_PATH] = "";
  for (int i = 0; i < DEAFULT_WEAPON_ORDER_SIZE; i++) {
    if (i + 1 == DEAFULT_WEAPON_ORDER_SIZE) {
      StrCat(default_cvar, PLATFORM_MAX_PATH, DEAFULT_KILLS_ON_LAST_LEVEL);
    } else {
      StrCat(default_cvar, PLATFORM_MAX_PATH, DEFAULT_KILLS_ON_OTHER_LEVELS);
    }
  }

  g_gungame_kills_per_level_cvar =
      CreateConVar("sm_lanofdoom_gungame_kills_per_level", default_cvar,
                   "In gungame mode, how many kills are required in order " ...
                   "to advance past each level in the weapon order as a. " ...
                   "comma-separated list. Any values beyond the number of " ...
                   "weapons in the weapon order will be ignored. Further, " ...
                   "if there are fewer entries in this list than there are " ...
                   "in the weapon order a value of 1 kill per level is used.");
}

static void Levels_OnMapStart() { Levels_Reload(); }

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
// Map Vote
//

static void MapVote_Trigger() {
  if (EndOfMapVoteEnabled() && CanMapChooserStartVote() &&
      !HasEndOfMapVoteFinished()) {
    InitiateMapChooserVote(MapChange_MapEnd);
  }
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
    CS_DropWeapon(client, entity, false, true);
    RemovePlayerItem(client, entity);
    AcceptEntityInput(entity, "Kill");
  }

  entity = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
  if (entity >= 0) {
    CS_DropWeapon(client, entity, false, true);
    RemovePlayerItem(client, entity);
    AcceptEntityInput(entity, "Kill");
  }

  for (;;) {
    entity = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE);
    if (entity < 0) {
      break;
    }

    CS_DropWeapon(client, entity, false, true);
    RemovePlayerItem(client, entity);
    AcceptEntityInput(entity, "Kill");
  }

  if (weapon != CSWeapon_KNIFE) {
    char weapon_alias[PLATFORM_MAX_PATH];
    CS_WeaponIDToAlias(weapon, weapon_alias, PLATFORM_MAX_PATH);

    char weapon_classname[PLATFORM_MAX_PATH];
    Format(weapon_classname, PLATFORM_MAX_PATH, "weapon_%s", weapon_alias);

    GivePlayerItem(client, weapon_classname);
  }
}

static void WeaponManager_OnMapStart() { WeaponManager_Reset(); }

static void WeaponManager_OnPlayerDeath(int attacker_userid,
                                        int victim_userid) {
  if (!g_weapon_manager_enabled) {
    return;
  }

  int victim_client = GetClientOfUserId(victim_userid);
  if (victim_client) {
    SDKUnhook(victim_client, SDKHook_WeaponCanUse,
              WeaponManager_OnWeaponCanUse);
  }

  int attacker_client = GetClientOfUserId(attacker_userid);
  if (!attacker_client) {
    return;
  }

  CSWeaponID old_weapon = WeaponManager_Get(attacker_userid);
  int kills = GetEntProp(attacker_client, Prop_Data, "m_iFrags");
  int level = Levels_GetLevel(kills);
  CSWeaponID new_weapon = WeaponOrder_GetLevel(level);

  PrintToChat(attacker_client, "Frag Count: %d", kills);

  if (new_weapon == CSWeapon_NONE) {
    GameEnd_Trigger(attacker_userid);
  }

  if (WeaponOrder_GetLevel(level + 3) == CSWeapon_NONE) {
    MapVote_Trigger();
  }

  g_player_weapons.Set(attacker_userid, new_weapon);

  if (old_weapon != new_weapon) {
    WeaponManager_RefreshWeapon(attacker_userid);

    char weapon_alias[PLATFORM_MAX_PATH];
    CS_WeaponIDToAlias(new_weapon, weapon_alias, PLATFORM_MAX_PATH);

    PrintToChat(attacker_client, "You are now on level %d of %d: %s", level,
                WeaponOrder_GetNumLevels(), weapon_alias);
  }

  int next_kill_level = Levels_GetLevel(kills + 1);
  CSWeaponID next_kill_weapon = WeaponOrder_GetLevel(next_kill_level);
  if (next_kill_weapon == CSWeapon_NONE) {
    char name[PLATFORM_MAX_PATH];
    if (GetClientName(attacker_client, name, PLATFORM_MAX_PATH)) {
      PrintCenterTextAll("%s is one kill from victory", name);
    }
  }
}

static void WeaponManager_OnPlayerSpawn(int userid) {
  if (!g_weapon_manager_enabled) {
    return;
  }

  WeaponManager_RefreshWeapon(userid);

  int client = GetClientOfUserId(userid);
  if (!client) {
    return;
  }

  SDKHook(client, SDKHook_WeaponCanUse, WeaponManager_OnWeaponCanUse);
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

  if (weapon_id == CSWeapon_C4 || weapon_id == CSWeapon_KNIFE) {
    return Plugin_Continue;
  }

  CSWeaponID level_weapon_id = WeaponManager_Get(userid);

  if (level_weapon_id == weapon_id) {
    return Plugin_Continue;
  }

  if (level_weapon_id == CSWeapon_HEGRENADE) {
    return Plugin_Continue;
  }

  return Plugin_Stop;
}

static Action WeaponManager_OnWeaponDrop(int client, int weapon) {
  if (!g_weapon_manager_enabled) {
    return Plugin_Continue;
  }

  if (!IsValidEntity(weapon)) {
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

  if (weapon_id == CSWeapon_C4) {
    return Plugin_Continue;
  }

  return Plugin_Stop;
}

static void WeaponManager_OnHEGrenadeDetonate(int userid) {
  if (!g_weapon_manager_enabled) {
    return;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    return;
  }

  if (!IsPlayerAlive(client)) {
    return;
  }

  if (WeaponManager_Get(userid) == CSWeapon_HEGRENADE) {
    int entity = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE);
    if (entity < 0) {
      GivePlayerItem(client, "weapon_hegrenade");
    }
  }
}

static Action WeaponManager_OnGrenadeTimerElapsed(Handle timer, any userid) {
  if (!g_weapon_manager_enabled) {
    return Plugin_Stop;
  }

  WeaponManager_OnHEGrenadeDetonate(userid);

  return Plugin_Stop;
}

static void WeaponManager_OnWeaponFire(int userid, const char[] weapon_name) {
  if (!g_weapon_manager_enabled) {
    return;
  }

  CSWeaponID weapon_id = CS_AliasToWeaponID(weapon_name);

  if (weapon_id != CSWeapon_HEGRENADE) {
    return;
  }

  // Fallback in case grenade does not detonate
  CreateTimer(2.5, WeaponManager_OnGrenadeTimerElapsed, userid,
              TIMER_FLAG_NO_MAPCHANGE);
}

static void WeaponManager_OnPlayerActivate(int client) {
  SDKHook(client, SDKHook_WeaponDrop, WeaponManager_OnWeaponDrop);
}

static void WeaponManager_Reset() {
  g_player_weapons.Clear();
}

static void WeaponManager_Enable() {
  g_weapon_manager_enabled = true;

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

static const CSWeaponID kDefaultWeaponOrder[DEAFULT_WEAPON_ORDER_SIZE] = {
    CSWeapon_M249,   CSWeapon_AUG,   CSWeapon_SG552,     CSWeapon_M4A1,
    CSWeapon_AK47,   CSWeapon_FAMAS, CSWeapon_GALIL,     CSWeapon_AWP,
    CSWeapon_SCOUT,  CSWeapon_P90,   CSWeapon_MP5NAVY,   CSWeapon_XM1014,
    CSWeapon_UMP45,  CSWeapon_MAC10, CSWeapon_TMP,       CSWeapon_M3,
    CSWeapon_DEAGLE, CSWeapon_ELITE, CSWeapon_FIVESEVEN, CSWeapon_P228,
    CSWeapon_USP,    CSWeapon_GLOCK, CSWeapon_HEGRENADE, CSWeapon_KNIFE};

static void WeaponOrder_Initialize() {
  static bool initialized = false;
  if (initialized) {
    return;
  }

  if (!CS_IsValidWeaponID(CSWeapon_GLOCK)) {
    return;
  }

  char default_cvar[PLATFORM_MAX_PATH] = "";
  g_gungame_weapon_order = CreateArray(1, DEAFULT_WEAPON_ORDER_SIZE);
  for (int i = 0; i < DEAFULT_WEAPON_ORDER_SIZE; i++) {
    if (i != 0) {
      StrCat(default_cvar, PLATFORM_MAX_PATH, ",");
    }

    g_gungame_weapon_order.Set(i, kDefaultWeaponOrder[i]);

    char weapon_alias[PLATFORM_MAX_PATH];
    CS_WeaponIDToAlias(kDefaultWeaponOrder[i], weapon_alias, PLATFORM_MAX_PATH);

    StrCat(default_cvar, PLATFORM_MAX_PATH, weapon_alias);
  }

  g_gungame_weapon_order_cvar =
      CreateConVar("sm_lanofdoom_gungame_weapon_order", default_cvar,
                   "In gungame mode, defines the order of the weapons.");

  initialized = true;
}

static void WeaponOrder_OnMapStart() { WeaponOrder_Initialize(); }

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

static int WeaponOrder_GetNumLevels() { return g_gungame_weapon_order.Length; }

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
    Levels_Reload();
    WeaponManager_Enable();
    WeaponOrder_Reload();
  } else {
    WeaponManager_Disable();
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
    attacker = userid;
  }

  WeaponManager_OnPlayerDeath(attacker, userid);

  return Plugin_Continue;
}

static Action OnHEGrenadeDetonate(Event event, const char[] name,
                                  bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  WeaponManager_OnHEGrenadeDetonate(userid);
  return Plugin_Continue;
}

static Action OnWeaponFire(Event event, const char[] name,
                           bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  char weapon_name[PLATFORM_MAX_PATH];
  GetEventString(event, "weapon", weapon_name, PLATFORM_MAX_PATH);

  WeaponManager_OnWeaponFire(userid, weapon_name);
  return Plugin_Continue;
}

//
// Forwards
//

public void OnPluginStart() {
  Levels_Initialize();
  WeaponManager_Initialize();
  WeaponOrder_Initialize();

  HookEvent("hegrenade_detonate", OnHEGrenadeDetonate);
  HookEvent("player_activate", OnPlayerActivate);
  HookEvent("player_death", OnPlayerDeath);
  HookEvent("player_spawn", OnPlayerSpawn);
  HookEvent("weapon_fire", OnWeaponFire);

  // Initialize GunGame Last
  GunGame_Initialize();
}

public void OnMapStart() {
  GameEnd_OnMapStart();
  Levels_OnMapStart();
  WeaponManager_OnMapStart();
  WeaponOrder_OnMapStart();
}