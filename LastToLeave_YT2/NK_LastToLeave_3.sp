#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <smlib>
#include <datapack>
#include <overlays>
#include <adt_array>

#pragma semicolon 1
#pragma newdecls required

#define DEBUG

#define PLUGIN_AUTHOR "defuJ"
#define PLUGIN_VERSION "0.01"

#define STICKER_MDL "models/inventory_items/sticker_inspect_chall2.mdl"

int g_iStickerEnts[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };
int g_iClients[MAXPLAYERS + 1] =  { 0, ... };
int g_iChallengers[MAXPLAYERS + 1] = { 0, ... };
int g_iLaserSprite;
int g_iWeapon;

int g_iTextName[14] = { INVALID_ENT_REFERENCE, ... };
int g_iSkins[14] = { INVALID_ENT_REFERENCE, ... };
int g_bSkins[14] = { false, ... };
int g_bSkinsClient[MAXPLAYERS + 1] = {false, ...};

bool g_bBot1;
bool g_bBot2;
int g_iBot1;
int g_iBot2;
float flBot1Pos[3];
float flBot2Pos[3];
bool g_iBotShoot1 = false;
bool g_iBotShoot2 = false;

ArrayList g_arWeapons;

int g_bSmokes[MAXPLAYERS + 1][3];

ConVar g_cvStickerScale;
ConVar g_cvWeaponScale;
ConVar g_cvWeaponSpawn;
ConVar g_cvDuelPrimary;
ConVar g_cvDuelSecondary;
ConVar g_cvPrimaryCTDefault;
ConVar g_cvPrimaryTDefault;
ConVar g_cvSecondaryCTDefault;
ConVar g_cvSecondaryTDefault;
ConVar g_cvGroundWeapons;
ConVar g_cvResetEquipment;

bool g_bAimChallenge = false;
bool g_bBotChallenge = false;
bool g_bThrowChallenge = false;
bool g_bSmokeChallenge = false;
bool g_bBombChallenge = false;
bool g_bStickerBlock = true;

public Plugin myinfo =
{
	name = "LastToLeave 3",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/defuj/"
};

public void OnPluginStart()
{
	g_arWeapons = new ArrayList();	
	g_arWeapons = CreateArray(32);
	
	g_cvWeaponSpawn = CreateConVar("sm_weapon_spawn", "weapon_deagle", "What model to spawn in");
	g_cvWeaponScale = CreateConVar("sm_weapon_scale", "3", "How big weapon scale shouid be");
	g_cvStickerScale = CreateConVar("sm_sticker_resize", "1.5", "How big sticker scale shouid be");
	g_cvDuelPrimary = CreateConVar("sm_duel_primary", "", "Primary wepaon for 1v1", FCVAR_CLIENTCMD_CAN_EXECUTE);
	g_cvDuelSecondary = CreateConVar("sm_duel_secondary", "weapon_deagle", "Secondary wepaon for 1v1");
	
	g_cvPrimaryCTDefault = FindConVar("mp_ct_default_primary");
	g_cvPrimaryTDefault = FindConVar("mp_t_default_primary");
	g_cvSecondaryCTDefault = FindConVar("mp_ct_default_secondary");
	g_cvSecondaryTDefault = FindConVar("mp_t_default_secondary");
	g_cvGroundWeapons = FindConVar("mp_weapons_allow_map_placed");
	g_cvResetEquipment = FindConVar("mp_equipment_reset_rounds");
	
//	HookConVarChange(g_cvDuelPrimary, OnPrimaryChange);
//	HookConVarChange(g_cvDuelSecondary, OnSecondaryChange);
	
	HookEvent("smokegrenade_detonate", OnSmokeDetonate);
	HookEvent("bomb_exploded", OnBombExplode);
	HookEvent("round_end", OnRoundEnd);

	RegAdminCmd("sm_blind_challengers", BlindChallengers, ADMFLAG_GENERIC, "Blind challengers", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_aim_challenge", AimChallenge, ADMFLAG_GENERIC, "Setup the Aim challenge", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_he_challenge", HEChallenge, ADMFLAG_GENERIC, "Setup the HE challenge", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_bot_challenge", BotChallenge, ADMFLAG_GENERIC, "Setup the bot challenge", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_throw_challenge", ThrowChallenge, ADMFLAG_GENERIC, "Setup the smoke challenge", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_smoke_challenge", SmokeChallenge, ADMFLAG_GENERIC, "Setup the smoke challenge", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_bomb_challenge", BombChallenge, ADMFLAG_GENERIC, "Setup the bomb challenge", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_price_challenge", PriceChallenge, ADMFLAG_GENERIC, "Setup the price challenge", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_sticker_challenge", StickerChallenge, ADMFLAG_GENERIC, "Setup the sticker challenge", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
	RegAdminCmd("sm_set_challengers", AddChallengers, ADMFLAG_GENERIC, "Select challengers to compete", _, FCVAR_CLIENTCMD_CAN_EXECUTE);
}

public void OnPluginEnd()
{
	delete g_arWeapons;
}

public void OnMapStart()
{
	g_iLaserSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	PrecacheModel(STICKER_MDL);	
	AddFileToDownloadsTable("models/inventory_items/sticker_inspect_chall2.vvd");
	AddFileToDownloadsTable("models/inventory_items/sticker_inspect_chall2.mdl");
	AddFileToDownloadsTable("models/inventory_items/sticker_inspect_chall2.dx90.vtx");	
	AddFileToDownloadsTable("models/inventory_items/sticker_inspect_chall2.phy");
	
	ConVar bot_quota = FindConVar("bot_quota");
	bot_quota.SetInt(10);
	ConVar bot_quota_mode = FindConVar("bot_quota_mode");
	bot_quota_mode.SetString("normal");
	ConVar mp_limitteams = FindConVar("mp_limitteams");
	mp_limitteams.SetInt(0);
	ConVar mp_autoteambalance = FindConVar("mp_autoteambalance");
	mp_autoteambalance.SetInt(0);
	ConVar ammo_grenade_limit_default = FindConVar("ammo_grenade_limit_default");
	ammo_grenade_limit_default.SetInt(3);
	
	
	ConVar sv_falldamage_scale = FindConVar("sv_falldamage_scale");
	sv_falldamage_scale.SetInt(0);
	
	int flags = GetCommandFlags("bot_stop");
	SetCommandFlags("bot_stop", flags & ~FCVAR_CHEAT);
	ConVar bot_stop = FindConVar("bot_stop");
	bot_stop.SetInt(1);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	g_iClients[client] = client;
}

public void OnClientDisconnect(int client)
{
	g_iClients[client] = 0;
	g_iChallengers[client] = 0;
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client)) {
		if (g_bBot1) {
			g_iBot1 = client;
			CS_RespawnPlayer(client);
			int weapon = GivePlayerItem(client, "weapon_ak47");
			EquipPlayerWeapon(client, weapon);
			g_bBot1 = false;
		}
		else if (g_bBot2) {
			g_iBot2 = client;
			CS_RespawnPlayer(client);
			int weapon = GivePlayerItem(client, "weapon_m4a1");
			EquipPlayerWeapon(client, weapon);
			g_bBot2 = false;
		}
	}
}

