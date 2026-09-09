/// scr_ai — how each faction picks what to shoot.
///
/// The AI only chooses targets; charging, firing and damage all run through the
/// same combat simulation the player uses. That keeps the factions honest — a
/// robot's laser behaves exactly like yours, it just aims at your reactor.

/// Facility indices on the player's car matching any of the given categories.
function ai_cands(_cats, _need_alive = true) {
    var pc = global.cb.player;
    var out = [];
    for (var i = 0; i < array_length(pc.facs); i++) {
        var f = pc.facs[i];
        if (_need_alive && f.hp <= 0) continue;
        var cat = fac(f.def).cat;
        for (var c = 0; c < array_length(_cats); c++) {
            if (cat == _cats[c]) { array_push(out, i); break; }
        }
    }
    return out;
}

/// Walk a priority list of category groups, returning from the first that hits.
function ai_first_of(_groups) {
    for (var g = 0; g < array_length(_groups); g++) {
        var c = ai_cands(_groups[g]);
        if (array_length(c) > 0) return c[irandom(array_length(c) - 1)];
    }
    var any = ai_cands(["power", "move", "weapon", "defence", "utility"]);
    if (array_length(any) > 0) return any[irandom(array_length(any) - 1)];
    return -1;
}

/// The facility a car concentrates fire on, by faction doctrine.
function ai_pick_focus(_car) {
    switch (_car.faction) {
        case "robots":
            // Kill the lights first, then the guns.
            return ai_first_of([["power"], ["weapon"], ["defence"]]);

        case "corps":
            // Disarm you and let the repossession clock do the work.
            return ai_first_of([["weapon"], ["utility"], ["power"]]);

        case "insects":
            // Chew through the plate, then whatever is behind it.
            return ai_first_of([["defence"], ["weapon"], ["power"]]);

        default: // bandits — stop you leaving, then strip you
            return ai_first_of([["move"], ["weapon"], ["utility"]]);
    }
}

/// Per-weapon override: some payloads want a specific kind of target.
function ai_weapon_target(_car, _f, _focus) {
    var pc = global.cb.player;
    var d = fac(_f.def);

    // Harpoons go on the drive train — pinning you is the whole point.
    if (d.harpoon > 0) {
        var mv = ai_cands(["move"]);
        if (array_length(mv) > 0) return mv[irandom(array_length(mv) - 1)];
        return _focus;
    }

    // Acid is for armour.
    if (d.applies == "acid") {
        var ar = [];
        var c1 = ai_cands(["defence"]);
        for (var i = 0; i < array_length(c1); i++) {
            if (fac(pc.facs[c1[i]].def).armour > 0) array_push(ar, c1[i]);
        }
        if (array_length(ar) > 0) return ar[irandom(array_length(ar) - 1)];
        return _focus;
    }

    // Fire looks for a slick to light — that combo is the bandits' signature.
    if (d.applies == "fire") {
        for (var i = 0; i < array_length(pc.facs); i++) {
            if (pc.facs[i].hp > 0 && pc.facs[i].st.oil > 0) return i;
        }
        var wp = ai_cands(["weapon", "power"]);
        if (array_length(wp) > 0) return wp[irandom(array_length(wp) - 1)];
        return _focus;
    }

    // Oil slows whatever it lands on, so it goes on engines and guns.
    if (d.applies == "oil") {
        var sl = ai_cands(["move", "weapon"]);
        if (array_length(sl) > 0) return sl[irandom(array_length(sl) - 1)];
        return _focus;
    }

    // Electricity is worth most on something expensive to lose.
    if (d.applies == "elec") {
        var el = ai_cands(["power", "defence", "weapon"]);
        if (array_length(el) > 0) return el[irandom(array_length(el) - 1)];
        return _focus;
    }

    return _focus;
}

function ai_update(_dt) {
    var cb = global.cb;
    if (cb.player.hull <= 0) return;

    for (var e = 0; e < array_length(cb.enemies); e++) {
        var car = cb.enemies[e];
        if (car.hull <= 0) continue;

        // Re-pick a focus when the old one is gone or the timer runs out.
        car.ai_timer -= _dt;
        var repick = (car.ai_timer <= 0) || (car.ai_focus < 0);
        if (car.ai_focus >= 0) {
            if (car.ai_focus >= array_length(cb.player.facs)) repick = true;
            else if (cb.player.facs[car.ai_focus].hp <= 0) repick = true;
        }
        if (repick) {
            car.ai_focus = ai_pick_focus(car);
            // Robots lock on hard; bandits are twitchy and keep switching.
            var base = (car.faction == "robots") ? 5.0 : ((car.faction == "bandits") ? 2.0 : 3.5);
            car.ai_timer = base + random(1.5);
        }

        for (var i = 0; i < array_length(car.facs); i++) {
            var f = car.facs[i];
            if (fac(f.def).charge <= 0) continue;
            f.target_car = -1;   // the player
            f.target_fac = ai_weapon_target(car, f, car.ai_focus);
        }

        // Corporations shed weapons to keep shields up when they're hurting;
        // they'd rather stall than trade.
        if (car.faction == "corps" && car.hull < car.hull_max * 0.4) {
            if (car_power_use(car) >= car_power_gen(car)) {
                for (var i = 0; i < array_length(car.facs); i++) {
                    var g = car.facs[i];
                    if (g.powered && fac(g.def).cat == "weapon" && fac(g.def).power > 0) {
                        var sh = car_facs_of_cat(car, "defence");
                        var need = false;
                        for (var s = 0; s < array_length(sh); s++) {
                            var sf = car.facs[sh[s]];
                            if (!sf.powered && fac(sf.def).shield > 0 && sf.hp > 0) need = true;
                        }
                        if (need) {
                            g.powered = false;
                            for (var s = 0; s < array_length(sh); s++) {
                                var sf2 = car.facs[sh[s]];
                                if (!sf2.powered && fac(sf2.def).shield > 0 && sf2.hp > 0) {
                                    if (car_power_use(car) + fac(sf2.def).power <= car_power_gen(car)) {
                                        sf2.powered = true;
                                        break;
                                    }
                                }
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
}
