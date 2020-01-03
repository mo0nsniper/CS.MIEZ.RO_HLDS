#include < amxmodx >
#include < amxmisc >
#include < cstrike >
#include < fun >


#pragma semicolon 1

#define PLUGIN "MIEZ - amx_ss"
#define VERSION "2.1"

#define SS_ACCESS	ADMIN_SLAY

enum
{
	
	INFO_NAME,
	INFO_IP,
	INFO_AUTHID
	
};

new const szTag[    ]  =  "";
new const szSite[    ]  =  "http://MIEZ.ro/forum";

new gCvarMoveSpec;
new gCvarAdminSpec;
new gCvarTiff;

public plugin_init( )
{
	// Idee plugin si primul care l-a publicat: ThE_ChOSeN_OnE
	// Acest cod este scris de mine in totalitate.. si modificat de mo0n_sniper :)
	register_plugin( PLUGIN, VERSION, "Askhanar & mo0n_sniper" );
	
	gCvarMoveSpec  =  register_cvar(  "ss_move_spec",  "0"  );
	gCvarAdminSpec =  register_cvar(  "ss_admin_spec",  "0"  );
	gCvarTiff =       register_cvar(  "ss_tiff",  "1"  );
	register_clcmd(  "amx_ss", "ClCmdSS"  );
	
}

public ClCmdSS(  id  )
{
	if(  !(  get_user_flags(  id  )  &  SS_ACCESS  )  )
	{
		client_cmd(  id, "echo %s Nu ai acces la aceasta comanda!", szTag  );
		return 1;
	}
	
	new szFirstArg[ 32 ];
	read_argv(  1,  szFirstArg, sizeof ( szFirstArg ) -1  );
	
	if(  equal(  szFirstArg, ""  )  )
	{
		client_cmd(  id, "echo amx_ss < nume > faci o poza semnata!"  );
		return 1;
	}
	
	new iPlayer  =  cmd_target(  id,  szFirstArg,  8  );
	
	if( !iPlayer  )
	{
		client_cmd(  id, "echo %s Jucatorul specificat nu a fost gasit!", szTag  );
		return 1;
	}
	
	if( !is_user_alive(  iPlayer  ) )
	{
		client_cmd(  id, "echo %s Jucatorul %s nu este in viata !", szTag, GetInfo(  iPlayer, INFO_NAME  )  );
		return 1;
	}
	
	if( get_pcvar_num(  gCvarAdminSpec  )  )
		if(  cs_get_user_team(  id  )  !=  CS_TEAM_SPECTATOR  )
			{
			client_cmd(  id, "echo %s Trebuie sa fi Spectator ca sa poti face o poza!", szTag  );
			return 1;
			}

	
	
	log_to_file ( "amx_ss.log", "Adminul %s a folosit amx_ss pe: %s, SteamID: %s, IP: %s", GetInfo(  id,  INFO_NAME  ), GetInfo(  iPlayer,  INFO_NAME  ), GetInfo(  iPlayer,  INFO_AUTHID  ), GetInfo(  iPlayer, INFO_IP  ) );
			
	client_print(id,print_console,"");
	client_print(id,print_console,"=========================================================");
	client_print(id,print_console,"Screenshot lui: %s | SteamID: %s | IP: %s", GetInfo(  iPlayer,  INFO_NAME  ), GetInfo(  iPlayer,  INFO_AUTHID  ), GetInfo(  iPlayer, INFO_IP  ) );
	client_print(id,print_console,"=========================================================");
	client_print(id,print_console,"");
	
	client_print(  0 ,  print_console,  "%s Adminul %s i-a facut o poza lui %s !",  szTag,  GetInfo(  id,  INFO_NAME  ),  GetInfo(  iPlayer,  INFO_NAME  )  );
	
	client_print_color(  0 ,  -2,  "^x04%s^x01 Adminul ^x04%s^x01 i-a facut o poza lui^x03 %s^x01 !",  szTag,  GetInfo(  id,  INFO_NAME  ),  GetInfo(  iPlayer,  INFO_NAME  )  );
	
	client_print_color(  iPlayer, -3, "^x04%s^x01 SteamID:^x03 %s^x01 | IP:^x03 %s", szTag, GetInfo(  iPlayer,  INFO_AUTHID  ), GetInfo(  iPlayer, INFO_IP  )  );
	client_print_color(  iPlayer, -3, "^x04%s^x01 Data/Ora:^x03 %s", szTag, _get_time(    )  );
	client_print_color(  iPlayer, -3, "^x04%s^x01 Site ^x03%s", szTag, szSite  );
	client_print(  iPlayer,  print_center,  "Screenshot"  );
	
	client_print(  iPlayer,  print_console,  "");
	client_print(  iPlayer,  print_console,  "=========================================================");
	client_print(  iPlayer,  print_console,  " %s Data/Ora: %s", szTag, _get_time(    )  );
	client_print(  iPlayer,  print_console,  " %s Site %s", szTag, szSite  );
	client_print(  iPlayer,  print_console,  "=========================================================");
	client_print(  iPlayer,  print_console,  " Poza se numeste:     HalfLifeXX.tga      !!!");
	client_print(  iPlayer,  print_console,  " Poza o gasesti in directorul:");
	client_print(  iPlayer,  print_console,  " Steam\steamapps\common\Half-Life\cstrike");
	client_print(  iPlayer,  print_console,  "=========================================================");
	client_print(  iPlayer,  print_console,  "=========================================================");
	client_print(  iPlayer,  print_console,  "");
	client_print(  iPlayer,  print_console,  " %s Adminul %s ti-a facut o poza !!!", szTag, GetInfo(  id,  INFO_NAME  )  );
	client_print(  iPlayer,  print_console,  "");
	client_print(  iPlayer,  print_console,  "=========================================================");
	client_print(  iPlayer,  print_console,  "=========================================================");
	client_print(  iPlayer,  print_console,  "");
	
	set_task(  0.2, "MZ_ss", iPlayer );
	
	return 0;

}

