#include <amxmodx>
#include <sockets>

#define TIMER_TASK 32490283094

new g_hltv_id, g_realplayersnum, g_hltv_recording, g_hltv_ip[16], g_hltv_port, g_ignorebots, g_messages, bool:g_mapchange
new g_hltvrec_cvar, g_hltvpath_cvar, g_minplayers_cvar, g_hltvpassword_cvar, g_ignorebots_cvar, g_recording_cvar, g_messages_cvar	//, g_challenge_cvar
new g_hltv_challenge[13], g_show_time	// Contains the hltv rcon challenge number
new bool:g_challenging_rcon, g_autodelay_cvar

public plugin_init()
{
	register_plugin("HLTV AutoRecord", "1.7", "Dr.Aft & mo0n_sniper")
	g_hltvrec_cvar = register_cvar("autohltv_record", "1")	// enable plugin
	
	// recording will be into cstrike/demos/HLTV-datetime.dem
	g_hltvpath_cvar = register_cvar("autohltv_path", "demos/HLTV")	

	// ignore bots as real players
	g_ignorebots_cvar = register_cvar("autohltv_ignorebots", "1")
	g_ignorebots = get_pcvar_num(g_ignorebots_cvar)
	
	// minimal players to start record, when it will be 1 player, recording will be stopped
	g_minplayers_cvar = register_cvar("autohltv_minplayers", "2")
	
	// This is fix if hltv is already recording, server can crash if we send the socket command again
	g_recording_cvar = register_cvar("autohltv_recording", "0", FCVAR_SERVER|FCVAR_SPONLY)
	if(get_pcvar_num(g_recording_cvar))
		g_hltv_recording = 4
	
	//g_challenge_cvar = register_cvar("autohltv_challenge", "", FCVAR_SPONLY|FCVAR_PROTECTED|FCVAR_UNLOGGED)
	
	// adminpassword for hltv
	g_hltvpassword_cvar = register_cvar("autohltv_pass", "hltvadminpass")
	g_autodelay_cvar = register_cvar("autohltv_delay", "30.0")
	
	register_cvar("autohltv_time", "2")		// 2 - time for everyone, 1 - only to hltv, 0 - disabled
	switch(get_cvar_num("autohltv_time"))
	{
		case 0:	g_show_time = -2
		case 1: g_show_time	= -1		
	}
	set_task(180.0, "prepare_for_mapchange", 0, _ , _ , "d")
	set_task(1.0, "mapchange", 0, _ , _ , "d")
	
	// show chat messages
	g_messages_cvar = register_cvar("autohltv_messages", "0")
	g_messages = get_pcvar_num(g_messages_cvar)


}

public client_putinserver(id)
{
	if(g_mapchange)
		return PLUGIN_CONTINUE
	
	if(is_user_bot(id))
		if(g_ignorebots)
			return PLUGIN_CONTINUE
		
	if(is_user_hltv(id))	
	{
		if(g_hltv_id == 0)
		{
			g_hltv_id = id
			if(g_show_time > -2)
			{			
				if(g_show_time == -1)
					g_show_time = g_hltv_id
				
				if(g_hltv_recording == 4)
					set_task(1.0, "hltv_show_time", TIMER_TASK, _, _, "b")
			}			
		}
		
		new hltv_ipport[32]
		get_user_ip(g_hltv_id, hltv_ipport, 31)
		
		strtok(hltv_ipport, g_hltv_ip, 16, hltv_ipport, 5, ':')
		g_hltv_port = str_to_num(hltv_ipport)
		check_stop_record()
	}
	else
		g_realplayersnum++	
	
	
	if(g_hltv_id > 0)
	{
		if(g_realplayersnum >= get_pcvar_num(g_minplayers_cvar))
		{
			if(get_pcvar_num(g_hltvrec_cvar) && g_hltv_recording < 3)
			{
				set_task(1.0, "hltv_start_record")				
				g_hltv_recording = 3
			}
		}
		
	}
	return PLUGIN_CONTINUE
}

#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
	if( (!is_user_bot(id) || !g_ignorebots) && !g_mapchange)		
	{
		if(id == g_hltv_id)
		{			
			g_hltv_id = 0			
			set_task(15.0, "flush_hltv")
			hltv_freehandle_challenge()
		}
		else
		{
			g_realplayersnum--
			check_stop_record()
		}
	}
}


public flush_hltv()
{
	//set_pcvar_string(g_challenge_cvar, "^0")
	set_pcvar_num(g_recording_cvar, 0)
	g_hltv_recording = 0
	g_hltv_challenge = ""
	
	if(g_show_time > 0)
	{		
		remove_task(TIMER_TASK)
		if(g_show_time > 0)
			g_show_time = -1
	}
}


