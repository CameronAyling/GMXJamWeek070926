/// scr_car — the chassis grid and everything derived from what's bolted into it.
///
/// A car is a W x H grid of cells. `cells` holds an index into `facs` (or -1),
/// and is always rebuilt from `facs` after a mutation so the two can't drift.
/// Every aggregate stat — power, armour, shields, evasion — is recomputed from
/// the live facility list rather than cached, so damage and status effects
/// change the car's capabilities the instant they land.

function car_new(_name, _w, _h, _hull) {
    return {
        name: _name,
        gw: _w, gh: _h,
        hull: _hull, hull_max: _hull,
        cells: array_create(_w * _h, -1),
        // Which cells physically exist. The player's chassis grows a bay at a
        // time, so its grid is not always a full rectangle.
        mask: array_create(_w * _h, true),
        bays: 0,             // rear-bay upgrades bought, 0..4
        trailer: false,      // 2x2 trailer hitched on the back
        facs: [],

        shield_cur: 0,
        shield_timer: 0,
        harpoon: 0,          // seconds still pinned by a harpoon
        escape: 0,           // 0..1 break-away meter

        // enemy flavour
        faction: "",
        repo: 0,             // corporate repossession timer
        repo_max: 0,
        regen: 0,            // insect self-repair, hp per second
        organic: false,      // runs on chemistry, not cells: no reactor, no budget
        no_repair: false,    // nothing on this hull ever comes back: no regen, no shield recharge

        ai_focus: -1,        // player facility this car is concentrating on
        ai_timer: 0,
    };
}

/// A fresh instance of a facility definition, placed at (_ox, _oy).
function car_fac_new(_def_id, _ox, _oy, _rot) {
    var d = fac(_def_id);
    return {
        def: _def_id,
        ox: _ox, oy: _oy, rot: _rot,
        cells: shape_rotated(d.cells, _rot),
        hp: d.hp, hp_max: d.hp,
        powered: true,
        manual_off: false,   // the player cut this deliberately — don't auto-restore it
        charge: 0,
        target_car: -1,
        target_fac: -1,
        st: { elec: 0, fire: 0, oil: 0, acid: 0 },
        burn_t: 0,           // accumulator between fire damage ticks
        spread_t: 0,         // accumulator between fire spread attempts
        repair_t: 0,         // accumulator for drone repair progress
        flash: 0,            // hit feedback, seconds
    };
}

function car_in_bounds(_car, _cx, _cy) {
    return (_cx >= 0 && _cy >= 0 && _cx < _car.gw && _cy < _car.gh);
}

/// Is there actually deck here? Inside the bounding box isn't enough — a
/// part-built rear bay leaves holes in the grid.
function car_cell_exists(_car, _cx, _cy) {
    if (!car_in_bounds(_car, _cx, _cy)) return false;
    var i = _cy * _car.gw + _cx;
    if (i < 0 || i >= array_length(_car.mask)) return false;
    return _car.mask[i];
}

/// First body column. Anything to the left of it is trailer.
function car_body_x0(_car) {
    return _car.trailer ? 2 : 0;
}

/// Total usable cells.
function car_cell_count(_car) {
    var n = 0;
    for (var i = 0; i < array_length(_car.mask); i++) if (_car.mask[i]) n += 1;
    return n;
}

/// Facility index occupying a cell, or -1.
function car_at(_car, _cx, _cy) {
    if (!car_in_bounds(_car, _cx, _cy)) return -1;
    return _car.cells[_cy * _car.gw + _cx];
}

/// Recompute the occupancy grid from the facility list.
function car_rebuild_cells(_car) {
    _car.cells = array_create(_car.gw * _car.gh, -1);
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        for (var c = 0; c < array_length(f.cells); c++) {
            var cx = f.ox + f.cells[c][0];
            var cy = f.oy + f.cells[c][1];
            if (car_in_bounds(_car, cx, cy)) _car.cells[cy * _car.gw + cx] = i;
        }
    }
}

