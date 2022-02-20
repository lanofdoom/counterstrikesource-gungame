#include <cstrike>
#include <mapchooser>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

public const Plugin myinfo = {
    name = "GunGame", author = "LAN of DOOM",
    description = "Enables GunGame game mode", version = "1.0.1",
    url = "https://github.com/lanofdoom/counterstrikesource-gungame"};

static ConVar g_gungame_enabled_cvar;

//
// Logic
//

static void EndGame(int winner) {
  static bool game_end_triggered = false;

  if (game_end_triggered) {
    return;
  }

  char name[PLATFORM_MAX_PATH];
  if (GetClientName(winner, name, PLATFORM_MAX_PATH)) {
    PrintToChatAll("%s wins!", name);
  }

  int team = GetClientTeam(winner);

  CSRoundEndReason reason;
  if (team == CS_TEAM_CT) {
    reason = CSRoundEnd_CTWin;
  } else if (team == CS_TEAM_T) {
    reason = CSRoundEnd_TerroristWin;
  }

  CS_TerminateRound(2.0, reason);

  int entity = CreateEntityByName("game_end");
  DispatchSpawn(entity);
  AcceptEntityInput(entity, "EndGame");

  game_end_triggered = true;
}

static void TriggerNextMapVote() {
  if (EndOfMapVoteEnabled() && CanMapChooserStartVote() &&
      !HasEndOfMapVoteFinished()) {
    InitiateMapChooserVote(MapChange_MapEnd);
  }
}

static void GetWeaponAndLevel(int frags, CSWeaponID& weapon, int& level,
                              int& num_levels) {
  static const CSWeaponID weapon_order[25] = {
      CSWeapon_M249,  CSWeapon_AWP,    CSWeapon_SG550, CSWeapon_SCOUT,
      CSWeapon_AUG,   CSWeapon_SG552,  CSWeapon_M4A1,  CSWeapon_AK47,
      CSWeapon_FAMAS, CSWeapon_GALIL,  CSWeapon_P90,   CSWeapon_MP5NAVY,
      CSWeapon_UMP45, CSWeapon_MAC10,  CSWeapon_TMP,   CSWeapon_XM1014,
      CSWeapon_M3,    CSWeapon_DEAGLE, CSWeapon_ELITE, CSWeapon_FIVESEVEN,
      CSWeapon_P228,  CSWeapon_USP,    CSWeapon_GLOCK, CSWeapon_HEGRENADE,
      CSWeapon_KNIFE};
  static const int weapon_order_size = 25;
  static const int frags_per_level = 2;

  int level_base_zero = frags / frags_per_level;
  level = 1 + level_base_zero;
  num_levels = weapon_order_size;

  if (level > num_levels) {
    level_base_zero = num_levels - 1;
    level = num_levels;
  }

  weapon = weapon_order[level_base_zero];
}

static CSWeaponID GetWeapon(int frags) {
  CSWeaponID result;
  int unused_level, unused_num_levels;
  GetWeaponAndLevel(frags, result, unused_level, unused_num_levels);
  return result;
}

static Action AllowWeaponImpl(int entity, CSWeaponID allowed_weapon) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
    return Plugin_Continue;
  }

  char alias[PLATFORM_MAX_PATH];
  if (!GetEntityClassname(entity, alias, PLATFORM_MAX_PATH)) {
    return Plugin_Continue;
  }

  if (ReplaceString(alias, PLATFORM_MAX_PATH, "weapon_", "", false) != 1) {
    return Plugin_Continue;
  }

  CSWeaponID weapon_id = CS_AliasToWeaponID(alias);

  if (weapon_id == CSWeapon_C4 || weapon_id == CSWeapon_KNIFE ||
      weapon_id == allowed_weapon) {
    return Plugin_Continue;
  }

  return Plugin_Stop;
}

static Action AllowAk47(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_AK47);
}

static Action AllowAug(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_AUG);
}

static Action AllowAwp(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_AWP);
}

static Action AllowDeagle(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_DEAGLE);
}

static Action AllowElite(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_ELITE);
}

static Action AllowFamas(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_FAMAS);
}

static Action AllowFiveSeven(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_FIVESEVEN);
}

static Action AllowGalil(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_GALIL);
}

static Action AllowGlock(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_GLOCK);
}

static Action AllowHEGrenade(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_HEGRENADE);
}

static Action AllowKnife(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_KNIFE);
}

static Action AllowM249(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_M249);
}

static Action AllowM3(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_M3);
}

static Action AllowM4A1(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_M4A1);
}

static Action AllowMac10(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_MAC10);
}

static Action AllowMp5Navy(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_MP5NAVY);
}

static Action AllowP228(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_P228);
}

static Action AllowP90(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_P90);
}

static Action AllowScout(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_SCOUT);
}

static Action AllowSg550(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_SG550);
}

static Action AllowSg552(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_SG552);
}

static Action AllowTmp(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_TMP);
}