public Action PriceChallenge(int client, int args)
{
	DisplayPriceChallenge(client);
}

public Action BotChallenge(int client, int args)
{
	DisplayBotChallenge(client);
}

public Action BombChallenge(int client, int args)
{
	DisplayBombChallenge(client);
}

public Action SmokeChallenge(int client, int args)
{
	DisplaySmokeChallenge(client);
}

public Action ThrowChallenge(int client, int args)
{
	DisplayThrowChallenge(client);
}

public Action StickerChallenge(int client, int args)
{
	DisplayStickerChallenge(client);
}

public Action HEChallenge(int client, int args)
{
	DisplayHEChallenge(client);
}

public Action AimChallenge(int client, int args)
{
	DisplayAimChallenge(client);
}

public Action BlindChallengers(int client, int args)
{
	DisplayBlindChallenge(client);
}

//=============================================================================
//=================================== EVENTS ==================================
//=============================================================================
public void OnPrimaryChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvPrimaryCTDefault.SetString(newValue);
	g_cvPrimaryTDefault.SetString(newValue);
}

public void OnSecondaryChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvSecondaryCTDefault.SetString(newValue);
	g_cvSecondaryTDefault.SetString(newValue);
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_arWeapons.Clear();
	
	for (int i = 0; i < sizeof(g_iSkins); i++)
		g_iSkins[i] = INVALID_ENT_REFERENCE;
	
	for (int i = 0; i < sizeof(g_bSkins); i++)
		g_bSkins[i] = false;
		
	for (int i = 0; i < sizeof(g_iTextName); i++)
		g_iTextName[i] = false;
		
	for (int i = 0; i < sizeof(g_bSkinsClient); i++)
		g_bSkinsClient[i] = false;
		
	for (int i = 0; i < sizeof(g_bSmokes); i++)
	{
		g_bSmokes[i][0] = 0;
		g_bSmokes[i][1] = 0;
		g_bSmokes[i][2] = 0;
		
	}

}

public void OnSmokeDetonate(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bSmokeChallenge)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		for (int i = 0; i < sizeof(g_iChallengers); i++)
		{
			if (g_iChallengers[i] == client)
			{
				float pos[3];
				pos[0] = GetEventFloat(event, "x");
				pos[1] = GetEventFloat(event, "y");
				pos[2] = GetEventFloat(event, "z");

				pos[2] += 10.0;
				// x1 <= x <= x2
				// x >= x1
				// x <= x2
				/*
				// x >= xMin && x <= xMax
				if (pos[0] <= g_flBoxMin[0] && pos[0] >= g_flBoxMax[0] && pos[1] >= g_flBoxMin[1] && pos[1] <= g_flBoxMax[1] && pos[2] >= g_flBoxMin[2] && pos[2] <= g_flBoxMax[2])
				{
					PrintToServer("[SMOKE] %N smoke LANDED", client);
				} else {
					PrintToServer("[SMOKE] %N smoke DID NOT land in area", client);
					
					PrintToServer("Point: %.0f, %.0f, %.0f", pos[0], pos[1], pos[2]);
					PrintToServer("Min: %.0f, %.0f, %.0f", g_flBoxMin[0], g_flBoxMin[1], g_flBoxMin[2]);
					PrintToServer("Max: %.0f, %.0f, %.0f", g_flBoxMax[0], g_flBoxMax[1], g_flBoxMax[2]);
					
				}
				*/
				
				float flPos1[3] = {-1080.0, -410.661316, -140.918243}; // Window smoke min box point
				float flPos2[3] = {-1381.686279, -833.965088, -19.827379}; // Window smoke max box point
				
				int index = -1;
				for(int j = 0; j < 3; j++)
				{
					if (g_bSmokes[client][j] == 0) {
						index = j;
						break;
					}
				}
				
				if (pos[0] <= flPos1[0] && pos[0] >= flPos2[0] && pos[1] <= flPos1[1] && pos[1] >= flPos2[1] && pos[2] > -200.0)
				{
					PrintToServer("[SMOKE] %N smoke LANDED", client);
					
					if (index != -1) g_bSmokes[client][index] = 1;
					
				} else {
					PrintToServer("[SMOKE] %N smoke DID NOT land in area", client);
//					PrintToServer("Point: %.0f, %.0f, %.0f", pos[0], pos[1], pos[2]);
					
					if (index != -1) g_bSmokes[client][index] = -1;
				}
				
				PrintToServer("[SMOKE] %N SCORES %i, %i, %i,",client, g_bSmokes[client][0], g_bSmokes[client][1], g_bSmokes[client][2]);
			}
		}
	}
}

public void OnBombExplode(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bBombChallenge) CreateTimer(2.0, CheckSurvivers);
}

public Action CheckSurvivers(Handle timer)
{
	if (g_bBombChallenge)
	{
		for (int i = 0; i < sizeof(g_iChallengers); i++)
		{
			if (g_iChallengers[i] != 0)
			{
				if (IsPlayerAlive(g_iChallengers[i])) {
					int health = GetClientHealth(g_iChallengers[i]);
					PrintToServer("[BOMB] %N survived with %i HEALTH", g_iChallengers[i], health);
				}
				else {
					PrintToServer("[BOMB] %N did NOT survive", g_iChallengers[i]);
				}
			}
		}
	}
}


//=============================================================================
//=================================== MENUS ===================================
//=============================================================================