/// Can a shape sit at this origin? `_ignore` skips one facility index, so a
/// piece being dragged doesn't collide with where it currently sits.
function car_can_place(_car, _cells, _ox, _oy, _ignore = -1) {
    for (var c = 0; c < array_length(_cells); c++) {
        var cx = _ox + _cells[c][0];
        var cy = _oy + _cells[c][1];
        if (!car_cell_exists(_car, cx, cy)) return false;
        var occ = car_at(_car, cx, cy);
        if (occ != -1 && occ != _ignore) return false;
    }
    return true;
}

/// Place a facility. Returns its index, or -1 if it doesn't fit.
function car_place(_car, _def_id, _ox, _oy, _rot = 0) {
    var d = fac(_def_id);
    var cells = shape_rotated(d.cells, _rot);
    if (!car_can_place(_car, cells, _ox, _oy)) return -1;

    array_push(_car.facs, car_fac_new(_def_id, _ox, _oy, _rot));
    car_rebuild_cells(_car);
    return array_length(_car.facs) - 1;
}

/// Remove a facility, returning its definition id ("" if the index is bad).
function car_remove(_car, _idx) {
    if (_idx < 0 || _idx >= array_length(_car.facs)) return "";
    var def_id = _car.facs[_idx].def;
    array_delete(_car.facs, _idx, 1);
    car_rebuild_cells(_car);
    return def_id;
}

/// First origin the shape fits at, scanning row-major. Returns [x, y] or -1.
function car_find_space(_car, _cells) {
    for (var gy = 0; gy < _car.gh; gy++) {
        for (var gx = 0; gx < _car.gw; gx++) {
            if (car_can_place(_car, _cells, gx, gy)) return [gx, gy];
        }
    }
    return -1;
}

// --- live state predicates --------------------------------------------------

/// Wrecked facilities do nothing until repaired above 0 hp.
function fac_alive(_f) { return _f.hp > 0; }

/// A facility only contributes if it's intact, switched on, and not shorted out.
function fac_active(_f) {
    return (_f.hp > 0 && _f.powered && _f.st.elec <= 0);
}

// --- aggregate stats --------------------------------------------------------

function car_power_gen(_car) {
    // An organic hull has no power economy at all — everything bolted to it
    // just works. Returning an effectively infinite supply means every
    // use-vs-gen comparison in the game passes without special-casing.
    if (_car.organic) return 999;

    var t = 0;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (!fac_alive(f) || f.st.elec > 0) continue;
        t += fac(f.def).gen;
    }
    // Every chassis has a starter cell wired straight to the frame. It's worth
    // exactly one facility, and it means losing your reactor cripples you
    // instead of stranding you — the shed order keeps the drive train lit.
    return max(1, t);
}

/// Power drawn by facilities currently switched on (wrecked ones draw nothing).
function car_power_use(_car) {
    var t = 0;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (!f.powered || !fac_alive(f)) continue;
        t += fac(f.def).power;
    }
    return t;
}

/// Total draw if everything were switched on — what the garage validates against.
function car_power_demand(_car) {
    var t = 0;
    for (var i = 0; i < array_length(_car.facs); i++) t += fac(_car.facs[i].def).power;
    return t;
}

/// Maximum generation with nothing damaged — the garage's budget. Includes the
/// same one-power starter cell, so a reactorless rig can still run one thing.
function car_power_cap(_car) {
    var t = 0;
    for (var i = 0; i < array_length(_car.facs); i++) t += fac(_car.facs[i].def).gen;
    return max(1, t);
}

/// Armour subtracted from each incoming hit. Acid guts the plate it lands on.
function car_armour(_car) {
    var t = 0;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (!fac_alive(f)) continue;
        var a = fac(f.def).armour;
        if (a <= 0) continue;
        if (f.st.acid > 0) a = a * 0.34;   // acid is the anti-armour answer
        t += a;
    }
    return floor(t);
}

function car_shield_max(_car) {
    var t = 0;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (fac_active(f)) t += fac(f.def).shield;
    }
    return t;
}

