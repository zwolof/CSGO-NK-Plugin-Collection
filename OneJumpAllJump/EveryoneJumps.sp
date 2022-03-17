#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <cstrike>

#define PLUGIN_AUTHOR "defuJ"
#define PLUGIN_VERSION "0.01"

#pragma newdecls required
#pragma semicolon 1

int g_iClients[MAXPLAYERS + 1] = { 0, ...};
int g_iShouldJump[MAXPLAYERS + 1] = { 0, ...};
int g_iExepectingCTJump;
int g_iExpectingTJump;

bool g_bRandomCT = false;
bool g_bRandomT = false;

ConVar g_cvRoundTime;

Handle TimerCT1, TimerCT2, TimerCT3;
Handle TimerT1, TimerT2, TimerT3;

public Plugin myinfo = 
{
	name = "Everyone Jumps",
	author = PLUGIN_AUTHOR,
	description = "When one player jumps, everyone jumps",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/defuj/"
};

public void OnPluginStart()
{
	g_cvRoundTime = FindConVar("mp_roundtime_defuse");
	
	RegConsoleCmd("sm_makemyjump", ForceJump);
	
	HookEvent("player_jump", OnPlayerJump);
	HookEvent("round_freeze_end", OnFreezeEnd);
	
}

public void OnClientAuthorized(int client, const char[] auth)
{
	g_iClients[client] = client; // this is so we can iterate through connected clients without error
}
public void OnClientDisconnect(int client)
{
	g_iClients[client] = 0; // remove client on disconnect
}


public Action OnFreezeEnd(Event event, const char[] name, bool dontBroadcast) {
	if (GameRules_GetProp("m_bWarmupPeriod") == 0)
	{
		float roundTime = g_cvRoundTime.FloatValue * 60;
		switch (GetRound())
		{
			case 1, 2, 3, 4, 5:
			{
				float CT = GetRandomFloat(0.0, roundTime);
				float T = GetRandomFloat(0.0, roundTime);
				TimerCT1 = CreateTimer(CT, ForceJumpTeam, CS_TEAM_CT);
				TimerT1 = CreateTimer(T, ForceJumpTeam, CS_TEAM_T);
				//PrintToChatAll("Have been called, Rand Values are: CT %f, T %f", CT, T);
			}
			case 6, 7, 8, 9, 10:
			{
				TimerCT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);
				TimerCT2 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT2 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);
			}
			case 11, 12, 13, 14, 15:
			{
				TimerCT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);
				TimerCT2 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT2 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);
				TimerCT3 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT3 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);
			}
			case 16, 17, 18, 19, 20:
			{
				TimerCT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);	

			}
			case 21, 22, 23, 24, 25:
			{
				TimerCT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);	
				TimerCT2 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT2 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);

			}
			case 26, 27, 28, 29, 30:{
				TimerCT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT1 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);	
				TimerCT2 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT2 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);
				TimerCT3 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_CT);
				TimerT3 = CreateTimer(GetRandomFloat(0.0, roundTime), ForceJumpTeam, CS_TEAM_T);
			}
			default:{}
		}
	}
}

