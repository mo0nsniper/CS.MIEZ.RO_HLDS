#include <amxmodx>
#include <amxmisc>

new cvar_top;
new cvar_rules;
new cvar_comenzi;

public plugin_init()
{
    register_plugin("MOTD Website", "0.1", "Exolent & mo0n_sniper");
    
    register_clcmd("say /top15", "CmdTop");
    register_clcmd("say_team /top15", "CmdTop");
    
    register_clcmd("say /regulament", "CmdRules");
    register_clcmd("say_team /regulament", "CmdRules");
	
    register_clcmd("say /comenzi", "CmdComenzi");
    register_clcmd("say_team /comenzi", "CmdComenzi");
    
    cvar_top		= register_cvar("motd_top", "http://miez.ro/cstrike/HLstatsX/top15.php");
    cvar_rules		= register_cvar("motd_rules", "http://miez.ro/forum/viewtopic.php?f=4&t=2");
    cvar_comenzi	= register_cvar("motd_comenzi", "http://miez.ro/forum/viewtopic.php?f=14&t=1130&p=7003#p7003");
    
}

public CmdTop(client)
{
    new website[128];
    get_pcvar_string(cvar_top, website, sizeof(website) - 1);
    
    new motd[256];
    formatex(motd, sizeof(motd) - 1,\
        "<html><head><meta http-equiv=^"Refresh^" content=^"0;url=%s^"></head><body style=^"background-color: #000000^"><p><center><font color=^"#FFB000^">LOADING...</font></center></p></body></html>",\
            website);
    
    show_motd(client, motd);
}

public CmdRules(client)
{
    new website[128];
    get_pcvar_string(cvar_rules, website, sizeof(website) - 1);
    
    new motd[256];
    formatex(motd, sizeof(motd) - 1,\
        "<html><head><meta http-equiv=^"Refresh^" content=^"0;url=%s^"></head><body style=^"background-color: #000000^"><p><center><font color=^"#FFB000^">LOADING...</font></center></p></body></html>",\
            website);
    
    show_motd(client, motd);
}

public CmdComenzi(client)
{
    new website[128];
    get_pcvar_string(cvar_comenzi, website, sizeof(website) - 1);
    
    new motd[256];
    formatex(motd, sizeof(motd) - 1,\
        "<html><head><meta http-equiv=^"Refresh^" content=^"0;url=%s^"></head><body style=^"background-color: #000000^"><p><center><font color=^"#FFB000^">LOADING...</font></center></p></body></html>",\
            website);
    
    show_motd(client, motd);
}