/// Seconds to regenerate one shield layer — the best deflector wins.
function car_shield_regen(_car) {
    var best = 999;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (!fac_active(f)) continue;
        var d = fac(f.def);
        if (d.shield > 0) best = min(best, d.regen);
    }
    return best;
}

/// Chance (0..1) that an incoming shot is intercepted.
function car_intercept(_car) {
    var miss = 1;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (fac_active(f)) {
            var pd = fac(f.def).pd;
            if (pd > 0) miss *= (1 - pd);   // stacks multiplicatively
        }
    }
    return 1 - miss;
}

/// Chance (0..1) an incoming shot simply misses.
function car_evade(_car) {
    var e = 0;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (!fac_active(f)) continue;
        var d = fac(f.def);
        if (d.cat == "move") e += 0.05 + (d.tier - 1) * 0.075;
    }
    return min(e, 0.55);
}

/// Break-away meter fill per second.
function car_escape_rate(_car) {
    var r = 0;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (!fac_active(f)) continue;
        var d = fac(f.def);
        if (d.cat != "move") continue;
        var base = 0.055 + (d.tier - 1) * 0.032;
        if (f.st.oil > 0) base *= 0.5;
        r += base;
    }
    return r;
}

/// Repair drones. One is baseline crew — fires must always be fightable.
function car_drones(_car) {
    var n = 1;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (fac_active(f)) n += fac(f.def).drones;
    }
    return n;
}

/// Global weapon charge-rate multiplier from targeting rigs.
function car_charge_mult(_car) {
    var m = 1;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (fac_active(f)) m *= fac(f.def).chg_mult;
    }
    return m;
}

function car_scrap_mult(_car) {
    var m = 1;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (fac_alive(f)) m *= fac(f.def).scrap_mult;
    }
    return m;
}

function car_has_sensors(_car) {
    for (var i = 0; i < array_length(_car.facs); i++) {
        if (fac_active(_car.facs[i]) && fac(_car.facs[i].def).sensors) return true;
    }
    return false;
}

/// Multiplier applied to an incoming status duration. Resist rigs halve it.
function car_resist_mult(_car, _key) {
    var m = 1;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (fac_active(f) && fac(f.def).resist == _key) m *= 0.5;
    }
    return m;
}

/// Indices of every facility in a category.
function car_facs_of_cat(_car, _cat) {
    var out = [];
    for (var i = 0; i < array_length(_car.facs); i++) {
        if (fac(_car.facs[i].def).cat == _cat) array_push(out, i);
    }
    return out;
}

/// Indices of facilities orthogonally adjacent to this one — how fire spreads.
function car_neighbours(_car, _idx) {
    var f = _car.facs[_idx];
    var seen = {};
    var out = [];
    for (var c = 0; c < array_length(f.cells); c++) {
        var cx = f.ox + f.cells[c][0];
        var cy = f.oy + f.cells[c][1];
        var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
        for (var d = 0; d < 4; d++) {
            var n = car_at(_car, cx + dirs[d][0], cy + dirs[d][1]);
            if (n == -1 || n == _idx) continue;
            var key = string(n);
            if (variable_struct_exists(seen, key)) continue;
            variable_struct_set(seen, key, true);
            array_push(out, n);
        }
    }
    return out;
}

function car_is_dead(_car) { return _car.hull <= 0; }

/// Shut facilities off, cheapest-priority first, until draw fits generation.
/// Called when a reactor is damaged or shorted out mid-fight.
function car_enforce_power(_car) {
    var gen = car_power_gen(_car);
    var use = car_power_use(_car);
    if (use <= gen) return;

    // Shed order: utility, then weapons, then defence, then mobility. Losing a
    // cargo rack hurts less than losing the ability to run away.
    var order = ["utility", "weapon", "defence", "move"];
    for (var o = 0; o < array_length(order); o++) {
        for (var i = array_length(_car.facs) - 1; i >= 0; i--) {
            if (use <= gen) return;
            var f = _car.facs[i];
            if (!f.powered || !fac_alive(f)) continue;
            var d = fac(f.def);
            if (d.cat != order[o] || d.power <= 0) continue;
            f.powered = false;
            use -= d.power;
        }
    }
}

