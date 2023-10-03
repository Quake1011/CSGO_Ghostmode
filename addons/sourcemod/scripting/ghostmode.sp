#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <vip_core>
#include <smlib>
#include <entity_prop_stocks>

#define PLUGIN_NAME "GHOSTMODE"
#define PLUGIN_VERSION 	"0.1.0"

public Plugin myinfo = 
{ 
	name = PLUGIN_NAME, 
	author = "Quake1011",
	description = "Ghostmode plugin for CS:GO", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/Quake1011" 
};

static const char wSemi[][] = {"mp9", "mac10", "mp7", "ump45", "p90", "bizon", "mp5sd"};
static const char wPistols[][] = {"deagle", "usp_silencer", "hkp2000", "glock", "elite", "p250", "cz75a", "fiveseven", "tec9", "revolver", "cutters", "defuser"};
static const char wAssault[][] = {"ak47", "m4a1", "m4a1_silencer", "famas", "galilar", "aug", "sg556", "ssg08", "awp"};
static const int g_iGrenadeOffsets[] = {15, 17, 16, 14, 18, 17};
char kvFlags[32], kvGroups[16*256], kvCTModel[PLATFORM_MAX_PATH], kvTModel[PLATFORM_MAX_PATH], ExplodeGroups[16][256];
float speed[4], invis[5], grav;
ArrayList Groups;
int g_iOffsetCanBeSpotted, m_hGroundEntity, g_iOffsetCollisionGroup, damage[4];
Handle hGravity[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Ghost_Version", Native_Version);
	CreateNative("Ghost_InInvisible", Native_Invisible);

	return (GetEngineVersion() == Engine_CSGO) ? APLRes_Success : APLRes_Failure;
}

/**
*		Получает версию ядра
*
* @param sBuffer				Буфер для хранения строки
* @param iBufferLength			Размер буфера
*
* @noreturn
*
*/
//native void Ghost_Version(char[] sBuffer, int iBufferLength)

/**
*		Возвращает, невидим ли игрок
*
* @param iClient				Индекс игрока
*
* @return						true - видим
*								false - невидим
*/
//native bool Ghost_InInvisible(int iClient)


public int Native_Version(Handle hPlugin, int iNumParams)
{
	SetNativeString(1, PLUGIN_VERSION, GetNativeCell(2), true);
	return 0;
}

public int Native_Invisible(Handle hPlugin, int iNumParams)
{
	int aC[4];
	Entity_GetRenderColor(GetNativeCell(1), aC);
	return (255*invis[0] == aC[3]) ? true : false;
}

