/// scr_facility_db — every facility that can sit in a chassis grid.
///
/// The central design rule: a facility's FOOTPRINT and POWER DRAW both grow
/// with its tier. Upgrading an arc laser from I to III turns a single cell into
/// a three-cell bar, so you can't just buy upgrades — you have to re-pack the
/// whole car around them. That, plus the reactor budget, is the choice pressure.
///
/// Cell offsets are normalised so the minimum x and y are both 0.

// --- shape vocabulary -------------------------------------------------------
function shp_single() { return [[0, 0]]; }                              // ▪
function shp_dom_h()  { return [[0, 0], [1, 0]]; }                      // ▪▪
function shp_dom_v()  { return [[0, 0], [0, 1]]; }                      // ▪ over ▪
function shp_bar()    { return [[0, 0], [1, 0], [2, 0]]; }              // ▪▪▪
function shp_ell()    { return [[0, 0], [0, 1], [1, 1]]; }              // L
function shp_corner() { return [[0, 0], [1, 0], [0, 1]]; }              // ⌐
function shp_square() { return [[0, 0], [1, 0], [0, 1], [1, 1]]; }      // 2x2
function shp_tee()    { return [[0, 0], [1, 0], [2, 0], [1, 1]]; }      // T
function shp_zig()    { return [[1, 0], [2, 0], [0, 1], [1, 1]]; }      // S

/// Fill a definition out with defaults so consuming code never has to
/// existence-check a field.
function _fac(_o) {
    var d = {
        id: "", name: "", family: "", tier: 1, cat: "utility", desc: "",
        cells: [[0, 0]], power: 0, gen: 0, hp: 5, cost: 40,

        // weapons
        charge: 0, dmg: 0, shots: 1, pierce: 0,
        applies: "", applies_dur: 0, harpoon: 0, hull_bonus: 0, scatter: false,

        // defence
        armour: 0, shield: 0, regen: 0, pd: 0, resist: "",

        // utility
        drones: 0, chg_mult: 1, scrap_mult: 1, sensors: false,
    };
    var keys = variable_struct_get_names(_o);
    for (var i = 0; i < array_length(keys); i++) {
        variable_struct_set(d, keys[i], variable_struct_get(_o, keys[i]));
    }
    return d;
}

