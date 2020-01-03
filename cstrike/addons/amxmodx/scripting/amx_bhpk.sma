/*	AMX Mod script

	Better High Ping Kicker (c) 2009-11 by Lev
	This file is provided as is (no warranties).

	URL: http://forums.alliedmods.net/showthread.php?t=85911

	This is mainly a modification of HPK by DynAstY.
	Thanks to all other HPK authors (OLO, DynAstY, shadow, EKS) - your plugins provided the base.

	Features:
		Players with immunity and slot reservations won't be checked.
		At night max ping defined by different CVAR (so usually it will be higher).
		By default keeps min 3 players (bots and HLTVs are not included) at server if they are not exceed night max ping twice.
		Player is banned for 1 minute, not just simply kicked.

	CVARs (Supplied values are defaults):
		hpk_ping_max 175 ; maximum ping to check for at day time
		hpk_ping_max_night 300 ; maximum ping to check for at night time
		hpk_ping_time 10 ; interval at which ping will be checked
		hpk_ping_tests 5 ; number of violations of maximum ping at which to kick
		hpk_min_players 3 ; don't kick player if there is this count or less players (bots and hltv are not included) at server and player's ping doesn't exceed night ping twice.
		hpk_night_start_hour 3 ; night period start hour (hour included)
		hpk_night_end_hour 9 ; night period end hour (hour excluded)

	How it is different from other HPK plugins:
		using pointers to CVARs;
		code flow is optimized;
		there is night period when ping defined by different CVAR, period also defined by CVARs;
		changes to max pings applies immediately;
		immunity for admins and slot reservations players;
		keeps min players at server (count defined by CVAR) if their ping is not too high (double night max ping);

	ChangeLog:
		v2.4 [2009.03.01]
			Initial release.
		v2.5 [2009.10.02]
			! Change: bots and hltv are now excluded from players count for comparison with hpk_min_players.
		v2.6 [2009.10.10]
			! Change: changed from ban ID to ban IP.
		v2.7 [2011.06.16]
			! New: added logging of kicks to amxx log.
			! Change: disconnect changed to server side kick.
*/

#pragma semicolon 1
#pragma ctrlchar '\'

#include <amxmodx>
#include <amxmisc>

#define AUTHOR "Lev & mo0n_sniper"
#define PLUGIN "MIEZ - BHPK"
#define VERSION "2.7"
#define VERSION_CVAR "bhpk_version"

#define ALWAYS_KICK_MULTIPLIER 1		// Player will be kicked even there is less then or equal min_players if player's ping exceed night max ping by this factor.
#define DELAY_BEFORE_START_TESTING 20.0	// Delay before showing warning and start ping checking. Real testing starts after hpk_ping_time also passed.

const TASK_ID_BASE = 52635;	// random number

const min_hpk_ping_max = 10;
const min_hpk_ping_time = 10;
const min_hpk_ping_tests = 4;

new pcvar_hpk_ping_max;
new pcvar_hpk_ping_max_night;
new pcvar_hpk_ping_time;
new pcvar_hpk_ping_tests;
new pcvar_hpk_min_players;
new pcvar_hpk_night_start_hour;
new pcvar_hpk_night_end_hour;

new ping_violations[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_cvar(VERSION_CVAR, VERSION, FCVAR_SERVER);

	pcvar_hpk_ping_max = register_cvar("hpk_ping_max", "175");
	pcvar_hpk_ping_max_night = register_cvar("hpk_ping_max_night", "300");
	pcvar_hpk_ping_time = register_cvar("hpk_ping_time", "10");
	pcvar_hpk_ping_tests = register_cvar("hpk_ping_tests", "5");
	pcvar_hpk_min_players = register_cvar("hpk_min_players", "3");
	pcvar_hpk_night_start_hour = register_cvar("hpk_night_start_hour", "3");
	pcvar_hpk_night_end_hour = register_cvar("hpk_night_end_hour", "9");
}
	
public client_putinserver(plrid)
{
	ping_violations[plrid] = 0;
	if (!is_user_bot(plrid) && !is_user_hltv(plrid))
		set_task(DELAY_BEFORE_START_TESTING, "showInfo", TASK_ID_BASE + plrid);
	return PLUGIN_CONTINUE;
}

