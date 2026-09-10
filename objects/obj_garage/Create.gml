game_init();

if (!run_exists()) run_new();
if (!variable_global_exists("garage_ctx")) global.garage_ctx = { shop: false, from_map: false, stock: [] };
// An older context from before this field existed still has to open cleanly.
if (!variable_struct_exists(global.garage_ctx, "from_map")) global.garage_ctx.from_map = false;

// Grid geometry. The cell size shrinks as the chassis is widened so the rig —
// including its cab overhang — always clears the inventory panel to the right.
gx = 48;
gy = 180;
cs = 58;

/// Recompute the cell size so the whole rig clears the inventory panel.
///
/// With painted bodywork the grid is pinned to the roof panel, and a postie is
/// nearly three times longer than its cargo roof — so the space the rig needs
/// is the grid divided by the roof's share of the sprite, not the grid plus a
/// bonnet. Sizing off the old procedural footprint drove the nose straight
/// under the trailer list.
function garage_fit() {
    var c = global.run.car;
    var has_art = variable_struct_exists(c, "art") && c.art != -1;

    if (!has_art) {
        // Procedural cutaway: grid, padding, bonnet and rear furniture.
        cs = floor(min(58, 440 / (c.gw + 1.85)));
        cs = max(28, cs);
        return;
    }

    var roof = variable_struct_exists(c, "art_roof") ? c.art_roof : [0, 0, 1, 1];
    var rw = max(0.05, roof[2] - roof[0]);
    var rh = max(0.05, roof[3] - roof[1]);

    // Room available to the left of the trailer list, and above the readouts.
    var avail_w = 448, avail_h = 296;
    cs = floor(min(58, avail_w * rw / c.gw, avail_h * rh / c.gh));
    cs = max(22, cs);
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