function facility_db_init() {
    if (variable_global_exists("FAC")) return;

    var db = {};
    var ids = [];

    var add = function(_db, _ids, _o) {
        var d = _fac(_o);
        variable_struct_set(_db, d.id, d);
        array_push(_ids, d.id);
    };

    // === POWER — generates, never consumes ==================================
    add(db, ids, { id: "reac_1", name: "REACTOR CORE I",   family: "reac", tier: 1, cat: "power",
        cells: shp_single(), gen: 5,  hp: 6,  cost: 0,
        desc: "Cracked fuel-cell stack. Supplies 5 power to the rig." });
    add(db, ids, { id: "reac_2", name: "REACTOR CORE II",  family: "reac", tier: 2, cat: "power",
        cells: shp_dom_h(),  gen: 8,  hp: 9,  cost: 55,
        desc: "Twin-cell stack. Supplies 8 power, and eats twice the floor." });
    add(db, ids, { id: "reac_3", name: "REACTOR CORE III", family: "reac", tier: 3, cat: "power",
        cells: shp_square(), gen: 12, hp: 13, cost: 120,
        desc: "Pre-Collapse fission block. 12 power, and a quarter of your grid." });

    // === MOBILITY — escape speed and evasion ================================
    add(db, ids, { id: "drv_1", name: "DRIVE TRAIN I",   family: "drv", tier: 1, cat: "move",
        cells: shp_single(), power: 1, hp: 5,  cost: 30,
        desc: "Stock axle. Slow break-away, 5% evasion." });
    add(db, ids, { id: "drv_2", name: "DRIVE TRAIN II",  family: "drv", tier: 2, cat: "move",
        cells: shp_dom_v(),  power: 2, hp: 8,  cost: 70,
        desc: "Reground gearbox. Faster break-away, 12% evasion." });
    add(db, ids, { id: "drv_3", name: "DRIVE TRAIN III", family: "drv", tier: 3, cat: "move",
        cells: shp_ell(),    power: 3, hp: 11, cost: 140,
        desc: "Turbine coupling. Rapid break-away, 20% evasion." });

    // === WEAPONS ============================================================
    add(db, ids, { id: "las_1", name: "ARC LASER I",   family: "las", tier: 1, cat: "weapon",
        cells: shp_single(), power: 1, hp: 4, cost: 35,
        charge: 3.5, dmg: 1, shots: 1, pierce: 1,
        desc: "Fast pulse. Shrugs off 1 armour but won't dent a shield." });
    add(db, ids, { id: "las_2", name: "ARC LASER II",  family: "las", tier: 2, cat: "weapon",
        cells: shp_dom_h(),  power: 2, hp: 6, cost: 85,
        charge: 3.0, dmg: 1, shots: 2, pierce: 2,
        desc: "Double pulse. Two shots per charge, shrugs off 2 armour." });
    add(db, ids, { id: "las_3", name: "ARC LASER III", family: "las", tier: 3, cat: "weapon",
        cells: shp_bar(),    power: 3, hp: 8, cost: 165,
        charge: 2.8, dmg: 1, shots: 3, pierce: 3,
        desc: "Triple pulse. Strips three shield layers, and ignores 3 armour." });

    add(db, ids, { id: "riv_1", name: "RIVET CANNON I",  family: "riv", tier: 1, cat: "weapon",
        cells: shp_dom_h(), power: 2, hp: 6, cost: 60,
        charge: 7.0, dmg: 3, hull_bonus: 1,
        desc: "Slow mass driver. Heavy facility damage and it bites the hull." });
    add(db, ids, { id: "riv_2", name: "RIVET CANNON II", family: "riv", tier: 2, cat: "weapon",
        cells: shp_ell(),   power: 3, hp: 9, cost: 130,
        charge: 6.5, dmg: 4, hull_bonus: 2,
        desc: "Siege driver. Wrecks a facility outright and caves the chassis." });

    add(db, ids, { id: "tes_1", name: "TESLA COIL I",  family: "tes", tier: 1, cat: "weapon",
        cells: shp_single(), power: 2, hp: 5, cost: 55,
        charge: 5.0, dmg: 1, applies: "elec", applies_dur: 3,
        desc: "Arc discharge. Knocks the struck facility offline for 3s." });
    add(db, ids, { id: "tes_2", name: "TESLA COIL II", family: "tes", tier: 2, cat: "weapon",
        cells: shp_corner(), power: 3, hp: 8, cost: 120,
        charge: 4.5, dmg: 1, shots: 2, applies: "elec", applies_dur: 4,
        desc: "Twin arc. Two facilities offline for 4s a hit." });

    add(db, ids, { id: "flm_1", name: "FLAMER POD I",  family: "flm", tier: 1, cat: "weapon",
        cells: shp_dom_v(), power: 2, hp: 5, cost: 55,
        charge: 5.5, dmg: 1, applies: "fire", applies_dur: 6,
        desc: "Ignites the target. Fire burns it down and spreads to neighbours." });
    add(db, ids, { id: "flm_2", name: "FLAMER POD II", family: "flm", tier: 2, cat: "weapon",
        cells: shp_ell(),   power: 3, hp: 8, cost: 120,
        charge: 5.0, dmg: 1, shots: 2, applies: "fire", applies_dur: 7,
        desc: "Twin nozzles. Two ignition points is usually an inferno." });

    add(db, ids, { id: "acd_1", name: "ACID SPRAYER I",  family: "acd", tier: 1, cat: "weapon",
        cells: shp_single(), power: 2, hp: 5, cost: 60,
        charge: 5.5, dmg: 1, applies: "acid", applies_dur: 8,
        desc: "Eats armour plating and amplifies every follow-up hit." });
    add(db, ids, { id: "acd_2", name: "ACID SPRAYER II", family: "acd", tier: 2, cat: "weapon",
        cells: shp_dom_h(),  power: 3, hp: 7, cost: 125,
        charge: 5.0, dmg: 2, applies: "acid", applies_dur: 10,
        desc: "Pressurised. The answer to anything wearing plate." });

    add(db, ids, { id: "oil_1", name: "SLICK LAUNCHER", family: "oil", tier: 1, cat: "weapon",
        cells: shp_dom_h(), power: 1, hp: 5, cost: 45,
        charge: 6.0, dmg: 0, applies: "oil", applies_dur: 9,
        desc: "No damage. Halves the target's speed — and oil catches." });

    add(db, ids, { id: "hrp_1", name: "HARPOON GUN", family: "hrp", tier: 1, cat: "weapon",
        cells: shp_dom_v(), power: 2, hp: 7, cost: 70,
        charge: 8.0, dmg: 2, harpoon: 6,
        desc: "Cable spike. Pins the target — nobody breaks away for 6s." });

    // Self-contained: draws no power, so it can be the entire contents of a
    // one-cell chassis. Enemy-only — cost 0 keeps it out of shop stock.
    add(db, ids, { id: "drn_1", name: "DRONE CORE", family: "drn", tier: 1, cat: "weapon",
        cells: shp_single(), power: 0, hp: 4, cost: 0,
        charge: 4.5, dmg: 1, pierce: 1,
        desc: "A whole vehicle in one cell: its own cell stack and a pop-gun laser." });

    add(db, ids, { id: "sct_1", name: "SCATTERGUN I",  family: "sct", tier: 1, cat: "weapon",
        cells: shp_dom_h(), power: 2, hp: 6, cost: 65,
        charge: 6.0, dmg: 1, shots: 3, scatter: true,
        desc: "Three pellets at random facilities. Can't be aimed." });
    add(db, ids, { id: "sct_2", name: "SCATTERGUN II", family: "sct", tier: 2, cat: "weapon",
        cells: shp_tee(),   power: 3, hp: 9, cost: 140,
        charge: 5.5, dmg: 1, shots: 5, scatter: true,
        desc: "Five pellets, scattered. Punishing against a packed grid." });

    // === DEFENCE ============================================================
    // Armour is always a four-cell slab — the one family whose footprint does
    // NOT grow with tier. Bolting plate on is a quarter of a stock chassis
    // whatever the grade, so it's the biggest spatial commitment in the game;
    // the tiers buy protection, and a nastier shape to pack around.
    add(db, ids, { id: "plt_1", name: "ABLATIVE PLATE I",   family: "plt", tier: 1, cat: "defence",
        cells: shp_square(), power: 0, hp: 8,  cost: 25,  armour: 1,
        desc: "Bolted scrap, welded as one four-cell slab. -1 damage from every hit (never below 1), no power. Acid ruins it." });
    add(db, ids, { id: "plt_2", name: "ABLATIVE PLATE II",  family: "plt", tier: 2, cat: "defence",
        cells: shp_tee(),    power: 0, hp: 12, cost: 75,  armour: 2,
        desc: "Layered plate. -2 damage from every hit. Same four cells, in a shape that fights you." });
    add(db, ids, { id: "plt_3", name: "ABLATIVE PLATE III", family: "plt", tier: 3, cat: "defence",
        cells: shp_zig(),    power: 0, hp: 16, cost: 150, armour: 3,
        desc: "Composite slab. -3 damage from every hit, no power — and four cells in the worst possible arrangement." });

    add(db, ids, { id: "shd_1", name: "DEFLECTOR FIELD I",   family: "shd", tier: 1, cat: "defence",
        cells: shp_single(), power: 2, hp: 5,  cost: 65,  shield: 1, regen: 11,
        desc: "One shield layer. Eats a whole shot, then recharges." });
    add(db, ids, { id: "shd_2", name: "DEFLECTOR FIELD II",  family: "shd", tier: 2, cat: "defence",
        cells: shp_dom_h(),  power: 3, hp: 8,  cost: 135, shield: 2, regen: 9,
        desc: "Two layers. Lasers strip them fast; rivets waste themselves on them." });
    add(db, ids, { id: "shd_3", name: "DEFLECTOR FIELD III", family: "shd", tier: 3, cat: "defence",
        cells: shp_square(), power: 4, hp: 11, cost: 230, shield: 3, regen: 8,
        desc: "Three layers. Corporate-grade. Costs a quarter grid and 4 power." });

    add(db, ids, { id: "pdc_1", name: "POINT DEFENCE", family: "pdc", tier: 1, cat: "defence",
        cells: shp_single(), power: 2, hp: 5, cost: 70, pd: 0.25,
        desc: "25% chance to swat an incoming shot out of the air." });
    add(db, ids, { id: "col_1", name: "COOLANT RIG", family: "col", tier: 1, cat: "defence",
        cells: shp_dom_h(), power: 1, hp: 7, cost: 50, resist: "fire",
        desc: "Halves fire duration and slowly smothers burns rig-wide." });
    add(db, ids, { id: "srg_1", name: "SURGE BREAKER", family: "srg", tier: 1, cat: "defence",
        cells: shp_single(), power: 1, hp: 6, cost: 50, resist: "elec",
        desc: "Halves how long electricity keeps a facility offline." });
    add(db, ids, { id: "scb_1", name: "SLICK SCRUBBER", family: "scb", tier: 1, cat: "defence",
        cells: shp_single(), power: 1, hp: 6, cost: 40, resist: "oil",
        desc: "Burns off oil fast, before somebody puts a match to it." });

    // === UTILITY ============================================================
    add(db, ids, { id: "rep_1", name: "REPAIR BAY I",  family: "rep", tier: 1, cat: "utility",
        cells: shp_single(), power: 1, hp: 6, cost: 55, drones: 1,
        desc: "One repair drone. Send it to patch damage or beat out fires." });
    add(db, ids, { id: "rep_2", name: "REPAIR BAY II", family: "rep", tier: 2, cat: "utility",
        cells: shp_dom_v(),  power: 2, hp: 9, cost: 120, drones: 2,
        desc: "Two drones. The difference between a fire and a write-off." });

    add(db, ids, { id: "tgt_1", name: "TARGETING RIG I",  family: "tgt", tier: 1, cat: "utility",
        cells: shp_single(), power: 1, hp: 5, cost: 60,  chg_mult: 1.20,
        desc: "All weapons charge 20% faster." });
    add(db, ids, { id: "tgt_2", name: "TARGETING RIG II", family: "tgt", tier: 2, cat: "utility",
        cells: shp_dom_h(),  power: 2, hp: 7, cost: 125, chg_mult: 1.40,
        desc: "All weapons charge 40% faster. Worth more than another gun." });

    add(db, ids, { id: "crg_1", name: "CARGO RACK", family: "crg", tier: 1, cat: "utility",
        cells: shp_dom_h(), power: 0, hp: 8, cost: 55, scrap_mult: 1.25,
        desc: "+25% scrap from every win. No power, but it hogs two cells." });
    add(db, ids, { id: "sen_1", name: "SENSOR MAST", family: "sen", tier: 1, cat: "utility",
        cells: shp_single(), power: 1, hp: 5, cost: 45, sensors: true,
        desc: "Reads enemy charge timers and reveals atlas nodes ahead." });

    global.FAC = db;
    global.FAC_IDS = ids;
}

