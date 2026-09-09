/// scr_factions — who's out there, and what they drive.
///
///   ROBOTS   lasers and tesla. Fast, focused, fragile. Shorts you out.
///   BANDITS  a pack of small cars. Harpoons so you can't run, fire and oil.
///   CORPS    shields, plate, point defence. Wants to outlast you — and it has
///            a repossession clock, so stalling loses.
///   INSECTS  the midpoint. Acid, armour, and steady self-repair.

function faction_name(_key) {
    switch (_key) {
        case "robots":  return "The Chrome Choir";
        case "bandits": return "The Rust Kings";
        case "corps":   return "Vantage Mutual";
        case "insects": return "The Chitin";
        default:        return "Unknown";
    }
}

function faction_colour(_key) {
    var p = global.PAL;
    switch (_key) {
        case "robots":  return p.st_elec;
        case "bandits": return p.st_fire;
        case "corps":   return p.cat_defence;
        case "insects": return p.st_acid;
        default:        return p.text;
    }
}

function faction_blurb(_key) {
    switch (_key) {
        case "robots":
            return "Autonomous freight that never got the recall notice, running its own drone escort. All its protection is field, none of it is frame.";
        case "bandits":
            return "Four cars welded out of six. They harpoon you first, argue about the split later, and nothing they lose ever comes back.";
        case "corps":
            return "Vantage Mutual recovery unit. It does not need to kill you. It needs you to still be here when the paperwork clears.";
        case "insects":
            return "Nobody agrees whether the chitin is armour or the driver. No cells, no wiring, nothing to short — acid first, patience second.";
        default:
            return "";
    }
}

/// Place a facility anywhere it fits. Tries every orientation, starting from a
/// random one, so a tight grid (a 3x3 hauler, a 2x2 bandit) packs reliably
/// instead of depending on one lucky guess.
function enemy_add(_car, _def_id) {
    if (!fac_exists(_def_id)) return false;
    var d = fac(_def_id);

    var start = irandom(3);
    for (var i = 0; i < 4; i++) {
        var rot = (start + i) mod 4;
        var cells = shape_rotated(d.cells, rot);
        var spot = car_find_space(_car, cells);
        if (is_array(spot)) {
            car_place(_car, _def_id, spot[0], spot[1], rot);
            return true;
        }
    }
    return false;
}

/// Add reactors until the car can actually run what's bolted to it.
function enemy_balance_power(_car) {
    if (_car.organic) return;   // nothing to balance — it has no power economy

    var guard = 0;
    while (car_power_demand(_car) > car_power_cap(_car) && guard < 8) {
        guard += 1;
        // Smallest first: it packs better, and it keeps a sector-1 enemy from
        // fielding tier-2 hardware just because it needed another cell of power.
        if (!enemy_add(_car, "reac_1")) {
            if (!enemy_add(_car, "reac_2")) break;
        }
    }
    car_enforce_power(_car);
}

/// Pick a tier-appropriate id from a family for the current difficulty.
/// `_cap` limits how high it will go — small chassis can't house tier 3.
function tier_pick(_family, _diff, _cap = 3) {
    // Thresholds track run_difficulty(): ~0.85-1.10 in sector 1, 1.30-1.55 in
    // sector 2, 1.75-2.00 in sector 3. So tier 2 lands as you enter sector 2
    // and tier 3 appears partway through sector 3.
    var want = 1;
    if (_diff > 1.45) want = 2;
    if (_diff > 1.80) want = 3;
    want = min(want, _cap);

    var best = "";
    for (var i = 0; i < array_length(global.FAC_IDS); i++) {
        var d = fac(global.FAC_IDS[i]);
        if (d.family != _family) continue;
        if (d.tier <= want && (best == "" || d.tier > fac(best).tier)) best = d.id;
    }
    return best;
}

/// Build one enemy vehicle. An `_organic` hull carries no reactor and needs
/// none, so every cell it has goes to kit.
function enemy_car(_faction, _name, _gw, _gh, _hull, _diff, _core, _pool, _fill, _organic = false, _cap_tier = 3) {
    var c = car_new(_name, _gw, _gh, _hull);
    c.faction = _faction;
    c.organic = _organic;

    if (!_organic) enemy_add(c, tier_pick("reac", _diff, _cap_tier));

    // Core goes on in order, so whatever the faction must never be without
    // gets first claim on the grid.
    for (var i = 0; i < array_length(_core); i++) {
        enemy_add(c, tier_pick(_core[i], _diff, _cap_tier));
    }

    var extras = _fill + ((_diff > 1.45) ? 1 : 0);
    for (var i = 0; i < extras; i++) {
        if (array_length(_pool) == 0) break;
        enemy_add(c, tier_pick(_pool[irandom(array_length(_pool) - 1)], _diff, _cap_tier));
    }

    enemy_balance_power(c);
    return c;
}

