/* 
*  Team Flash Control
*
*  Author: OT
* 
*  Plugin Link: http://forums.alliedmods.net/showthread.php?p=651444
*  
*  Changelog:
* 
* 12.0 - remade some forwards, made the plugin more efficient, added cvar for chat messages, made the dynamic light hookable
* 11.0 - added more forwards and natives for the plugin, some isues fixed!
* 10.0 - added forward for the plugin, here you can block a player beeing flashed, and do other stuff.
*  9.5 - new method of remembering the owner! Low on memory usage!
*  9.1 - last improvements + the plugin can now be seen on servers.
*  9.0 - control pannel + last improvements
*  8.5 - new punish system
*  8.1 - cvar bug fix, flashlight bug fix
*  8.0 - new feature -> color flashbangs
*  7.0 - updated all the features, now work 100% + new dynamic light feature
*  6.5 - improvement to the player origin, now the plugin gets the players head
*  6.0 - major improvement to all the blocks (including the new feature)
*  5.5 - small improvement to the moment a player is flashed (when a player is flashed for a long time the flash will count)
*  5.3 - big improvement to the bug detection
*  5.0 - improvement to the new feature
* 5.0b - new feature added -> block flash when you flashed a teammate and a enemy together
*  4.5 - bugfix feature added 
*  4.0 - multilang
*  3.5 - added more features, the plugin has a new name "Team Flash Control"
*  3.0 - optimized plugin (pcvars + new forwards) -> now works 100% (2008-07-11)
*  2.0 - optimized plugin -> now works > 70% (2008-07-08)
*  1.1 - fixed bug: more than one player can get a message from the same teamflash event, new cvar: tfc_adminchat (2007-11-04)
*  1.0 - sound on/off cvar: tfc_sound 1/0 (2006-04-14)
*  0.3 - fixed bug: dead spectators will nog get message about teamflash (2006-03-16)
*  0.2 - changed flash owner code, a timer is added, "[Team Flash Snitch]" in green text (2006-03-12)
*  0.1 - initial release (2006-01-25)
*
* Credits:
* Tender for Team Flash Snitch
* MpNumb for Bugfix feature
* xxAvalanchexx for Dynamiclight
* v3x for Colored Flashbangs
*/ 

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

// The defines that hold info on how the user has been blinded
#define BLINDED_FULLY					255
#define BLINDED_PARTLY					200

// Task unique id
#define REMAIN_TASK						642354

// Private data
#define OFFSET_OWNER  					41
#define OFFSET_LINUX  					4

// Macros
#define chars(%1)						(sizeof(%1) - 1)

// Bitsum useful functions
#define set_block_flash(%0)				g_bs_block_flash |= (1<<((%0)-1))
#define can_block_flash(%0)				(g_bs_block_flash & (1<<((%0)-1)))

#define set_reset_counter(%0)			g_bs_reset_counter |= (1<<((%0)-1))
#define del_reset_counter(%0)			g_bs_reset_counter &= ~(1<<((%0)-1))
#define can_reset_counter(%0)			(g_bs_reset_counter & (1<<((%0)-1)))

#define set_can_count(%0)				g_bs_counter_in_effect |= (1<<((%0)-1))
#define del_can_count(%0)				g_bs_counter_in_effect &= ~(1<<((%0)-1))
#define ply_can_count(%0)				(g_bs_counter_in_effect & (1<<((%0)-1)))

// Option macros, for easy manuver
#define get_option(%0) 					get_pcvar_num(pcvars[%0])
#define toggle_option(%0)				set_pcvar_num(pcvars[%0], !get_pcvar_num(pcvars[%0]))
#define get_option_float(%0) 			get_pcvar_float(pcvars[%0])
#define set_option_float(%0, %1)		set_pcvar_float(pcvars[%0], %1)
#define set_option_cell(%0, %1)			set_pcvar_num(pcvars[%0], %1)

// Options
enum Option
{
	pc_frc_enable, 
	pc_frc_chat, 
	pc_frc_sound, 
	pc_frc_admin, 
	pc_frc_block, 
	pc_frc_selfb, 
	pc_frc_blocka, 

	pc_frc_count, 
	pc_frc_punish, 
	pc_frc_limit, 
	pc_frc_warn, 
	pc_frc_mode, 
	pc_frc_type, 
	pc_frc_nr_ctr, 

	pc_frc_mcolor, 
	pc_frc_rcolor, 
	pc_frc_gcolor, 
	pc_frc_bcolor, 

	pc_frc_dlight, 

	pc_frc_bug, 
}


// Plugin returns
enum
{
	FRC_CONTINUE 		= 0, 
	FRC_MAKE_PARTIALLY = 200, 
	FRC_MAKE_FULLY 		= 255, 
	FRC_BLOCK 			= 300
}

// Message events
new saytext
new scrfade

// Flasher id
new g_flasher = 0
new CsTeams:g_fl_team

// Flash entity index
new g_flash_ent = 0

// Player info
new g_flash_mon[33] = {0, ...}
new g_round_lock[33]
new Float:g_time_lock[33]

// These are used for forwards, and modified paramaters
new g_last_flashtype[33] = {FRC_BLOCK, ...}
new g_modifdur[33]
new g_modifhold[33]

// Bistums, we use this for information storage, check the macros!
new g_bs_block_flash
new g_bs_counter_in_effect
new g_bs_reset_counter

// Native coords, and stuff
new g_flashdur[33]
new g_flashhold[33]

// Forward info
new bool:g_allow_forward = true

// Colors
new g_color_red = 255
new g_color_green = 255
new g_color_blue = 255

// Pcvars
enum OptionType
{
	OPTION_TOGGLE = 1, 
	OPTION_CELL, 
	OPTION_FLOAT
}

// Trace & maxplayers
new g_trace
new g_maxplayers

// Cvars
new pcvars[Option]
new OptionType:option_type[Option]
new option_value[Option][100]
new option_information[Option][300]

// Control pannel
new settingsmenu
new callbacks[2]

// Forwards
new g_forward_preflash
new g_forward_postflash
new g_forward_bang
new g_forward_trace
new g_forward_traceb
new g_forward_search
new g_forward_punish
new g_forward_freedata
new g_forward_client
new g_forward_extinit