public Action OnPlayerJump(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetClientTeam(client);
	int remainingTeamAlive = 0;
	char clientName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));
	
	if (team == CS_TEAM_CT) {
		if (!g_bRandomCT){
			if (g_iExepectingCTJump == 0) { // First time jumping
				for (int i=0; i<sizeof(g_iClients); i++) {
					if (g_iClients[i] != 0) {
						if (GetClientTeam(g_iClients[i]) == CS_TEAM_CT) {
							if (IsPlayerAlive(g_iClients[i])) {
								remainingTeamAlive++;
								g_iShouldJump[i] = g_iClients[i];
							}
							
							PrintHintText(i, "<strong><font color='#FF0000'> %s </font></strong><font color='#0000FF'>jumped</font>", clientName);
						}
					}
				}
				
				g_iExepectingCTJump = remainingTeamAlive - 1;
				CreateTimer(0.5, ResetTeam, CS_TEAM_CT);
				//PrintToChat(client, "Your on CT and exepecting %i jumps", g_iExepectingCTJump);
			}
			else { // Everyone else following
				g_iExepectingCTJump--;
				//PrintToChat(client, "Removed an expected jump, remaining: %i", g_iExepectingCTJump);
			}
		}
		else {
			for (int i=0; i<sizeof(g_iClients); i++) {
				if (g_iClients[i] != 0) {
					if (GetClientTeam(g_iClients[i]) == CS_TEAM_CT) {
						PrintHintText(i, "<strong><font color='#FF0000'> SUPRISE JUMP </font></strong>");
					}
				}
			}
			CreateTimer(0.5, ResetTeam, CS_TEAM_CT);
		}
	}
	else if (team == CS_TEAM_T) {
		if (!g_bRandomT) {
			if (g_iExpectingTJump == 0) { // First time jumping
				for (int i=0; i<sizeof(g_iClients); i++) {
					if (g_iClients[i] != 0) {
						if (GetClientTeam(g_iClients[i]) == CS_TEAM_T) {
							if (IsPlayerAlive(g_iClients[i])) {
								remainingTeamAlive++;
								g_iShouldJump[i] = g_iClients[i];
							}
							
							PrintHintText(i, "<strong><font color='#FF0000'> %s </font></strong><font color='#0000FF'>jumped</font>", clientName);
						}
					}
				}
				
				g_iExpectingTJump = remainingTeamAlive - 1;
				CreateTimer(0.5, ResetTeam, CS_TEAM_T);
				//PrintToChat(client, "Your on T and exepecting %i jumps", g_iExpectingTJump);
			}
			else { // Everyone else following
				g_iExpectingTJump--;
				//PrintToChat(client, "Removed an expected jump, remaining: %i", g_iExpectingTJump);
			}
		}
		else {
			for (int i=0; i<sizeof(g_iClients); i++) {
				if (g_iClients[i] != 0) {
					if (GetClientTeam(g_iClients[i]) == CS_TEAM_T) {
						PrintHintText(i, "<strong><font color='#FF0000'> SUPRISE JUMP </font></strong>");
					}
				}
			}
			CreateTimer(0.5, ResetTeam, CS_TEAM_T);
		}
	}
	
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2]){
	if (g_iShouldJump[client] != 0) {
		buttons |= IN_JUMP;
		g_iShouldJump[client] = 0;
	}
}

public Action ForceJump(int client, int args) {
	g_iShouldJump[client] = client;
	PrintToChat(client, "Roundtime is %f seconds", g_cvRoundTime.FloatValue * 60);
}

public Action ForceJumpTeam(Handle timer, int team) {
	if (team == CS_TEAM_CT) {
		g_bRandomCT = true;
	}
	else if (team == CS_TEAM_T) {
		g_bRandomT = true;
	}
	
	for (int i=0; i<sizeof(g_iClients); i++) {
		if (g_iClients[i] != 0) {
			if (GetClientTeam(g_iClients[i]) == team) {
				if (IsPlayerAlive(g_iClients[i])) {
					g_iShouldJump[i] = g_iClients[i];
				}
			}
		}
	}
}

public Action ResetTeam(Handle timer, int team){
	if (team == CS_TEAM_CT) {
		g_iExepectingCTJump = 0;
		g_bRandomCT = false;
	}
	else if (team == CS_TEAM_T) {
		g_iExpectingTJump = 0;
		g_bRandomT = false;
	}
}

stock int GetRound()
{
	int ctScore = CS_GetTeamScore(CS_TEAM_CT);
	int tScore = CS_GetTeamScore(CS_TEAM_T);
	int totalScore = ctScore + tScore;
		
	return totalScore + 1;
}

stock void ClearTimer(Handle timer) 
{ 
    if (timer != INVALID_HANDLE) 
    { 
        KillTimer(timer); 
    } 
    timer = INVALID_HANDLE; 
} 