#include <amxmodx> 
#include <amxmisc> 

#define BLIND		(1<<0)

new PlayerFlags[33]
new gmsgFade

public amx_blind(id)
{ 
    if ((get_user_flags(id)&ADMIN_KICK)) 
	{

	new arg[32] 
	read_argv(1, arg, 31) 
	new user = cmd_target(id, arg, 5) 
	if(!user) 
		return PLUGIN_HANDLED

	new authid[16], name2[32], authid2[16], name[32], userip[32]
	get_user_authid(id, authid, 15)
	get_user_name(id, name, 31)
	get_user_authid(user, authid2, 15)
	get_user_name(user, name2, 31)
	get_user_ip(user,userip,31,1)
	if(PlayerFlags[user] & BLIND)
	{
		console_print(id, "Client ^"%s^" is already blind", name2)
		return PLUGIN_HANDLED
	}
	else
	{
		new bIndex[2]
		bIndex[0] = user
		PlayerFlags[user] += BLIND
		set_task(1.0, "delay_blind", 0, bIndex, 2)
		message_begin(MSG_ONE, gmsgFade, {0,0,0}, user) // use the magic #1 for "one client"  
		write_short(1<<12) // fade lasts this long duration  
		write_short(1<<8) // fade lasts this long hold time  
		write_short(1<<0) // fade type IN 
		write_byte(0) // fade red  
		write_byte(0) // fade green  
		write_byte(0) // fade blue    
		write_byte(255) // fade alpha    
		message_end()
	}
	console_print(id, "Client ^"%s^" blinded", name2) 
	log_amx("Cmd: ADMIN %s: blinded %s ,Ip: %s", name, name2, userip)
	}
	
	return PLUGIN_HANDLED
}

public amx_unblind(id)
{ 
    if ((get_user_flags(id)&ADMIN_KICK)) 
	{

	new arg[32] 
	read_argv(1, arg, 31) 
	new user = cmd_target(id, arg, 5) 
	if(!user)
		return PLUGIN_HANDLED

	new authid[16], name2[32], authid2[16], name[32], userip[32]
	get_user_authid(id, authid, 15) 
	get_user_name(id, name, 31) 
	get_user_authid(user, authid2, 15) 
	get_user_name(user, name2, 31)
	get_user_ip(user,userip,31,1)
	if(PlayerFlags[user] & BLIND)
	{
		new bIndex[2]
		bIndex[0] = user
		PlayerFlags[user] -= BLIND
		message_begin(MSG_ONE, gmsgFade, {0,0,0}, user) // use the magic #1 for "one client"  
		write_short(1<<12) // fade lasts this long duration  
		write_short(1<<8) // fade lasts this long hold time  
		write_short(1<<1) // fade type OUT 
		write_byte(0) // fade red  
		write_byte(0) // fade green  
		write_byte(0) // fade blue    
		write_byte(255) // fade alpha    
		message_end()
	}
	else
	{
		console_print(id, "Client ^"%s^" is already unblind", name2)
		return PLUGIN_HANDLED
	}
	console_print(id, "Client ^"%s^" unblinded", name2)
	log_amx("Cmd: ADMIN %s: unblinded %s ,Ip: %s", name, name2, userip)
	}
	
	return PLUGIN_HANDLED
}

public screen_fade(id) 
{
	new bIndex[2]
	bIndex[0] = id
	set_task(0.5, "delay_blind", 0, bIndex, 2)
	return PLUGIN_CONTINUE
}

public delay_blind(bIndex[])
{
	new id = bIndex[0]
	if(PlayerFlags[id])
	{
		// Blind Bit  
		message_begin(MSG_ONE, gmsgFade, {0,0,0}, id) // use the magic #1 for "one client" 
		write_short(1<<0) // fade lasts this long duration 
		write_short(1<<0) // fade lasts this long hold time 
		write_short(1<<2) // fade type HOLD 
		write_byte(0) // fade red 
		write_byte(0) // fade green 
		write_byte(0) // fade blue  
		write_byte(255) // fade alpha  
		message_end() 
	}
	return PLUGIN_CONTINUE
}

public plugin_init()
{
	register_plugin("AMX Blind","1","snoopy")
	
	gmsgFade = get_user_msgid("ScreenFade") 
	register_event("ScreenFade", "screen_fade", "b")

	register_concmd("amx_blind","amx_blind") 
	register_concmd("amx_unblind","amx_unblind") 

	return PLUGIN_CONTINUE 
}