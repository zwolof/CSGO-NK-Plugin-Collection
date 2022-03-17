#include <sourcemod>
#include <sdktools>
#include <entity> 
#include <cstrike>
#include <timers>
#include <sdkhooks>
#include <convars>

#define PLUGIN_AUTHOR "defuJ"
#define PLUGIN_VERSION "0.1"

#pragma semicolon 1
#pragma newdecls required

int g_iOnGround[MAXPLAYERS + 1] = { 0, ...};
int g_iDurationModifier[MAXPLAYERS + 1] = { 1, ...};
int g_iTimerCount = 0;

Handle g_hTimer;

ConVar gcv_duration;

public Plugin myinfo = 
{
	name = "Jump Intervals",
	author = PLUGIN_AUTHOR,
	description = "Each round you will have to jump every x amount of seconds",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/defuj"
};

public void OnPluginStart()
{
	ConVar autokick = FindConVar("mp_autokick");
	SetConVarInt(autokick, 0, true, false);
	delete autokick;
	
	gcv_duration = CreateConVar("sm_jump_fire_duration", "3.0", "How long ignite should last for");
	
	HookEvent("round_freeze_end", OnFreezeEnd);
	HookEvent("round_end", OnRoundEnd);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!( GetEntityFlags(client) & FL_ONGROUND )) {
		g_iOnGround[client] = 0;
	}
	else {
		g_iOnGround[client] = client;
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	KillTimer(g_hTimer);
	g_hTimer = INVALID_HANDLE;
	
	for (int i = 0; i < sizeof(g_iDurationModifier); i++){
		g_iDurationModifier[i] = 1;
	}
}

public void OnFreezeEnd(Event event, const char[] name, bool dontBroadcast) {
	if (!GameRules_GetProp("m_bWarmupPeriod")){
		int round = GetRound();
		
		switch (round) {
			case 0, 1, 2, 3, 4: {
				int interval = 10;
				g_iTimerCount = interval;
				g_hTimer = CreateTimer(1.0, DisplayTimer, interval, TIMER_REPEAT);
			}
			case 5, 6, 7, 8, 9: {
				int interval = 8;
				g_iTimerCount = interval;
				g_hTimer = CreateTimer(1.0, DisplayTimer, interval, TIMER_REPEAT);
			}
			case 10, 11, 12, 13, 14: {
				int interval = 6;
				g_iTimerCount = interval;
				g_hTimer = CreateTimer(1.0, DisplayTimer, interval, TIMER_REPEAT);
			}
			case 15, 16, 17, 18, 19: {
				int interval = 4;
				g_iTimerCount = interval;
				g_hTimer = CreateTimer(1.0, DisplayTimer, interval, TIMER_REPEAT);
			}
			case 20, 21, 22, 23, 24: {
				int interval = 2;
				g_iTimerCount = interval;
				g_hTimer = CreateTimer(1.0, DisplayTimer, interval, TIMER_REPEAT);
			}
			case 25, 26, 27, 28, 29: {
				int interval = 1;
				g_iTimerCount = interval;
				g_hTimer = CreateTimer(1.0, DisplayTimer, interval, TIMER_REPEAT);
			}
			default: {
				int interval = 1;
				g_iTimerCount = interval;
				g_hTimer = CreateTimer(1.0, DisplayTimer, interval, TIMER_REPEAT);
			}// OT
			
		}
	}
	
}

public Action DisplayTimer(Handle timer, int interval)
{	
	if (g_iTimerCount >= 1) {
		PrintHintTextToAll("%i", g_iTimerCount);
		g_iTimerCount--;
	} 
	else {
		PrintHintTextToAll("JUMP");
		IgniteNonJumpers();
		g_iTimerCount = interval;
	}
	
	return Plugin_Continue;
}

public Action IgniteNonJumpers(){
	for (int i=0; i<sizeof(g_iOnGround); i++) {
		if (g_iOnGround[i] != 0) {
			IgniteEntity(i, (g_iDurationModifier[i] * gcv_duration.FloatValue));
			g_iDurationModifier[i]++;
		}
	}
}

stock int GetRound() { // 0 1 2 3
	int ctScore = CS_GetTeamScore(CS_TEAM_CT);
	int tScore = CS_GetTeamScore(CS_TEAM_T);
	int totalScore = ctScore + tScore;
	
	return totalScore;
}