static Action AllowUmp45(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_UMP45);
}

static Action AllowUsp(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_USP);
}

static Action AllowXm1014(int client, int entity) {
  return AllowWeaponImpl(entity, CSWeapon_XM1014);
}

static SDKHookCB AllowWeapon(CSWeaponID weapon) {
  SDKHookCB result;
  switch (weapon) {
    case CSWeapon_AK47: {
      result = AllowAk47;
    }
    case CSWeapon_AUG: {
      result = AllowAug;
    }
    case CSWeapon_AWP: {
      result = AllowAwp;
    }
    case CSWeapon_DEAGLE: {
      result = AllowDeagle;
    }
    case CSWeapon_ELITE: {
      result = AllowElite;
    }
    case CSWeapon_FAMAS: {
      result = AllowFamas;
    }
    case CSWeapon_FIVESEVEN: {
      result = AllowFiveSeven;
    }
    case CSWeapon_GALIL: {
      result = AllowGalil;
    }
    case CSWeapon_GLOCK: {
      result = AllowGlock;
    }
    case CSWeapon_HEGRENADE: {
      result = AllowHEGrenade;
    }
    case CSWeapon_KNIFE: {
      result = AllowKnife;
    }
    case CSWeapon_M249: {
      result = AllowM249;
    }
    case CSWeapon_M3: {
      result = AllowM3;
    }
    case CSWeapon_M4A1: {
      result = AllowM4A1;
    }
    case CSWeapon_MAC10: {
      result = AllowMac10;
    }
    case CSWeapon_MP5NAVY: {
      result = AllowMp5Navy;
    }
    case CSWeapon_P228: {
      result = AllowP228;
    }
    case CSWeapon_P90: {
      result = AllowP90;
    }
    case CSWeapon_SCOUT: {
      result = AllowScout;
    }
    case CSWeapon_SG550: {
      result = AllowSg550;
    }
    case CSWeapon_SG552: {
      result = AllowSg552;
    }
    case CSWeapon_TMP: {
      result = AllowTmp;
    }
    case CSWeapon_UMP45: {
      result = AllowUmp45;
    }
    case CSWeapon_USP: {
      result = AllowUsp;
    }
    case CSWeapon_XM1014: {
      result = AllowXm1014;
    }
    default: {
      result = AllowKnife;
    }
  }

  return result;
}

static void EquipWeapon(int client, CSWeaponID old_weapon,
                        CSWeaponID new_weapon) {
  SDKUnhook(client, SDKHook_WeaponCanUse, AllowWeapon(old_weapon));

  int entity = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
  if (entity >= 0 && IsValidEntity(entity)) {
    RemovePlayerItem(client, entity);
    AcceptEntityInput(entity, "Kill");
  }

  entity = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
  if (entity >= 0 && IsValidEntity(entity)) {
    RemovePlayerItem(client, entity);
    AcceptEntityInput(entity, "Kill");
  }

  for (;;) {
    entity = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE);
    if (entity < 0 || !IsValidEntity(entity)) {
      break;
    }

    RemovePlayerItem(client, entity);
    AcceptEntityInput(entity, "Kill");
  }

  if (new_weapon != CSWeapon_KNIFE) {
    char weapon_alias[PLATFORM_MAX_PATH];
    CS_WeaponIDToAlias(new_weapon, weapon_alias, PLATFORM_MAX_PATH);

    char weapon_classname[PLATFORM_MAX_PATH];
    Format(weapon_classname, PLATFORM_MAX_PATH, "weapon_%s", weapon_alias);

    GivePlayerItem(client, weapon_classname);
  }

  SDKHook(client, SDKHook_WeaponCanUse, AllowWeapon(new_weapon));
}

static void RefillHEGrenade(int userid) {
  int client = GetClientOfUserId(userid);
  if (!client) {
    return;
  }

  int frags = GetClientFrags(client);

  CSWeaponID weapon = GetWeapon(frags);
  if (weapon == CSWeapon_HEGRENADE) {
    EquipWeapon(client, CSWeapon_HEGRENADE, CSWeapon_HEGRENADE);
  }
}

static Action OnHEGrenadeTimerElapsed(Handle timer, any userid) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
    return Plugin_Stop;
  }

  RefillHEGrenade(userid);

  return Plugin_Stop;
}

static Action OnWeaponSpawn(int entity) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
    return Plugin_Continue;
  }

  int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
  if (client > 0 || client <= MaxClients) {
    return Plugin_Continue;
  }

  AcceptEntityInput(entity, "Kill");

  return Plugin_Stop;
}

//
// Hooks
//

static Action OnPlayerSpawn(Event event, const char[] name,
                            bool dont_broadcast) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
    return Plugin_Continue;
  }

  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Continue;
  }

  int frags = GetClientFrags(client);
  CSWeaponID weapon = GetWeapon(frags);
  EquipWeapon(client, weapon, weapon);

  return Plugin_Continue;
}

