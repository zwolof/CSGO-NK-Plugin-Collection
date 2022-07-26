#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <smlib>
#include <datapack>
#include <overlays>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG

#define PLUGIN_AUTHOR "defuJ"
#define PLUGIN_VERSION "0.01"

#define STICKER_MDL "models/inventory_items/sticker_inspect_defuj.mdl"

int g_iClients[MAXPLAYERS + 1] =  { 0, ... };
int g_iChallengers[MAXPLAYERS + 1] = { 0, ... };
int g_iBombEnts[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
int g_iStickerEnts[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
int g_iLaserSprite;
int g_iKnifeEnt;

bool g_bSmokeChallenge = false;
bool g_bBombChallenge = false;
bool g_bBlockDefuseSound = false;
bool g_bStickerBlock = true;
bool g_bChickenChallenge = false;

float g_flBombTick[MAXPLAYERS + 1] = { 0.0, ... };
float g_flSmokeChallenge[MAXPLAYERS + 1][3];
float g_vGoalOrigin[3] = { 0.0, ... };

float g_flPoint1[3];
float g_flPoint2[3];

ConVar g_cvChickenAmount;
ConVar g_cvBombTime;
ConVar g_cvKnifeScale;
ConVar g_cvStickerScale;

Handle g_tBomb;

int g_iMaster = 0;
int g_iPreviousFlags[MAXPLAYERS + 1];
float g_flPreviousPos[MAXPLAYERS + 1][3];

public Plugin myinfo = 
{
	name = "LastToLeave YT",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/defuj/"
};

public void OnPluginStart()
{
	g_cvChickenAmount = CreateConVar("sm_chicken_amount", "50", "The amount of chickens to spawn");
	g_cvBombTime = CreateConVar("sm_practice_c4_time", "20.0", "How long the practice bomb challenge should last");
	g_cvKnifeScale = CreateConVar("sm_knife_resize", "10.0", "How big knife scale shouid be");
	g_cvStickerScale = CreateConVar("sm_sticker_resize", "1.5", "How big sticker scale shouid be");
	
	HookEvent("smokegrenade_detonate", OnSmokeDetonate);
	HookEvent("bomb_defused", OnBombDefused);
	
	RegConsoleCmd("kill", Cmd_Kill);
	RegConsoleCmd("explode", Cmd_Kill);
	
	RegAdminCmd("sm_set_challengers", AddChallengers, ADMFLAG_GENERIC, "Select challengers to compete");
	RegAdminCmd("sm_freeze_challengers", FreezeChallengers, ADMFLAG_GENERIC, "Freeze challengers");
	RegAdminCmd("sm_blind_challenge", BlindChallenge, ADMFLAG_GENERIC, "Setup the blind challenge");
	RegAdminCmd("sm_chicken_challenge", ChickenChallenge, ADMFLAG_GENERIC, "Setup the chicken challenge");
	RegAdminCmd("sm_smoke_challenge", SmokeChallenge, ADMFLAG_GENERIC, "Setup the smoke challenge");
	RegAdminCmd("sm_bomb_challenge", BombChallenge, ADMFLAG_GENERIC, "Setup the bomb challenge");
	RegAdminCmd("sm_measure_distance", MeasureDistance, ADMFLAG_GENERIC, "Setup the bomb challenge");
	RegAdminCmd("sm_sticker_challenge", StickerChallenge, ADMFLAG_GENERIC, "Setup the sticker challenge");
	RegAdminCmd("sm_knife_challenge", KnifeChallenge, ADMFLAG_GENERIC, "Setup the knife challenge");
	
	RegAdminCmd("sm_setmaster", SetMaster, ADMFLAG_GENERIC, "Sets the master client");
	
	AddNormalSoundHook(Event_SoundPlayed);
}

public void OnMapStart()
{
	g_iLaserSprite = PrecacheModel("materials/sprites/laserbeam.vmt");	
	
	PrecacheModel("models/inventory_items/sticker_inspect_defuj.mdl");
	
	AddFileToDownloadsTable("models/inventory_items/sticker_inspect_defuj.vvd");
	AddFileToDownloadsTable("models/inventory_items/sticker_inspect_defuj.mdl");
	AddFileToDownloadsTable("models/inventory_items/sticker_inspect_defuj.dx90.vtx");	
	AddFileToDownloadsTable("models/inventory_items/sticker_inspect_defuj.phy");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (classname[0] == 'i')
	{
		if (StrEqual(classname, "info_map_parameters", true))
		{
			SDKHook(entity, SDKHook_Spawn, SDK_OnMapParametersSpawn);
		}
	}
	if (StrEqual(classname, "chicken"))
	{
		SDKHook(entity, SDKHook_Use, SDK_OnChickenUse);
	}
}

public Action SDK_OnChickenUse(int entity, int activator, int caller, UseType type, float value)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_leader");
	if (Client_IsValid(owner))
	{
		float vEntPos[3];
		float vClientPos[3];
		
		Entity_GetAbsOrigin(entity, vEntPos);
		Entity_GetAbsOrigin(owner, vClientPos);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action SDK_OnMapParametersSpawn(int entity)
{
	if (!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}
	
	if (g_bChickenChallenge)
		SetEntProp(entity, Prop_Data, "m_iPetPopulation", 600);
		
	return Plugin_Continue;
}


public void OnClientAuthorized(int client, const char[] auth)
{
	g_iClients[client] = client;
}

public void OnClientDisconnect(int client)
{
	g_iClients[client] = 0;
}

public Action Event_SoundPlayed(int clients[64],int &numClients,char sample[PLATFORM_MAX_PATH],int &entity,int &channel,float &volume,int &level,int &pitch,int &flags) 
{
	if (StrContains(sample, "c4_disarmstart", false) != -1 && g_bBlockDefuseSound)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	int pressedButtons = GetEntProp(client, Prop_Data, "m_afButtonPressed");
	int releasedButtons = GetEntProp(client, Prop_Data, "m_afButtonReleased");
	
	int flags = GetEntityFlags(client);
	
	if (pressedButtons & IN_JUMP)
	{
		GetClientAbsOrigin(client, g_flPreviousPos[client]);
	}
	if (!(g_iPreviousFlags[client] & FL_ONGROUND) && flags & FL_ONGROUND)
	{
		float vOrigin[3];
		GetClientAbsOrigin(client, vOrigin);
		
		float distance = GetVectorDistance(g_flPreviousPos[client], vOrigin) + 31;
		PrintToConsole(g_iMaster, "[LONGJUMP] %N jumped %f", client, distance);
	}
	
	if (pressedButtons & IN_USE)
	{
		//PrintToChatAll("Pressed called");
		
		int ent = GetClientAimTarget(client, false);
		if (Entity_IsValid(ent))
		{
			char targetname[MAX_NAME_LENGTH];
			GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
			
			if (String_StartsWith(targetname, "STICKER_"))  
			{
				float vEntOrigin[3];
				float vOrigin[3];
				float distance;
				
				Entity_GetAbsOrigin(ent, vEntOrigin);
				Entity_GetAbsOrigin(client, vOrigin);
				distance = GetVectorDistance(vOrigin, vEntOrigin);
				
				if (distance < 250.0)
					g_iStickerEnts[client] = EntIndexToEntRef(ent);
			}
		}
		
	}
	
	if (releasedButtons & IN_USE)
	{
		g_iStickerEnts[client] = INVALID_ENT_REFERENCE;
	}
	
	if (g_iStickerEnts[client] != INVALID_ENT_REFERENCE && g_bStickerBlock)
	{
		int ent = EntRefToEntIndex(g_iStickerEnts[client]);
		if (Entity_IsValid(ent))
		{
			// Teleport 20.0 distance away
			float vEyePos[3], vEyeFwd[3]; // Base values
			float vEndPoint[3];
			
			float distance = 70.0;
			
			GetClientEyePosition(client,vEyePos);
			GetAngleVectors(angles, vEyeFwd, NULL_VECTOR, NULL_VECTOR);
			
			vEndPoint[0] = vEyePos[0] + (vEyeFwd[0]*distance);
			vEndPoint[1] = vEyePos[1] + (vEyeFwd[1]*distance);
			vEndPoint[2] = vEyePos[2] + (vEyeFwd[2]*distance);
			
			TeleportEntity(ent, vEndPoint, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	g_iPreviousFlags[client] = flags;
}

public void OnSmokeDetonate(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bSmokeChallenge)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		for (int i = 0; i < 3; i++)
		{
			if (g_flSmokeChallenge[client][i] == 0)
			{
				g_flSmokeChallenge[client][i] = GetEventFloat(event, "z");
				break;
			}
		}
		
		UpdateSmokeHUD();
	}
}

public void UpdateSmokeHUD()
{
	if (g_bSmokeChallenge) {
		char message[1024];
		
		int totalChallengers = 0;
		
		for (int i = 0; i < sizeof(g_iChallengers); i++)
		{
			if (g_iChallengers[i] != 0)
			{	
				float highest = 0.0;
				char buffer[64];
				
				for (int j = 0; j < 3; j++)
				{
					if (g_flSmokeChallenge[i][j] != 0.0) {
						if (g_flSmokeChallenge[i][j] > highest || highest == 0.0)
							highest = g_flSmokeChallenge[i][j];
					}
				}
				
				Format(buffer, sizeof(buffer), "\n%N: %.0f", g_iChallengers[i], highest);
				
				StrCat(message, sizeof(message), buffer);
				
				totalChallengers++;
			}
		}
		
		DisplayHUDMessageAll(message);
	}
}

//===================================================================
// Commands
//===================================================================
public Action SetMaster(int client, int args)
{
	g_iMaster = client;
}

public Action Cmd_Kill(int client, int args)
{
	PrintToChat(client, "Forced suicide is disabled");
	
	return Plugin_Handled;
}

public Action AddChallengers(int client, int args)
{
	
	DisplayChallengerMenu(client);
	
	return Plugin_Continue;
}

public Action FreezeChallengers(int client, int args)
{
	DisplayChallengerFreezeMenu(client);
	
	return Plugin_Continue;
}

public Action BlindChallenge(int client, int args)
{
	DisplayBlindChallenge(client);
	
	return Plugin_Continue;
}

public Action ChickenChallenge(int client, int args)
{
	DisplayChickenChallenge(client);
	
	return Plugin_Continue;
}

public Action SmokeChallenge(int client, int args)
{
	DisplaySmokeChallenge(client);
	
	return Plugin_Continue;
}

public Action BombChallenge(int client, int args)
{
	DisplayBombChallenge(client);
	
	return Plugin_Continue;
}

public Action MeasureDistance(int client, int args)
{
	DisplayDistanceChallenge(client);
	
	return Plugin_Continue;
}

public Action StickerChallenge(int client, int args)
{
	DisplayStickerChallenge(client);
	
	return Plugin_Continue;
}

public Action KnifeChallenge(int client, int args)
{
	DisplayKnifeChallenge(client);
	
	return Plugin_Continue;
}

//===================================================================
// Menu
//===================================================================
public void DisplayChallengerMenu(int client)
{
	Menu menu = new Menu(Menu_Challengers);
	menu.SetTitle("Select challengers");
	for (int i = 0; i < sizeof(g_iClients); i++) // check is all alive players in box
	{
		if (g_iClients[i] != 0)
		{
			char id[16];
			char text[MAX_NAME_LENGTH];
			
			bool isChallenger = false;
			
			if (g_iChallengers[g_iClients[i]] > 0)
				isChallenger = true;
			
			Format(id, sizeof(id), "%i", g_iClients[i]);
			Format(text, sizeof(text), "%N, %i", g_iClients[i], isChallenger);
			
			menu.AddItem(id, text);
		}
		
	}
	menu.Display(client, 30);	
}

public int Menu_Challengers(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));

			int challenger = StringToInt(item);
			
			if (g_iChallengers[challenger])
				g_iChallengers[challenger] = 0;
			else
				g_iChallengers[challenger] = challenger;
			
			// Reopen the menu, param1 meant to be original client
			DisplayChallengerMenu(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void DisplayChallengerFreezeMenu(int client)
{
	Menu menu = new Menu(Menu_Freeze);
	menu.SetTitle("Freeze or unfreeze");
	menu.AddItem("freezeall", "Freeze All");
	menu.AddItem("unfreezeall", "Unfreeze All");
	
	for (int i = 0; i < sizeof(g_iChallengers); i++) // check is all alive players in box
	{
		if (g_iChallengers[i] != 0)
		{
			char id[16];
			char text[MAX_NAME_LENGTH];
			
			bool isFrozen = false;

			MoveType movetype = GetEntityMoveType(g_iChallengers[i]);
			if (movetype == MOVETYPE_NONE)
				isFrozen = true;
			
			Format(id, sizeof(id), "%i", g_iClients[i]);
			Format(text, sizeof(text), "%N, %i", g_iClients[i], isFrozen);
			
			menu.AddItem(id, text);
		}
		
	}
	menu.Display(client, 30);	
}

public int Menu_Freeze(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "freezeall"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++)
					if (g_iChallengers[i] != 0)
						SetEntityMoveType(g_iChallengers[i], MOVETYPE_NONE);
			}
			else if (StrEqual(item, "unfreezeall"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++)
					if (g_iChallengers[i] != 0)
						SetEntityMoveType(g_iChallengers[i], MOVETYPE_WALK);
			}
			else 
			{	
				int challenger = StringToInt(item);
				MoveType movetype = GetEntityMoveType(challenger);
				
				if (movetype != MOVETYPE_NONE)
					SetEntityMoveType(challenger, MOVETYPE_NONE);
				else if (movetype == MOVETYPE_NONE)
					SetEntityMoveType(challenger, MOVETYPE_WALK);
			}
			// Reopen the menu, param1 meant to be original client
			DisplayChallengerFreezeMenu(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void DisplayBlindChallenge(int client)
{
	Menu menu = new Menu(Menu_Blind);
	menu.SetTitle("Blind challenge");
	menu.AddItem("setorigin", "Set Origin");
	menu.AddItem("distance", "Get distance");
	menu.AddItem("reveal", "Render beams");
	menu.AddItem("blindall", "Blind all");
	menu.AddItem("unblindall", "Unblind all");
	menu.AddItem("freezeall", "Freeze all");
	menu.AddItem("unfreezeall", "Unfreeze all");
	menu.Display(client, 30);	
}

public int Menu_Blind(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "setorigin"))
			{
				GetClientEyePosition(param1, g_vGoalOrigin);
				PrintToConsole(param1, "[BLIND] Origin set: %f, %f, %f", g_vGoalOrigin[0], g_vGoalOrigin[1], g_vGoalOrigin[2]);
			}
			else if (StrEqual(item, "distance"))
			{
				PrintToConsole(param1, "[BLIND] Furthest away is %N", GetFurtherstAway(param1));
			}
			else if (StrEqual(item, "reveal"))
			{
				int loser = GetFurtherstAway(param1);
				
				for (int i = 0; i < sizeof(g_iChallengers); i++) 
				{
					if (g_iChallengers[i] != 0) 
					{
						float vOrigin[3];
						int vColour[4] = { 0, 0, 0, 255 };
						
						GetClientEyePosition(g_iChallengers[i], vOrigin);
						
						if (g_iChallengers[i] == loser) {
							vColour[0] = 255;
						}
						else {
							vColour[1] = 255;
						}
						
						TE_SetupBeamPoints(vOrigin, g_vGoalOrigin, g_iLaserSprite, 0, 0, 0, 30.0, 3.0, 3.0, 1, 0.0, vColour, 0);
						TE_SendToAll();
					}
				}
			}
			else if (StrEqual(item, "blindall"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++) 
					if (g_iChallengers[i] != 0) 
						ShowOverlay(g_iChallengers[i], "effects/black", 0.0);
			}
			else if (StrEqual(item, "unblindall"))
			{
				ShowOverlayAll("", 1.0);
			}
			else if (StrEqual(item, "freezeall"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++)
					if (g_iChallengers[i] != 0)
						SetEntityMoveType(g_iChallengers[i], MOVETYPE_NONE);
			}
			else if (StrEqual(item, "unfreezeall"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++)
					if (g_iChallengers[i] != 0)
						SetEntityMoveType(g_iChallengers[i], MOVETYPE_WALK);
			}
			
			// Reopen the menu, param1 meant to be original client
			DisplayBlindChallenge(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public int GetFurtherstAway(int client)
{
	int loser;
	float highestDist;
	
	for (int i = 0; i < sizeof(g_iChallengers); i++) 
	{
		if (g_iChallengers[i] != 0) 
		{
			float vOrigin[3];
			float distance;
			
			GetClientEyePosition(g_iChallengers[i], vOrigin);
			distance = GetVectorDistance(vOrigin, g_vGoalOrigin);
			
			if (distance > highestDist) {
				loser = g_iChallengers[i];
				highestDist = distance;
			}
			
			PrintToConsole(client, "[BLIND] %N, %f units from goal", g_iChallengers[i], distance);
		}
	}	
	
	return loser;
}

public void DisplayChickenChallenge(int client)
{
	char item1[64];
	Format(item1, sizeof(item1), "Toggle Challenge %i", g_bChickenChallenge);
	
	Menu menu = new Menu(Menu_Chicken);
	menu.SetTitle("Chicken challenge");
	menu.AddItem("togglechallenge", item1);
	menu.AddItem("spawnchicken", "Spawn Chickens");
	menu.AddItem("setpopulation", "Set population");
	menu.AddItem("removechicken", "Remove Chickens");
	menu.AddItem("getowners", "Get Owners");
	menu.Display(client, 30);
}

public int Menu_Chicken(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "togglechallenge"))
			{
				g_bChickenChallenge = !g_bChickenChallenge;
			}
			else if (StrEqual(item, "spawnchicken")) // SPAWN CHICKENS
			{
				float vOrigin[3];
				GetClientEyePosition(param1, vOrigin);
				
				vOrigin[2] += 20.0;
				
				for (int i = 0; i < g_cvChickenAmount.IntValue; i++)
				{
					float vVel[3];
					float vAng[3];
					
					int chicken = CreateEntityByName("chicken");
					SetEntityModel(chicken, "models/chicken/chicken.mdl");
					DispatchSpawn(chicken);
					
					vVel[0] = GetRandomFloat(-200.0, 200.0);
					vVel[1] = GetRandomFloat(-200.0, 200.0);
					vVel[2] = GetRandomFloat(100.0, 500.0);
					
					vAng[1] = GetRandomFloat(0.0, 360.0);
					
					TeleportEntity(chicken, vOrigin, vAng, vVel);
				}
			}
			else if (StrEqual(item, "setpopulation"))
			{
				int entity = FindEntityByClassname(-1, "info_map_parameters");
				
				if (!IsValidEntity(entity))
				{
					entity = CreateEntityByName("info_map_parameters");
					DispatchSpawn(entity);
				}

				SetEntProp(entity, Prop_Data, "m_iPetPopulation", g_cvChickenAmount.FloatValue);	
			}
			else if (StrEqual(item, "removechicken")) // REMOVE CHICKENS
			{
				int entity = -1;
				
				while ((entity = FindEntityByClassname(entity, "chicken")) != INVALID_ENT_REFERENCE)
				{
					AcceptEntityInput(entity, "Kill");
				}
			}
			else if (StrEqual(item, "getowners")) // CALCULATE SCORE
			{
				int clients[MAXPLAYERS + 1] = { 0, ... };
				int entity = -1;
				
				while ((entity = FindEntityByClassname(entity, "chicken")) != INVALID_ENT_REFERENCE)
				{
					int owner = GetEntPropEnt(entity, Prop_Send, "m_leader");
					if (Client_IsValid(owner))
					{
						clients[owner] += 1;
					}
				}
				
				for (int i = 0; i < sizeof(clients); i++)
				{
					if (clients[i] > 0)
					{
						PrintToConsole(param1, "[CHCKN] %N owns %i chickens", i, clients[i]);
					}
				}
			}
			
			// Reopen the menu, param1 meant to be original client
			DisplayChickenChallenge(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}


public void DisplaySmokeChallenge(int client)
{
	char item1[64];
	Format(item1, sizeof(item1), "Toggle Challenge %i", g_bSmokeChallenge);
	
	Menu menu = new Menu(Menu_Smoke);
	menu.SetTitle("Smoke challenge");
	menu.AddItem("togglechallenge", item1);
	menu.AddItem("resetscores", "Reset Scores");
	menu.AddItem("printscores", "Print Scores");
	menu.AddItem("removehud", "Remove Hud");
	menu.Display(client, 30);
}

public int Menu_Smoke(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "togglechallenge")) // SPAWN CHICKENS
			{
				g_bSmokeChallenge = !g_bSmokeChallenge;
			}
			else if (StrEqual(item, "resetscores"))
			{
				for (int i = 0; i < sizeof(g_flSmokeChallenge); i++)
				{
					for (int j = 0; j < 3; j++)
						g_flSmokeChallenge[i][j] = 0.0;
				}
				
				UpdateSmokeHUD();
			}
			else if (StrEqual(item, "printscores"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++)
				{
					if (g_iChallengers[i] != 0 )
						PrintToConsole(param1, "[SMOKE] %N, %f, %f, %f", g_iChallengers[i], g_flSmokeChallenge[i][0], g_flSmokeChallenge[i][1], g_flSmokeChallenge[i][2]);
				}
			}
			else if (StrEqual(item, "removehud"))
			{
				EndHUDMessageAll();
			}
			
			// Reopen the menu, param1 meant to be original client
			DisplaySmokeChallenge(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}


public void DisplayBombChallenge(int client)
{
	char item1[32];
	Format(item1, sizeof(item1), "Mute defuse, %i", g_bBlockDefuseSound);
	
	Menu menu = new Menu(Menu_Bomb);
	menu.SetTitle("Bomb challenge");
	menu.AddItem("startchallenge", "Start Challenge");
	menu.AddItem("removebombs", "Reset Challenge");
	menu.AddItem("disablesound", item1);
	for (int i = 0; i < sizeof(g_iChallengers); i++)
	{
		if (g_iChallengers[i] != 0)
		{
			char id[16];
			char text[MAX_NAME_LENGTH];
			
			bool isSet = false;
			
			if (IsValidEntity(EntRefToEntIndex(g_iBombEnts[i])))
				isSet = true;
			
			Format(id, sizeof(id), "%i", g_iClients[i]);
			Format(text, sizeof(text), "%N, %i", g_iClients[i], isSet);
			
			menu.AddItem(id, text);
		}
		
	}
	
	menu.Display(client, 30);
}

public int Menu_Bomb(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "startchallenge")) // SPAWN CHICKENS
			{
				for (int i = 0; i < sizeof(g_iBombEnts); i++)
				{
					if (g_iBombEnts[i] != INVALID_ENT_REFERENCE)
					{
						int bomb = EntRefToEntIndex(g_iBombEnts[i]);
						if (IsValidEntity(bomb)) 
						{	
							SetVariantFloat(g_cvBombTime.FloatValue);
							AcceptEntityInput(bomb, "ActivateSetTimerLength");
							
							g_bBombChallenge = true;
							PrintToConsole(param1, "[BOMB] %N c4 started for %fs", i, g_cvBombTime.FloatValue);
						}
					}
				}
				
				if (g_tBomb != null) {
					delete g_tBomb;
					g_tBomb = null;
				}
					
				g_tBomb = CreateTimer(g_cvBombTime.FloatValue, BombTimer, param1);
			}
			else if (StrEqual(item, "removebombs"))
			{
				int ent = -1;
				
				while ((ent = FindEntityByClassname(ent, "planted_c4_training")) != INVALID_ENT_REFERENCE)
				{
					AcceptEntityInput(ent, "Kill");
				}
				for (int i = 0; i < sizeof(g_iBombEnts); i++) {
					g_flBombTick[i] = 0.0;
					g_iBombEnts[i] = INVALID_ENT_REFERENCE;
				}
					
				g_bBombChallenge = false;
			}
			else if (StrEqual(item, "disablesound"))
			{
				g_bBlockDefuseSound = !g_bBlockDefuseSound;
			}
			else 
			{	
				int challenger = StringToInt(item);
				
				if (g_iBombEnts[challenger] != INVALID_ENT_REFERENCE) {
					int ent = EntRefToEntIndex(g_iBombEnts[challenger]);
					if (IsValidEntity(ent))
						AcceptEntityInput(ent, "Kill");
				}
				float vEyePos[3];
				float vEyeAng[3];
				
				GetClientEyePosition(param1, vEyePos);
				GetClientEyeAngles(param1, vEyeAng);
				
				TR_TraceRayFilter(vEyePos, vEyeAng, MASK_SOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterPlayer, param1);
				if (TR_DidHit()) 
				{
					float vEndPos[3];
					float vNorm[3];
					
					TR_GetEndPosition(vEndPos);
					TR_GetPlaneNormal(INVALID_HANDLE, vNorm);
					GetVectorAngles(vNorm, vNorm);
					
					vNorm[0] += 90;
					
					int bomb = CreateEntityByName("planted_c4_training");
					DispatchSpawn(bomb);
					TeleportEntity(bomb, vEndPos, vNorm, NULL_VECTOR);
					
					g_iBombEnts[challenger] = EntIndexToEntRef(bomb);
				}
				
			}
			
			// Reopen the menu, param1 meant to be original client
			DisplayBombChallenge(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action BombTimer(Handle timer, int caller)
{
	g_tBomb = null;
	
	float expTime = GetGameTime();
	
	for (int i = 0; i < sizeof(g_iChallengers); i++)
	{
		if (g_iChallengers[i] != 0) 
		{
			if (g_flBombTick[i] != 0.0)
				PrintToConsole(caller, "[BOMB] %N defused %f before detonation", i, expTime - g_flBombTick[i]);
			else 
				PrintToConsole(caller, "[BOMB] %N failed to defuse", i);
		}
	}
	
}

public void OnBombDefused(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bBombChallenge) {
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		g_flBombTick[client] = GetGameTime();
	}
}

public void DisplayDistanceChallenge(int client)
{
	char item1[64];
	Format(item1, sizeof(item1), "Toggle Challenge %i", g_bSmokeChallenge);
	
	Menu menu = new Menu(Menu_Distance);
	menu.SetTitle("Measure Distance");
	menu.AddItem("setpoint1", "Set Point 1");
	menu.AddItem("setpoint2", "Set Point 2");
	menu.AddItem("getdistance", "Get Distance");
	menu.AddItem("renderdistance", "Render distance");
	menu.Display(client, 30);
}

public int Menu_Distance(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "setpoint1")) // SPAWN CHICKENS
			{
				GetClientEyePosition(param1, g_flPoint1);
			}
			else if (StrEqual(item, "setpoint2"))
			{
				GetClientEyePosition(param1, g_flPoint2);
			}
			else if (StrEqual(item, "getdistance"))
			{
				PrintToConsole(param1, "[DIST] Distance is %f", GetVectorDistance(g_flPoint1, g_flPoint2));
			}
			else if (StrEqual(item, "renderdistance"))
			{
				int vColour[4] = { 0, 0, 255, 255 };
				TE_SetupBeamPoints(g_flPoint1, g_flPoint2, g_iLaserSprite, 0, 0, 0, 30.0, 3.0, 3.0, 1, 0.0, vColour, 0);
				TE_SendToAll();
			}
			
			// Reopen the menu, param1 meant to be original client
			DisplayDistanceChallenge(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void DisplayStickerChallenge(int client)
{
	char item1[32];
	Format(item1, sizeof(item1), "Toggle motion, %i", g_bStickerBlock);
	
	Menu menu = new Menu(Menu_Stickers);
	menu.SetTitle("Sticker challenge");
	menu.AddItem("remmoveall", "Remove All Stickers");
	menu.AddItem("disablemotion", item1);
	menu.AddItem("spawnset1", "Spawn Set 1");
	menu.AddItem("spawnset2", "Spawn Set 2");
	menu.AddItem("spawnset3", "Spawn Set 3");
	menu.AddItem("spawnpreset", "Spawn Preset");
	menu.Display(client, 30);	
}

public int Menu_Stickers(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "remmoveall")) // SPAWN CHICKENS
			{
				int ent = -1;
				
				while ((ent = FindEntityByClassname(ent, "prop_dynamic_override")) != INVALID_ENT_REFERENCE)
				{
					char targetname[MAX_NAME_LENGTH];
					GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
					
					if (String_StartsWith(targetname, "STICKER_"))
						AcceptEntityInput(ent, "Kill");
				}
				
				ent = -1;
				while ((ent = FindEntityByClassname(ent, "point_worldtext")) != INVALID_ENT_REFERENCE)
				{
					char targetname[MAX_NAME_LENGTH];
					GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
					
					if (String_StartsWith(targetname, "STICKER_"))
						AcceptEntityInput(ent, "Kill");
				}
			}
			else if (StrEqual(item, "disablemotion"))
			{
				g_bStickerBlock = !g_bStickerBlock;
			}
			else if (StrEqual(item, "spawnset1"))
			{
				SpawnStickerSet(param1, "1", "2", "3", "4");
			}
			else if (StrEqual(item, "spawnset2"))
			{
				SpawnStickerSet(param1, "5", "6", "7", "8");
			}
			else if (StrEqual(item, "spawnset3"))
			{
				SpawnStickerSet(param1, "9", "10", "11", "12");
			}
			else if (StrEqual(item, "spawnpreset"))
			{
				SpawnStickerPreset(param1);
			}

			
			// Reopen the menu, param1 meant to be original client
			DisplayStickerChallenge(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void DisplayKnifeChallenge(int client)
{
	Menu menu = new Menu(Menu_Knife);
	char item1[64];
	Format(item1, sizeof(item1), "Select ent, %i", g_iKnifeEnt);
	
	menu.SetTitle("Select knife model");
	menu.AddItem("knifeselect", item1);
	menu.AddItem("setorigin", "Set origin");
	menu.AddItem("setscale", "Set Scale");
	menu.AddItem("setpreset", "Set Preset");
	menu.AddItem("getvalues", "Get values");
	menu.AddItem("add0", "+X");
	menu.AddItem("minus0", "-X");
	menu.AddItem("add1", "+Y");
	menu.AddItem("minus1", "-Y");
	menu.AddItem("add2", "+Z");
	menu.AddItem("minus2", "-Z");
	menu.Display(client, 30);	
}

public int Menu_Knife(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "knifeselect")) // SPAWN CHICKENS
			{
				int ent = GetClientAimTarget(param1, false);
				if (Entity_IsValid(ent))
					g_iKnifeEnt = ent;
			}
			else if (StrEqual(item, "setorigin"))
			{
				float vOrigin[3];
				
				GetClientEyePosition(param1, vOrigin);
				Entity_SetAbsOrigin(g_iKnifeEnt, vOrigin);
				SetEntityMoveType(g_iKnifeEnt, MOVETYPE_NONE);
			}
			else if (StrEqual(item, "setscale"))
			{
				SetEntPropFloat(g_iKnifeEnt, Prop_Send, "m_flModelScale", g_cvKnifeScale.FloatValue); 
			}
			else if (StrEqual(item, "setpreset"))
			{
				float vOrigin[3] =  { -3742.6, -397.5, 626.8 };
				float vAngles[3] =  { -26.3, 190.2, -180.2 };
				Entity_SetAbsAngles(g_iKnifeEnt, vAngles);
				Entity_SetAbsOrigin(g_iKnifeEnt, vOrigin);
			}
			else if (StrEqual(item, "getvalues"))
			{
				float vOrigin[3];
				float vAngles[3];
				Entity_GetAbsAngles(g_iKnifeEnt, vAngles);
				Entity_GetAbsOrigin(g_iKnifeEnt, vOrigin);
				PrintToConsole(param1, "Origin: %f, %f, %f \nAngles %f, %f, %f", vOrigin[0], vOrigin[1], vOrigin[2], vAngles[0], vAngles[1], vAngles[2]);
			}
			else if (StrEqual(item, "add0"))
			{
				float vAng[3];
				Entity_GetAbsAngles(g_iKnifeEnt, vAng);
				vAng[0] += 10;
				Entity_SetAbsAngles(g_iKnifeEnt, vAng);
			}
			else if (StrEqual(item, "minus0"))
			{
				float vAng[3];
				Entity_GetAbsAngles(g_iKnifeEnt, vAng);
				vAng[0] -= 10;
				Entity_SetAbsAngles(g_iKnifeEnt, vAng);
			}
			else if (StrEqual(item, "add1"))
			{
				float vAng[3];
				Entity_GetAbsAngles(g_iKnifeEnt, vAng);
				vAng[1] += 10;
				Entity_SetAbsAngles(g_iKnifeEnt, vAng);
			}
			else if (StrEqual(item, "minus1"))
			{
				float vAng[3];
				Entity_GetAbsAngles(g_iKnifeEnt, vAng);
				vAng[1] -= 10;
				Entity_SetAbsAngles(g_iKnifeEnt, vAng);
			}
			else if (StrEqual(item, "add2"))
			{
				float vAng[3];
				Entity_GetAbsAngles(g_iKnifeEnt, vAng);
				vAng[2] += 10;
				Entity_SetAbsAngles(g_iKnifeEnt, vAng);
			}
			else if (StrEqual(item, "minus2"))
			{
				float vAng[3];
				Entity_GetAbsAngles(g_iKnifeEnt, vAng);
				vAng[2] -= 10;
				Entity_SetAbsAngles(g_iKnifeEnt, vAng);
			}
			
			// Reopen the menu, param1 meant to be original client
			DisplayKnifeChallenge(param1);
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