// CFG file (save data)
new const CFG_FILE_NAME[] = "flash_remote_control.cfg"
new CFG_FILE[300]

public plugin_init()
{
	// Let's register the plugin
	register_plugin("Flash Remote Control", "12.0", "OT")
	register_cvar("flash_remote_version", "12.0", (FCVAR_SERVER | FCVAR_SPONLY))
	
	// The basic cvars
	register_option(pc_frc_enable, "frc_enable", "1") // Enable the plugin, this will stop the plugin sending the news but not the forwards!!!
	register_option(pc_frc_chat, "frc_chat", "1") // The message you have flashed/been flashed by
	register_option(pc_frc_sound, "frc_sound", "1") // the sound that is sent to the flasher
	register_option(pc_frc_admin, "frc_adminchat", "1") // the admin messages
	register_option(pc_frc_block, "frc_block_team_flash", "0") // block the moment when you flash your teammates
	register_option(pc_frc_selfb, "frc_block_self_flash", "0") // block the moment when you flash yourself
	register_option(pc_frc_blocka, "frc_block_team_all_flash", "0") // block all players that are flashed if a teammate is flashed
	
	// The punish system cvars
	register_option(pc_frc_punish, "frc_flasher_punish", "1") // punish the player that flashed too much
	register_option(pc_frc_count, "frc_flasher_counter", "1") // 0 -> count only the full flashes 1 -> count all the flashes
	register_option(pc_frc_limit, "frc_flasher_mistake_allow", "10", OPTION_CELL) // the times that a player is allowed to flash his teammates before being punished
	register_option(pc_frc_warn, "frc_flasher_warn", "0") // warn the player
	register_option(pc_frc_mode, "frc_flasher_punish_mode", "2", OPTION_CELL) // punish mode: 0 -> map end, 1 -> rounds, 2 -> time
	register_option(pc_frc_type, "frc_flasher_punish_type", "0", OPTION_CELL) // punish type: 0 -> block throw, 1 -> kill when flash, 2 -> flash himself when flash
	register_option(pc_frc_nr_ctr, "frc_flasher_punish_control", "2", OPTION_FLOAT) // punish mode control controls how many round/minutes the player will have problems (doesn't work with punish mode 0)
	
	// Flash color cvars
	register_option(pc_frc_mcolor, "frc_color_mode", "2", OPTION_CELL) // 0 -> off, 1 -> specified color, 2 -> random color chose(for all players), 3 -> random color for every player
	register_option(pc_frc_rcolor, "frc_red_color", "100") // the red color cvar
	register_option(pc_frc_gcolor, "frc_green_color", "100") // the green color cvar
	register_option(pc_frc_bcolor, "frc_blue_color", "255") // the blue color cvar
	
	// Flash dynamic light cvars, the dynamic light is affected by the color cvars
	register_option(pc_frc_dlight, "frc_dynamic_light", "1") // dynamic light
	
	// Bug fix cvar
	register_option(pc_frc_bug, "frc_bug_fix", "1") // bug fix control toggle
	
	// Special option values
	register_option_value(pc_frc_limit, "5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20")
	register_option_value(pc_frc_mode, "0;1;2")
	register_option_value(pc_frc_type, "0;1;2")
	register_option_value(pc_frc_mcolor, "0;1;2;3")
	
	// Control panel menu
	register_clcmd("amx_flash_control_menu", "conjure_menu", ADMIN_CFG, "Shows settings menu for flashbang remote control.")
	register_clcmd("amx_fcm", "conjure_menu", ADMIN_CFG, "Shows settings menu for flashbang remote control.")
	
	// The message constants
	saytext = get_user_msgid("SayText")
	scrfade = get_user_msgid("ScreenFade")
	
	// The events
	register_event("ScreenFade", "event_blinded", "be", "1>4096", "4=255", "5=255", "6=255", "7>199")
	register_logevent("event_round_end", 2, "1=Round_End")
	
	// The forwards
	register_forward(FM_SetModel, 			"fw_setmodel", 1)
	register_forward(FM_EmitSound, 			"fw_emitsound", 1)
	register_forward(FM_PlayerPreThink, 	"fw_player_prethink")
	register_forward(FM_FindEntityInSphere, "fw_findentityinsphere")
	
	// Control pannel
	callbacks[0] = menu_makecallback("callback_disabled")
	callbacks[1] = menu_makecallback("callback_enabled")
	
	// The dictionary
	register_dictionary("flashbang_remote_control.txt")
	
	// Config file
	new config[200]
	get_configsdir(config, chars(config))
	format(CFG_FILE, chars(CFG_FILE), "%s/%s", config, CFG_FILE_NAME)
	
	// Create the trace handle so we can't interfere on other plugins that use the tracehandle 0.
	g_trace = create_tr2()
	g_maxplayers = get_maxplayers()
	
	// Create the plugin forwards
	g_forward_preflash 	= CreateMultiForward("fw_FRC_preflash", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL) // Tested!
	g_forward_postflash = CreateMultiForward("fw_FRC_postflash", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL) // Tested!
	g_forward_bang 		= CreateMultiForward("fw_FRC_flashbang_explosion", ET_IGNORE, FP_CELL, FP_CELL) // Tested!
	g_forward_punish  	= CreateMultiForward("fw_FRC_punish", ET_CONTINUE, FP_CELL, FP_CELL)	 // Tested!
	g_forward_freedata	= CreateMultiForward("fw_FRC_free_plugin_data", ET_IGNORE) // Tested!
	g_forward_trace		= CreateMultiForward("fw_FRC_trace", ET_CONTINUE, FP_ARRAY, FP_ARRAY, FP_CELL, FP_CELL, FP_CELL)// Tested!
	g_forward_traceb	= CreateMultiForward("fw_FRC_trace_bug", ET_CONTINUE, FP_ARRAY, FP_ARRAY, FP_CELL, FP_CELL, FP_CELL)// Tested!
	g_forward_client  	= CreateMultiForward("fw_FRC_counter_reset", ET_IGNORE, FP_CELL) // Tested!
	g_forward_search  	= CreateMultiForward("fw_FRC_flash_find_in_sphere", ET_CONTINUE, FP_CELL, FP_CELL) // Tested!
	g_forward_extinit	= CreateMultiForward("fw_FRC_extention_init", ET_IGNORE)
	
	// Loat settings
	exec_cfg()
	
	set_task(1.0, "register_delay")
}