public Action AddChallengers(int client, int args)
{
	DisplayChallengerMenu(client);
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

//====== Bomb Challenge
public void DisplayBombChallenge(int client)
{
	char text[64];
	Format(text, sizeof(text), "Toggle challenge: %i", g_bBombChallenge);

	Menu menu = new Menu(Menu_BombChallenge);
	menu.SetTitle("Bomb challenge");
	menu.AddItem("toggle", text);
	menu.AddItem("health100", "Health 100");
	menu.AddItem("health150", "Health 150");
	menu.AddItem("health200", "Health 200");
	menu.Display(client, 30);
}

public int Menu_BombChallenge(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));

			if (StrEqual(item, "toggle"))
			{
				g_bBombChallenge = !g_bBombChallenge;
			}
			else if (StrEqual(item, "health100"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++)
				{
					if (g_iChallengers[i] != 0)
					{
						if (IsPlayerAlive(g_iChallengers[i]))
						{
							Entity_SetMaxHealth(g_iChallengers[i], 100);
							Entity_SetHealth(g_iChallengers[i], 100);
						}
					}
				}
			}
			else if (StrEqual(item, "health150"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++)
				{
					if (g_iChallengers[i] != 0)
					{
						if (IsPlayerAlive(g_iChallengers[i]))
						{
							Entity_SetMaxHealth(g_iChallengers[i], 150);
							Entity_SetHealth(g_iChallengers[i], 150);
						}
					}
				}
			}
			else if (StrEqual(item, "health200"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++)
				{
					if (g_iChallengers[i] != 0)
					{
						if (IsPlayerAlive(g_iChallengers[i]))
						{
							Entity_SetMaxHealth(g_iChallengers[i], 200);
							Entity_SetHealth(g_iChallengers[i], 200);
						}
					}
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

//===== Smoke Challenge
public void DisplaySmokeChallenge(int client)
{
	char text[64];
	Format(text, sizeof(text), "Toggle challenge: %i", g_bSmokeChallenge);

	Menu menu = new Menu(Menu_SmokeChallenge);
	menu.SetTitle("Smoke challenge");
	menu.AddItem("toggle", text);
	menu.AddItem("reset", "Reset smokes");
	menu.AddItem("strip", "Strip Weapons");
	menu.AddItem("givesmokes", "Give Smokes");
	menu.AddItem("results", "Results");
	menu.Display(client, 30);
}

public int Menu_SmokeChallenge(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));

			if (StrEqual(item, "toggle"))
			{
				g_bSmokeChallenge = !g_bSmokeChallenge;
			}
			else if (StrEqual(item, "reset"))
			{
				for (int i = 0; i < sizeof(g_bSmokes); i++)
				{
					g_bSmokes[i][0] = 0;
					g_bSmokes[i][1] = 0;
					g_bSmokes[i][2] = 0;
					
				}
			}
			else if (StrEqual(item, "strip"))
			{
				for (int j = 0; j < sizeof(g_iChallengers); j++) 
				{
					if (g_iChallengers[j] != 0) 
					{
						for (int i = 0; i <= 4; i++)
						{
							int weapon = -1;
							while((weapon = GetPlayerWeaponSlot(g_iChallengers[j], i)) != -1)
							{
								if(Weapon_IsValid(weapon))
								{
									RemovePlayerItem(g_iChallengers[j], weapon);
									AcceptEntityInput(weapon, "Kill");
								}
							}
						}
					}
				}
			}
			else if (StrEqual(item, "givesmokes"))
			{
				for (int j = 0; j < sizeof(g_iChallengers); j++) 
				{
					if (g_iChallengers[j] != 0) 
					{
						if (IsPlayerAlive(g_iChallengers[j]))
						{
							GivePlayerItem(g_iChallengers[j] ,"weapon_smokegrenade");
							GivePlayerItem(g_iChallengers[j] ,"weapon_smokegrenade");
							GivePlayerItem(g_iChallengers[j] ,"weapon_smokegrenade");
							GivePlayerItem(g_iChallengers[j] ,"weapon_knife");
						}
					}
				}
			}
			else if (StrEqual(item, "results"))
			{
				for (int j = 0; j < sizeof(g_iChallengers); j++) 
				{
					if (g_iChallengers[j] != 0) 
					{
						PrintToServer("[SMOKE] %N RESULTS %i, %i, %i", g_iChallengers[j], g_bSmokes[j][0], g_bSmokes[j][1], g_bSmokes[j][2]);
					}
				}
			}
			/*
			else if (StrEqual(item, "pos1"))
			{
				GetClientAbsOrigin(param1, g_flBoxMin);
				PrintToChat(param1, "Set Pos1");
			}
			else if (StrEqual(item, "pos2"))
			{
				GetClientEyePosition(param1, g_flBoxMax);
				PrintToChat(param1, "Set Pos2");
			}
			else if (StrEqual(item, "clear"))
			{
				g_flBoxMin[0] = 0.0;
				g_flBoxMin[1] = 0.0;
				g_flBoxMin[2] = 0.0;
				g_flBoxMax[0] = 0.0;
				g_flBoxMax[1] = 0.0;
				g_flBoxMax[2] = 0.0;
			}
			else if (StrEqual(item, "render"))
			{
				TE_DrawBox(g_flBoxMin, g_flBoxMax, 10.0);
			}
			*/
			// Reopen the menu, param1 meant to be original client
			DisplaySmokeChallenge(param1);

		}
		case MenuAction_End: delete menu;
	}
}

//===== Throw Challenge
public void DisplayThrowChallenge(int client)
{
	char text[64];
	Format(text, sizeof(text), "Toggle challenge: %i", g_bThrowChallenge);

	Menu menu = new Menu(Menu_ThrowChallenge);
	menu.SetTitle("Throw challenge");
	menu.AddItem("toggle", text);
	
	Format(text, sizeof(text), "Select Client: %N", g_iWeapon);
	menu.AddItem("select", text);
	menu.AddItem("spawn", "Spawn Weapon");
	menu.AddItem("remove", "Remove");
	menu.AddItem("result", "Results");
	menu.Display(client, 30);
}