//===================================================================
// Stocks
//===================================================================
stock void DisplayHUDMessageAll(char[] message)
{
	Event newevent_message = CreateEvent("cs_win_panel_round");
	newevent_message.SetString("funfact_token", message);
	
	for(int z = 1; z <= MaxClients; z++)
	  if(IsClientInGame(z) && !IsFakeClient(z))
	    newevent_message.FireToClient(z);
	                                
	newevent_message.Cancel(); 	
}

stock void EndHUDMessageAll()
{
	Event newevent_round = CreateEvent("round_start");
	
	for(int z = 1; z <= MaxClients; z++)
	  if(IsClientInGame(z) && !IsFakeClient(z))
	    newevent_round.FireToClient(z);
	
	newevent_round.Cancel(); 	
}

stock bool TraceEntityFilterPlayer(int entity, int mask, any data)
{
	return data != entity;
}

stock void SpawnStickerSet(int client, char[] st1, char[] st2, char[] st3, char[] st4)
{
	int ents[4];
	
	float vEyePos[3], vEyeAngles[3], vEyeFwd[3]; // Base values
	float vEndPoint[3];
	float distance = 20.0;
	
	GetClientEyeAngles(client, vEyeAngles);
	GetClientEyePosition(client,vEyePos);
	GetAngleVectors(vEyeAngles, vEyeFwd, NULL_VECTOR, NULL_VECTOR);
	
	vEndPoint[0] = vEyePos[0] + (vEyeFwd[0]*distance);
	vEndPoint[1] = vEyePos[1] + (vEyeFwd[1]*distance);
	vEndPoint[2] = vEyePos[2] + (vEyeFwd[2]*distance);
	
	for (int i = 0; i < 4; i++) {
		char skin[12];
		float adjustedPos[3];
		
		adjustedPos = vEndPoint;
		adjustedPos[1] += (i * 40.0);
		Format(skin, sizeof(skin), "%i", i);
				
		ents[i] = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(ents[i], "targetname", "STICKER_PROP");
		DispatchKeyValue(ents[i], "solid", "6");
		SetEntProp(ents[i], Prop_Data, "m_nSolidType", 6);
		DispatchKeyValue(ents[i], "spawnflags", "8"); 
		SetEntProp(ents[i], Prop_Data, "m_CollisionGroup", 5);
		SetEntityModel(ents[i], STICKER_MDL);
		DispatchSpawn(ents[i]);
		TeleportEntity(ents[i], adjustedPos, NULL_VECTOR, NULL_VECTOR);
		
		AcceptEntityInput(ents[i], "EnableCollision"); 
		AcceptEntityInput(ents[i], "TurnOn", ents[i], ents[i], 0);
		
		SetEntPropFloat(ents[i], Prop_Send, "m_flModelScale", g_cvStickerScale.FloatValue); 
	}
	
	float vLow[3];
	float vHigh[3];
	float vTextAng[3] = {0.0, 180.0, 0.0};
	
	vLow = vEndPoint;
	vHigh = vEndPoint;
	
	vLow[2] -= 30.0;
	vLow[1] -= 20.0;
	vHigh[2] -= 30.0;
	vHigh[1] += 3 * 40.0;
	
	int worldtextLow = CreateEntityByName("point_worldtext");
	DispatchKeyValue(worldtextLow, "targetname", "STICKER_PROP");
	DispatchKeyValue(worldtextLow, "color", "255 255 255");
	DispatchKeyValue(worldtextLow, "textsize", "5"); 
	DispatchKeyValue(worldtextLow, "message", "low"); 
	DispatchSpawn(worldtextLow);
	TeleportEntity(worldtextLow, vLow, vTextAng, NULL_VECTOR);
	
	int worldtextHigh = CreateEntityByName("point_worldtext");
	DispatchKeyValue(worldtextHigh, "targetname", "STICKER_PROP");
	DispatchKeyValue(worldtextHigh, "color", "255 255 255");
	DispatchKeyValue(worldtextHigh, "textsize", "5"); 
	DispatchKeyValue(worldtextHigh, "message", "high"); 
	DispatchSpawn(worldtextHigh);
	TeleportEntity(worldtextHigh, vHigh, vTextAng, NULL_VECTOR);
	
	DispatchKeyValue(ents[0], "skin", st1);
	DispatchKeyValue(ents[1], "skin", st2);
	DispatchKeyValue(ents[2], "skin", st3);
	DispatchKeyValue(ents[3], "skin", st4);
	
	
}

