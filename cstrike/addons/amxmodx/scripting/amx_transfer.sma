/*************************************************************************************************
*
*   AMX Transfer (from amx_super.sma)
*   Copyright (C) AMX Mod X Team
*
*   This program is free software; you can redistribute it and/or
*   modify it under the terms of the GNU General Public License
*   as published by the Free Software Foundation; either version 2
*   of the License, or (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program; if not, write to the Free Software
*   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*
*   In addition, as a special exception, the author gives permission to
*   link the code of this program with the Half-Life Game Engine ("HL
*   Engine") and Modified Game Libraries ("MODs") developed by Valve,
*   L.L.C ("Valve"). You must obey the GNU General Public License in all
*   respects for all of the code used other than the HL Engine and MODs
*   from Valve. If you modify this file, you may extend this exception
*   to your version of the file, but you are not obligated to do so. If
*   you do not wish to do so, delete this exception statement from your
*   version.
*
**************************************************************************************************
*
*   Link of plugin: http://forums.alliedmods.net/showthread.php?p=810784
*   Link for AMX Super: http://forums.supercentral.net/index.php?showtopic=20
*
**************************************************************************************************
*   I take no credit for this plugin as I didn't created !
*   I just toked it out from AMX_SUPER and make it work !
*
*   The real plugin included in amx_super was created like follows
*
*   ADMIN TRANSFER v1.0 by Deviance - Transfer players to diff teams, swap teams, and swap players
*
**************************************************************************************************/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <hamsandwich>


#define VERSION "1.2"

new amx_show_activity
new TEAM_INVALID[] = "TEAM_INVALID"


