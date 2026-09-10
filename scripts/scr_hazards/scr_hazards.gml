/// scr_hazards — bad country, printed onto the atlas.
///
/// A few stops per sector sit inside a hazard. Each one hooks a different
/// system — fuel, status, accuracy, repair, escape — so routing around them is
/// a question of which of your systems you're willing to fight without, not
/// just "avoid the red ones".
///
/// A hazard marked `combat: false` bites when you drive into the node. The
/// rest bite during the fight that happens there, so those are only ever
/// placed on nodes that actually hold a fight.

/// Defaults-merge, same shape as the facility DB.
function _haz(_id, _name, _short, _blurb, _fields) {
    var d = {
        id: _id, name: _name, short: _short, blurb: _blurb,
        combat: true,        // only matters once the shooting starts?
        fuel_mult: 1,        // fuel burned driving in
        evade_bonus: 0,      // added to everyone's evasion — nobody can see
        repair_mult: 1,      // drone repair speed
        escape_mult: 1,      // break-away spool speed
        drip: "",            // status dripped onto a random facility, both cars
        drip_every: 0,       // seconds between drips
        drip_dur: 0,         // seconds of status each drip applies
    };
    var keys = variable_struct_get_names(_fields);
    for (var i = 0; i < array_length(keys); i++) {
        variable_struct_set(d, keys[i], variable_struct_get(_fields, keys[i]));
    }
    return d;
}

function hazard_db() {
    if (variable_global_exists("HAZ")) return global.HAZ;

    global.HAZ = {
        rough: _haz("rough", "ROUGH GOING", "ROUGH",
            "Washouts and broken slab. Twice the fuel to get across it.",
            { combat: false, fuel_mult: 2 }),

        acidrain: _haz("acidrain", "ACID RAIN", "ACID",
            "It comes in through the vents. Everything on the road corrodes — theirs too.",
            { drip: "acid", drip_every: 3.4, drip_dur: 4.5 }),

        duststorm: _haz("duststorm", "DUST STORM", "DUST",
            "Nobody can see past their own bonnet. Every gun out here shoots worse.",
            { evade_bonus: 0.30 }),

        interference: _haz("interference", "STATIC FIELD", "STATIC",
            "Interference off the pylons. Your drones crawl and the fires get a head start.",
            { repair_mult: 0.40 }),

        climb: _haz("climb", "THE LONG CLIMB", "CLIMB",
            "A gradient that never tops out. The drive takes forever to spool — you're committed.",
            { escape_mult: 0.45 }),
    };
    return global.HAZ;
}

/// Definition for an id, or undefined for "" / anything unknown.
function hazard(_id) {
    if (!is_string(_id) || _id == "") return undefined;
    var db = hazard_db();
    if (!variable_struct_exists(db, _id)) return undefined;
    return variable_struct_get(db, _id);
}

/// Spot ink for a hazard, chosen so each reads distinctly over tan stock.
function hazard_colour(_id) {
    var p = global.PAL;
    switch (_id) {
        case "rough":     return p.atlas_road;
        case "acidrain":  return p.st_acid;
        case "duststorm": return p.amber;
        case "interference": return p.st_elec;
        case "climb":     return p.violet;
        default:          return p.atlas_alert;
    }
}

/// Any hazard, uniformly. Regions cover whatever nodes they land on, so the
/// "does this hazard have anything to bite here" question is answered by the
/// region validation in map_generate, not by the draw.
function hazard_pick_any() {
    var ids = variable_struct_get_names(hazard_db());
    return ids[irandom(array_length(ids) - 1)];
}

// ---------------------------------------------------------------- regions
//
// A hazard covers an area of the page, not a pin. The area is defined as a
// radius that varies with angle — two slow sine terms, so it comes out as an
// organic blob with no spikes. Membership and the drawn outline both read that
// same function, which is the whole point: a node is inside the hazard exactly
// when it is inside the shape you can see.

function hazard_region_new(_id, _cx, _cy, _base) {
    return {
        id: _id,
        cx: _cx, cy: _cy,
        base: _base,
        a1: 0.16 + random(0.16),  p1: random(360),
        a2: 0.07 + random(0.10),  p2: random(360),
    };
}

/// The region's edge distance at a given bearing from its centre.
function hazard_region_radius(_reg, _ang) {
    return _reg.base * (1
        + _reg.a1 * dsin(_ang * 2 + _reg.p1)
        + _reg.a2 * dsin(_ang * 3 + _reg.p2));
}

function hazard_region_contains(_reg, _px, _py) {
    var d = point_distance(_reg.cx, _reg.cy, _px, _py);
    if (d > _reg.base * 1.6) return false;          // cheap reject
    var a = point_direction(_reg.cx, _reg.cy, _px, _py);
    return (d <= hazard_region_radius(_reg, a));
}

/// Where a region's name could go, best first, as centre-top anchors for
/// label_place. Eight bearings hugging the blob, the same eight again further
/// out, and dead centre as a last resort — enough choices that a crowded
/// corner of the atlas can still find clear paper.
///
/// Shared with the tests on purpose: the check that names don't land on stops
/// has to be checking the same geometry the map actually draws.
function hazard_label_slots(_reg, _w, _h) {
    var out = [];
    var bear = [90, 270, 180, 0, 45, 135, 225, 315];
    for (var pass = 0; pass < 2; pass++) {
        for (var i = 0; i < array_length(bear); i++) {
            var a = bear[i];
            var rr = hazard_region_radius(_reg, a) + 12 + pass * 28;
            array_push(out, [_reg.cx + lengthdir_x(rr, a),
                             _reg.cy + lengthdir_y(rr, a) - _h * 0.5]);
        }
    }
    array_push(out, [_reg.cx, _reg.cy - _h * 0.5]);
    return out;
}

/// The region outline as a list of [x, y], for drawing.
function hazard_region_points(_reg, _steps = 30) {
    var pts = [];
    for (var i = 0; i < _steps; i++) {
        var a = i * (360 / _steps);
        var rr = hazard_region_radius(_reg, a);
        array_push(pts, [_reg.cx + lengthdir_x(rr, a), _reg.cy + lengthdir_y(rr, a)]);
    }
    return pts;
}

/// The hazard id sitting on the node you're parked at, or "" — used by combat,
/// which has no map of its own and may be running headless in a balance sim.
function hazard_here() {
    if (!variable_global_exists("run") || !is_struct(global.run)) return "";
    var r = global.run;
    if (!is_struct(r.map)) return "";
    if (r.node < 0 || r.node >= array_length(r.map.nodes)) return "";
    var n = r.map.nodes[r.node];
    if (!variable_struct_exists(n, "hazard")) return "";
    return n.hazard;
}

/// Litres to drive into a node.
function hazard_fuel_cost(_node) {
    if (!is_struct(_node) || !variable_struct_exists(_node, "hazard")) return 1;
    var h = hazard(_node.hazard);
    return (h == undefined) ? 1 : h.fuel_mult;
}

/// One-line effect summary for the map readout.
function hazard_effect_line(_id) {
    var h = hazard(_id);
    if (h == undefined) return "";
    switch (_id) {
        case "rough":     return "2 FUEL TO ENTER";
        case "acidrain":  return "ACID KEEPS LANDING";
        case "duststorm": return "EVERYONE MISSES MORE";
        case "interference": return "DRONES AT 40%";
        case "climb":     return "BREAK-AWAY AT 45%";
        default:          return "";
    }
}