public int Menu_ThrowChallenge(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));

			if (StrEqual(item, "toggle"))
			{
				g_bThrowChallenge = !g_bThrowChallenge;
			}
			else if (StrEqual(item, "select"))
			{
				int ent = GetClientAimTarget(param1, false);
				if (Entity_IsValid(ent))
					g_iWeapon = ent;
			}
			else if (StrEqual(item, "spawn"))
			{
				char szWeapon[64];
				float flPos[3];
				int arr[4];

				g_cvWeaponSpawn.GetString(szWeapon, sizeof(szWeapon));
				GetAimVector(param1, flPos);
				int ent = SpawnWeapon(szWeapon, flPos);
				SetEntPropFloat(ent, Prop_Send, "m_flModelScale", g_cvWeaponScale.FloatValue);
				Entity_SetOwner(ent, g_iWeapon);
				SetVariantBool(false);
				AcceptEntityInput(ent, "ToggleCanBePickedUp");
				
				arr[0] = ent;
				arr[1] = RoundFloat(flPos[0]);
				arr[2] = RoundFloat(flPos[1]);
				arr[3] = RoundFloat(flPos[2]);
				g_arWeapons.PushArray(arr, 4);
			}
			else if (StrEqual(item, "remove"))
			{
				int ent = GetClientAimTarget(param1, false);
				if (Weapon_IsValid(ent)) {
					AcceptEntityInput(ent, "kill");
				}
			}
			else if (StrEqual(item, "result"))
			{
				PrintToServer("");
				int arr[4], owner;
				float flPos1[3], flPos2[3], distance;
				
				for (int i = 0; i < g_arWeapons.Length; i++)
				{
					g_arWeapons.GetArray(i, arr, 4);
					int weapon = arr[0];
					if (Weapon_IsValid(weapon)) {
						flPos1[0] = float(arr[1]);
						flPos1[1] = float(arr[2]);
						flPos1[2] = float(arr[3]);
						Entity_GetAbsOrigin(weapon, flPos2);
						owner = Entity_GetOwner(weapon);
						distance = GetVectorDistance(flPos1, flPos2);
						PrintToServer("%N's weapon traveled %f", owner, distance);
					}
				}
			}

			// Reopen the menu, param1 meant to be original client
			DisplayThrowChallenge(param1);

		}
		case MenuAction_End: delete menu;
	}
}