public plugin_init() 
{
	/* Register plugin and author */
	register_plugin("AMX Transfer", VERSION, "Deviance")
	
	/* Register plugin version by cvar */
	register_cvar("transfer_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	set_cvar_string("transfer_version", VERSION);
	
	/* Register admin commands */
	register_concmd("amx_transfer", "cmd_transfer", ADMIN_SLAY,"- <name> <CT/T/Spec> Transfers that player to the specified team")
	register_concmd("amx_team", "cmd_transfer", ADMIN_SLAY,"- <name> <CT/T/Spec> Transfers that player to the specified team")
	register_concmd("amx_swap", "cmd_swap", ADMIN_SLAY,"- <name 1> <name 2> Swaps two players with eachother")
	register_concmd("amx_teamswap", "cmd_teamswap", ADMIN_SLAY,"- Swaps two teams with eachother") 
	
	/* Register plugin cvars */
	amx_show_activity = get_cvar_pointer("amx_show_activity");
	
	/* Register language file */
	register_dictionary("amx_transfer.txt")
	
}

public cmd_transfer(id,level,cid)
{
	
	if(!cmd_access(id, level, cid, 2)) 
		return PLUGIN_HANDLED;
	
	new arg1[32], arg2[32]
	
	read_argv(1, arg1, 31)
	read_argv(2, arg2, 31)
	
	new player = cmd_target(id, arg1, 2)
	
	if(!player)
		return PLUGIN_HANDLED
	
	new teamname[32]
	
	if(!strlen(arg2))
	{
		cs_set_user_team(player, cs_get_user_team(player) == CS_TEAM_CT ? CS_TEAM_T:CS_TEAM_CT)
		teamname = cs_get_user_team(player) == CS_TEAM_CT ? "Counter-Terrorists":"Terrorists"
	}
	else
	{
		if(equali(arg2, "T"))
		{
			cs_set_user_team(player, CS_TEAM_T)
			teamname = "Terrorists"
			ExecuteHamB(Ham_CS_RoundRespawn, player)
		}
		else if(equali(arg2, "CT"))
		{
			cs_set_user_team(player, CS_TEAM_CT)
			teamname = "Counter-Terrorists"
			ExecuteHamB(Ham_CS_RoundRespawn, player)
		}
		else if(equali(arg2, "SPEC"))
		{
			user_silentkill(player)
			cs_set_user_team(player, CS_TEAM_SPECTATOR)
			teamname = "Spectator"
		}
		else
		{
			client_print(id, print_console, "%L", id, TEAM_INVALID)
			return PLUGIN_HANDLED
		}
	}
	
	new name[32], admin[32], authid[35]
	
	get_user_name(id, admin, 31)
	get_user_name(player, name, 31)
	get_user_authid(id, authid, 34)
	
	switch(get_pcvar_num(amx_show_activity)) 
	{
		case 2:	client_print(0, print_chat, "%L", LANG_PLAYER, "TRANSFER_PLAYER_CASE2", admin, name, teamname)
		case 1:	client_print(0, print_chat, "%L", LANG_PLAYER, "TRANSFER_PLAYER_CASE1", name, teamname)
	}
	
	client_print(player, print_chat, "%L", LANG_PLAYER, "TRANSFER_PLAYER_TEAM", teamname)
	
	console_print(id, "%L", id, "TRANSFER_PLAYER_CONSOLE", name, teamname)
	log_amx("%L", LANG_SERVER, "TRANSFER_PLAYER_LOG", admin, authid, name, teamname)
	return PLUGIN_HANDLED
	
}
public cmd_swap(id, level, cid) 
{
	if (!cmd_access(id, level, cid, 3))
	return PLUGIN_HANDLED
	
	new arg1[32], arg2[32]
	
	read_argv(1, arg1, 31)
	read_argv(2, arg2, 31)
	
	new player = cmd_target(id, arg1, 2)
	new player2 = cmd_target(id, arg2, 2)
	
	if(!player || !player2)
	return PLUGIN_HANDLED
	
	new CsTeams:team = cs_get_user_team(player)
	new CsTeams:team2 = cs_get_user_team(player2)
	
	if(team == team2)
	{
		client_print(id, print_console, "%L", id, "TRANSFER_PLAYER_ERROR_CASE1")
		return PLUGIN_HANDLED
	}
	
	if(team == CS_TEAM_UNASSIGNED || team2 == CS_TEAM_UNASSIGNED)
	{
		client_print(id, print_console, "%L", id, "TRANSFER_PLAYER_ERROR_CASE2")
		return PLUGIN_HANDLED
	}
	
	if(team == CS_TEAM_SPECTATOR)
		user_silentkill(player2)
	
	else if(team2 == CS_TEAM_SPECTATOR)
		user_silentkill(player)
	
	cs_set_user_team(player, team2)
	ExecuteHamB(Ham_CS_RoundRespawn, player)
	
	cs_set_user_team(player2, team)
	ExecuteHamB(Ham_CS_RoundRespawn, player2)
	
	new name[32], name2[32], admin[32], authid[35]
	
	get_user_name(id, admin, 31)
	get_user_name(player, name, 31)
	get_user_name(player2, name2, 31)
	
	get_user_authid(id, authid, 34)
	
	switch(get_pcvar_num(amx_show_activity)) {
		case 2:	client_print(0, print_chat,"%L", LANG_PLAYER, "TRANSFER_SWAP_PLAYERS_SUCCESS_CASE2",admin,name,name2)
		case 1:	client_print(0, print_chat,"%L", LANG_PLAYER, "TRANSFER_SWAP_PLAYERS_SUCCESS_CASE1", name, name2);
	}

	client_print(player, print_chat,"%L", player, "TRANSFER_SWAP_PLAYERS_MESSAGE1", name2)
	client_print(player2, print_chat,"%L", player2, "TRANSFER_SWAP_PLAYERS_MESSAGE2", name)

	client_print(id, print_console,"%L", id, "TRANSFER_SWAP_PLAYERS_CONSOLE", name, name2)
	log_amx("%L", LANG_PLAYER, "TRANSFER_SWAP_PLAYERS_LOG", admin, authid, name, name2)
	
	return PLUGIN_HANDLED
}

public cmd_teamswap(id, level, cid) 
{
	if (!cmd_access(id, level, cid, 1))
	return PLUGIN_HANDLED

	new players[32], num
	get_players(players, num)
	
	new player
	for(new i = 0; i < num; i++)
	{
		player = players[i]
		cs_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? CS_TEAM_CT:CS_TEAM_T)
	}
	
	new name[32], authid[35]
	
	get_user_name(id, name, 31)
	get_user_authid(id, authid, 34)

	switch(get_pcvar_num(amx_show_activity)) {
		case 2:	client_print(0, print_chat,"%L", LANG_PLAYER, "TRANSFER_SWAP_TEAM_SUCCESS_CASE2",name)
		case 1:	client_print(0, print_chat,"%L", LANG_PLAYER, "TRANSFER_SWAP_TEAM_SUCCESS_CASE1")
	}

	console_print(id,"%L", LANG_PLAYER, "TRANSFER_SWAP_TEAM_MESSAGE")
	log_amx("%L", LANG_SERVER, "TRANSFER_SWAP_TEAM_LOG", name,authid)
	
	return PLUGIN_HANDLED
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
