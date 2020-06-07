#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>

#define PLUGIN "Spec Switch"
#define VERSION "0.1.3"
#define AUTHOR "many & mo0n_sniper"

new g_cvar

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_cvar	= register_cvar("amx_specmode",	"0") 	// 0 - enable use to all, 1 - enable use only ADMINs
	
	register_clcmd("say /spec", 		"cmdSpec", ADMIN_ALL, "- go to spectator")
	register_clcmd("say_team /spec", 	"cmdSpec", ADMIN_ALL, "- go to spectator")
}

public cmdSpec(id)
{
	if(!get_pcvar_num(g_cvar)) Spec(id)
	else if( get_pcvar_num(g_cvar) && (get_user_flags(id) & ADMIN_KICK)) Spec(id)
	else if( get_pcvar_num(g_cvar) && !(get_user_flags(id) & ADMIN_KICK)) client_print(id,print_chat,"Doar adminii pot folosi comanda /spec")
}

public Spec(id)
{
	if (cs_get_user_team(id) == CS_TEAM_SPECTATOR)
	return
	else{
		cs_set_user_team(id, CS_TEAM_SPECTATOR)
		user_silentkill(id)
	}
	return
}