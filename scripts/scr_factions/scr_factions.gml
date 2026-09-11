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

/// Hang the right bodywork on a car, from its faction alone.
///
/// `art_roof` is the rectangle of the sprite the cell grid is pinned to, in
/// fractions of the canvas — measured off the art, and chosen roughly square
/// because every enemy chassis is square. Get it wrong in one axis and the
/// whole vehicle stretches in that axis, since the deck is what's held fixed.
///
///   robots   the wasp's striped abdomen is the deck
///   insects  same again on the beetle, with the wing pair flapping over the
///            thorax in front of it
///   corps    the long grey roof of the saloon, middle section
///   bandits  the tarp over the buggy's bed — and the only sprite painted
///            nose-left, so it carries art_flip to join the traffic
function faction_art(_car) {
    switch (_car.faction) {
        case "robots":
            _car.art      = Spr_Robot_Wasp;
            _car.art_roof = [0.58, 0.30, 0.90, 0.66];
            break;

        case "insects":
            _car.art             = Spr_Bug;
            _car.art_roof        = [0.58, 0.31, 0.90, 0.68];
            _car.art_wings       = Spr_Bug_Wings_Flap;
            _car.art_wings_at    = [0.45, 0.50];
            _car.art_wings_scale = 1.35;
            break;

        case "corps":
            // Drawn at the proportions it was painted at. The deck is a square
            // 250px patch of the grey roof — square in sprite PIXELS, not in
            // fractions, which is what keeps a square chassis from stretching
            // the saloon (0.25 x 998 == 0.60 x 416).
            //
            // Held to 500px on screen, half the canvas it was painted on and
            // about the footprint of the player's rig. Without the cap a
            // sixteen-cell deck asks for a car twice that: undistorted, but
            // towering over everything else on the road.
            _car.art         = Spr_Car_Corporate;
            _car.art_roof    = [0.275, 0.20, 0.525, 0.80];
            _car.art_uniform = true;
            _car.art_max_w   = 500;
            break;

        case "bandits":
            _car.art      = Spr_Car_Bandit;
            _car.art_roof = [0.17, 0.29, 0.62, 0.69];
            _car.art_flip = true;
            break;
    }
    return _car;
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

/// Fit the heaviest grade that will actually go on, walking down the list.
///
/// Armour is the family that needs this. A grade is only worth asking for if
/// the chassis has that exact shape free, and a sixteen-cell corp with a
/// reactor, a shield and a gun aboard has five cells left in whatever
/// arrangement the packing happened to leave — a five-cell plate lines up with
/// them about a quarter of the time. Asking for the slab and taking the square
/// when it won't go beats arriving with no plate at all.
function enemy_add_best(_car, _ids) {
    for (var i = 0; i < array_length(_ids); i++) {
        if (enemy_add(_car, _ids[i])) return _ids[i];
    }
    return "";
}

/// Armour grades to try for a difficulty, heaviest first.
///
/// Same thresholds tier_pick uses, so plate keeps step with every other family
/// — but expressed as a ladder, because whether a grade goes on is a question
/// about the shape of the room left, not just the sector.
function plate_ladder(_diff) {
    if (_diff > 1.80) return ["plt_3", "plt_2", "plt_1"];
    if (_diff > 1.45) return ["plt_2", "plt_1"];
    return ["plt_1"];
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
    faction_art(c);

    if (!_organic) enemy_add(c, tier_pick("reac", _diff, _cap_tier));

    // Core goes on in order, so whatever the faction must never be without
    // gets first claim on the grid. An entry given as an array is a ladder:
    // the heaviest grade that fits, rather than one grade or nothing.
    for (var i = 0; i < array_length(_core); i++) {
        if (is_array(_core[i])) enemy_add_best(c, _core[i]);
        else                    enemy_add(c, tier_pick(_core[i], _diff, _cap_tier));
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
        faction_art(b);
        enemy_add(b, "reac_3");
        enemy_add(b, "shd_3");
        // Composite, not the scrap grade — thirty cells of chassis can carry
        // the heaviest plate on the road and the finale should be wearing it.
        enemy_add(b, "plt_3");
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
                faction_art(dc);            // a little wasp, escorting the big one
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
                faction_art(bc);
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
            // Defensive wall on a clock. Sixteen cells, and by sector 3 the
            // plate alone eats six of them, so they are genuinely packed.
            //
            // Core order matters: the gun is claimed BEFORE the plate. With
            // plate second, a tier-3 reactor, shield and slab filled the grid
            // and the rivet cannon never found room — every late corp rolled
            // up unable to shoot, which turns their repossession clock from a
            // threat into a countdown you can ignore.
            //
            // The plate is pinned to grade II. The six-cell slab is more than a
            // third of their chassis, and asking for it just meant they arrived
            // with no plate at all. The Chitin carry no reactor, so they can
            // afford the heavy one; a corp buys its survivability in shields.
            var cc = enemy_car("corps", "VANTAGE ADJUSTER", 4, 4,
                enemy_hull(22, _diff, hull_mult), _diff,
                ["shd", "riv", plate_ladder(_diff), "pdc"], ["shd", "las", "col", "pdc"], 1);
            cc.repo_max = max(32, 46 - _diff * 4);
            cc.repo = 0;
            array_push(cars, cc);
            break;

        default: // insects
            // Organic: no reactor, no power budget, so the whole grid is kit.
            // They only show up once you're deep enough to handle that.
            var ic = enemy_car("insects", "CHITIN DRIFTER", 4, 4,
                enemy_hull(17, _diff, hull_mult), _diff,
                ["acd", plate_ladder(_diff), "las"], ["acd", "plt", "drv", "flm"], 2, true);
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
