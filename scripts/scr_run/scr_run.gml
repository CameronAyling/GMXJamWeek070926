/// scr_run — the run: what you own, where you are, and how close the repo line is.
///
/// Everything here lives in global.run so it survives room_goto. Non-persistent
/// controllers rebuild themselves on every room change; the run does not.

#macro SECTOR_COUNT 3

function run_new() {
    global.run = {
        sector: 1,
        scrap: 40,
        fuel: 10,
        car: car_new_player(),

        inv: ["rep_1", "plt_1"],   // owned, not currently bolted on

        map: undefined,
        node: 0,
        moves: 0,
        convoy: -1.6,              // repo line position, in map columns

        log: [],
        result: "",                // "dead" | "won" | "" while running
        kills: 0,
        boss_beaten: false,
    };

    map_generate();
    run_log("Tank's full. The atlas says three sectors to the border.");
    run_log("Repo line is somewhere behind you. Don't let it catch up.");
}

function run_exists() {
    return variable_global_exists("run") && is_struct(global.run);
}

/// Append a line to the rolling status log shown on the map screen.
function run_log(_msg) {
    array_push(global.run.log, _msg);
    while (array_length(global.run.log) > 40) array_delete(global.run.log, 0, 1);
}

function run_add_scrap(_n) {
    global.run.scrap = max(0, global.run.scrap + _n);
}

function run_add_fuel(_n) {
    global.run.fuel = max(0, global.run.fuel + _n);
}

/// Hull damage outside combat (events, the convoy catching you).
function run_damage_hull(_n) {
    var c = global.run.car;
    c.hull = max(0, c.hull - _n);
    if (c.hull <= 0) run_end("dead");
}

function run_repair_hull(_n) {
    var c = global.run.car;
    c.hull = min(c.hull_max, c.hull + _n);
}

function run_end(_result) {
    global.run.result = _result;
}

function sector_name(_n) {
    switch (_n) {
        case 1:  return "THE RUSTBELT APPROACH";
        case 2:  return "NEON FLATS";
        case 3:  return "THE CREDITOR CORRIDOR";
        default: return "UNCHARTED";
    }
}

/// Roughly how tough enemies should be right now: ~0.85 leaving the yard, ~2.1
/// at the border.
///
/// It opens below 1.0 because you start on nine cells with four facilities —
/// the first couple of fights happen before you've won any deck to build on,
/// and they have to be survivable at that size. The curve then climbs faster
/// than it used to, so the top end lands in the same place.
function run_difficulty() {
    var r = global.run;
    var through = 0;
    if (is_struct(r.map)) through = r.moves / max(1, r.map.cols * 1.5);
    return 0.85 + (r.sector - 1) * 0.45 + through * 0.25;
}

/// Move to the next sector, or win the run after the last one.
function run_next_sector() {
    var r = global.run;
    if (r.sector >= SECTOR_COUNT) {
        // The border is shut. One last creditor stands in the way.
        combat_begin("corps", false, true);
        return;
    }
    r.sector += 1;
    r.convoy = -1.6;
    r.moves = 0;
    map_generate();
    run_log("=== SECTOR " + string(r.sector) + " — " + sector_name(r.sector) + " ===");
    run_log("New atlas page. The repo line reset to the sector line behind you.");
}

/// Total repair-drone count available in combat.
function run_drones() {
    return car_drones(global.run.car);
}

// --- economy ----------------------------------------------------------------

#macro HULL_REPAIR_COST 3    // scrap per hull point
#macro FAC_REPAIR_COST  9    // scrap to un-wreck one facility
#macro FUEL_COST        11   // scrap per litre

/// Highest facility tier a shop will stock this deep into the run.
function shop_max_tier() {
    return min(3, global.run.sector + 1);
}

/// Five things to sell, biased away from what you already have equipped.
function shop_stock() {
    var maxt = shop_max_tier();
    var pool = [];
    for (var i = 0; i < array_length(global.FAC_IDS); i++) {
        var d = fac(global.FAC_IDS[i]);
        if (d.cost <= 0) continue;
        if (d.tier > maxt) continue;
        array_push(pool, d.id);
    }

    var stock = [];
    var guard = 0;
    while (array_length(stock) < 5 && guard < 200 && array_length(pool) > 0) {
        guard += 1;
        var pick = pool[irandom(array_length(pool) - 1)];
        var dupe = false;
        for (var i = 0; i < array_length(stock); i++) if (stock[i] == pick) dupe = true;
        if (!dupe) array_push(stock, pick);
    }
    return stock;
}

/// Rear bays are earned free by winning fights (see combat_exit). You can also
/// buy one outright, but deliberately at a premium — the price is roughly four
/// fights' salvage, so paying for deck is impatience, not a strategy. Useful if
/// you've been running from everything.
function bay_cost(_car) { return 160 + _car.bays * 70; }   // 160, 230, 300

/// The trailer is never earned — it's the one piece of chassis you must buy.
function trailer_cost() { return 340; }

/// Scrap back for selling something out of the inventory.
function sell_price(_id) {
    return max(5, round(fac(_id).cost * 0.55));
}

/// Open the garage. `_shop` adds the truck-stop trading panel.
function garage_open(_shop) {
    global.garage_ctx = {
        shop: _shop,
        stock: _shop ? shop_stock() : [],
    };
    goto_room(rm_garage);
}

/// How many facilities are sitting wrecked and need paying for.
function run_wrecked_count() {
    var c = global.run.car;
    var n = 0;
    for (var i = 0; i < array_length(c.facs); i++) if (c.facs[i].hp <= 0) n += 1;
    return n;
}

/// Scrap awarded for a win, before the cargo-rack multiplier.
function run_combat_reward(_elite, _boss) {
    var base = 22 + irandom(14) + round(run_difficulty() * 8);
    if (_elite) base = round(base * 1.6);
    if (_boss)  base = round(base * 2.5);
    return round(base * car_scrap_mult(global.run.car));
}
