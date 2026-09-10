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
    // already been. An ambush or a roadside encounter happened once and isn't
    // happening again — but a truck stop is a business, and it's still open.
    if (n.resolved && n.kind != "shop") {
        run_log("Back through " + map_node_title(n) + ". Nothing left here but tyre marks.");
        return;
    }

    switch (n.kind) {
        case "fight":
            n.resolved = true;
            combat_begin(n.faction, false, false);
            break;

        case "shop":
            // The stop owns its shelves. They're rolled once and then kept, so
            // what you bought stays bought and what you couldn't afford is
            // still there when you come back for it — and bouncing between two
            // stops can't be used to re-roll the stock.
            if (!is_array(n.stock)) n.stock = shop_stock();
            if (n.resolved) {
                run_log(array_length(n.stock) > 0
                    ? "Back at the same truck stop. Same coffee, same shelves."
                    : "Back at the same truck stop. Shelves are bare, but the pumps work.");
            } else {
                run_log("Truck stop. Coffee, parts, and somebody's opinion about the road ahead.");
            }
            n.resolved = true;
            garage_open(true, false, n.stock);
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