/// Enemy durability, superlinear in difficulty.
///
/// Measured, not guessed: the player's output scales faster than linearly with
/// difficulty because weapon tiers multiply shot count (a tier-3 laser fires
/// roughly four times as often as a tier-1) while a linear hull curve only
/// doubles. Flat scaling left sector 3 at a 95% win rate.
function enemy_hull(_base, _diff, _mult) {
    return max(4, round(_base * power(_diff, 1.7) * _mult));
}

/// The whole opposing force. Bandits return several cars; everyone else one.
function enemy_group(_faction, _diff, _elite, _boss) {
    var cars = [];
    var hull_mult = _elite ? 1.35 : 1;

    if (_boss) {
        // Trimmed from 7x5/84 when the player's chassis came down to a 3x3 that
        // maxes at sixteen cells — the finale should tower over you, not be
        // twice your rig with a clock on top.
        var b = car_new("THE FORECLOSURE", 6, 5, 58);
        b.faction = "corps";
        enemy_add(b, "reac_3");
        enemy_add(b, "shd_3");
        enemy_add(b, "plt_1");
        enemy_add(b, "riv_2");
        enemy_add(b, "tes_2");
        enemy_add(b, "hrp_1");
        enemy_add(b, "drv_2");
        enemy_balance_power(b);
        b.repo_max = 70;
        b.repo = 0;
        array_push(cars, b);
        return cars;
    }

    switch (_faction) {
        case "robots":
            // A 3x3 hauler escorted by single-cell drones. The drones are
            // trivial individually — the point is that they multiply the
            // number of shots in the air while the hauler works your reactor.
            // Shield first in the core, so a hauler is never without one even
            // when the rest of the kit can't find room. It pays for the field
            // with frame: the thinnest hull of anything on the road, and no
            // plate at all, so once the shield is stripped it folds fast.
            // Tier-capped at 2 — a tier-3 reactor or deflector would eat most
            // of a nine-cell grid on its own.
            array_push(cars, enemy_car("robots", "CHOIR HAULER", 3, 3,
                enemy_hull(13, _diff, hull_mult), _diff,
                ["shd", "las", "tes"], ["las", "tes", "tgt"], 1, false, 2));

            var swarm = (_diff > 1.70) ? 3 : ((_diff > 1.20) ? 2 : 1);
            for (var i = 0; i < swarm; i++) {
                var dc = car_new("CHOIR DRONE " + string(i + 1), 1, 1,
                                 enemy_hull(5, _diff, hull_mult));
                dc.faction = "robots";
                enemy_add(dc, "drn_1");
                array_push(cars, dc);
            }
            break;

        case "bandits":
            // Up to four two-by-two cars, each a one-trick specialist. Killing
            // one genuinely takes its trick off the table.
            // The Rust Kings are gone by sector 3, so their pack has to reach
            // full size inside sectors 1 and 2 or it never would.
            var pack = (_diff > 1.45) ? 4 : ((_diff > 1.05) ? 3 : 2);
            var tags = ["ALPHA", "BETA", "GAMMA", "DELTA"];
            var kits = [["hrp_1"], ["flm_1", "las_1"], ["oil_1", "las_1"], ["las_1", "las_1"]];
            for (var i = 0; i < pack; i++) {
                var bc = car_new("RUST KING " + tags[i], 2, 2,
                                 enemy_hull(13, _diff, hull_mult));
                bc.faction = "bandits";
                // Welded together out of other people's cars. Whatever you
                // break on a Rust King stays broken for the rest of the fight.
                bc.no_repair = true;
                enemy_add(bc, "reac_1");
                var kit = kits[i];
                for (var k = 0; k < array_length(kit); k++) enemy_add(bc, kit[k]);
                enemy_balance_power(bc);
                array_push(cars, bc);
            }
            break;

        case "corps":
            // Defensive wall on a clock. Sixteen cells, and the plate eats four
            // of them, so they are genuinely packed.
            var cc = enemy_car("corps", "VANTAGE ADJUSTER", 4, 4,
                enemy_hull(22, _diff, hull_mult), _diff,
                ["shd", "plt", "pdc", "riv"], ["shd", "las", "col", "pdc"], 1);
            cc.repo_max = max(32, 46 - _diff * 4);
            cc.repo = 0;
            array_push(cars, cc);
            break;

        default: // insects
            // Organic: no reactor, no power budget, so the whole grid is kit.
            // They only show up once you're deep enough to handle that.
            var ic = enemy_car("insects", "CHITIN DRIFTER", 4, 4,
                enemy_hull(17, _diff, hull_mult), _diff,
                ["acd", "plt", "las"], ["acd", "plt", "drv", "flm"], 2, true);
            ic.regen = 0.25 + _diff * 0.15;   // hp per second, spread over damage
            array_push(cars, ic);
            break;
    }

    return cars;
}

/// Kick off a fight. Stashes the context and jumps to the combat room.
function combat_begin(_faction, _elite = false, _boss = false) {
    global.combat_ctx = {
        faction: _boss ? "corps" : _faction,
        elite: _elite,
        boss: _boss,
        diff: run_difficulty() * (_elite ? 1.25 : 1),
    };
    goto_room(rm_combat);
}
