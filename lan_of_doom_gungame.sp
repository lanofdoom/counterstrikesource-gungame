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
// GunGame Toggle
//

static bool g_gungame_enabled = false;

static ConVar g_gungame_enabled_cvar;

static void GunGame_Initialize() {
  g_gungame_enabled_cvar =
      CreateConVar("sm_lanofdoom_gungame_enabled", "0",
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

    PrintHintTextToAll("GunGame Started");
  } else {
    BuyZones_Enable();

    PrintHintTextToAll("GunGame Stopped");
  }

  g_gungame_enabled = enabled;
}

//
// Forwards
//

public void OnPluginStart() {
  // Initialize GunGame Last
  GunGame_Initialize();
}