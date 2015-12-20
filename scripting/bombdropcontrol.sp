#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION  		"v1.5"
#define PLUGIN_DESCRIPTION 		"Pass C4 to near terrorist player on set distance"

#define BOMB_WEAPON "weapon_c4"

public Plugin myinfo = {
    name = "Bomb Drop Control",
    author = "Nerus",
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?t=262398"
};

Handle sm_bdc_enable = INVALID_HANDLE;
Handle sm_bdc_pass_bots = INVALID_HANDLE;
Handle sm_bdc_maximum_distance = INVALID_HANDLE;
Handle sm_bdc_pass_advert = INVALID_HANDLE;
Handle sm_bdc_drop_advert = INVALID_HANDLE;
Handle sb_bdc_drop_deny_sound = INVALID_HANDLE;

bool PLUGIN_ENABLED = true;
bool PASS_TO_BOTS = false;
int BOMB_PASS_DISTANCE = 300;
bool PASS_ADVERTS_ENABLED = true;
bool DROP_ADVERT_ENABLED = true;

char deny_sound_name[PLATFORM_MAX_PATH];

public void SetConVars() 
{
	CreateConVar("sm_bdc_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION);

	sm_bdc_enable = CreateConVar("sm_bdc_enable", "1", "Enable or disable the drop bomb restriction 0 - disabled, 1 - enabled");

	sm_bdc_pass_bots = CreateConVar("sm_bdc_pass_bots", "0", "Enable or disable passing bomb for near bot 0 - disabled, 1 - enabled");
	
	sm_bdc_maximum_distance = CreateConVar("sm_bdc_maximum_distance", "300", "Maximum distance to pass bomb, value must be > 100");

	sm_bdc_pass_advert = CreateConVar("sm_bdc_pass_advert", "1", "Enable or disable advertisements in chat on passing bomb 0 - disabled, 1 - enabled");

	sm_bdc_drop_advert = CreateConVar("sm_bdc_drop_advert", "1", "Enable or disable advertisement denay on drop bomb 0 - disabled, 1 - enabled");

	sb_bdc_drop_deny_sound = CreateConVar("sb_bdc_drop_deny_sound", "buttons/button11.wav", "The name of the sound to play when an action is denied");

	AutoExecConfig(true, "bombdropcontrol");
}

public void SetValues() 
{
	PLUGIN_ENABLED = GetConVarBool(sm_bdc_enable);

	PASS_TO_BOTS = GetConVarBool(sm_bdc_pass_bots);

	BOMB_PASS_DISTANCE = GetConVarInt(sm_bdc_maximum_distance);
}

public void SetHooks()
{
	HookConVarChange(sm_bdc_enable, OnConVarEnableChange);
	
	HookConVarChange(sm_bdc_pass_bots, OnConVarPassToBotsChange);

	HookConVarChange(sm_bdc_maximum_distance, OnConVarMaximumDistanceChange);

	HookConVarChange(sm_bdc_pass_advert, OnConVarPassAdvertisementsChange);

	HookConVarChange(sm_bdc_drop_advert, OnConVarDropAdvertisementChange);

	HookConVarChange(sb_bdc_drop_deny_sound, OnConVarDropDenySoundChange);
}

public void OnConVarEnableChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(StrEqual(newValue, "1") || StrEqual(newValue, "true", false)) PLUGIN_ENABLED = true;
	else PLUGIN_ENABLED = false;
}

public void OnConVarPassToBotsChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(StrEqual(newValue, "1") || StrEqual(newValue, "true", false)) PASS_TO_BOTS = true;
	else PASS_TO_BOTS = false;
}

public void OnConVarMaximumDistanceChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int value = StringToInt(newValue, 300);
	if(value > 100) BOMB_PASS_DISTANCE = value;
}

public void OnConVarPassAdvertisementsChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(StrEqual(newValue, "1") || StrEqual(newValue, "true", false)) PASS_ADVERTS_ENABLED = true;
	else PASS_ADVERTS_ENABLED = false;
}

public void OnConVarDropAdvertisementChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(StrEqual(newValue, "1") || StrEqual(newValue, "true", false)) DROP_ADVERT_ENABLED = true;
	else DROP_ADVERT_ENABLED = false;
}

public void OnConVarDropDenySoundChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetSound();
}

public void OnPluginStart()
{	
	LoadTranslations("bombdropcontrol.phrases");

	SetConVars();

	SetValues();
	
	SetHooks();

	AddCommandListener(OnCommandDrop, "drop");
}

public void SetSound()
{
	GetConVarString(sb_bdc_drop_deny_sound, deny_sound_name, sizeof(deny_sound_name));

	if(strcmp(deny_sound_name, ""))
	{
		char buffer[PLATFORM_MAX_PATH];
		PrecacheSound(deny_sound_name, true);
		Format(buffer, sizeof(buffer), "sound/%s", deny_sound_name);
		AddFileToDownloadsTable(buffer);
	}
}

public void OnMapStart()
{
	SetSound();
}

/**
 * Event on player drop weapon 
 *
 * @param client 	An client entity index.
 * @return			Returns true if the switch success, false otherwise.
 */