public register_delay()
{
	// We register this here so we can let other plugins mess with flash events! And with the grenade properties!
	RegisterHam(Ham_Think, "grenade", "fw_think")
	register_message(scrfade, "message_screenfade")
	
	new ret
	ExecuteForward(g_forward_extinit, ret)
}

public plugin_end()
{
	// Free the trace handle
	free_tr2(g_trace)
	
	// Dealloc the plugin forwards
	DestroyForward(g_forward_preflash)
	DestroyForward(g_forward_postflash)
	DestroyForward(g_forward_bang)
	DestroyForward(g_forward_punish)
	DestroyForward(g_forward_freedata)
	DestroyForward(g_forward_traceb)
	DestroyForward(g_forward_trace)
	DestroyForward(g_forward_client)
	DestroyForward(g_forward_search)
}

public plugin_natives()
{
	register_library("frc_lib")
	
	register_native("get_FRC_duration", "native_get_FRC_duration", 1)
	register_native("set_FRC_duration", "native_set_FRC_duration", 1)
	register_native("get_FRC_holdtime", "native_get_FRC_holdtime", 1)
	register_native("set_FRC_holdtime", "native_set_FRC_holdtime", 1)
	register_native("get_FRC_counter", "native_get_FRC_counter", 1)
	register_native("set_FRC_counter", "native_set_FRC_counter", 1)
	register_native("get_FRC_flash_limit", "native_get_FRC_flash_limit", 1)
	
	register_native("get_FRC_exploding_flash", "native_get_FRC_exploding_flash", 1)
	register_native("get_FRC_exploding_owner", "native_get_FRC_explo_fl_owner", 1)
	
	register_native("FRC_flash_player", "native_FRC_flash_player", 1)
}

public native_get_FRC_counter(id)
{
	return g_flash_mon[id]
}

public native_set_FRC_counter(id, quantity)
{
	g_flash_mon[id] = quantity
	return 1
}

public native_get_FRC_flash_limit()
{
	return get_option(pc_frc_limit)
}

public native_get_FRC_exploding_flash()
{
	return g_flash_ent
}

public native_get_FRC_explo_fl_owner()
{
	return g_flasher
}

public native_set_FRC_duration(flashed, duration)
{
	g_flashdur[flashed] = duration
}

public native_get_FRC_duration(flashed)
{
	return g_flashdur[flashed]
}

public native_set_FRC_holdtime(flashed, duration)
{
	g_flashhold[flashed] = duration
}

public native_get_FRC_holdtime(flashed)
{
	return g_flashhold[flashed]
}

public native_FRC_flash_player(flasher, flashed, duration, holdtime, amount)
{
	if (flasher == 0 || g_flasher != 0)
	{
		switch (get_option(pc_frc_mcolor))
		{
			case 1:
			{
				g_color_red  = get_option(pc_frc_rcolor)
				g_color_green = get_option(pc_frc_gcolor)
				g_color_blue = get_option(pc_frc_bcolor)
			}
			case 2, 3:
			{
				g_color_red  = random_num(0, 255)
				g_color_green = random_num(0, 255)
				g_color_blue = random_num(0, 255)
			}
			default:
			{
				g_color_red  = 255
				g_color_green = 255
				g_color_blue = 255
			}
		}
		
		flash(flashed, floatround(float(duration) * 409.6), floatround(float(holdtime) * 409.6), 0x0000 , g_color_red, g_color_green, g_color_blue, amount)
	}
	else
	{
		switch (get_option(pc_frc_mcolor))
		{
			case 1:
			{
				g_color_red  = get_option(pc_frc_rcolor)
				g_color_green = get_option(pc_frc_gcolor)
				g_color_blue = get_option(pc_frc_bcolor)
			}
			case 2, 3:
			{
				g_color_red  = random_num(0, 255)
				g_color_green = random_num(0, 255)
				g_color_blue = random_num(0, 255)
			}
			default:
			{
				g_color_red  = 255
				g_color_green = 255
				g_color_blue = 255
			}
		}
		
		g_flash_ent = flasher
		g_flasher = flasher
		
		eflash(flashed, floatround(float(duration) * 409.6), floatround(float(holdtime) * 409.6), 0x0000 , 255, 255, 255, amount)
		
		g_flash_ent = 0
		g_flasher = 0
		
		new ret
		ExecuteForward(g_forward_freedata, ret)
	}
	
	return 1
}

// Cache the sound
public plugin_precache()
{
	engfunc(EngFunc_PrecacheSound, "radio/bot/im_blind.wav")
}

// Control Pannel
// Cfg save system
public exec_cfg()
{
	if(file_exists(CFG_FILE))
		server_cmd("exec %s", CFG_FILE)
}

public save_cfg()
{
	new file[2000]
	format(file, chars(file), "echo [Flashbang Remote Control] Executing config file ...^n")
	
	add_to_file(file, chars(file), pc_frc_enable)
	add_to_file(file, chars(file), pc_frc_chat)
	add_to_file(file, chars(file), pc_frc_sound)
	add_to_file(file, chars(file), pc_frc_admin)
	add_to_file(file, chars(file), pc_frc_selfb)
	add_to_file(file, chars(file), pc_frc_block)
	add_to_file(file, chars(file), pc_frc_blocka)
	add_to_file(file, chars(file), pc_frc_punish)
	add_to_file(file, chars(file), pc_frc_count)
	add_to_file(file, chars(file), pc_frc_limit)
	add_to_file(file, chars(file), pc_frc_warn)
	add_to_file(file, chars(file), pc_frc_mode)
	add_to_file(file, chars(file), pc_frc_type)
	add_to_file(file, chars(file), pc_frc_nr_ctr)
	add_to_file(file, chars(file), pc_frc_mcolor)
	add_to_file(file, chars(file), pc_frc_rcolor)
	add_to_file(file, chars(file), pc_frc_gcolor)
	add_to_file(file, chars(file), pc_frc_bcolor)
	add_to_file(file, chars(file), pc_frc_dlight)
	add_to_file(file, chars(file), pc_frc_bug)
	
	format(file, chars(file), "%secho [Flashbang Remote Control] Settings loaded from config file", file)
	
	delete_file(CFG_FILE)
	write_file(CFG_FILE, file)
}

