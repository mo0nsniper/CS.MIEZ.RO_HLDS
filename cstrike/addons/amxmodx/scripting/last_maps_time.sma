#include <amxmodx>
#include <amxmisc>

// number of last maps to save
#define LAST_MAPS_SAVE 5

new gSaveFile[64];
new gLastMapName[LAST_MAPS_SAVE][32];
new gLastMapTime[LAST_MAPS_SAVE];
new gNumLastMaps;

public plugin_init() {
	register_plugin("Last Maps Time", "0.0.1", "Exolent");
	
	register_clcmd("say /harti", "CmdLastMaps");
	
	get_datadir(gSaveFile, charsmax(gSaveFile));
	add(gSaveFile, charsmax(gSaveFile), "/lastmaps.txt");
	
	new f = fopen(gSaveFile, "rt");
	
	if(f) {
		new line[64], minutes[12];
		
		while(!feof(f) && gNumLastMaps < LAST_MAPS_SAVE) {
			fgets(f, line, charsmax(line));
			trim(line);
			
			if(line[0]) {
				parse(line, gLastMapName[gNumLastMaps], charsmax(gLastMapName[]), minutes, charsmax(minutes));
				gLastMapTime[gNumLastMaps++] = str_to_num(minutes);
			}
		}
		
		fclose(f);
	}
}

public plugin_end() {
	new minutes = floatround(get_gametime() / 60.0, floatround_ceil);
	
	new map[32];
	get_mapname(map, charsmax(map));
	
	new f = fopen(gSaveFile, "wt");
	
	fprintf(f, "^"%s^" %d", map, minutes);
	
	if(gNumLastMaps == LAST_MAPS_SAVE) {
		gNumLastMaps--;
	}
	
	for(new i = 0; i < gNumLastMaps; i++) {
		fprintf(f, "^n^"%s^" %d", gLastMapName[i], gLastMapTime[i]);
	}
	
	fclose(f);
}

public CmdLastMaps(id) {
	if(gNumLastMaps) {
		new maps[192], len;
		for(new i = 0; i < gNumLastMaps; i++) {
			len += formatex(maps[len], charsmax(maps) - len, "%s%s (%dmin)", len ? ", " : "", gLastMapName[i], gLastMapTime[i]);
		}
		
		client_print(id, print_chat, "* Last Maps: %s", maps);
	} else {
		client_print(id, print_chat, "* Sorry, no last maps have been saved in the logs.");
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