public void OnPluginStart()
{
	AddNormalSoundHook(HookSounds);
	g_iOffsetCanBeSpotted = FindSendPropInfo("CBaseEntity", "m_bSpotted") - 4;
	g_iOffsetCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

	HookEvent("player_spawn", EvntPlayerSpawn, EventHookMode_Post);
	HookEvent("buymenu_open", EvntBuyMenuOpen, EventHookMode_Pre);

	char sPath[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ghostmode.ini");
	KeyValues kv = CreateKeyValues("Settings");

	if(kv.ImportFromFile(sPath))
	{
		kv.Rewind();
		kv.GetString("Adminflags", kvFlags, sizeof(kvFlags));
		kv.GetString("VIPS", kvGroups, sizeof(kvGroups));
		kv.GetString("CTModel", kvCTModel, sizeof(kvCTModel));
		kv.GetString("TModel", kvTModel, sizeof(kvTModel));
		speed[0] = kv.GetFloat("Speed");
		speed[1] = kv.GetFloat("VIPSSpeed");
		speed[2] = kv.GetFloat("AdminSpeed")
		speed[3] = kv.GetFloat("CTSpeed");
		invis[0] = kv.GetFloat("Invis_Stay");
		invis[1] = kv.GetFloat("Invis_Shifting");
		invis[2] = kv.GetFloat("Invis_InRUN");
		invis[3] = kv.GetFloat("Invis_Duck");
		invis[4] = kv.GetFloat("Invis_InJump");
		damage[0] = kv.GetNum("CTHealth");
		damage[1] = kv.GetNum("THealth");
		damage[2] = kv.GetNum("CTArmor");
		damage[3] = kv.GetNum("TArmor");
		grav = kv.GetFloat("Gravity");
	}
	delete kv;
	
	Groups = CreateArray(256);
	ExplodeString(kvGroups, ";", ExplodeGroups, sizeof(ExplodeGroups), sizeof(ExplodeGroups[]));
	for(int i = 0; i < sizeof(ExplodeGroups[]); i++)
	{
		if(ExplodeGroups[i][0] != '\0')
		{
			TrimString(ExplodeGroups[i]);
			Groups.PushString(ExplodeGroups[i]);
		}
		else break;
	}
}

public void OnMapStart()
{
	SetConVarInt(FindConVar("ammo_grenade_limit_flashbang"), 10);
	SetConVarInt(FindConVar("ammo_grenade_limit_total"), 500);
	SetConVarInt(FindConVar("ammo_grenade_limit_default"), 500);
	SetConVarInt(FindConVar("mp_playerid"), 1);
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
	SDKHook(client, SDKHook_Touch, Tch);
	SDKHook(client, SDKHook_EndTouch, End);
}

public Action Tch(int entity, int other)
{
	if((0 < entity <= MaxClients) && (0 < other <= MaxClients) && (IsClientInGame(entity) && IsClientInGame(other)))
	{
		if(GetClientTeam(entity) == 3 && GetClientTeam(other) == 3)
		{
			SetEntData(entity, g_iOffsetCollisionGroup, 5, 4, true);
			SetEntData(other, g_iOffsetCollisionGroup, 5, 4, true);
		}
		else if(GetClientTeam(entity) == 2 && GetClientTeam(other) == 2)
		{
			SetEntData(entity, g_iOffsetCollisionGroup, 2, 4, true);
			SetEntData(other, g_iOffsetCollisionGroup, 2, 4, true);
		}
		else if((GetClientTeam(entity) == 3 && GetClientTeam(other) == 2) || (GetClientTeam(entity) == 2 && GetClientTeam(other) == 3))
		{
			SetEntData(entity, g_iOffsetCollisionGroup, 5, 4, true);
			SetEntData(other, g_iOffsetCollisionGroup, 5, 4, true);
		}
	}
	return Plugin_Continue;
}

public Action End(int entity, int other)
{
	if((0 < entity <= MaxClients) && (0 < other <= MaxClients) && (IsClientInGame(entity) && IsClientInGame(other)))
	{
		SetEntData(entity, g_iOffsetCollisionGroup, 5, 4, true);
		SetEntData(other, g_iOffsetCollisionGroup, 5, 4, true);
	}
	return Plugin_Continue;
}

public Action WeaponCanUse(int client, int weapon)
{
	if(GetClientTeam(client) == 2)
	{
		if(weapon != -1)
		{
			char sWeaponName[64];
			GetEntityClassname(weapon, sWeaponName, sizeof(sWeaponName));
			if( StrContains(sWeaponName, "weapon_flashbang", false) != -1 
			|| StrContains(sWeaponName, "weapon_smokegrenade", false) != -1 
			|| StrContains(sWeaponName, "weapon_hegrenade", false) != -1 
			|| StrContains(sWeaponName, "weapon_molotov", false) != -1 
			|| StrContains(sWeaponName, "weapon_decoy", false) != -1 
			|| StrContains(sWeaponName, "weapon_c4", false) != -1 
			|| StrContains(sWeaponName, "weapon_knife", false) != -1 ) return Plugin_Continue;
			else return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action EvntBuyMenuOpen(Event hEvent, const char[] sEvent, bool bdb)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(0 < client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2) return Plugin_Handled;
	return Plugin_Continue;
}

public void EvntPlayerSpawn(Event hEvent, const char[] sEvent, bool bdb)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(0 < client <= MaxClients && IsClientInGame(client))
	{
		if(IsPlayerAlive(client) && GetClientTeam(client) == 2) 
		{
			for (int i = 0; i < 5; ++i)
			{
				if(i != CS_SLOT_KNIFE)
				{
					if(i == 3) RemoveNades(client);
					else RemoveWeaponBySlot(client, i);
				}
			}
		}

		if(GetClientTeam(client) == 2) 
		{
			if((CheckVipOk(client) == false) && (CheckAdminFlag(client) == false)) SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed[0]);
			else if(CheckVipOk(client) == true) 
			{	
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed[1]);
				GetWeapon(client, "weapon_flashbang", 1);
				GetWeapon(client, "weapon_smokegrenade", 1);
				GetWeapon(client, "item_assaultsuit", 1);
			}
			else if(CheckAdminFlag(client) == true) 
			{
				GetWeapon(client, "weapon_flashbang", 2);
				GetWeapon(client, "weapon_smokegrenade", 2);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed[2]);
			}
			
			if(kvTModel[0] != '\0') SetEntityModel(client, kvTModel);
			
			SetEntityHealth(client, damage[1]);
			SetEntProp(client, Prop_Data, "m_ArmorValue", damage[3]);
			
			SetEntProp(client, Prop_Send, "m_bSpotted", false);
			SetEntProp(client, Prop_Send, "m_bSpottedByMask", 0, 4, 0);
			SetEntProp(client, Prop_Send, "m_bSpottedByMask", 0, 4, 1);
			SetEntData(client, g_iOffsetCanBeSpotted, 0);
			SetEntProp(client, Prop_Data, "m_CollisionGroup", 17);
			hGravity[client] = CreateTimer(0.2, SetGravity, client, TIMER_REPEAT);
		}
		else if(GetClientTeam(client) == 3)
		{
			if(kvCTModel[0] != '\0') SetEntityModel(client, kvCTModel);
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed[3]);
			SetEntityHealth(client, damage[0]);
			SetEntProp(client, Prop_Data, "m_ArmorValue", damage[2]);
			SetEntData(client, g_iOffsetCanBeSpotted, 9);
			if(hGravity[client] != INVALID_HANDLE) hGravity[client] = null;
		}
	}
}