/// Look a definition up by id.
function fac(_id) {
    return variable_struct_get(global.FAC, _id);
}

/// True if the id names a real facility.
function fac_exists(_id) {
    return variable_struct_exists(global.FAC, _id);
}

/// Bounding box of a cell list, as [w, h].
function shape_extent(_cells) {
    var mx = 0, my = 0;
    for (var i = 0; i < array_length(_cells); i++) {
        mx = max(mx, _cells[i][0]);
        my = max(my, _cells[i][1]);
    }
    return [mx + 1, my + 1];
}

/// Rotate a cell list 90 degrees clockwise, re-normalised to origin.
function shape_rotate(_cells) {
    var out = [];
    var min_x = 999, min_y = 999;
    for (var i = 0; i < array_length(_cells); i++) {
        // (x, y) -> (-y, x) is CCW in screen space; use (y, -x) for CW.
        var nx = -_cells[i][1];
        var ny =  _cells[i][0];
        array_push(out, [nx, ny]);
        min_x = min(min_x, nx);
        min_y = min(min_y, ny);
    }
    for (var i = 0; i < array_length(out); i++) {
        out[i] = [out[i][0] - min_x, out[i][1] - min_y];
    }
    return out;
}

/// Apply `_rot` quarter-turns to a definition's shape.
function shape_rotated(_cells, _rot) {
    var c = _cells;
    var n = ((_rot % 4) + 4) % 4;
    for (var i = 0; i < n; i++) c = shape_rotate(c);
    return c;
}

