/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[TF2] Cstrike"
#define PLUGIN_DESCRIPTION "A Counter-Strike gamemode for Team Fortress 2."
#define PLUGIN_VERSION "1.0.0"

#define TYPE_SET 0
#define TYPE_ADD 1
#define TYPE_SUB 2

/*****************************/
//Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

/*****************************/
//ConVars

/*****************************/
//Globals

bool g_LateLoad;

Handle g_PlayerHud;

enum struct PlayersData
{
	int client;
	int cash;
	int armor;
	bool canbuy;

	void Reset()
	{
		this.client = -1;
		this.cash = 0;
		this.armor = 0;
		this.canbuy = false;
	}

	void Init(int client)
	{
		this.client = client;
		this.cash = 0;
		this.armor = 0;
		this.canbuy = false;
	}

	void AddCash(int value)
	{
		this.cash += value;

		if (this.cash > 16000)
			this.cash = 16000;
		
		this.UpdateHud();
	}

	void SetCash(int value)
	{
		this.cash = value;
		this.UpdateHud();
	}

	bool RemoveCash(int value)
	{
		if (this.cash < value)
			return false;
		
		this.cash -= value;
		this.UpdateHud();

		return true;
	}

	void AddArmor(int value)
	{
		this.armor += value;

		if (this.armor > 16000)
			this.armor = 16000;
		
		this.UpdateHud();
	}

	void SetArmor(int value)
	{
		this.armor = value;
		this.UpdateHud();
	}

	bool RemoveArmor(int value)
	{
		if (this.armor < value)
			return false;
		
		this.armor -= value;
		this.UpdateHud();

		return true;
	}

	void UpdateHud()
	{
		SetHudTextParams(0.2, 0.95, 99999.0, 0, 255, 0, 255);
		ShowSyncHudText(this.client, g_PlayerHud, "Cash: %i\nArmor: %i", this.cash, this.armor);
	}
}

PlayersData g_PlayersData[MAXPLAYERS + 1];

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = "Drixevel", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_LateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);

	RegConsoleCmd("sm_buy", Command_Buy);

	g_PlayerHud = CreateHudSynchronizer();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
			OnClientConnected(i);
		
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}

	if (g_LateLoad)
	{
		g_LateLoad = false;
		SetTeamScore(2, 0);
		SetTeamScore(3, 0);
		TF2_ForceWin();
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			ClearSyncHud(i, g_PlayerHud);
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(5.0, Timer_DisplayWeaponsMenu, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DisplayWeaponsMenu(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		if (GetTeamScore(2) < 1 && GetTeamScore(3) < 1)
		{
			g_PlayersData[i].SetCash(800);
			g_PlayersData[i].SetArmor(100);
		}
		else
			g_PlayersData[i].UpdateHud();

		g_PlayersData[i].canbuy = true;
		SendWeaponsMenu(i);
	}

	CreateTimer(20.0, Timer_DisableBuying, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DisableBuying(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		g_PlayersData[i].canbuy = false;
	}

	PrintToChatAll("Buyphase is open over.");
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client > 0)
		g_PlayersData[client].UpdateHud();
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (attacker > 0)
		g_PlayersData[attacker].AddCash(600);
}

public Action Command_Buy(int client, int args)
{
	if (!g_PlayersData[client].canbuy)
	{
		PrintToChat(client, "You cannot buy items at this time.");
		return Plugin_Handled;
	}

	SendWeaponsMenu(client);
	return Plugin_Handled;
}

void SendWeaponsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Weapons);
	menu.SetTitle("Pick a type:");

	menu.AddItem("snipers", "Sniper Rifles");
	menu.AddItem("smgs", "SMGs");
	menu.AddItem("rifles", "Rifles");
	menu.AddItem("gear", "Gear");
	menu.AddItem("grenades", "Grenades");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Weapons(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!g_PlayersData[param1].canbuy)
			{
				PrintToChat(param1, "You cannot buy items at this time.");
				return;
			}

			char sType[32]; char sDisplay[32];
			menu.GetItem(param2, sType, sizeof(sType), _, sDisplay, sizeof(sDisplay));

			OpenItemsMenu(param1, sType, sDisplay);
		}

		case MenuAction_End:
			delete menu;
	}
}