public client_infochanged(plrid)
{
	remove_task(TASK_ID_BASE + plrid);
	if (!is_user_bot(plrid) && !is_user_hltv(plrid))
		set_task(DELAY_BEFORE_START_TESTING, "showInfo", TASK_ID_BASE + plrid);
	return PLUGIN_CONTINUE;
}

#if AMXX_VERSION_NUM < 183
public client_disconnect(plrid)
#else
public client_disconnected(plrid)
#endif
{
	remove_task(TASK_ID_BASE + plrid);
	return PLUGIN_CONTINUE;
}

public showInfo(taskid)
{
	new plrid = taskid - TASK_ID_BASE;
	if (access(plrid, ADMIN_IMMUNITY) || access(plrid, ADMIN_RESERVATION))
		//client_print(plrid, print_chat, "[BHPK] Ping checking disabled due to immunity...");
		return PLUGIN_CONTINUE;
	else
	{
		//client_print(plrid, print_chat, "[BHPK] Players with ping higher than %dms will be kicked!", get_hpk_ping_max());
		set_task(float(get_hpk_ping_time()), "checkPing", TASK_ID_BASE + plrid, _, _, "b");
	}
	return PLUGIN_CONTINUE;
}

public checkPing(taskid)
{
	new plrid = taskid - TASK_ID_BASE;
	new ping, loss;

	get_user_ping(plrid, ping, loss);

	if (ping > get_hpk_ping_max()) ping_violations[plrid]++;
	else if (ping_violations[plrid] > 0) ping_violations[plrid]--;

	new hpk_ping_tests = get_hpk_ping_tests();
	if (ping_violations[plrid] >= hpk_ping_tests)
	{
		static players[32];
		new playerCount;
		get_players(players, playerCount, "ch");
		// Allow player to stay if there is less or equal than 'min_players' players and player ping is not too high.
		if (playerCount <= get_pcvar_num(pcvar_hpk_min_players) && 
			ping < get_pcvar_num(pcvar_hpk_ping_max_night) * ALWAYS_KICK_MULTIPLIER)
		{
			ping_violations[plrid] = hpk_ping_tests;
			return PLUGIN_CONTINUE;
		}
		kickPlayer(plrid, ping);
	}

	return PLUGIN_CONTINUE;
}

kickPlayer(plrid, ping)
{
	new name[33], ip[15];
	new userid = get_user_userid(plrid);
	get_user_ip(plrid, ip, charsmax(ip), 1);
	get_user_name(plrid, name, charsmax(name));

	server_cmd("kick #%d \"[BHPK] Sorry but you have high ping, try later...\"; addip 1 \"%s\"", userid, ip);
	client_print(0, print_chat, "[BHPK] %s was disconnected due to high ping!", name);
	log_amx("\"%s\" was kicked due to high ping (%dms).", name, ping);
	return PLUGIN_CONTINUE;
} 

get_hpk_ping_max()
{
	new ping_max;
	new hour, minute, second;

	time(hour, minute, second);

	// At night we use different CVAR
	if (hour >= get_pcvar_num(pcvar_hpk_night_start_hour) && 
		hour < get_pcvar_num(pcvar_hpk_night_end_hour))
		ping_max = get_pcvar_num(pcvar_hpk_ping_max_night);
	else 
		ping_max = get_pcvar_num(pcvar_hpk_ping_max);
	// Check to be no less then minimum value
	if (ping_max < min_hpk_ping_max) return min_hpk_ping_max;
	return ping_max;
}
get_hpk_ping_time()
{
	new time = get_pcvar_num(pcvar_hpk_ping_time);
	// Check to be no less then minimum value
	if (time < min_hpk_ping_time) return min_hpk_ping_time;
	return time;
}
get_hpk_ping_tests()
{
	new tests = get_pcvar_num(pcvar_hpk_ping_tests);
	// Check to be no less then minimum value
	if (tests < min_hpk_ping_tests) return min_hpk_ping_tests;
	return tests;
}