// fucking lazy code lmao
stock void SpawnStickerPreset(int client)
{
	int ents[6];
	
	float vEyePos[3], vEyeAngles[3], vEyeFwd[3]; // Base values
	float vEndPoint[3];
	
	float distance = 20.0;
	
	GetClientEyeAngles(client, vEyeAngles);
	GetClientEyePosition(client,vEyePos);
	GetAngleVectors(vEyeAngles, vEyeFwd, NULL_VECTOR, NULL_VECTOR);
	
	vEndPoint[0] = vEyePos[0] + (vEyeFwd[0]*distance);
	vEndPoint[1] = vEyePos[1] + (vEyeFwd[1]*distance);
	vEndPoint[2] = vEyePos[2] + (vEyeFwd[2]*distance);
	
	for (int i = 0; i < 6; i++) {
		char skin[12];
		float adjustedPos[3];
		
		adjustedPos = vEndPoint;
		adjustedPos[1] += (i * 40.0);
		Format(skin, sizeof(skin), "%i", i);
		
		ents[i] = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(ents[i], "targetname", "STICKER_PROP");
		DispatchKeyValue(ents[i], "solid", "6");
		SetEntProp(ents[i], Prop_Data, "m_nSolidType", 6);
		DispatchKeyValue(ents[i], "spawnflags", "8"); 
		SetEntProp(ents[i], Prop_Data, "m_CollisionGroup", 5);
		SetEntityModel(ents[i], STICKER_MDL);
		DispatchSpawn(ents[i]);
		TeleportEntity(ents[i], adjustedPos, NULL_VECTOR, NULL_VECTOR);
		
		AcceptEntityInput(ents[i], "EnableCollision"); 
		AcceptEntityInput(ents[i], "TurnOn", ents[i], ents[i], 0);
		
		SetEntPropFloat(ents[i], Prop_Send, "m_flModelScale", g_cvStickerScale.FloatValue); 
	}
	
	float vLow[3];
	float vHigh[3];
	float vTextAng[3] = {0.0, 180.0, 0.0};
	
	vLow = vEndPoint;
	vHigh = vEndPoint;
	
	vLow[2] -= 30.0;
	vLow[1] -= 20.0;
	vHigh[2] -= 30.0;
	vHigh[1] += 5 * 40.0;
	
	int worldtextLow = CreateEntityByName("point_worldtext");
	DispatchKeyValue(worldtextLow, "targetname", "STICKER_PROP");
	DispatchKeyValue(worldtextLow, "color", "255 255 255");
	DispatchKeyValue(worldtextLow, "textsize", "5"); 
	DispatchKeyValue(worldtextLow, "message", "low"); 
	DispatchSpawn(worldtextLow);
	TeleportEntity(worldtextLow, vLow, vTextAng, NULL_VECTOR);
	
	int worldtextHigh = CreateEntityByName("point_worldtext");
	DispatchKeyValue(worldtextHigh, "targetname", "STICKER_PROP");
	DispatchKeyValue(worldtextHigh, "color", "255 255 255");
	DispatchKeyValue(worldtextHigh, "textsize", "5"); 
	DispatchKeyValue(worldtextHigh, "message", "high"); 
	DispatchSpawn(worldtextHigh);
	TeleportEntity(worldtextHigh, vHigh, vTextAng, NULL_VECTOR);
	
	DispatchKeyValue(ents[0], "skin", "7");
	DispatchKeyValue(ents[1], "skin", "4");
	DispatchKeyValue(ents[2], "skin", "8");
	DispatchKeyValue(ents[3], "skin", "10");
	DispatchKeyValue(ents[4], "skin", "2");
	DispatchKeyValue(ents[5], "skin", "3");
	
	
}