/// Switch back on anything the reactor can afford again that the player didn't
/// cut by hand. Without this, one tesla hit on the reactor would black the rig
/// out permanently — everything sheds, and nothing ever comes back.
function car_restore_power(_car) {
    var gen = car_power_gen(_car);
    var use = car_power_use(_car);
    if (use >= gen) return;

    // Restore in the reverse of the shed order: the things you'd miss most.
    var order = ["move", "defence", "weapon", "utility"];
    for (var o = 0; o < array_length(order); o++) {
        for (var i = 0; i < array_length(_car.facs); i++) {
            var f = _car.facs[i];
            if (f.powered || f.manual_off || !fac_alive(f)) continue;
            var d = fac(f.def);
            if (d.cat != order[o] || d.power <= 0) continue;
            if (use + d.power > gen) continue;
            f.powered = true;
            use += d.power;
        }
    }
}

// --- chassis growth ---------------------------------------------------------

/// Insert `_n` empty columns at the rear, shifting everything already fitted
/// forwards. The rear is x=0, so growth means making room at the low index.
function car_prepend_columns(_car, _n) {
    var ow = _car.gw;
    var nw = ow + _n;
    var nm = array_create(nw * _car.gh, false);

    for (var gy = 0; gy < _car.gh; gy++) {
        for (var gx = 0; gx < ow; gx++) {
            nm[gy * nw + (gx + _n)] = _car.mask[gy * ow + gx];
        }
    }

    _car.gw = nw;
    _car.mask = nm;
    for (var i = 0; i < array_length(_car.facs); i++) _car.facs[i].ox += _n;
    car_rebuild_cells(_car);
}

/// Order the rear bay fills in: middle outwards, so every new cell is
/// orthogonally touching one you already have and two-cell kit always fits.
function car_bay_row(_n) {
    var order = [1, 2, 0, 3];
    return order[_n % 4];
}

/// A rear bay is one cell, and the column is done when it's as tall as the
/// chassis — so a 3-tall rig takes three wins to widen, a 4-tall one takes four.
function car_max_bays(_car) { return _car.gh; }

function car_can_upgrade_bay(_car) { return (_car.bays < car_max_bays(_car)); }

/// Weld one more cell onto the rear bay. The first one opens a new column.
function car_upgrade_bay(_car) {
    if (!car_can_upgrade_bay(_car)) return false;

    if (_car.bays == 0) car_prepend_columns(_car, 1);

    var gy = min(car_bay_row(_car.bays), _car.gh - 1);
    _car.mask[gy * _car.gw + 0] = true;
    _car.bays += 1;
    car_rebuild_cells(_car);
    return true;
}

function car_can_attach_trailer(_car) {
    return (!_car.trailer && _car.bays >= car_max_bays(_car));
}

/// Hitch a 2x2 trailer on the back, centred on the chassis.
function car_attach_trailer(_car) {
    if (!car_can_attach_trailer(_car)) return false;

    car_prepend_columns(_car, 2);
    var y0 = max(0, floor((_car.gh - 2) * 0.5));
    for (var gy = y0; gy < min(y0 + 2, _car.gh); gy++) {
        _car.mask[gy * _car.gw + 0] = true;
        _car.mask[gy * _car.gw + 1] = true;
    }

    _car.trailer = true;
    car_rebuild_cells(_car);
    return true;
}

/// The player's starting rig: nine cells, five of them already spoken for.
///
/// The four that are left form exactly one 2x2 — which is exactly the shape of
/// the ablative plate sitting in your trailer. So the opening decision is a
/// clean one: bolt the plate on and fill the car completely, or keep the hole
/// and stay able to react.
function car_new_player() {
    var c = car_new("THE LAST CALL", 3, 3, 36);
    car_place(c, "reac_1", 0, 0);      // gen 5
    car_place(c, "las_1",  1, 0);      // 1 power
    car_place(c, "drv_1",  2, 0);      // 1 power
    car_place(c, "riv_1",  0, 1, 1);   // 2 power, two cells, stood on end
    return c;
}