stock add_to_file(file[], size_of_file, Option:option)
{
	switch (option_type[option])
	{
		case OPTION_TOGGLE, OPTION_CELL: format(file, size_of_file, "%s%s %d^n", file, option_information[option], get_option(option))
		case OPTION_FLOAT: format(file, size_of_file, "%s%s %f^n", file, option_information[option], get_option_float(option))
	}
}

// Control Pannel Menu system
public conjure_menu(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
	{
		menu_adjust(id)
	}
	return PLUGIN_HANDLED
}

// Let's create the menu!
stock menu_adjust(id, page = 0)
{
	settingsmenu = menu_create("Flash Remote Control Pannel", "menu_handler")
	
	add_option_toggle(pc_frc_enable, "Enable plugin", "Yes", "No")
	
	if (get_option(pc_frc_enable) == 0)
	{
		menu_display(id, settingsmenu, page)
		return PLUGIN_CONTINUE
	}
	
	add_option_toggle(pc_frc_chat, "Enable chat messages (when flashed)", "Yes", "No")
	add_option_toggle(pc_frc_admin, "Admin text message display", "Enabled", "Disabled")
	add_option_toggle(pc_frc_sound, "Play the ^"I'm blind^" sound", "On", "Off")
	add_option_toggle(pc_frc_block, "Block team flash", "Yes", "No")
	add_option_toggle(pc_frc_selfb, "Block self flash", "Yes", "No")
	add_option_toggle(pc_frc_blocka, "Block the flash effect to all when a teammate is flashed", "Yes", "No")
	add_option_toggle(pc_frc_bug, "Enable bug fixer", "Yes", "No")
	add_option_toggle(pc_frc_dlight, "Enable dynamic light", "Yes", "No")
	add_option_quatrotoggle(pc_frc_mcolor, "Flash color mode", "Normal", "Specified colors", "Random color (the same for all the players)", "Random color for every player")
	
	add_option_toggle(pc_frc_punish, "Punish system", "On", "Off")
	
	if (get_option(pc_frc_punish))
	{
		add_option_toggle(pc_frc_count, "Method of counting", "All the teamflashes", "Just the full teamflashes")
		add_option_toggle(pc_frc_warn, "Warn the flasher", "Yes", "No")
		add_option_tritoggle(pc_frc_mode, "Punish mode", "Until map end", "By rounds", "By time")
		add_option_tritoggle(pc_frc_type, "Punish type", "Block throw", "Kill", "Self flash")
		add_cell_option(pc_frc_limit, "The number of players someone can flash before beeing punished", "times")
		
		
		switch (get_option(pc_frc_mode))
		{
			case 1:
			{
				register_option_value(pc_frc_nr_ctr, "1;2;3;4;5;6;7;8;9;10")
				add_float_cell_option(pc_frc_nr_ctr, "Number of rounds of punish", "times")
			}
			case 2:
			{	
				register_option_value(pc_frc_nr_ctr, "1;1.5;2;2.5;3;3.5;4;4.5;5;5.5;6;7;8;9;10")
				add_float_option(pc_frc_nr_ctr, "Time of punish", "minutes")
			}
		}
		
	}
	
	menu_display(id, settingsmenu, page)
	return PLUGIN_CONTINUE
}

stock add_option_toggle(Option:control_option, const basetext[], const yestext[], const notext[], Option:displayif = Option:-1)
{
	new cmd[3], itemtext[100]
	num_to_str(_:control_option, cmd, chars(cmd))
	format(itemtext, chars(itemtext), "%s: %s%s", basetext, (get_option(control_option) ? "\y" : "\r" ), (get_option(control_option) ? yestext : notext))
	menu_additem(settingsmenu, itemtext, cmd, _, (displayif != Option:-1 && !get_option(displayif)) ? callbacks[0] : callbacks[1])
}

stock add_option_tritoggle(Option:control_option, const basetext[], const text[], const text2[], const text3[], Option:displayif = Option:-1)
{
	new cmd[3], itemtext[100]
	num_to_str(_:control_option, cmd, chars(cmd))
	format(itemtext, chars(itemtext), "%s:\y %s%s%s", basetext, (get_option(control_option) == 0 ? text : "" ), (get_option(control_option) == 1 ? text2 : "" ), (get_option(control_option) == 2 ? text3 : "" ))
	menu_additem(settingsmenu, itemtext, cmd, _, (displayif != Option:-1 && !get_option(displayif)) ? callbacks[0] : callbacks[1])
}

stock add_option_quatrotoggle(Option:control_option, const basetext[], const text[], const text2[], const text3[], const text4[], Option:displayif = Option:-1)
{
	new cmd[3], itemtext[100]
	num_to_str(_:control_option, cmd, chars(cmd))
	format(itemtext, chars(itemtext), "%s:\y %s%s%s%s", basetext, (get_option(control_option) == 0 ? text : "" ), (get_option(control_option) == 1 ? text2 : "" ), (get_option(control_option) == 2 ? text3 : "" ), (get_option(control_option) == 3 ? text4 : "" ))
	menu_additem(settingsmenu, itemtext, cmd, _, (displayif != Option:-1 && !get_option(displayif)) ? callbacks[0] : callbacks[1])
}

stock add_float_option(Option:control_option, const basetext[], const unit[])
{
	new cmd[3], itemtext[100]
	new value[20]
	
	format(value, chars(value), "%0.2f", get_option_float(control_option))
	
	num_to_str(_:control_option, cmd, chars(cmd))
	format(itemtext, chars(itemtext), "%s: \y%s \r%s", basetext, value, unit)
	menu_additem(settingsmenu, itemtext, cmd, _, _)
}

stock add_float_cell_option(Option:control_option, const basetext[], const unit[])
{
	new cmd[3], itemtext[100]
	new value[20]
	
	format(value, chars(value), "%d", floatround(get_option_float(control_option)))
	
	num_to_str(_:control_option, cmd, chars(cmd))
	format(itemtext, chars(itemtext), "%s: \y%s \r%s", basetext, value, unit)
	menu_additem(settingsmenu, itemtext, cmd, _, _)
}

stock add_cell_option(Option:control_option, const basetext[], const unit[])
{
	new cmd[3], itemtext[100]
	new value[20]
	
	format(value, chars(value), "%d", get_option(control_option))
	
	num_to_str(_:control_option, cmd, chars(cmd))
	format(itemtext, chars(itemtext), "%s: \y%s \r%s", basetext, value, unit)
	menu_additem(settingsmenu, itemtext, cmd, _, _)
}

public callback_disabled(id, menu, item)
{
	return ITEM_DISABLED
}

public callback_enabled(id, menu, item)
{
	return ITEM_ENABLED
}


// Base cvar change system
public menu_handler(id, menu, item)
{
	new access, info[5], callback
	menu_item_getinfo(menu, item, access, info, chars(info), _, _, callback)
	
	if (item < 0)
	{
		save_cfg()
		return PLUGIN_HANDLED
	}
	
	new cvar = str_to_num(info)
	
	switch (option_type[Option:cvar])
	{
		case OPTION_TOGGLE:
		{
			toggle_option(Option:cvar)
		}
		case OPTION_CELL:
		{
			new value_string[100]
			format(value_string, chars(value_string), "%s;", option_value[Option:cvar])
			
			new values[20][10]
			new true_value[20]
			
			new last = 0, newpos = 0, k = 0;
			
			for (new i=0;i<sizeof(value_string);i++)
			{
				if(equal(value_string[i], ";", 1))
				{
					newpos = i
				}
				
				if (newpos > last)
				{					
					for (new j=last;j<newpos;j++)
					{
						format(values[k], 9, "%s%s", values[k], value_string[j])
					}
					
					last = newpos + 1
					k++
				}
			}
			
			new bool:ok = false
			new counter = 0
			
			for (new i=0;i<k;i++)
			{
				counter++
				
				true_value[i] = str_to_num(values[i])
				
				if (ok == true)
				{
					set_pcvar_num(pcvars[Option:cvar], true_value[i])
					counter = 0
					break
				}
				
				if (true_value[i] == get_option(Option:cvar))
					ok = true
			}
			
			if (counter == k)
				set_pcvar_num(pcvars[Option:cvar], true_value[0])
		}
		case OPTION_FLOAT:
		{
			new value_string_float[100]
			format(value_string_float, chars(value_string_float), "%s;", option_value[Option:cvar])
			
			new values_float[20][10]
			new Float:true_value_float[20]
			
			new last = 0, newpos = 0, k = 0;
			
			for (new i=0;i<sizeof(value_string_float);i++)
			{
				if(equal(value_string_float[i], ";", 1))
				{
					newpos = i
				}
				
				if (newpos > last)
				{					
					for (new j=last;j<newpos;j++)
					{
						format(values_float[k], 9, "%s%s", values_float[k], value_string_float[j])
					}
					
					last = newpos + 1
					k++
				}
			}
			
			new bool:ok=false
			new counter = 0
			
			for (new i=0;i<k;i++)
			{
				counter++
				
				true_value_float[i] = str_to_float(values_float[i])
				
				if (ok == true)
				{
					set_pcvar_float(pcvars[Option:cvar], true_value_float[i])
					counter = 0
					break
				}
				
				if (true_value_float[i] == get_option_float(Option:cvar))
					ok = true
			}
			
			if (counter == k)
				set_pcvar_float(pcvars[Option:cvar], true_value_float[0])
		}
	}
	
	menu_destroy(menu)
	menu_adjust(id, floatround(float(item)/7.0, floatround_floor))
	save_cfg()
	return PLUGIN_HANDLED
}

// Round end
public event_round_end()
{
	static players[32], num, id
	get_players(players, num)
	
	for (new i=0;i<num;i++)
	{
		id = players[i]
		
		if (g_round_lock[id] > 0 && !ply_can_count(id))
			g_round_lock[id] -= 1
		
		if (g_round_lock[id] == 0 && get_option(pc_frc_mode) == 1 && !ply_can_count(id))
		{
			del_reset_counter(id)
			set_can_count(id)
			g_flash_mon[id] = 0
		}
	}
}

// Reset the monitor when a player connects or disconnects
#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#else
public client_disconnected(id)
#endif
{
	set_reset_counter(id)
}

public client_connect(id)
{
	set_reset_counter(id)
}

// Damn you!!! You flashed me!!!
public event_blinded(id)
{ 
	if (!is_user_alive(id) || g_flasher == 0) 
		return PLUGIN_CONTINUE 
	
	new alpha, ret
	
	g_flashdur[id] = -1
	g_modifhold[id] = -1
	
	switch (g_last_flashtype[id])
	{
		case FRC_BLOCK:
		{
			return PLUGIN_CONTINUE
		}
		case FRC_MAKE_PARTIALLY:
		{
			alpha = BLINDED_PARTLY
		}
		case FRC_MAKE_FULLY:
		{
			alpha = BLINDED_FULLY
		}
		default:
		{
			alpha = read_data(7)
		}
	}
	
	g_last_flashtype[id] = FRC_BLOCK
	
	ExecuteForward(g_forward_postflash, ret, g_flasher, id, g_flash_ent, alpha)
	
	// And now the news!
	return show_news(id, alpha, g_flasher)
}

public message_screenfade(msg_id, msg_dest, ent)
{
	if (g_flasher == 0)
		return PLUGIN_CONTINUE
	
	g_flashdur[ent] = floatround(float(get_msg_arg_int(1)) / 409.6)
	g_flashhold[ent] = floatround(float(get_msg_arg_int(2)) / 409.6)
	
	new ret
	ExecuteForward(g_forward_preflash, ret, g_flasher, ent, g_flash_ent, get_msg_arg_int(7))
	
	new actdur = (g_flashdur[ent] > 0) ? g_flashdur[ent] : 0
	new acthold = (g_flashhold[ent] > 0) ? g_flashhold[ent] : 0
	
	if (actdur != floatround(float(get_msg_arg_int(1)) / 409.6))
	{
		if (actdur == 0)
		{
			ret = FRC_BLOCK
		}
		else
		{
			g_modifdur[ent] = floatround(float(actdur) * 409.6)
			set_msg_arg_int(1, ARG_SHORT, g_modifdur[ent])
		}
	}
	
	if (floatround(float(get_msg_arg_int(2)) / 409.6) != acthold)
	{
		g_modifhold[ent] = floatround(float(acthold) * 409.6)
		set_msg_arg_int(2, ARG_SHORT, g_modifhold[ent])
	}
	
	switch (ret)
	{
		case FRC_BLOCK:
		{
			g_last_flashtype[ent] = FRC_BLOCK
			return PLUGIN_HANDLED
		}
		case FRC_MAKE_PARTIALLY:
		{
			g_last_flashtype[ent] = FRC_MAKE_PARTIALLY
			set_msg_arg_int(7, ARG_BYTE, BLINDED_PARTLY)
		}
		case FRC_MAKE_FULLY:
		{
			g_last_flashtype[ent] = FRC_MAKE_FULLY
			set_msg_arg_int(7, ARG_BYTE, BLINDED_FULLY)
		}
		default:
		{
			g_last_flashtype[ent] = FRC_CONTINUE
		}
	}
	
	if (get_option(pc_frc_mcolor) != 3)
	{
		set_msg_arg_int(4, ARG_BYTE, g_color_red)
		set_msg_arg_int(5, ARG_BYTE, g_color_green)
		set_msg_arg_int(6, ARG_BYTE, g_color_blue)
	}
	else
	{
		set_msg_arg_int(4, ARG_BYTE, random_num(0, 255))
		set_msg_arg_int(5, ARG_BYTE, random_num(0, 255))
		set_msg_arg_int(6, ARG_BYTE, random_num(0, 255))
	}
	
	return PLUGIN_CONTINUE
}

// Show the news!
public show_news(id, alpha, id_fl)
{	
	// If you flash a teammate
	if (cs_get_user_team(id) == g_fl_team && id != id_fl && get_option(pc_frc_enable) != 0)
	{
		new flasher[32]
		get_user_name(id_fl, flasher, chars(flasher))
		
		new name[32]
		get_user_name(id, name, chars(name))
		
		if (get_option(pc_frc_chat))
		{
			new message1[128], message2[128]
			
			format(message1, chars(message1), "^x04[Team Flash Control]^x01 %L ^x03%s", id, "THE_FLASHED_MSG", flasher)
			format(message2, chars(message1), "^x04[Team Flash Control]^x01 %L ^x03(%s)", id_fl, alpha == BLINDED_FULLY ? "FLASHER_MSG_TOTAL" : "FLASHER_MSG_PART", name)
			
			colored_msg(id, message1)
			colored_msg(id_fl, message2)
		}
		
		if (!is_user_bot(id_fl) && get_option(pc_frc_punish) && ply_can_count(id_fl) && (alpha == BLINDED_FULLY || (get_option(pc_frc_count) && alpha != BLINDED_FULLY)))
		{
			g_flash_mon[id_fl] += 1
			
			if (g_flash_mon[id_fl] >= get_option(pc_frc_limit))
			{
				del_can_count(id_fl)
				
				switch (get_option(pc_frc_mode))
				{
					case 1: g_round_lock[id_fl] = floatround(get_option_float(pc_frc_nr_ctr), floatround_round)
					case 2: g_time_lock[id_fl] = get_gametime() + (get_option_float(pc_frc_nr_ctr) * 60.0)
				}
				
				if(get_option(pc_frc_admin) && get_option(pc_frc_punish))
				{
					new msg[128]
					format(msg, chars(msg), "%L", LANG_SERVER, "BLOCK_USER_FLASH_MSG", flasher)
					admin_message("[Team Flash Control]", msg)
				}
				
			}
		}
		
		if (g_flash_mon[id_fl] >= get_option(pc_frc_limit) && alpha == BLINDED_FULLY && get_option(pc_frc_punish))
		{
			new ret = FRC_CONTINUE
			ExecuteForward(g_forward_punish, ret, id_fl, get_option(pc_frc_mode))
			
			if (ret == FRC_CONTINUE)
			{
				switch (get_option(pc_frc_type))
				{
					case 1: user_kill(id_fl)
					case 2: eflash(id_fl, 10<<12, 1<<12, 0x0000 , 255, 255, 255, 255)
				}
			}
		}
		

		if(get_option(pc_frc_sound))
			client_cmd(id_fl, "spk sound/radio/bot/im_blind.wav")
		
		if(alpha == BLINDED_FULLY && get_option(pc_frc_admin))
		{
			new msg[128]
			format(msg, chars(msg), "%L", LANG_SERVER, "ADMIN_MSG", flasher, name)
			admin_message("[Team Flash Control]", msg)
		}
	}
	
	return PLUGIN_CONTINUE
}

// Player prethink
public fw_player_prethink(id)
{
	if (can_reset_counter(id))
	{
		del_reset_counter(id)
		set_can_count(id)
		
		g_flash_mon[id] = 0
		
		new ret
		ExecuteForward(g_forward_client, ret, id)
	}
	
	if (get_gametime() >= g_time_lock[id] && get_option(pc_frc_mode) == 2 && ply_can_count(id))
	{
		del_reset_counter(id)
		set_can_count(id)
		
		g_flash_mon[id] = 0
		
		new ret
		ExecuteForward(g_forward_client, ret, id)
	}
	
	if (!is_user_alive(id))
		return FMRES_IGNORED
	
	if (get_user_weapon(id) == CSW_FLASHBANG && pev(id, pev_button) & IN_ATTACK && g_flash_mon[id] >= get_option(pc_frc_limit) && get_option(pc_frc_punish) && get_option(pc_frc_type) == 0 && get_option(pc_frc_enable) != 0)
	{
		new ret = FRC_CONTINUE
		ExecuteForward(g_forward_punish, ret, id, get_option(pc_frc_mode))
		
		if (ret == FRC_CONTINUE)
		{
			set_pev(id, pev_button, pev(id, pev_button) & ~IN_ATTACK)
			return FMRES_HANDLED
		}
	}
	
	return FMRES_IGNORED
}

// The moment the flash is thrown
public fw_setmodel(ent, const model[])
{
	if (!pev_valid(ent))
		return FMRES_IGNORED
	
	// Not yet thrown
	if (pev_float(ent, pev_gravity) == 0.0)
		return FMRES_IGNORED
	
	if (containi(model, "w_flashbang.mdl") == -1)
		return FMRES_IGNORED
	
	// Get the owner	
	set_pdata_int(ent, OFFSET_OWNER, pev(ent, pev_owner), OFFSET_LINUX)
	
	return FMRES_IGNORED
}

// The grenade thinks ... quiet!!!
public fw_think(ent)
{
	if (!is_flash(ent) || g_flash_ent == ent)
		return HAM_IGNORED
	
	// The flash has not kaboomed 
	if (pev_float(ent, pev_dmgtime) > get_gametime())
		return HAM_IGNORED
	
	g_flasher = get_pdata_int(ent, OFFSET_OWNER, OFFSET_LINUX)
	g_fl_team = cs_get_user_team(g_flasher)
	g_flash_ent = ent
	
	new ret
	ExecuteForward(g_forward_bang, ret, ent, g_flasher)
	
	new Float:origin[3]
	pev(ent, pev_origin, origin)
	
	if (get_option(pc_frc_selfb) != 0 && get_option(pc_frc_enable) != 0)
		set_block_flash(g_flasher)
	
	if (get_option(pc_frc_block) != 0 && get_option(pc_frc_enable) != 0)
	{
		for (new i=1;i<33;i++)
		{
			if (!is_user_connected(i) || is_user_connecting(i))
				continue
			
			if (i != g_flasher && cs_get_user_team(i) == g_fl_team)
				set_block_flash(i)
		}
	}
	
	if (get_option(pc_frc_blocka) != 0 && get_option(pc_frc_enable) != 0)
	{
		new Float:user_origin[3], Float:start[3]
		new hit
		
		while ((hit = engfunc(EngFunc_FindEntityInSphere, hit, origin, 1500.0)))
		{
			if (hit > g_maxplayers)
				break
			
			if (hit == g_flasher)
				continue
			
			if (!is_user_alive(hit))
				continue
			
			if (cs_get_user_team(hit) != g_fl_team)
				continue
			
			// Get the origin of the players head
			pev(hit, pev_origin, user_origin)
			pev(hit, pev_view_ofs, start)
			xs_vec_add(user_origin, start, user_origin)
			
			// Traceline from the player origin to the grenade origin
			engfunc(EngFunc_TraceLine, origin, user_origin, DONT_IGNORE_MONSTERS, ent, g_trace)
			
			new ret, ar_start, ar_end
			ar_start = PrepareArray(_:origin, 3, 0)
			ar_end = PrepareArray(_:user_origin, 3, 0)
			
			ExecuteForward(g_forward_trace, ret, ar_start, ar_end, DONT_IGNORE_MONSTERS, hit, g_trace)
			
			if (get_tr2(g_trace, TR_pHit) == hit)
			{
				g_allow_forward = false
				break
			}
		}
	}
	
	if (get_option(pc_frc_dlight) != 0 && get_option(pc_frc_enable) != 0)
	{
		switch (get_option(pc_frc_mcolor))
		{
			case 1:
			{
				g_color_red  = get_option(pc_frc_rcolor)
				g_color_green = get_option(pc_frc_gcolor)
				g_color_blue = get_option(pc_frc_bcolor)
				
				dynamic_light(origin, g_color_red, g_color_green, g_color_blue)
			}
			case 2:
			{
				g_color_red  = random_num(0, 255)
				g_color_green = random_num(0, 255)
				g_color_blue = random_num(0, 255)
				
				dynamic_light(origin, g_color_red, g_color_green, g_color_blue)
			}
			default:
			{
				g_color_red  = 255
				g_color_green = 255
				g_color_blue = 255
				
				dynamic_light(origin)
			}
		}
	}
	
	return HAM_IGNORED
}

// The grenade emits the explosion sound
public fw_emitsound(ent, chan, const sound[])
{
	if (!pev_valid(ent))
		return FMRES_IGNORED
	
	if (contain(sound, "flash") == -1)
		return FMRES_IGNORED
	
	static classname[32]
	pev(ent, pev_classname, classname, 31)
	if (!equal(classname, "grenade"))
		return FMRES_IGNORED
	
	// Good time to reset the flasher and the ent id
	g_flash_ent = 0
	g_flasher = 0
	g_allow_forward = true
	
	new owner = get_pdata_int(ent, OFFSET_OWNER, OFFSET_LINUX)
	
	if (task_exists(owner + REMAIN_TASK))
		remove_task(owner + REMAIN_TASK)
	
	// Show the user how many flashes he has left to throw before before beeing blocked
	set_task(0.2, "remaining_flashes", owner + REMAIN_TASK)
	
	// Remove all the flashes that need to be blocked!
	g_bs_block_flash = 0
	
	new ret
	ExecuteForward(g_forward_freedata, ret)
	
	return FMRES_IGNORED
}

// Let's find the victims
public fw_findentityinsphere(start_ent, Float:origin[3], Float:radius)
{
	if (radius != 1500.0 || g_flash_ent == 0)
		return FMRES_IGNORED
	
	if (g_allow_forward == false)
	{
		forward_return(FMV_CELL, -1)
		return FMRES_SUPERCEDE
	}
	
	static hit, Float:user_origin[3], Float:fraction, Float:start[3], ret, hit_fw
	
	hit_fw = engfunc(EngFunc_FindEntityInSphere, hit, origin, radius)
	
	if (1 <= hit_fw <= g_maxplayers)
	{
		ExecuteForward(g_forward_search, ret, hit_fw, g_flash_ent)
		
		if (ret != FRC_CONTINUE)
		{
			hit = hit_fw
			forward_return(FMV_CELL, -1)
			return FMRES_SUPERCEDE
		}
	}
	
	if (get_option(pc_frc_enable) != 0)
	{
		if (get_option(pc_frc_bug) != 0)
		{
			while ((hit = engfunc(EngFunc_FindEntityInSphere, hit, origin, radius)))
			{
				if (hit > g_maxplayers)
				{
					forward_return(FMV_CELL, hit)
					return FMRES_SUPERCEDE
				}
				
				// Hit dead player
				if (!is_user_alive(hit))
				{
					forward_return(FMV_CELL, hit)
					return FMRES_SUPERCEDE
				}
				
				
				// Get the origin of the players head
				pev(hit, pev_origin, user_origin)
				pev(hit, pev_view_ofs, start)
				xs_vec_add(user_origin, start, user_origin)
				
				// Traceline from the player origin to the grenade origin
				engfunc(EngFunc_TraceLine, user_origin, origin, DONT_IGNORE_MONSTERS, hit, g_trace)
				
				new ret, ar_start, ar_end
				ar_start = PrepareArray(_:user_origin, 3, 0)
				ar_end = PrepareArray(_:origin, 3, 0)
				
				ExecuteForward(g_forward_traceb, ret, ar_start, ar_end, DONT_IGNORE_MONSTERS, hit, g_trace)
				
				get_tr2(g_trace, TR_flFraction, fraction)
				
				// If the trace didn't hit anything in it's way then we're cool!
				if (fraction == 1.0 && !can_block_flash(hit))
				{
					forward_return(FMV_CELL, hit)
					return FMRES_SUPERCEDE
				}
			}
		}
		else
		{
			while ((hit = engfunc(EngFunc_FindEntityInSphere, hit, origin, radius)))
			{
				if (hit > g_maxplayers)
				{
					forward_return(FMV_CELL, hit)
					return FMRES_SUPERCEDE
				}
				
				// Hit dead player
				if (!is_user_alive(hit))
				{
					forward_return(FMV_CELL, hit)
					return FMRES_SUPERCEDE
				}
				
				if (!can_block_flash(hit))
				{
					forward_return(FMV_CELL, hit)
					return FMRES_SUPERCEDE
				}
			}
		}
		
		// Cancel the check, if nothing was hit
		forward_return(FMV_CELL, -1)
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
} 

// We are in trouble!
public remaining_flashes(id)
{
	id -= REMAIN_TASK
	
	if (!(get_option(pc_frc_admin) != 0 && get_option(pc_frc_limit) >= g_flash_mon[id] >= (get_option(pc_frc_limit) - 2) && get_option(pc_frc_punish) != 0 && get_option(pc_frc_warn) != 0) || get_option(pc_frc_enable) == 0)
		return PLUGIN_CONTINUE
	
	new message[128]
	
	format(message, chars(message), "^x04[Team Flash Control] ^x01%L ^x03%d ", id, "FLASHER_MSG_LEFT1", get_option(pc_frc_limit) - g_flash_mon[id] + 1)
	format(message, chars(message), "%s^x01%L", message, id, "FLASHER_MSG_LEFT2")
	
	colored_msg(id, message)
	
	return PLUGIN_CONTINUE
}

// Is the entity a flash grenade??? hmmm...
public bool:is_flash(ent)
{
	static model[32]
	pev(ent, pev_model, model, 31)
	return bool:(containi(model, "w_flashbang.mdl") != -1)
}

// The dynamic light of the flashbang, it adds a little bit of realism
dynamic_light(Float:origin[3], red = 255, green = 255, blue = 255)
{
	new o[3]
	FVecIVec(origin, o)
	
	emessage_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	ewrite_byte(TE_DLIGHT) // The light effect
	ewrite_coord(o[0]) // x
	ewrite_coord(o[1]) // y
	ewrite_coord(o[2]) // z
	ewrite_byte(75) // radius
	ewrite_byte(red) // r
	ewrite_byte(green) // g
	ewrite_byte(blue) // b
	ewrite_byte(4) // life
	ewrite_byte(120) // decay rate
	emessage_end()
}

// Hookable flash message
eflash(id, duration, holdtime, flags, red = 255, green = 255, blue = 255, alpha)
{
	emessage_begin(MSG_ONE, scrfade, {0, 0, 0}, id)
	ewrite_short(duration)
	ewrite_short(holdtime)
	ewrite_short(flags)
	ewrite_byte(red)
	ewrite_byte(green)
	ewrite_byte(blue)
	ewrite_byte(alpha)
	emessage_end()
}

flash(id, duration, holdtime, flags, red = 255, green = 255, blue = 255, alpha)
{
	message_begin(MSG_ONE, scrfade, {0, 0, 0}, id)
	write_short(duration)
	write_short(holdtime)
	write_short(flags)
	write_byte(red)
	write_byte(green)
	write_byte(blue)
	write_byte(alpha)
	message_end()
}

// Just the colored message ... don't you like colors?
public colored_msg(id, msg[])
{
	message_begin(MSG_ONE, saytext, {0, 0, 0}, id)
	write_byte(id)
	write_string(msg)
	message_end()
}

// Similar to pev() just returns a float value
public Float:pev_float(index, type)
{
	static Float:nr
	pev(index, type, nr)
	return nr
}

// Message to admins, they need to know ...
public admin_message(const name[], const message[])
{
	new message2[192]
	new players[32], num
	get_players(players, num)
	
	format(message2, chars(message2), "(ADMINS) %s : %s", name, message)
	
	for (new i = 0; i < num; ++i)
	{
		if (access(players[i], ADMIN_CHAT))
			client_print(players[i], print_chat, "%s", message2)
	}
}

// Control panel system functions/stocks
register_option(Option:option, const name[300], const string[], OptionType:type = OPTION_TOGGLE, flags = 0, Float:value = 0.0)
{
	pcvars[option] = register_cvar(name, string, flags, value)
	option_type[option] = type
	option_information[option] = name
}

register_option_value(Option:option, values[100])
{
	if (option_type[option] == OPTION_TOGGLE)
		return
	
	option_value[option] = values
}