public void OnClientDisconnect(int client)
{
	if(hGravity[client] != INVALID_HANDLE) 
	{
		KillTimer(hGravity[client]);
		hGravity[client] = null;
	}
}

public Action SetGravity(Handle hTimer, int client)
{
	if(0 < client <= MaxClients && IsClientInGame(client)) 	
	{	
		if(GetClientTeam(client) == 2) SetEntityGravity(client, grav);
		else SetEntityGravity(client, 1.0);
	}
	return Plugin_Continue;
}

public Action HookSounds(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if(StrContains(sample, "suit", false) == -1 && StrContains(sample, "new", false) != -1) 
	{
		if(GetClientTeam(entity) == 2)
		{
			volume = 0.20;
			return Plugin_Changed;
		}
	}
    return Plugin_Continue;
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
	if(GetClientTeam(client) == 3)
	{
		bool b = false;
		for(int i = 0; i < sizeof(wPistols); i++)
		{
			if(StrEqual(weapon, wPistols[i], false))
			{
				b = true;
				break;
			}
		}
		
		for(int i = 0; i < sizeof(wSemi); i++)
		{
			if(StrEqual(weapon, wSemi[i], false))
			{
				b = true;
				break;
			}
		}		
		
		if(CheckVipOk(client) == true || CheckAdminFlag(client) == true)
		{
			for(int i = 0; i < sizeof(wAssault); i++)
			{
				if(StrEqual(weapon, wAssault[i], false))
				{
					b = true;
					break;
				}
			}	
		}
		if(b == false) return Plugin_Handled;
	}
	else return Plugin_Handled;
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		m_hGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
		SetEntityRenderMode(client, RENDER_TRANSALPHA);
		if(m_hGroundEntity == -1) Entity_SetRenderColor(client, -1, -1, -1, RoundToFloor(255*invis[4]));
		else if(((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT)) && (buttons & IN_SPEED)) Entity_SetRenderColor(client, -1, -1, -1, RoundToFloor(255*invis[1]));
		else if(((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT)) && (buttons & IN_DUCK)) Entity_SetRenderColor(client, -1, -1, -1, RoundToFloor(255*invis[3]));
		else if((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT)) Entity_SetRenderColor(client, -1, -1, -1, RoundToFloor(255*invis[2]));
		else Entity_SetRenderColor(client, -1, -1, -1, RoundToFloor(255*invis[0]));
	}
	else if(GetClientTeam(client) == 3)
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		Entity_SetRenderColor(client, 255, 255, 255, 255);
	}
	return Plugin_Continue;
}

bool CheckAdminFlag(int client) {
	AdminId admin = GetUserAdmin(client);
	AdminFlag flag;
	int k = false;
	for(int i = 0; i < sizeof(kvFlags); i++)
	{
		if(FindFlagByChar(kvFlags[i], flag)) 
		{
			k = true;
			break;
		}
	}
	return admin == INVALID_ADMIN_ID ? false : k && GetAdminFlag(admin, flag) ? true : false;
}

bool CheckVipOk(int client) 
{
	if(VIP_IsClientVIP(client))
	{
		char temp[256], temp2[256];
		VIP_GetClientVIPGroup(client, temp, sizeof(temp))
		{
			for(int i = 0; i < Groups.Length; i++)
			{
				Groups.GetString(i, temp2, sizeof(temp2));
				if(StrEqual(temp, temp2, true)) return true;
			}
		}
	}
	return false;
}

void GetWeapon(int client, const char[] weapon, int count = 1)
{
	for(int i = 0 ; i < count; i++)
	{
		float origin[3];
		GetClientAbsOrigin(client, origin);
		int ent = CreateEntityByName(weapon);
		DispatchKeyValueVector(ent, "origin", origin);
		DispatchSpawn(ent);		
	}
}

void RemoveNades(int client)
{
	while(RemoveWeaponBySlot(client, 3))
		for(int i = 0; i < 6; i++)
			SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, g_iGrenadeOffsets[i]);
}

bool RemoveWeaponBySlot(int client, int slot)
{
	int entity = GetPlayerWeaponSlot(client, slot);
	if (IsValidEdict(entity))
	{
		RemovePlayerItem(client, entity);
		AcceptEntityInput(entity, "Kill");
		return true;
	}
	return false;
}