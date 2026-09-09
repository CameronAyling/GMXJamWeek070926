game_init();

if (!run_exists()) run_new();
if (!variable_global_exists("garage_ctx")) global.garage_ctx = { shop: false, stock: [] };

// Grid geometry. The cell size shrinks as the chassis is widened so the rig —
// including its cab overhang — always clears the inventory panel to the right.
gx = 48;
gy = 180;
cs = 58;

/// Recompute the cell size for the current chassis width.
function garage_fit() {
    var gw = global.run.car.gw;
    // Overhead footprint: gw*cs of grid, 0.6*cs of padding, a 0.9*cs bonnet
    // and ~0.3*cs of rear bumper and exhaust.
    cs = floor(min(58, 440 / (gw + 1.85)));
    cs = max(28, cs);
}

garage_fit();

// The piece currently on the cursor.
held      = "";     // facility def id, "" when empty-handed
held_rot  = 0;
held_from = -1;     // inventory index it was lifted from, -1 if lifted off the car

inv_scroll = 0;
msg = "";
msg_t = 0;

function garage_msg(_s) {
    msg = _s;
    msg_t = 3.2;
}

/// Put whatever is on the cursor back in the inventory.
function garage_stow() {
    if (held == "") return;
    array_push(global.run.inv, held);
    held = "";
    held_rot = 0;
    held_from = -1;
}
