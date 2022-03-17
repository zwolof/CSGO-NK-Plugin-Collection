#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <clients>
#include <cstrike>
#include <entity>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Everybody reloads",
	author = "defuJ",
	description = "When one person on your team reloads, everyone reloads",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	HookEvent("weapon_reload", Reload);
	HookEvent("weapon_fire", WeaponFireAmmoCheck);
}

public void OnPluginEnd(){
	UnhookEvent("weapon_reload", Reload);
	UnhookEvent("weapon_fire", WeaponFireAmmoCheck);
}

public Action TeamReload(int client){
	int team = GetClientTeam(client);
	char clientName[MAX_NAME_LENGTH];
	
	GetClientName(client, clientName, sizeof(clientName));
	
	for (int i=1; i<=MaxClients; i++)	// i represents players index
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team){ 	// checks if player is on team var, if so increment players alive
            setWpnAmmo(i);
            PrintToChat(i, "   \x01\07%s \x01caused the whole team to reload.  ", clientName);
            //PrintToChat(i, "reloaded cause team lmao");
        }
    }
}

public Action Reload(Event event, const char[] name, bool dontBroadcast){
	char clientName[MAX_NAME_LENGTH];
	int clientid = GetClientOfUserId((GetEventInt(event, "userid"))); // get client id of who reloaded

	GetClientName(clientid, clientName, sizeof(clientName)); // get client name
	int weapon = GetEntPropEnt(clientid, Prop_Send, "m_hActiveWeapon");
	char S_Weaponname[64];
	
	if(GetEdictClassname(weapon, S_Weaponname, sizeof(S_Weaponname)) 
	&& StrEqual(S_Weaponname, "weapon_nova") == false
	&& StrEqual(S_Weaponname, "weapon_xm1014") == false
	&& StrEqual(S_Weaponname, "weapon_sawedoff") == false){
		TeamReload(clientid);
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

public Action WeaponFireAmmoCheck(Event event, const char[] name, bool dontBroadcast){
	char clientName[MAX_NAME_LENGTH];
	int clientid = GetClientOfUserId((GetEventInt(event, "userid"))); // get client id of who reloaded
	int weapon = GetEntPropEnt(clientid, Prop_Send, "m_hActiveWeapon"); // get weapon
	GetClientName(clientid, clientName, sizeof(clientName)); // get client name
	
	char S_Weaponname[64];
	
	if(GetEdictClassname(weapon, S_Weaponname, sizeof(S_Weaponname)) 
	&& StrEqual(S_Weaponname, "weapon_knife") == false 
	&& StrEqual(S_Weaponname, "weapon_knife") == false
	&& StrEqual(S_Weaponname, "weapon_taser") == false
	&& StrEqual(S_Weaponname, "weapon_flashbang") == false
	&& StrEqual(S_Weaponname, "weapon_hegrenade") == false
	&& StrEqual(S_Weaponname, "weapon_incgrenade") == false
	&& StrEqual(S_Weaponname, "weapon_molotov") == false
	&& StrEqual(S_Weaponname, "weapon_decoy") == false
	&& StrEqual(S_Weaponname, "weapon_smokegrenade") == false)
	{
		int clip = GetEntProp(weapon, Prop_Data, "m_iClip1") - 1; // get value of primary clip
		//int primary = GetEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount"); // get value of primary clip
		//int secondary = GetEntProp(weapon, Prop_Data, "m_iSecondaryReserveAmmoCount"); // get value of secondary clip
		
		if (clip == 0){
			TeamReload(clientid);
			return Plugin_Handled;
		}
		//PrintToChatAll("%s fired, clip %d", clientName, clip);
		//PrintToChatAll("%s fired, primary %d", clientName, primary);
		//PrintToChatAll("%s fired, secondary %d", clientName, secondary);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public void setWpnAmmo(int client){
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); // get weapon
	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	int reserve = GetEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount");

	SetEntProp(weapon, Prop_Data, "m_iClip1", 0); //set clip to client
	// SetEntProp(weapon, Prop_Data, "m_iClip2", (clip + reserve)); //set reserve to client
	weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", clip + reserve);
}
