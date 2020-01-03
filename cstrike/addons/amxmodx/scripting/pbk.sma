/*  
   Title:    Play or Be Kicked
   Author:   Brad Jones

   Current Version:   1.5.243
   Release Date:      2008-JUL-23
   Compatibility:     AMXX 1.8 or higher

   This plugin has the ability to kick players for any of the following three events:

      * not joining a team or spectator mode in time when initially joining the server
      * spectatating too long
      * being AFK too long

   Which events your server looks for is configurable, as is the amount of time allowed for each event.


   INSTALLATION

      File Locations:
      
         .\configs\pbk.cfg
         .\data\lang\pbk.txt
         .\plugins\pbk.amxx

        
   CHANGE LOG:

      2008-JUL-23		1.5.243
      	
      	- Removed all vestiges of the engine module and used fakemeta instead.
        - Optimized various portions of code to be more efficient.
        - No longer comparing Z-axis to see if a player moved. This fixes an issue where
        	players' AFK meters could get reset upon round start if you had a low (2 seconds
					or less) freeze time.  Also fixes an issue on maps where players can be constantly 
          moving along the Z-axis, even when AFK (for example, ka_bungee).
        - Replaced "pbk_immunity" with three new CVARs: "pbk_spec_immunity_flags", 
        	"pbk_afk_immunity_flags", and "pbk_join_immunity_flags".  Allows you to set 
          one or more flags that should have immunity from each kick event.
        - Added plugin-specific config file, "pbk.cfg".
        - Added ability to redirect players to a different server upon kicking them. Uses the
          new CVARs, "pbk_kick2_ip" and "pbk_kick2_port".
        - Implemented optional feature whereas, if this plugin detects someone in spectator 
          mode, and the plugin is configured to kick for too much time in spectator mode, it can
          periodically query the player to see if they're actually at the keyboard or not.

      2005-DEC-11		1.4   
      	
      	- Fixed inconsistencies between what the docs said the default values for certain
        	CVARs were and what they were set as in the code.  The docs were correct, 
          the code was wrong.
				- Replaced "pbk_min_players" with three new CVARs: "pbk_join_min_players", 
        	"pbk_spec_min_players", and "pbk_afk_min_players".  This allows you to have
          finer control over when players should be kicked.
                           
      2005-NOV-11		1.3   
      	
      	- Fixed issue where player would be able to choose a team but not a model
        	and then sit there indefinitely. 
				- Added CVAR "pbk_log" which lets you specify how to log kicks. Options are to log
        	in the AMXX log (as was previously done), the chat log (allows kicks to be seen in
          programs like HLSW that show you the chat log), and in their own file (pbkMM.log 
          where MM is the two-digit month). The default is to log in the AMXX and chat logs.
				- Added CVAR "pbk_log_cnt" which lets you specify how many months of logs to keep if
        	you are logging kicks into their own file.
        - Added functionality to kick AFK users via new CVAR "pbk_afk_time". A value of 0 will
        	disable checking of AFK status.
        - Renamed CVAR "pbk_un_time" to "pbk_join_time". Added the ability to specify 0 to 
        	disable checking of initial join status.
        - Added ability to specify 0 for the "pbk_spec_time" CVAR to disable checking of 
        	spectator status.
        - Removed CVAR "pbk_restrict". Functionality that it provided is now being provided
        	via "pbk_join_time", "pbk_spec_time", and "pbk_afk_time".
        - Renamed CVAR "pbk_allow_immunity" to "pbk_immunity".
        - Changed the options for "pbk_immunity" to allow indication of what events an
        	immune player can be immune from being kicked. Options are "joining", "spectating", 
        	and "being AFK".
        - Added CVAR "pbk_immunity_warning" to indicate whether players with immunity should
        	be shown the warning countdown. The default is to show the countdown.
        - Fixed issue where the time length wasn't multilingual.

      2005-JUL-16		1.1   
      	
      	- Will ignore HLTV users. 
        - Added CVAR to allow immune players to be kicked. 
        - Replaced CVAR "pbk_time" with "pbk_spec_time" and "pbk_un_time".

      2005-JUL-10		1.0   
      
      	- Initial release.
   
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <logging>
#include <time>
#include <cstrike>
#include <engine>

new const PLUGIN[]  = "Play or Be Kicked";
new const RELEASE[] = "1.5.243";
new const AUTHOR[]  = "Brad Jones & mo0n_sniper";

#define CHECK_FREQ 5

// team flags
#define TEAM_T  1
#define TEAM_CT 2

// event flags
#define EVENT_JOIN 1
#define EVENT_SPEC 2
#define EVENT_AFK  4

// coordinate info
#define MAX_COORD_CNT   3

#define COORD_X	0
#define COORD_Y	1

// player 
#define MAX_PLAYER_CNT 33	// really 32, but 32 is 0-31 and we want 1-32, so... 33


new g_playerJoined[MAX_PLAYER_CNT], g_playerSpawned[MAX_PLAYER_CNT];
new g_timeJoin[MAX_PLAYER_CNT], g_timeSpec[MAX_PLAYER_CNT], g_timeAFK[MAX_PLAYER_CNT], g_timeSpecQuery[MAX_PLAYER_CNT];
new g_prevCoords[MAX_PLAYER_CNT][MAX_COORD_CNT];
new g_joinImmunity[32], g_specImmunity[32], g_afkImmunity[32];

new bool:g_roundInProgress = false;

new g_cvar_joinMinPlayers, g_cvar_joinTime, g_cvar_joinImmunity;
new g_cvar_specMinPlayers, g_cvar_specTime, g_cvar_specImmunity, g_cvar_specQuery;
new g_cvar_afkMinPlayers, g_cvar_afkTime, g_cvar_afkImmunity;
new g_cvar_immunityWarning, g_cvar_warningTime;
new g_cvar_log, g_cvar_logCnt;
new g_cvar_kick2ip, g_cvar_kick2port;

public plugin_init()
{
	register_plugin(PLUGIN, RELEASE, AUTHOR);
	
	register_cvar("pbk_debug", "-1");
	register_cvar("pbk_version", RELEASE, FCVAR_SERVER|FCVAR_SPONLY);  // For GameSpy/HLSW and such

	register_dictionary("pbk.txt");
	register_dictionary("time.txt");

	register_event("ResetHUD", "event_resethud", "be");

	register_forward(FM_PlayerPostThink, "fm_playerPostThink");
	register_logevent("event_round_start", 2, "0=World triggered", "1=Round_Start");
	register_logevent("event_round_end", 2, "0=World triggered", "1=Round_End")	;
	
	g_cvar_joinMinPlayers		= register_cvar("pbk_join_min_players", "4");
	g_cvar_joinTime					= register_cvar("pbk_join_time", "120");
	g_cvar_joinImmunity			= register_cvar("pbk_join_immunity_flags", "");
	
	g_cvar_specMinPlayers		= register_cvar("pbk_spec_min_players", "4");
	g_cvar_specTime					= register_cvar("pbk_spec_time", "120");
	g_cvar_specImmunity			= register_cvar("pbk_spec_immunity_flags", "");
	g_cvar_specQuery				= register_cvar("pbk_spec_query", "0");
	
	g_cvar_afkMinPlayers		= register_cvar("pbk_afk_min_players", "4");
	g_cvar_afkTime					= register_cvar("pbk_afk_time", "90");
	g_cvar_afkImmunity			= register_cvar("pbk_afk_immunity_flags", "");

	g_cvar_immunityWarning	= register_cvar("pbk_immunity_warning", "7");
	g_cvar_warningTime 			= register_cvar("pbk_warning_time", "20");

	g_cvar_log 							= register_cvar("pbk_log", "3");
	g_cvar_logCnt 					= register_cvar("pbk_log_cnt", "2");

	g_cvar_kick2ip					= register_cvar("pbk_kick2_ip", "");
	g_cvar_kick2port				= register_cvar("pbk_kick2_port", "27015");
	
}

public plugin_cfg()
{
	new configDir[255];
	formatex(configDir[get_configsdir(configDir, sizeof(configDir)-1)], sizeof(configDir)-1, "/");
	server_cmd("exec %spbk.cfg", configDir);
	server_exec();
	
	get_pcvar_string(g_cvar_joinImmunity, g_joinImmunity, sizeof(g_joinImmunity)-1);
	get_pcvar_string(g_cvar_specImmunity, g_specImmunity, sizeof(g_specImmunity)-1);
	get_pcvar_string(g_cvar_afkImmunity, g_afkImmunity, sizeof(g_afkImmunity)-1);	

	cycle_log_files("pbk", clamp(get_pcvar_num(g_cvar_logCnt), 0, 11)); // must keep between 0 and 11 months

	register_menucmd(register_menuid("pbk_AreYouThere"), (1<<0)|(1<<1), "query_answered");
	
	set_task(float(CHECK_FREQ), "check_players", _, _, _, "b");	set_task(float(CHECK_FREQ), "check_players", _, _, _, "b");
}

public fm_playerPostThink(id)
{
	if (!g_playerJoined[id])
	{
		// if the player is on the T or CT team or is spectating, they have "fully joined"
		new team[2], teamID = get_user_team(id, team, 1);
		if (teamID == TEAM_T || teamID == TEAM_CT || team[0] == 'S') g_playerJoined[id] = true;
	}
	return PLUGIN_CONTINUE;
}

#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
	g_playerJoined[id] = false;
	g_playerSpawned[id] = false;
	
	g_timeJoin[id] = 0;
	g_timeSpec[id] = 0;
	g_timeAFK[id] = 0;
}

public event_resethud(id)
{
	if (!g_playerSpawned[id]) g_playerSpawned[id] = true;
}

public event_round_end()
{
	g_roundInProgress = false;
}

public event_round_start()
{
	// reset the coords of each player (for use in AFK checking)
	new players[32], playerCnt, id;
	get_players(players, playerCnt, "ch"); // skip bots and hltv
	
	for (new playerIdx = 0; playerIdx < playerCnt; playerIdx++)
	{
		id = players[playerIdx];
		get_user_origin(id, g_prevCoords[id], 0);
	}
	
	// note that the round has started
	g_roundInProgress = true;
}

public check_players()
{
	new playerCnt = get_playersnum();
	new team[2], eventType, curCoords[MAX_COORD_CNT], prevCoords[MAX_COORD_CNT];

	new bool:checkJoinStatus = (get_pcvar_num(g_cvar_joinTime) && playerCnt >= get_pcvar_num(g_cvar_joinMinPlayers));
	new bool:checkSpecStatus = (get_pcvar_num(g_cvar_specTime) && playerCnt >= get_pcvar_num(g_cvar_specMinPlayers));
	new bool:checkAFKStatus  = (get_pcvar_num(g_cvar_afkTime)  && playerCnt >= get_pcvar_num(g_cvar_afkMinPlayers) && g_roundInProgress);

	new players[32], id;
	get_players(players, playerCnt, "ch"); // skip bots and hltv
	
	for (new playerIdx = 0; playerIdx < playerCnt; playerIdx++)
	{
		id = players[playerIdx];

		if (g_playerJoined[id])
		{
			get_user_team(id, team, 1);
			eventType = (team[0] == 'S') ? EVENT_SPEC : EVENT_AFK;

			if (eventType == EVENT_AFK && checkAFKStatus && g_playerSpawned[id] && is_user_alive(id))
			{
				// grab the current position of the player
				get_user_origin(id, curCoords, 0);

				// compare to previous coords
				prevCoords = g_prevCoords[id];
				if (prevCoords[COORD_X] == curCoords[COORD_X] && prevCoords[COORD_Y] == curCoords[COORD_Y])
				{
					g_timeAFK[id] += CHECK_FREQ;
				}
				else
				{
					g_prevCoords[id] = curCoords;
					g_timeAFK[id] = 0;
				}
			}
			else if (eventType == EVENT_SPEC && checkSpecStatus)
			{
				g_timeSpec[id] += determine_spec_time_elapsed(id);
			}
			else continue;
		}
		else 
		{
			eventType = EVENT_JOIN;
			if (checkJoinStatus) g_timeJoin[id] += CHECK_FREQ;
			else continue;
		}
		handle_time_elapsed(id, eventType);
	}
}

determine_spec_time_elapsed(id)
{
	new timeElapsed = 0;

	if (get_pcvar_num(g_cvar_specQuery))
	{
		g_timeSpecQuery[id] += CHECK_FREQ;
		
		if (g_timeSpecQuery[id] == 45)
		{
			display_spec_query(id);
		}
		else if (g_timeSpecQuery[id] >= 55)
		{
			timeElapsed = g_timeSpecQuery[id] - CHECK_FREQ;
			g_timeSpecQuery[id] = CHECK_FREQ;
		}
	}
	else
	{	
		timeElapsed = CHECK_FREQ;
	}

	return timeElapsed;
}

display_spec_query(id)
{
	new query[192];
	formatex(query, sizeof(query)-1, "\r%L\R^n^n\y1.\w %L^n\y2.\w %L", id, "KICK_SPEC_AREYOUTHERE", id, "YES", id, "NO");
	show_menu(id, (1<<0)|(1<<1), query, 4, "pbk_AreYouThere");
}

public query_answered(id, key)
{
	//g_timeSpec[id] -= g_timeSpecQuery[id];
	g_timeSpecQuery[id] = 0;
}

public handle_time_elapsed(id, eventType)
{
	new warningFlag = get_pcvar_num(g_cvar_immunityWarning);
	new maxSeconds, elapsedSeconds, eventImmunity, showWarning;
	if (eventType == EVENT_JOIN)
	{
		maxSeconds = get_pcvar_num(g_cvar_joinTime);
		elapsedSeconds = g_timeJoin[id];
		eventImmunity = has_flag(id, g_joinImmunity);
		showWarning = eventImmunity ? warningFlag & EVENT_JOIN : 1;
	}
	else if (eventType == EVENT_SPEC)
	{
		maxSeconds = get_pcvar_num(g_cvar_specTime);
		elapsedSeconds = g_timeSpec[id];
		eventImmunity = has_flag(id, g_specImmunity);
		showWarning = eventImmunity ? warningFlag & EVENT_SPEC : 1;
	}
	else if (eventType == EVENT_AFK)
	{
		maxSeconds = get_pcvar_num(g_cvar_afkTime);
		elapsedSeconds = g_timeAFK[id];
		eventImmunity = has_flag(id, g_afkImmunity);
		showWarning = eventImmunity ? warningFlag & EVENT_AFK : 1;
	}
	else return;
	
	new warningStartSeconds = maxSeconds - get_pcvar_num(g_cvar_warningTime);
	
	if (elapsedSeconds >= maxSeconds) 
	{
		// if players have immunity for this event abort
		if (eventImmunity) return;

		// get the correct message formats for this event type
		new msgReason[32], msgAnnounce[32];
		switch (eventType)
		{
			case EVENT_JOIN:
			{
				copy(msgReason, 31, "KICK_JOIN_REASON");
				copy(msgAnnounce, 31, "KICK_JOIN_ANNOUNCE");
			}
			case EVENT_SPEC:
			{
				copy(msgReason, 31, "KICK_SPEC_REASON");
				copy(msgAnnounce, 31, "KICK_SPEC_ANNOUNCE");
			}
			case EVENT_AFK:
			{
				copy(msgReason, 31, "KICK_AFK_REASON");
				copy(msgAnnounce, 31, "KICK_AFK_ANNOUNCE");
			}
		}

		new maxTime[128];
		get_time_length(id, maxSeconds, timeunit_seconds, maxTime, 127);

		new kick2ip[32];
		get_pcvar_string(g_cvar_kick2ip, kick2ip, sizeof(kick2ip)-1);

		if (kick2ip[0] != 0 && eventType == EVENT_AFK)
		{
			// set the user spectator
			user_kill(  id,  1  ) //added by me
			cs_set_user_team(id, CS_TEAM_SPECTATOR)
		}
		else
		{

			// kick the player into the nether
			server_cmd("kick #%d %L", get_user_userid(id), id, msgReason, maxTime);
		}

		// announce the kick to the rest of the world
		new players[32], playerCnt;
		get_players(players, playerCnt, "c");
		new playerName[32];
		get_user_name(id, playerName, 31);
		new playerID;

		for (new playerIdx = 0; playerIdx < playerCnt; playerIdx++)
		{
			playerID = players[playerIdx];
			get_time_length(playerID, maxSeconds, timeunit_seconds, maxTime, 127);
			client_print(playerID, print_chat, "[PBK] %L", playerID, msgAnnounce, playerName, maxTime);
		}

		// log the kick
		new logFlags = get_pcvar_num(g_cvar_log);
		if (logFlags)
		{
			get_time_length(0, maxSeconds, timeunit_seconds, maxTime, 127);
			
			new logText[128];
			format(logText, 127, "%L", LANG_SERVER, msgAnnounce, "", maxTime);
			// remove the single space that not providing a name added
			trim(logText);
			
			create_log_entry(id, "PBK", logFlags, logText);
		}
	}
	else if (warningStartSeconds <= elapsedSeconds && showWarning)
	{
		// get the correct message format for this event type
		new msgWarning[32];
		switch (eventType)
		{
			case EVENT_JOIN: copy(msgWarning, 31, "KICK_JOIN_WARNING");
			case EVENT_SPEC: copy(msgWarning, 31, "KICK_SPEC_WARNING");
			case EVENT_AFK:  copy(msgWarning, 31, "KICK_AFK_WARNING");
		}
		
		new timeLeft[128]
		get_time_length(id, maxSeconds - elapsedSeconds, timeunit_seconds, timeLeft, 127);

		// warn the user about their impending departure
		client_print(id, print_chat, "[PBK] %L", id, msgWarning, timeLeft);
	} 
}