game_init();

if (!run_exists()) run_new();
if (!is_struct(global.run.map)) map_generate();

t = 0;

ev        = undefined;   // event currently on screen
ev_result = "";          // outcome line once a choice is taken

hover_node = -1;

/// Play out whatever is at the node you just arrived at.
function map_resolve_arrival() {
    var r = global.run;
    var n = map_node(r.node);

    // Roads run both ways now, so you can drive back through somewhere you've
    // already been. Whatever was here happened once and isn't happening again.
    if (n.resolved) {
        run_log("Back through " + map_node_title(n) + ". Nothing left here but tyre marks.");
        return;
    }

    switch (n.kind) {
        case "fight":
            n.resolved = true;
            combat_begin(n.faction, false, false);
            break;

        case "shop":
            n.resolved = true;
            run_log("Truck stop. Coffee, parts, and somebody's opinion about the road ahead.");
            garage_open(true);
            break;

        case "fuel":
            n.resolved = true;
            var amt = irandom_range(2, 4);
            run_add_fuel(amt);
            run_log("Fuel depot: +" + string(amt) + " litres.");
            break;

        case "event":
            n.resolved = true;
            ev = event_pick();
            ev_result = "";
            break;

        case "exit":
            n.resolved = true;
            run_next_sector();
            break;
    }
}