//===== Bot Challenge
public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	int pressedButtons = GetEntProp(client, Prop_Data, "m_afButtonPressed");
	int releasedButtons = GetEntProp(client, Prop_Data, "m_afButtonReleased");
	
	if (pressedButtons & IN_USE)
	{
		//PrintToChatAll("Pressed called");
		
		int ent = GetClientAimTarget(client, false);
		if (Entity_IsValid(ent))
		{
			char targetname[MAX_NAME_LENGTH];
			GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
			
			if (String_StartsWith(targetname, "STICKER_"))  // FIX ME
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
		
		if (Client_IsValid(ent)) {
			if (IsFakeClient(ent)) {
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
	
	/*
	for (int i = 0; i < sizeof(g_iSkins); i++)
	{
		if (g_iSkins[i] != INVALID_ENT_REFERENCE) 
		{
			int ent = EntRefToEntIndex(g_iSkins[i]);
			float flPos[3];
			float flClientPos[3];
			
			Entity_GetAbsOrigin(ent, flPos);
			Entity_GetAbsOrigin(client, flClientPos);
			
			if (GetVectorDistance(flPos, flClientPos) < 60.0)
			{
				char name[MAX_NAME_LENGTH];
				Format(name, sizeof(name), "%N", client);
				DispatchKeyValue(g_iTextName[i], "message", name);
			}
		}
	}
	*/
	
	if (g_bSmokeChallenge)
	{
		if (g_iChallengers[client] > 0) {
			char first[5];
			char second[5];
			char third[5];
			
			// surley gotta be a better way to do this
			if (g_bSmokes[client][0] == -1) first = "❌";
			if (g_bSmokes[client][1] == -1) second = "❌";
			if (g_bSmokes[client][2] == -1) third = "❌";
			
			if (g_bSmokes[client][0] == 0) first = "?";
			if (g_bSmokes[client][1] == 0) second = "?";
			if (g_bSmokes[client][2] == 0) third = "?";
			
			if (g_bSmokes[client][0] == 1) first = "✔";
			if (g_bSmokes[client][1] == 1) second = "✔";
			if (g_bSmokes[client][2] == 1) third = "✔";
			
			PrintCenterText(client, "<span class='fontSize-xl'><font color='#ffd505'> %s %s %s </font></span>", first, second, third);
		}
	}
	
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsFakeClient(client) && IsPlayerAlive(client)) {
		if (g_bBotChallenge) { buttons |= IN_ATTACK; }
		if (g_iBotShoot1 && client == g_iBot1) { buttons |= IN_ATTACK; }
		if (g_iBotShoot2 && client == g_iBot2) { buttons |= IN_ATTACK; }
	}

	return Plugin_Continue;
}


public void DisplayBotChallenge(int client)
{
	char text[64];
	Format(text, sizeof(text), "Start shooting: %i", g_bBotChallenge);

	Menu menu = new Menu(Menu_BotChallenge);
	menu.SetTitle("Bot challenge");
	menu.AddItem("add1", "Add Bot1");
	menu.AddItem("add2", "Add Bot2");
	menu.AddItem("respawn", "Respawn");
	menu.AddItem("teleport1", "Teleport Bot1");
	menu.AddItem("teleport2", "Teleport Bot2");
	menu.AddItem("toggle", text);
	menu.AddItem("equip", "Equip");
	menu.AddItem("remove", "Remove fake clients");
	
	Format(text, sizeof(text), "Bot1 shooting: %i", g_iBotShoot1);
	menu.AddItem("shoot1", text);
	Format(text, sizeof(text), "Bot2 shooting: %i", g_iBotShoot2);
	menu.AddItem("shoot2", text);
	menu.AddItem("setdistance", "Set pos");
	menu.AddItem("measure", "Measure");
	menu.Display(client, 30);
}

public int Menu_BotChallenge(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			char cmd[32];
			char team[10];
			if (GetClientTeam(param1) == CS_TEAM_CT) team = "ct"; 
			else team = "t";
			Format(cmd, sizeof(cmd), "bot_add_%s", team);
			
			if (StrEqual(item, "add1"))
			{
				g_bBot1 = true;
				ServerCommand(cmd);
			}
			else if (StrEqual(item, "add2"))
			{
				g_bBot2 = true;
				ServerCommand(cmd);
			} 
			else if (StrEqual(item, "respawn"))
			{
				if (g_iBot1) CS_RespawnPlayer(g_iBot1);
				if (g_iBot2) CS_RespawnPlayer(g_iBot2);
			}
			else if (StrEqual(item, "teleport1")) 
			{
				float flPos[3];
				float flAng[3];
				Entity_GetAbsOrigin(param1, flPos);
				Entity_GetAbsAngles(param1, flAng);
				TeleportEntity(g_iBot1, flPos, flAng, NULL_VECTOR);
			}
			else if (StrEqual(item, "teleport2")) 
			{
				float flPos[3];
				float flAng[3];
				Entity_GetAbsOrigin(param1, flPos);
				Entity_GetAbsAngles(param1, flAng);
				TeleportEntity(g_iBot2, flPos, flAng, NULL_VECTOR);
			}
			else if (StrEqual(item, "toggle"))
			{
				g_bBotChallenge = !g_bBotChallenge;
				
				int weapon = Client_GetActiveWeapon(param1);
				PrintToServer("PaintKit %i",GetEntProp(weapon,Prop_Send,"m_nFallbackPaintKit"));
			}
			else if (StrEqual(item, "equip"))
			{
				if (g_iBot1) {
					int weapon = Client_GetWeaponBySlot(g_iBot1, CS_SLOT_SECONDARY);
					EquipPlayerWeapon(g_iBot1, weapon);
				}
				if (g_iBot2) {
					int weapon = Client_GetWeaponBySlot(g_iBot2, CS_SLOT_SECONDARY);
					EquipPlayerWeapon(g_iBot2, weapon);
				}
			}
			else if (StrEqual(item, "remove"))
			{
				for(int i = 0; i < MAXPLAYERS; i++)
				{
					if (Client_IsValid(i))
					{
						if (IsFakeClient(i) && GetClientTeam(i) == GetClientTeam(param1))
						{
							KickClient(i);
						}
					}
				}
			}
			else if (StrEqual(item, "shoot1"))
			{
				g_iBotShoot1 = !g_iBotShoot1;
			}
			else if (StrEqual(item, "shoot2"))
			{
				g_iBotShoot2 = !g_iBotShoot2;
			}
			else if (StrEqual(item, "setdistance"))
			{
				Entity_GetAbsOrigin(g_iBot1, flBot1Pos);
				Entity_GetAbsOrigin(g_iBot2, flBot2Pos);
			}
			else if (StrEqual(item, "measure"))
			{
				float temp1[3];
				float temp2[3];
				
				Entity_GetAbsOrigin(g_iBot1, temp1);
				Entity_GetAbsOrigin(g_iBot2, temp2);
				
				float dist1 = GetVectorDistance(temp1, flBot1Pos);
				float dist2 = GetVectorDistance(temp2, flBot2Pos);
				float total = dist1 + dist2;
				PrintToServer("[BOT] Bot1 off by %f, Bot2 off by %f, total diff %f", dist1, dist2, total);
			}
			
			// Reopen the menu, param1 meant to be original client
			DisplayBotChallenge(param1);

		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

//===== Skin Challenge
public void DisplayPriceChallenge(int client)
{
	char text[64];
	Format(text, sizeof(text), "Toggle challenge: %i", g_bBombChallenge);

	Menu menu = new Menu(Menu_PriceChallenge);
	menu.SetTitle("Price challenge");
	menu.AddItem("finalise", "Reset names");
	menu.AddItem("spawn1", "Spawn Glock");
	menu.AddItem("spawn2", "Spawn Negev");
	menu.AddItem("spawn3", "Spawn Ump");
	menu.AddItem("spawn4", "Spawn Sawed");
	menu.AddItem("spawn5", "Spawn Aug");
	menu.AddItem("spawn6", "Spawn Mag7");
	menu.AddItem("spawn7", "Spawn Mp9");
	menu.AddItem("spawn8", "Spawn Cz");
	menu.AddItem("spawn9", "Spawn Ak");
	menu.AddItem("spawn10", "Spawn Scar20");
	menu.AddItem("spawn11", "Spawn M4A1");
	menu.AddItem("spawn12", "Spawn Bizon");
	menu.AddItem("spawn13", "Spawn Awp");
	menu.AddItem("spawn14", "Spawn Deagle");
	menu.Display(client, 30);
}

public int Menu_PriceChallenge(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			
			if (StrEqual(item, "finalise"))
			{
				int ent = -1;
				while ((ent = FindEntityByClassname(ent, "point_worldtext")) != INVALID_ENT_REFERENCE)
				{
					char targetname[MAX_NAME_LENGTH];
					GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
					
					if (String_StartsWith(targetname, "PWT_"))
						DispatchKeyValue(ent, "message", "");
						
				}
				
				for (int i = 0; i < sizeof(g_bSkins); i++)
					g_bSkins[i] = false;
					
				for (int i = 0; i < sizeof(g_bSkinsClient); i++)
					g_bSkinsClient[i] = false;
			}
			else if (StrEqual(item, "spawn1"))
			{
				int ent = SpawnSkin(param1, "weapon_glock", "FN Synth Leaf", 732);
				int text = SpawnText(ent);
				g_iSkins[0] = EntIndexToEntRef(ent);
				g_iTextName[0] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn2"))
			{
				int ent = SpawnSkin(param1, "weapon_negev", "FN Mjolnir", 763);
				int text = SpawnText(ent);
				g_iSkins[1] = EntIndexToEntRef(ent);
				g_iTextName[1] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn3"))
			{
				int ent = SpawnSkin(param1, "weapon_ump45", "FN Fade", 879);
				int text = SpawnText(ent);
				g_iSkins[2] = EntIndexToEntRef(ent);
				g_iTextName[2] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn4"))
			{
				int ent = SpawnSkin(param1, "weapon_sawedoff", "FN Copper", 41);
				int text = SpawnText(ent);
				g_iSkins[3] = EntIndexToEntRef(ent);
				g_iTextName[3] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn5"))
			{
				int ent = SpawnSkin(param1, "weapon_aug", "FN Hot Rod", 33);
				int text = SpawnText(ent);
				g_iSkins[4] = EntIndexToEntRef(ent);
				g_iTextName[4] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn6"))
			{
				int ent = SpawnSkin(param1, "weapon_mag7", "FN Cinquedea", 737);
				int text = SpawnText(ent);
				g_iSkins[5] = EntIndexToEntRef(ent);
				g_iTextName[5] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn7"))
			{
				int ent = SpawnSkin(param1, "weapon_mp9", "FN Bulldozer", 39);
				int text = SpawnText(ent);
				g_iSkins[6] = EntIndexToEntRef(ent);
				g_iTextName[6] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn8"))
			{
				int ent = SpawnSkin(param1, "weapon_cz75a", "FN Xiangliu", 643);
				int text = SpawnText(ent);
				g_iSkins[7] = EntIndexToEntRef(ent);
				g_iTextName[7] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn9"))
			{
				int ent = SpawnSkin(param1, "weapon_ak47", "FT Wild Lotus", 724);
				int text = SpawnText(ent);
				g_iSkins[8] = EntIndexToEntRef(ent);
				g_iTextName[8] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn10"))
			{
				int ent = SpawnSkin(param1, "weapon_scar20", "FN Splash Jam", 165);
				int text = SpawnText(ent);
				g_iSkins[9] = EntIndexToEntRef(ent);
				g_iTextName[9] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn11"))
			{
				int ent = SpawnSkin(param1, "weapon_m4a1", "MW Howl", 309);
				int text = SpawnText(ent);
				g_iSkins[10] = EntIndexToEntRef(ent);
				g_iTextName[10] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn12"))
			{
				int ent = SpawnSkin(param1, "weapon_bizon", "FN Runic", 973);
				int text = SpawnText(ent);
				g_iSkins[11] = EntIndexToEntRef(ent);
				g_iTextName[11] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn13"))
			{
				int ent = SpawnSkin(param1, "weapon_awp", "MW Medusa", 446);
				int text = SpawnText(ent);
				g_iSkins[12] = EntIndexToEntRef(ent);
				g_iTextName[12] = EntIndexToEntRef(text);
			}
			else if (StrEqual(item, "spawn14"))
			{
				int ent = SpawnSkin(param1, "weapon_deagle", "FN Blaze", 37);
				int text = SpawnText(ent);
				g_iSkins[13] = EntIndexToEntRef(ent);
				g_iTextName[13] = EntIndexToEntRef(text);
			}
			
			// Reopen the menu, param1 meant to be original client
			DisplayPriceChallenge(param1);

		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}


//===== Sticker Challenge
public void DisplayStickerChallenge(int client)
{
	char item1[32];
	Format(item1, sizeof(item1), "Toggle motion, %i", g_bStickerBlock);
	
	Menu menu = new Menu(Menu_Stickers);
	menu.SetTitle("Sticker challenge");
	menu.AddItem("remmoveall", "Remove All Stickers");
	menu.AddItem("disablemotion", item1);
	menu.AddItem("spawnset1", "Spawn Set 1");
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
				
				while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != INVALID_ENT_REFERENCE)
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
				SpawnStickerSet(param1, "6", "4", "3", "1", "5", "2");
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

stock void SpawnStickerSet(int client, char[] st1, char[] st2, char[] st3, char[] st4, char[] st5, char[] st6)
{
	int ents[6];
	
	float vEyePos[3], vEyeAngles[3], vEyeFwd[3], vEyeRight[3]; // Base values
	float vEndPoint[3];
	float distance = 40.0;
	
	GetClientEyeAngles(client, vEyeAngles);
	GetClientEyePosition(client,vEyePos);
	GetAngleVectors(vEyeAngles, vEyeFwd, vEyeRight, NULL_VECTOR);
	
	vEndPoint[0] = vEyePos[0] + (vEyeFwd[0]*distance);
	vEndPoint[1] = vEyePos[1] + (vEyeFwd[1]*distance);
	vEndPoint[2] = vEyePos[2] + (vEyeFwd[2]*distance);
	
	float flAng[3];
	MakeVectorFromPoints(vEndPoint, vEyePos, flAng);
	GetVectorAngles(flAng, flAng);
	flAng[0] = 0.0;
	
	for (int i = 0; i < 6; i++) {
		char skin[12];
		
		vEndPoint[0] = vEyePos[0] + (vEyeRight[0]*(i*distance));
		vEndPoint[1] = vEyePos[1] + (vEyeRight[1]*(i*distance));
	
		Format(skin, sizeof(skin), "%i", i);
				
		ents[i] = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(ents[i], "targetname", "STICKER_PROP");
		DispatchKeyValue(ents[i], "solid", "6");
		SetEntProp(ents[i], Prop_Data, "m_nSolidType", 6);
		DispatchKeyValue(ents[i], "spawnflags", "8"); 
		SetEntProp(ents[i], Prop_Data, "m_CollisionGroup", 5);
		SetEntityModel(ents[i], STICKER_MDL);
		DispatchSpawn(ents[i]);
		TeleportEntity(ents[i], vEndPoint, flAng, NULL_VECTOR);
		
		AcceptEntityInput(ents[i], "EnableCollision"); 
		AcceptEntityInput(ents[i], "TurnOn", ents[i], ents[i], 0);
		
		SetEntPropFloat(ents[i], Prop_Send, "m_flModelScale", g_cvStickerScale.FloatValue); 
		
		float tempAng[3];
		float tempPos[3];
		tempPos = vEndPoint;
		tempAng = flAng;
		tempAng[1] -= 180.0;
		
		// this is actually too lazy
		if (i == 0) {
			int ent = CreateStickerText("low");
			tempPos[2] -= 30.0;
			TeleportEntity(ent, tempPos, tempAng, NULL_VECTOR);
		}
		else if (i == 5)
		{
			int ent = CreateStickerText("high");
			tempPos[2] -= 30.0;
			TeleportEntity(ent, tempPos, tempAng, NULL_VECTOR);
		}
	}
	
	DispatchKeyValue(ents[0], "skin", st1);
	DispatchKeyValue(ents[1], "skin", st2);
	DispatchKeyValue(ents[2], "skin", st3);
	DispatchKeyValue(ents[3], "skin", st4);
	DispatchKeyValue(ents[4], "skin", st5);
	DispatchKeyValue(ents[5], "skin", st6);
	
}

stock int CreateStickerText(char[] message)
{
	int worldtextHigh = CreateEntityByName("point_worldtext");
	DispatchKeyValue(worldtextHigh, "targetname", "STICKER_PROP");
	DispatchKeyValue(worldtextHigh, "color", "255 255 255");
	DispatchKeyValue(worldtextHigh, "textsize", "5"); 
	DispatchKeyValue(worldtextHigh, "message", message); 
	DispatchSpawn(worldtextHigh);
	return worldtextHigh;
}

//===== HE Challenge
public void DisplayHEChallenge(int client)
{
	Menu menu = new Menu(Menu_HEChallenge);
	menu.SetTitle("Price challenge");
	menu.AddItem("remove", "Remove weapons");
	menu.AddItem("sethp", "Set HP");
	menu.AddItem("give", "Give grenades and armour");
	menu.AddItem("toggle", "Toggle ammo");
	menu.Display(client, 30);
}

public int Menu_HEChallenge(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "remove"))
			{
				for (int j = 0; j < sizeof(g_iChallengers); j++) 
				{						
					if (g_iChallengers[j] != 0) 
					{
						if (!IsFakeClient(g_iChallengers[j])) {
							for (int i = 0; i <= 4; i++)
							{
								int weapon = -1;
								while((weapon = GetPlayerWeaponSlot(g_iChallengers[j], i)) != -1)
								{
									if(Weapon_IsValid(weapon))
									{
										RemovePlayerItem(g_iChallengers[j], weapon);
										AcceptEntityInput(weapon, "Kill");
									}
								}
							}
						}
					}
				}
			}
			else if (StrEqual(item, "sethp"))
			{
				for (int j = 0; j < sizeof(g_iChallengers); j++) 
				{						
					if (g_iChallengers[j] != 0) 
					{
						Entity_SetMaxHealth(g_iChallengers[j], 150);
						Entity_SetHealth(g_iChallengers[j], 150);
					}
				}
			}
			else if (StrEqual(item, "give"))
			{
				for (int j = 0; j < sizeof(g_iChallengers); j++) 
				{						
					if (g_iChallengers[j] != 0) 
					{
						GivePlayerItem(g_iChallengers[j], "weapon_knife");
						GivePlayerItem(g_iChallengers[j], "weapon_hegrenade");
						GivePlayerItem(g_iChallengers[j], "item_kevlar");
					}
				}
			}
			else if (StrEqual(item, "toggle"))
			{
				ConVar ammo = FindConVar("sv_infinite_ammo");
				if (ammo.IntValue == 2) SetConVarInt(ammo, 0);
				else SetConVarInt(ammo, 2);
				PrintToChat(param1, "sv_infinte_ammo: %i", ammo.IntValue);
			}

			// Reopen the menu, param1 meant to be original client
			DisplayHEChallenge(param1);

		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

//===== Aim Challenge
public void DisplayAimChallenge(int client)
{
	char item1[32];
	Format(item1, sizeof(item1), "Aim Challenge, %i", g_bAimChallenge);
	
	Menu menu = new Menu(Menu_AimChallenge);
	menu.SetTitle("Aim challenge");
	menu.AddItem("toggle", item1);
	menu.AddItem("set", "Set Weapons");
	menu.AddItem("endround", "Restart round");
	Format(item1, sizeof(item1), "Ground weapons, %i", g_cvGroundWeapons.BoolValue);
	menu.AddItem("ground", item1);
	menu.Display(client, 30);
}

public int Menu_AimChallenge(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "toggle"))
			{
				g_bAimChallenge = !g_bAimChallenge;
				SetConVarString(g_cvPrimaryCTDefault, "");
				SetConVarString(g_cvPrimaryTDefault, "");
				SetConVarString(g_cvSecondaryCTDefault, "");
				SetConVarString(g_cvSecondaryTDefault, "");
				SetConVarBool(g_cvResetEquipment, true);
				
			}
			else if (StrEqual(item, "endround"))
			{
				CS_TerminateRound(0.0, CSRoundEnd_Draw);
			}
			else if (StrEqual(item, "ground"))
			{
				g_cvGroundWeapons.SetBool(!g_cvGroundWeapons.BoolValue);
			}
			else if (StrEqual(item, "set"))
			{
				for (int j = 0; j < sizeof(g_iChallengers); j++) 
				{						
					if (g_iChallengers[j] != 0) 
					{
						if (!IsFakeClient(g_iChallengers[j])) {
							for (int i = 0; i <= 4; i++)
							{
								int weapon = -1;
								while((weapon = GetPlayerWeaponSlot(g_iChallengers[j], i)) != -1)
								{
									if(Weapon_IsValid(weapon))
									{
										RemovePlayerItem(g_iChallengers[j], weapon);
										AcceptEntityInput(weapon, "Kill");
									}
								}
							}
							
							char szPrimary[32];
							char szSecondary[32];
										
							GetConVarString(g_cvDuelPrimary, szPrimary, sizeof(szPrimary));
							GetConVarString(g_cvDuelSecondary, szSecondary, sizeof(szSecondary));
									
							GivePlayerItem(g_iChallengers[j], "weapon_knife");
							GivePlayerItem(g_iChallengers[j], szSecondary);
							GivePlayerItem(g_iChallengers[j], szPrimary);
						}
					}
				}
			}

			// Reopen the menu, param1 meant to be original client
			DisplayAimChallenge(param1);

		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

// Blind menu
public void DisplayBlindChallenge(int client)
{
	Menu menu = new Menu(Menu_Blind);
	menu.SetTitle("Blind challengers");
	menu.AddItem("blindall", "Blind all");
	menu.AddItem("unblindall", "Unblind all");
	menu.Display(client, 30);	
}

public int Menu_Blind(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action){
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			
			if (StrEqual(item, "blindall"))
			{
				for (int i = 0; i < sizeof(g_iChallengers); i++) 
					if (g_iChallengers[i] != 0) 
						ShowOverlay(g_iChallengers[i], "effects/black", 0.0);
			}
			else if (StrEqual(item, "unblindall"))
			{
				ShowOverlayAll("", 1.0);
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

public void OnVPhysUpdatePost(int ent)
{
	int index = g_arWeapons.FindValue(ent);
	if (index >= 0) {
		int arr[4];
		g_arWeapons.GetArray(index, arr, 4);
	}
}

public void OnVPhysUpdate(int weapon)
{
	float flPos[3];
	Entity_GetAbsAngles(weapon, flPos);
	Entity_SetAbsAngles(weapon, flPos);
}

stock int SpawnSkin(int client, char[] weapon, char[] text, int paintId)
{
	float flPos[3];
	float flTargetPos[3];
	float flAng[3];
	
	GetAimVector(client, flPos);
	flPos[2] += 50.0;
	
	int ent = CreateEntityByName(weapon);
	DispatchSpawn(ent);
	GetClientEyePosition(client, flTargetPos);
	MakeVectorFromPoints(flTargetPos, flPos, flAng);
	GetVectorAngles(flAng, flAng);

	SetEntProp(ent,Prop_Send,"m_iItemIDLow",-1);
	SetEntProp(ent,Prop_Send,"m_nFallbackPaintKit", paintId);
	
	flAng[0] = 0.0;
	flAng[1] += 90.0;
	TeleportEntity(ent, flPos, flAng, NULL_VECTOR);
	SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 2.0);
	SetVariantBool(false);
	AcceptEntityInput(ent, "ToggleCanBePickedUp");
	
	float flRight[3];
	GetAngleVectors(flAng, NULL_VECTOR, flRight, NULL_VECTOR);
	
	int textEnt = CreateEntityByName("point_worldtext");
	DispatchKeyValue(textEnt, "message", text);
	DispatchKeyValue(textEnt, "textsize", "5.0");
	DispatchSpawn(textEnt);
	
//	PrintToServer("%.0f, %.0f, %.0f", flRight[0], flRight[1], flRight[2]);
	flPos[2] += 20.0;
	flAng[1] -= 90.0;
	TeleportEntity(textEnt, flPos, flAng, NULL_VECTOR);
	
	SDKHook(ent, SDKHook_VPhysicsUpdate, OnVPhysUpdate);
	SDKHook(ent, SDKHook_Use, OnWeaponUse);
	
	return ent;
}

public Action OnWeaponUse(int entity, int activator, int caller, UseType type, float value)
{
	int index = -1;
	for (int i = 0; i < sizeof(g_iSkins); i++) {
		if (entity == EntRefToEntIndex(g_iSkins[i])) {
			index = i;
			break;
		}
	}
	
	if (index >= 0) {
		if (!g_bSkins[index] && !g_bSkinsClient[activator]) {
			char name[MAX_NAME_LENGTH];
			Format(name, sizeof(name), "%N", activator);
			DispatchKeyValue(g_iTextName[index], "message", name);
			g_bSkins[index] = true;
			g_bSkinsClient[activator] = true;
		}
	}
	
	return Plugin_Continue;
}

stock int SpawnText(int ent)
{
	float flAng[3];
	float flPos[3];
	
	Entity_GetAbsOrigin(ent, flPos);
	Entity_GetAbsAngles(ent, flAng);
	
	int textEnt = CreateEntityByName("point_worldtext");
	DispatchKeyValue(textEnt, "targetname", "PWT_NAME");
	DispatchKeyValue(textEnt, "message", "");
	DispatchKeyValue(textEnt, "textsize", "5.0");
	DispatchSpawn(textEnt);
	
	flPos[2] += 30.0;
	flAng[1] -= 90.0;
	TeleportEntity(textEnt, flPos, flAng, NULL_VECTOR);
	
	return textEnt;
}

stock int SpawnWeapon(char[] weapon, float origin[3], float rotation[3] =  { 0.0, 0.0, 90.0 } )
{
	int ent = CreateEntityByName(weapon);
	if (!IsValidEntity(ent))
		ThrowError("Invalid Entity.");

	if (!DispatchSpawn(ent))
		ThrowError("Invalid entity index, or no mod support.");
		
	origin[2] += 10.0;
	ActivateEntity(ent);
	TeleportEntity(ent, origin, rotation, NULL_VECTOR);
	
	return ent;
}

stock int SpawnProp(char[] path, float origin[3], float rotation[3] =  { 0.0, 0.0, 90.0 } )
{
	int ent = CreateEntityByName("prop_dynamic_override");
	if (!IsValidEntity(ent))
		ThrowError("Invalid Entity.");
	
	if(!IsModelPrecached(path)) PrecacheModel(path);
	SetEntityModel(ent, path);

	if (!DispatchSpawn(ent))
		ThrowError("Invalid entity index, or no mod support.");
	
	origin[2] += 10.0;
	ActivateEntity(ent);
	TeleportEntity(ent, origin, rotation, NULL_VECTOR);
	
	return ent;
}

stock void TE_DrawBox(float vMins[3], float vMaxs[3], float time)
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
	TE_SendBeam(vMaxs, vPos1, time);
	TE_SendBeam(vMaxs, vPos2, time);
	TE_SendBeam(vMaxs, vPos3, time);
	TE_SendBeam(vPos6, vPos1, time);
	TE_SendBeam(vPos6, vPos2, time);
	TE_SendBeam(vPos6, vMins, time);
	TE_SendBeam(vPos4, vMins, time);
	TE_SendBeam(vPos5, vMins, time);
	TE_SendBeam(vPos5, vPos1, time);
	TE_SendBeam(vPos5, vPos3, time);
	TE_SendBeam(vPos4, vPos3, time);
	TE_SendBeam(vPos4, vPos2, time);
}

stock void TE_SendBeam(const float vMins[3], const float vMaxs[3], float timer)
{
	float width = 0.5;
	float amplitude = 5.0;
	int color[] =  { 255, 255, 255, 255 };
	TE_SetupBeamPoints(vMins, vMaxs, g_iLaserSprite, g_iLaserSprite, 0, 0, timer, width, 1.0, 1, amplitude, color, 0);
	TE_SendToAll();
}

stock bool GetAimVector(int client, float vec[3])
{
	float pos[3], ang[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, ang);
	TR_TraceRayFilter(pos, ang, MASK_SOLID, RayType_Infinite, Filter_DontHitPlayers);

	if(TR_DidHit())
	{
		TR_GetEndPosition(vec);
		return true;
	} else {
		LogError("ERROR: Unable to get aim vector of %N", client);
	}

	return false;
}

stock bool Filter_DontHitPlayers(int entity, any contentsMask, any data)
{
	return !((entity > 0) && (entity <= MaxClients));
}

public bool TraceEntityFilterSelf(int entity, int mask, any data)
{
	return data != entity;
}