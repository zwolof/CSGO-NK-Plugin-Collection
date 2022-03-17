#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "defuJ"
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required


int healthRounds[30] = { 300, 270, 220, 180, 160, 32,
140, 130, 120, 22, 110, 100, 90, 49,
80, 70, 60, 6, 50, 40, 30, 2,
20, 10, 1, 1, 1, 1, 1, 1 };

ConVar gcv_bDynamicHealth = null;

bool consecRounds = false;

public Plugin myinfo = 
{
	name = "Progressive HP",
	author = PLUGIN_AUTHOR,
	description = "HP gets lower the more you play",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/defuj/"
};

public void OnPluginStart()
{
	HookEvent("round_start", OnRoundStart);
	gcv_bDynamicHealth = CreateConVar("sm_dynamichealth", "0", "Whether it should change rounds to 1hp depending on how close to victory");
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (gcv_bDynamicHealth.BoolValue)
	{
		if (GameRules_GetProp("m_bWarmupPeriod") == 0 && !consecRounds && (GetRound(CS_TEAM_CT) >= 11 || GetRound(CS_TEAM_T) >= 11))
		{
			
			healthRounds[GetRound()] = 1;
			healthRounds[GetRound() + 1] = 1;
			healthRounds[GetRound() + 2] = 1;
			healthRounds[GetRound() + 3] = 1;
			healthRounds[GetRound() + 4] = 1;
			
			consecRounds = true;
			
			//PrintToChatAll("T rounds: %i, CT Rounds: %i", GetRound(CS_TEAM_T), GetRound(CS_TEAM_CT));
		}
	}
	if (GameRules_GetProp("m_bWarmupPeriod") == 0)
	{
		switch (GetRound())
		{
			case 6, 10, 14, 18, 22:
			{
				SetAllHp(GetRandomInt(1, 50));
			}
			case 1, 2, 3, 4, 5, 7, 8, 9, 11, 12, 13 ,15, 16, 17, 19, 20, 21, 23, 24:
			{
				SetAllHp(healthRounds[GetRound() - 1]);
			}				
			default:
			{
				SetAllHp(1);
			}
		}
	}
		
}

stock void SetAllHp(int hp)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i)) 
		{
			SetEntityHealth(i, hp);
		}
	}
}

stock int GetRound(int team = 0)
{
	if (team == CS_TEAM_CT)
	{
		return CS_GetTeamScore(CS_TEAM_CT);
	}
	else if (team == CS_TEAM_T)
	{
		return CS_GetTeamScore(CS_TEAM_T);
	}
	else if (team == 0)
	{
		int ctScore = CS_GetTeamScore(CS_TEAM_CT);
		int tScore = CS_GetTeamScore(CS_TEAM_T);
		int totalScore = ctScore + tScore;
		
		return totalScore + 1;
	}
	
	return -1;
}