public Action OnCommandDrop(int client, const char[] command, int argc)
{
	if(!PLUGIN_ENABLED) 
		return Plugin_Continue;

	if(!IsClientValid(client) || IsFakeClient(client)) 
		return Plugin_Continue;

	char weapon_name[32];
	int weapon = SetActiveWeapon(client, weapon_name);
	
	if(weapon > -1 && IsBomb(weapon_name))
	{
		int terrorist = GetNearstTerroristPlayer(client);

		if(IsClientValid(terrorist) && IsTerrorist(terrorist)) 
		{
			if(GiveBombToAnotherPlayer(client, terrorist, weapon)) 
			{
				SetLastWeapon(client);
				if(PASS_ADVERTS_ENABLED) 
				{
					PrintToChat(client, "\x03[SM]\x01 %t", "Bomb_Removed", '\x04' ,terrorist, '\x01');
					PrintToChat(terrorist, "\x03[SM]\x01 %t", "Bomb_Added", '\x04' ,client, '\x01');
				}
			}
		}
		else 
		{
			if(DROP_ADVERT_ENABLED)
			{
				DenySound(client);
				PrintToChat(client, "\x03[SM]\x01 %t", "Bomb_Drop_Denied", '\x04', BOMB_PASS_DISTANCE, '\x01');
				
			}
				
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

/**
 * Checks nearst player for selected client in some set distance (BOMB_PASS_DISTANCE)
 *
 * @param client 	An client entity index.
 * @return			Returns nearst teammate terrosist entity index in set dicstance, otherwise -1.
 */
public int GetNearstTerroristPlayer(int client) 
{
	int terrorist = -1;
	int distance = 0;

	// Get player position
	float client_position[3];
	GetClientAbsOrigin(client, client_position);

	for (int player = 1; player <= MaxClients + 1; player++)
	{
		if(IsNotSamePlayer(client, player) && IsClientValid(player) && IsTerrorist(player)) 
		{
			if(!PASS_TO_BOTS && IsFakeClient(player))
				continue;

			// Get players (teammates) position
			float terrorist_position[3];
			GetClientAbsOrigin(player, terrorist_position);

			// Get current position betwean player and teammate
			int current_distance = RoundToZero(GetVectorDistance(client_position, terrorist_position));

			if(current_distance <= BOMB_PASS_DISTANCE) 
			{
				if(distance == 0 || distance > current_distance)  
				{
					distance = current_distance;
					terrorist = player;
				}
			}
		}
	}
	return terrorist;
}

/**
 * Set player weapon entity index and weapon name.
 *
 * @param player 		An player entity index.
 * @param weapon_name	An returned weapon name.
 * @return				Returns weapon entity index and set name as param, otherwise -1.
 */
public int SetActiveWeapon(int player, char weapon_name[32])
{	
	int weapon = GetEntPropEnt(player, Prop_Send, "m_hActiveWeapon");
	if(weapon > -1 && GetEdictClassname(weapon, weapon_name, sizeof(weapon_name))) return weapon;
	return -1;
}

/**
 * Gives client bomb to other player, without drop.
 *
 * @param sender 		An sender entity index
 * @param receiver 		An receiver entity index.
 * @param itemIndex 	An receiver entity index.
 * @return				Returns true if receiver recived bomb, false otherwise.
 */
public bool GiveBombToAnotherPlayer(int sender, int receiver, int itemIndex) 
{
	if(RemovePlayerItem(sender, itemIndex)) 
		if(GivePlayerItem(receiver, BOMB_WEAPON) > -1) 
			return AcceptEntityInput(itemIndex, "kill");

	return false;
}

/**
 * Set player last active weapon before change. 
 *
 * @param client 	An client entity index.
 * @return			Returns true if the switch success, false otherwise.
 */
public bool SetLastWeapon(int client)
{
	if(ClientCommand(client, "lastinv") > -1) return true;
	return false;
}

/**
 * Checks weapon is a bomb. 
 *
 * @param String 	Weapon name.
 * @return			Returns true if the switch success, false otherwise.
 */
public bool IsBomb(char weapon_name[32])
{
	return StrEqual(weapon_name, BOMB_WEAPON, true);
}

/**
 * Check player and teammate are the same client
 *
 * @param player 	An player entity index.
 * @param teammate 	An teammate entity index.
 * @return			Returns true if is a same client, false otherwise.
 */
public bool IsNotSamePlayer(int player, int teammate)
{
	if(teammate != player) return true;
	return false;
}

/**
 * Checks client is valid player.
 *
 * @param client 	An client entity index.
 * @return			Returns true if client is valid player, false otherwise.
 */
public bool IsClientValid(int client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)) return true;	
	return false;
}

/**
 * Checks player is terrorist.
 *
 * @param client 	An client entity index.
 * @return			Returns true if player is terrorist, false otherwise.
 */
public bool IsTerrorist(int client) 
{
	if(GetClientTeam(client) == CS_TEAM_T) return true;
	return false;
}

public void DenySound(int client)
{
	if(IsClientValid(client) && strcmp(deny_sound_name, ""))
	{
		char buffer[PLATFORM_MAX_PATH + 5];
		Format(buffer, sizeof(buffer), "play %s", deny_sound_name);
		ClientCommand(client, buffer);
	}
}