#include <amxmodx>
#include <amxmisc>
#define MAX_GROUPS 7
new g_groupNames[MAX_GROUPS][] = {
"Imperator",
"Legatus",
"Praetor",
"Centurion",
"Legionaries",
"Immunes",
"Roman (Slot)"
}
new g_groupFlags[MAX_GROUPS][] = {
"bcdefghijklmnopqrstu",
"bcdefghijlmnopqrsu",
"bcdefghijmnopqru",
"bcdefhiju",
"bcdefiju",
"biju",
"bz"
}
new g_groupFlagsValue[MAX_GROUPS]
public plugin_init() {
register_plugin("MIEZ - admin_who", "1.0", "mo0n_sniper & eXtreamCS")
register_concmd("admin_who", "cmdWho", 0)
for(new i = 0; i < MAX_GROUPS; i++) {
g_groupFlagsValue[i] = read_flags(g_groupFlags[i])
}
}
public cmdWho(id) {
new players[32], inum, player, name[32], i, a
get_players(players, inum)
console_print(id, "================================")
for(i = 0; i < MAX_GROUPS; i++) {
console_print(id, "=-=-=- [ %s ] -=-=-=", g_groupNames[i])
for(a = 0; a < inum; ++a) {
player = players[a]
get_user_name(player, name, 31)
if(get_user_flags(player) == g_groupFlagsValue[i]) {
console_print(id, "%s", name)
}
}
}
console_print(id, "================================")
return PLUGIN_HANDLED
}
