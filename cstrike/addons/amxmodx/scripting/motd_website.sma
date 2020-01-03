#include <amxmodx>
#include <amxmisc>

new cvar_website;

new g_mapname[64];

public plugin_init()
{
    register_plugin("MOTD Website", "0.1", "Exolent & mo0n_sniper");
    
    register_clcmd("say /top15", "CmdMotd");
    register_clcmd("say_team /top15", "CmdMotd");
    
    cvar_website = register_cvar("motd_website", "http://miez.ro/cstrike/HLstatsX/top15.php");
    
    get_mapname(g_mapname, sizeof(g_mapname) - 1);
}

public CmdMotd(client)
{
    new website[128];
    get_pcvar_string(cvar_website, website, sizeof(website) - 1);
    
    replace(website, sizeof(website) - 1, "%map%", g_mapname);
    
    new motd[256];
    formatex(motd, sizeof(motd) - 1,\
        "<html><head><meta http-equiv=^"Refresh^" content=^"0;url=%s^"></head><body style=^"background-color: #000000^"><p><center><font color=^"#FFB000^">LOADING...</font></center></p></body></html>",\
            website);
    
    show_motd(client, motd);
}