public check_stop_record()
{
	if(g_hltv_recording == 4 && !g_mapchange)
			if(g_realplayersnum < get_pcvar_num(g_minplayers_cvar))
			{
				set_task(1.0, "hltv_stop_record")
				g_hltv_recording = 1
			}
}


public hltv_start_record()
{
	new record_string[90]
	
	if(g_messages == 1)
		hltv_rcon_command("say [HLTV] Starting record...")

	get_pcvar_string(g_hltvpath_cvar, record_string, 80)	
	format(record_string, 90, "record %s", record_string)	
	if(get_pcvar_float(g_autodelay_cvar) > 5.0)
		set_task(get_pcvar_float(g_autodelay_cvar) - 5.0, "hltv_rcon_command", 0, record_string, strlen(record_string))
	else
		hltv_rcon_command(record_string)
}


public hltv_stop_record()
{	
	
	hltv_rcon_command("stoprecording")
	
	if(g_messages == 1)
		hltv_rcon_command("say [HLTV] Stopped recording...")
}

public hltv_rcon_command(hltv_command[])
{
	// Declare variables
	new socket_address		// Contains the socket address of the hltv server 
	new socket_error = 0	// Contains the error code of the socket connection
	
	
	new send[256]			// Contains the send socket command	
	
	
	new hltv_password[20]	//, hltv_challenge[15]
			
	// Set hltv rcon password
	get_pcvar_string(g_hltvpassword_cvar, hltv_password, 19)
		
	// Connect to the HLTV Proxy
	socket_address = socket_open(g_hltv_ip, g_hltv_port, SOCKET_UDP, socket_error)
		
	if (socket_error != 0)
		return server_print("HLTV connection failure...", socket_error)
		
	// Send challenge rcon and receive response
	// Do NOT add spaces after the commas, you get an error about invalid function call
	
	if(equali(g_hltv_challenge, ""))
	{
		if(!g_challenging_rcon)
		{
			setc(send, 4, 0xff)
			copy(send[4], 255, "challenge rcon")
			setc(send[28], 1, '^n')
			
			socket_send2(socket_address, send, 255)	
      
			set_task(2.0, "hltv_challenge_receive", socket_address)
			g_challenging_rcon = true
		}
		set_task(4.2, "hltv_rcon_command", 0, hltv_command, strlen(hltv_command))	
	}
	else
	{	
		replace(g_hltv_challenge, 255, "^n", "")
		
		// Set rcon command
		setc(send, 255, 0x00)
		setc(send, 4, 0xff)
		
		log_amx("hltv_command: %s", hltv_command)
		formatex(send[4], 255, "rcon %s %s %s ^n", g_hltv_challenge, hltv_password, hltv_command)
		log_amx("sending: %s", send)
		socket_send2(socket_address, send, 255)
		socket_close(socket_address)
				
		switch(hltv_command[0])
		{
			case 'r':
			{
				if(g_show_time > -2)
					set_task(1.0, "hltv_show_time", TIMER_TASK, _, _, "b")
				g_hltv_recording = 4
				set_pcvar_num(g_recording_cvar, 1)	
			}
			case 's':		
			{
				remove_task(str_to_num(g_hltv_challenge))
				g_hltv_recording = 0
				set_pcvar_num(g_recording_cvar, 0)
			}
		}
			
		socket_close(socket_address)
	}
	return PLUGIN_CONTINUE
}
	

public hltv_challenge_receive(socket_address)	
{
	if(socket_is_readable(socket_address))
	{
		if(task_exists(socket_address))
			remove_task(socket_address)
		new receive[255]	
		socket_recv(socket_address, receive, 255)
		copy(g_hltv_challenge, 12, receive[19])
		set_task(20.0, "hltv_freehandle_challenge")
		g_challenging_rcon = false
	}
	else
	{
		new send[255], socket_error = 0
		socket_close(socket_address)
		socket_address = socket_open(g_hltv_ip, g_hltv_port, SOCKET_UDP, socket_error)
		if(socket_error > 0)
			log_amx("HLTV not responding...")
		else
		{
			if(!task_exists(socket_address))
			{
				setc(send, 4, 0xff)
				copy(send[4], 255, "challenge rcon")
				setc(send[28], 1, '^n')

				socket_send2(socket_address, send, 255)	
				set_task(1.0, "hltv_challenge_receive", socket_address)
			}
		}
	} 
}


public hltv_freehandle_challenge()
{
	g_hltv_challenge = ""
}	


public hltv_show_time()
{
	static time[22]
	get_time("%d/%m/%Y - %X", time, 21)
	set_hudmessage(0, 100, 200, 0.77, 0.19, 0, 0.0, 1.0, 0.1, 0.2, 4)
	show_hudmessage(g_show_time, time)
}
	

public prepare_for_mapchange()
{
	if(task_exists(TIMER_TASK))
		remove_task(TIMER_TASK)
}


public mapchange()
{	
	g_mapchange = true
}