/// The next tier up in a family, or "" if this is the top.
function fac_next_tier(_id) {
    var d = fac(_id);
    for (var i = 0; i < array_length(global.FAC_IDS); i++) {
        var o = fac(global.FAC_IDS[i]);
        if (o.family == d.family && o.tier == d.tier + 1) return o.id;
    }
    return "";
}

/// All ids in a category, useful for shop stock generation.
function fac_ids_in_cat(_cat) {
    var out = [];
    for (var i = 0; i < array_length(global.FAC_IDS); i++) {
        if (fac(global.FAC_IDS[i]).cat == _cat) array_push(out, global.FAC_IDS[i]);
    }
    return out;
}

/// A one-line stat summary for shop rows and tooltips.
function fac_stat_line(_id) {
    var d = fac(_id);
    var parts = [];
    if (d.gen    > 0) array_push(parts, "+" + string(d.gen) + " PWR");
    if (d.power  > 0) array_push(parts, string(d.power) + " PWR");
    if (d.charge > 0) {
        var s = ui_secs(d.charge) + " / " + string(d.dmg) + " DMG";
        if (d.shots > 1) s += " x" + string(d.shots);
        array_push(parts, s);
    }
    if (d.pierce  > 0) array_push(parts, "PIERCE " + string(d.pierce));
    if (d.applies != "") array_push(parts, string_upper(d.applies) + " " + string(d.applies_dur) + "s");
    if (d.harpoon > 0) array_push(parts, "HARPOON " + string(d.harpoon) + "s");
    if (d.armour  > 0) array_push(parts, "ARMOUR " + string(d.armour));
    if (d.shield  > 0) array_push(parts, "SHIELD " + string(d.shield));
    if (d.pd      > 0) array_push(parts, "INTERCEPT " + string(round(d.pd * 100)) + "%");
    if (d.resist != "") array_push(parts, "RESIST " + string_upper(d.resist));
    if (d.drones  > 0) array_push(parts, "+" + string(d.drones) + " DRONE");
    if (d.chg_mult   != 1) array_push(parts, "+" + string(round((d.chg_mult - 1) * 100)) + "% CHARGE");
    if (d.scrap_mult != 1) array_push(parts, "+" + string(round((d.scrap_mult - 1) * 100)) + "% SCRAP");
    if (d.sensors) array_push(parts, "SENSORS");
    array_push(parts, string(array_length(d.cells)) + " CELL" + (array_length(d.cells) > 1 ? "S" : ""));

    var s = "";
    for (var i = 0; i < array_length(parts); i++) {
        if (i > 0) s += "  ";
        s += parts[i];
    }
    return s;
}
