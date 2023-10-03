#include <cstrike>
#include <sdktools>

#define PLUGIN_NAME 	"Ghostmode sound"
#define PLUGIN_VERSION 	"0.0.1"

public Plugin myinfo = 
{ 
	name = PLUGIN_NAME, 
	author = "Quake1011",
	description = "Plays the sound of ghostmode", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/Quake1011" 
};

int counter = 0;

char sounds[][] = 
{
	"sound/ghostmode_sounds/ghosts_win.wav",
	"sound/ghostmode_sounds/round_start.wav",
	"*/ghostmode_sounds/ghosts_win.wav",
	"*/ghostmode_sounds/round_start.wav"
};

public void OnPluginStart()
{
	HookEvent("round_start", EventRoundStart, EventHookMode_Post);
}

public void OnMapStart()
{
	for(int i = 0 ; i < 2; i++)
	{
		AddFileToDownloadsTable(sounds[i]);
		FakePrecacheSound(sounds[i+2]);
	}
	
	counter = 0;
}

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason)
{
	if(reason != CSRoundEnd_GameStart) counter++;
	
	if(reason == CSRoundEnd_TerroristWin || reason == CSRoundEnd_TargetBombed)
		if(counter % 3 == 0)
			for(int i = 1; i <= MaxClients; i++)
				if(IsClientInGame(i) && !IsFakeClient(i))
					ClientCommand(i, "playgamesound */ghostmode_sounds/ghosts_win.wav");

	return Plugin_Continue;
}

public void EventRoundStart(Event hEvent, const char[] sEvent, bool bdb)
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i))
			ClientCommand(i, "playgamesound */ghostmode_sounds/round_start.wav");
}

void FakePrecacheSound(const char[] szPath)
{
	AddToStringTable(FindStringTable("soundprecache"), szPath);
}