static Action OnPlayerDeath(Event event, const char[] name,
                            bool dont_broadcast) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
    return Plugin_Continue;
  }

  int victim_userid = GetEventInt(event, "userid");
  if (!victim_userid) {
    return Plugin_Continue;
  }

  int victim_client = GetClientOfUserId(victim_userid);
  if (!victim_client) {
    return Plugin_Continue;
  }

  int victim_frags = GetClientFrags(victim_client);
  CSWeaponID victim_weapon = GetWeapon(victim_frags);
  SDKUnhook(victim_client, SDKHook_WeaponCanUse, AllowWeapon(victim_weapon));

  int attacker = GetEventInt(event, "attacker");
  if (!attacker) {
    attacker = victim_userid;
  }

  int attacker_client = GetClientOfUserId(attacker);
  if (!attacker_client) {
    return Plugin_Continue;
  }

  int old_frags = GetClientFrags(attacker_client);

  int frags;
  if (attacker == victim_userid) {
    if (old_frags == 0) {
      SetEntProp(attacker_client, Prop_Data, "m_iFrags", old_frags + 1);
      frags = old_frags;
    } else {
      frags = old_frags - 1;
    }
  } else {
    frags = old_frags + 1;
  }

  CSWeaponID old_weapon = GetWeapon(old_frags);

  CSWeaponID weapon;
  int level, num_levels;
  GetWeaponAndLevel(frags, weapon, level, num_levels);

  if (old_weapon != weapon) {
    char weapon_alias[PLATFORM_MAX_PATH];
    CS_WeaponIDToAlias(weapon, weapon_alias, PLATFORM_MAX_PATH);

    PrintToChat(attacker_client, "You are now on level %d of %d: %s", level,
                num_levels, weapon_alias);

    EquipWeapon(attacker_client, old_weapon, weapon);
  }

  if (level + 4 >= num_levels) {
    TriggerNextMapVote();
  }

  if (level == num_levels) {
    if (weapon != old_weapon) {
      char player_name[PLATFORM_MAX_PATH];
      if (GetClientName(attacker_client, player_name, PLATFORM_MAX_PATH)) {
        PrintCenterTextAll("%s is one kill from victory", player_name);
      }
    } else {
      EndGame(attacker_client);
    }
  }

  return Plugin_Continue;
}

static Action OnHEGrenadeDetonate(Event event, const char[] name,
                                  bool dont_broadcast) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
    return Plugin_Continue;
  }

  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  RefillHEGrenade(userid);

  return Plugin_Continue;
}

static Action OnWeaponFire(Event event, const char[] name,
                           bool dont_broadcast) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
    return Plugin_Continue;
  }

  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  CSWeaponID weapon_id = CS_AliasToWeaponID(name);

  if (weapon_id != CSWeapon_HEGRENADE) {
    return Plugin_Continue;
  }

  // Fallback in case grenade does not detonate
  CreateTimer(2.5, OnHEGrenadeTimerElapsed, userid, TIMER_FLAG_NO_MAPCHANGE);

  return Plugin_Continue;
}

static Action OnWeaponDrop(int client, int weapon) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
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

static void OnCvarChanged(ConVar convar, char[] old_value, char[] new_value) {
  if (!GetConVarBool(g_gungame_enabled_cvar)) {
    return;
  }

  for (int client = 1; client <= MaxClients; client++) {
    if (!IsClientInGame(client)) {
      continue;
    }

    int frags = GetClientFrags(client);
    if (frags < 0) {
      SetEntProp(client, Prop_Data, "m_iFrags", 0);
      frags = 0;
    }

    CSWeaponID weapon = GetWeapon(frags);
    EquipWeapon(client, weapon, weapon);
  }

  for (int entity = 0; entity <= GetMaxEntities(); entity++) {
    if (!IsValidEntity(entity)) {
      continue;
    }

    char classname[PLATFORM_MAX_PATH];
    if (!GetEntityClassname(entity, classname, PLATFORM_MAX_PATH)) {
      continue;
    }

    if (!StrContains(classname, "weapon_") ||
        StrEqual(classname, "weapon_c4")) {
      continue;
    }

    OnWeaponSpawn(entity);
  }
}

//
// Forwards
//

public void OnEntityCreated(int entity, const char[] classname) {
  if (StrContains(classname, "weapon_") && !StrEqual(classname, "weapon_c4")) {
    SDKHook(entity, SDKHook_Spawn, OnWeaponSpawn);
  }
}

public void OnClientPutInServer(int client) {
  SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
}

public void OnPluginStart() {
  g_gungame_enabled_cvar = CreateConVar("sm_lanofdoom_gungame_enabled", "1",
                                        "If true, gungame mode is enabled.");
  g_gungame_enabled_cvar.AddChangeHook(OnCvarChanged);

  HookEvent("hegrenade_detonate", OnHEGrenadeDetonate);
  HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", OnPlayerSpawn);
  HookEvent("weapon_fire", OnWeaponFire);
}