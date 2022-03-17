#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <cstrike>

#define PLUGIN_AUTHOR "defuJ"
#define PLUGIN_VERSION "0.01"

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = 
{
	name = "Shared HP",
	author = PLUGIN_AUTHOR,
	description = "Teammates share a pool of HP",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/defuj/"
};

int g_iClients[MAXPLAYERS + 1] = { 0, ...};

ConVar gcv_bTotalKill;

public void OnPluginStart()
{
	ConVar autokick = FindConVar("mp_autokick");
	SetConVarInt(autokick, 0, true, false);
	delete autokick;
	
	gcv_bTotalKill = CreateConVar("sm_teamhpkill", "0", "Set whether plugin should kill teammates who share hp", _, true, 0.0, true, 1.0);
	
	HookEvent("round_start", OnRoundStart);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	g_iClients[client] = client; // this is so we can iterate through connected clients without error
}
public void OnClientDisconnect(int client)
{
	g_iClients[client] = 0; // remove client on disconnect
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetClientTeam(victim);
	
	if (gcv_bTotalKill.BoolValue) {
		for (int i=0; i<sizeof(g_iClients); i++) {
			if (g_iClients[i] != 0) {
				if (GetClientTeam(g_iClients[i]) == team) {
					if (IsPlayerAlive(g_iClients[i])) 
					{
						ForcePlayerSuicide(g_iClients[i]);
					}
				}
			}
		}
	}
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	if (GameRules_GetProp("m_bWarmupPeriod") == 0) {

		int hurt = GetClientOfUserId(GetEventInt(event, "userid")); // get client id of who hurt
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		int damage = GetEventInt(event, "dmg_health");
		int team = GetClientTeam(hurt);
		char weapon[64];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		
		char hurtName[MAX_NAME_LENGTH];
		GetClientName(hurt, hurtName, sizeof(hurtName));
		
		//PrintToChatAll("%s took %i damage, Current HP: %i, Attacker %i", hurtName, damage, GetClientHealth(hurt), attacker);
		InflictTeamDamage(team, damage, attacker, hurt, weapon);
	}
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (GameRules_GetProp("m_bWarmupPeriod") == 0)
	{
		switch (GetRound())
		{
			case 1, 2, 16, 17:{
				SetTeamHealth(CS_TEAM_CT, 1000);
				SetTeamHealth(CS_TEAM_T, 1000);
			}
			case 3, 4, 18, 19:{
				SetTeamHealth(CS_TEAM_CT, 900);
				SetTeamHealth(CS_TEAM_T, 900);
			}
			case 5, 6, 20, 21:{
				SetTeamHealth(CS_TEAM_CT, 800);
				SetTeamHealth(CS_TEAM_T, 800);
			}
			case 7, 8, 22, 23:{
				SetTeamHealth(CS_TEAM_CT, 700);
				SetTeamHealth(CS_TEAM_T, 700);
			}
			case 9, 10, 24, 25: {
				SetTeamHealth(CS_TEAM_CT, 600);
				SetTeamHealth(CS_TEAM_T, 600);
			}
			case 11, 12, 26, 27:{
				SetTeamHealth(CS_TEAM_CT, 500);
				SetTeamHealth(CS_TEAM_T, 500);
			}
			case 13, 14, 28, 29:{
				SetTeamHealth(CS_TEAM_CT, 450);
				SetTeamHealth(CS_TEAM_T, 450);
			}
			case 15, 30:{
				SetTeamHealth(CS_TEAM_CT, 400);
				SetTeamHealth(CS_TEAM_T, 400);
			}
			default:{
				SetTeamHealth(CS_TEAM_CT, 400);
				SetTeamHealth(CS_TEAM_T, 400);
			}
		}
	}
}

stock int GetRound()
{
	int ctScore = CS_GetTeamScore(CS_TEAM_CT);
	int tScore = CS_GetTeamScore(CS_TEAM_T);
	int totalScore = ctScore + tScore;
		
	return totalScore + 1;
}

stock void InflictTeamDamage(int team, int damage, int attacker, int causer, char[] weapon) {
	int healthToSet = GetClientHealth(causer);
	
	for (int i=0; i<sizeof(g_iClients); i++) {
		if (g_iClients[i] != 0) {
			if (GetClientTeam(g_iClients[i]) == team) {
				if (IsPlayerAlive(g_iClients[i])) 
				{					
					if (healthToSet > 1) {
						SetEntityHealth(g_iClients[i], healthToSet); // Will never result a value below 1 (Always above 1)
					} else if (!gcv_bTotalKill.BoolValue) {
						SetEntityHealth(g_iClients[i], 1); // This only occurs when health to set is below 0
					}
				}
			}
		}
	}
}

stock void SetTeamHealth(int team, int value) {
	for (int i=0; i<sizeof(g_iClients); i++) {
		if (g_iClients[i] != 0) {
			if (GetClientTeam(g_iClients[i]) == team) {
				if (IsPlayerAlive(g_iClients[i])) 
				{
					SetEntityHealth(g_iClients[i], value);
				}
			}
		}
	}
}