public MZ_ss(  iPlayer  )
{
	
	if( get_pcvar_num(  gCvarTiff  )  )
	{
		client_cmd(  iPlayer,  "toggleconsole;screenshot;toggleconsole;toggleconsole;say ScreenShot_Terminat"  );
	}
	else
	{
		client_cmd(  iPlayer,  "toggleconsole;snapshot;toggleconsole;toggleconsole;say ScreenShot_Terminat"  );
	}
	
	if( get_pcvar_num(  gCvarMoveSpec  )  )
		set_task(  2.0, "MoveSpec", iPlayer  );
	
	return 0;
	
}

public MoveSpec(  iPlayer  )
{

	if(  !is_user_connected( iPlayer )  )	return 1;
	
	user_kill(  iPlayer,  1  );
	cs_set_user_team(  iPlayer,  CS_TEAM_SPECTATOR  );
	
	return 0;
	
}
	
stock GetInfo( id, const iInfo )
{
	
	new szInfoToReturn[  64  ];
	
	switch(  iInfo  )
	{
		case INFO_NAME:
		{
			new szName[ 32 ];
			get_user_name(  id,  szName,  sizeof ( szName ) -1  );
			
			copy(  szInfoToReturn,  sizeof ( szInfoToReturn ) -1,  szName  );
		}
		case INFO_IP:
		{
			new szIp[ 32 ];
			get_user_ip(  id,  szIp,  sizeof ( szIp ) -1,  1  );
			
			copy(  szInfoToReturn,  sizeof ( szInfoToReturn ) -1,  szIp  );
		}
		case INFO_AUTHID:
		{
			new szAuthId[ 35 ];
			get_user_authid(  id,  szAuthId,  sizeof ( szAuthId ) -1  );
			
			copy(  szInfoToReturn,  sizeof ( szInfoToReturn ) -1,  szAuthId  );
		}
	}

	return szInfoToReturn;
}

stock _get_time( )
{
	new logtime[ 32 ];
	get_time("%d.%m.%Y - %H:%M:%S", logtime ,sizeof ( logtime ) -1 );
	
	return logtime;
}