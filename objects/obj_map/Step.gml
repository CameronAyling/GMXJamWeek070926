goto_flush();   // start any queued room change — must happen before any Draw event

ui_begin();
t += dt();

var r = global.run;

// The run can end from an event outcome (hull hitting zero).
if (r.result != "") {
    goto_room(rm_gameover);
    exit;
}

// An event outcome can start a fight once the player dismisses it.
if (ev == undefined && variable_struct_exists(r, "pending_fight")) {
    var f = r.pending_fight;
    variable_struct_remove(r, "pending_fight");
    combat_begin(f, false, false);
    exit;
}

if (ev != undefined) exit;   // the event panel owns input while it's open
if (transitioning()) exit;   // already leaving — don't take another hop

// ---------------------------------------------------------------- the rig
// Re-pack the chassis from the road, any time. The atlas is the one screen
// where nothing is shooting at you, so making the player drive to a truck stop
// before they can move a facility only ever added a trip, never a decision.
if (keyboard_check_pressed(ord("G"))) {
    garage_open(false, true);
    exit;
}

// ---------------------------------------------------------------- hover
hover_node = -1;
for (var i = 0; i < array_length(r.map.nodes); i++) {
    var n = r.map.nodes[i];
    if (point_distance(ui_mx(), ui_my(), n.px, n.py) <= 20) hover_node = i;
}

// ---------------------------------------------------------------- travel
if (hover_node != -1 && hover_node != r.node && map_can_travel(hover_node)) {
    if (global.ui_click) {
        global.ui_click = false;
        var caught = map_travel(hover_node);
        if (caught == "caught") {
            // Late: the company sends a crew to repossess the freight, and they are
            // heavier than anything the sector spawns normally.
            combat_begin("corps", true, false);
            exit;
        }
        map_resolve_arrival();
        exit;
    }
}