void OpenItemsMenu(int client, const char[] type, const char[] display)
{
	Menu menu = new Menu(MenuHandler_Items);
	menu.SetTitle("Pick a %s:", display);
	
	if (StrEqual(type, "snipers"))
	{
		menu.AddItem("", "Manncannon");
		menu.AddItem("", "Ol' Betty");
		menu.AddItem("", "The Veteran's Repeater");
	}
	else if (StrEqual(type, "smgs"))
	{
		menu.AddItem("", "Broomhandle Backup");
		menu.AddItem("", "Heckler");
		menu.AddItem("", "Iron Cover");
		menu.AddItem("", "Russian Repeater");
		menu.AddItem("", "Li'l Mate");
	}
	else if (StrEqual(type, "rifles"))
	{
		menu.AddItem("", "AK-47");
		menu.AddItem("", "FAMAS");
		menu.AddItem("", "Hellraiser");
		menu.AddItem("", "M4");
	}
	else if (StrEqual(type, "gear"))
	{
		menu.AddItem("", "Armor");
		menu.AddItem("", "Armor + Helmet");
	}
	else if (StrEqual(type, "grenades"))
	{
		menu.AddItem("", "Flash Grenade");
		menu.AddItem("", "HE Grenade");
		menu.AddItem("", "Smoke Grenade");
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Items(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!g_PlayersData[param1].canbuy)
			{
				PrintToChat(param1, "You cannot buy items at this time.");
				return;
			}

			char sType[32]; char sDisplay[32];
			menu.GetItem(param2, sType, sizeof(sType), _, sDisplay, sizeof(sDisplay));

			g_PlayersData[param1].RemoveCash(600);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				SendWeaponsMenu(param1);
		}

		case MenuAction_End:
			delete menu;
	}
}

public void OnClientConnected(int client)
{
	g_PlayersData[client].Init(client);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (attacker > 0 && attacker <= MaxClients && g_PlayersData[victim].armor > 0)
	{
		int dmg = RoundFloat(damage);

		if (g_PlayersData[victim].armor >= dmg)
		{
			g_PlayersData[victim].RemoveArmor(dmg);
			damage = 0.0;
			return Plugin_Changed;
		}
		else
		{
			int difference = dmg - g_PlayersData[victim].armor;
			g_PlayersData[victim].RemoveArmor(difference);
			damage = float(difference);
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public void OnClientDisconnect_Post(int client)
{
	g_PlayersData[client].Reset();
}

public Action TF2_OnClassChange(int client, TFClassType& class)
{
	if (class != TFClass_Sniper)
	{
		class = TFClass_Sniper;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public void TF2_OnPlayerSpawn(int client, int team, int class)
{
	if (TF2_GetPlayerClass(client) != TFClass_Sniper)
	{
		TF2_SetPlayerClass(client, TFClass_Sniper);
		TF2_RegeneratePlayer(client);
	}

	CreateTimer(0.2, Timer_UpdateWeapons, client);
}

public Action Timer_UpdateWeapons(Handle timer, any data)
{
	int client = data;

	EquipWeaponSlot(client, 2);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom", false))
		SDKHook(entity, SDKHook_Spawn, OnRespawnRoomSpawn);
}

public Action OnRespawnRoomSpawn(int entity)
{
	if (IsValidEntity(entity))
		AcceptEntityInput(entity, "Kill");
}

void EquipWeaponSlot(int client, int slot)
{
	int iWeapon = GetPlayerWeaponSlot(client, slot);
	
	if (IsValidEntity(iWeapon))
	{
		char class[64];
		GetEntityClassname(iWeapon, class, sizeof(class));
		FakeClientCommand(client, "use %s", class);
	}
}

void TF2_ForceWin(TFTeam team = TFTeam_Unassigned)
{
	int iFlags = GetCommandFlags("mp_forcewin");
	SetCommandFlags("mp_forcewin", iFlags &= ~FCVAR_CHEAT);
	ServerCommand("mp_forcewin %i", view_as<int>(team));
	SetCommandFlags("mp_forcewin", iFlags);
}

public void TF2_OnEnterSpawnRoomPost(int client, int respawnroom)
{
	g_PlayersData[client].canbuy = true;
}

public void TF2_OnLeaveSpawnRoomPost(int client, int respawnroom)
{
	g_PlayersData[client].canbuy = false;
}