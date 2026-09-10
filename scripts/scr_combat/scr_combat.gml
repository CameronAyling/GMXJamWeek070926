/// scr_combat — the real-time-with-pause fight.
///
/// Both sides run through exactly the same simulation: weapons charge against a
/// clock, statuses tick, shields regenerate. The only asymmetry is that the
/// player picks targets by hand and the AI picks them in scr_ai.
///
/// Shields absorb a whole shot per layer, so a 3-shot laser strips three layers
/// while one big rivet wastes itself on one. Armour subtracts from damage
/// instead, which is why acid (which dissolves armour) and piercing lasers are
/// the answers to plate.

#macro DRONE_REPAIR_TIME  1.1    // seconds per hit point repaired
#macro DRONE_DOUSE_RATE   2.5    // extra fire-duration burned per second
#macro SHOT_SPEED         620    // pixels per second
#macro HULL_SPILL         0.34   // fraction of facility damage that reaches hull
#macro STRAY_CHANCE       0.45   // odds a dodged shot clips an adjacent cell
#macro STRAY_DAMAGE       0.5    // damage and status duration multiplier for a graze

function combat_init() {
    var ctx = global.combat_ctx;
    var player = global.run.car;

    // Everything is repaired between fights except hull; statuses never carry.
    for (var i = 0; i < array_length(player.facs); i++) {
        status_clear_all(player.facs[i]);
        player.facs[i].charge = 0;
        player.facs[i].target_car = -1;
        player.facs[i].target_fac = -1;
        player.facs[i].powered = true;      // every fight starts with the rig lit up
        player.facs[i].manual_off = false;
    }
    player.shield_cur = car_shield_max(player);
    player.shield_timer = 0;
    player.harpoon = 0;
    player.escape = 0;
    car_enforce_power(player);
    car_restore_power(player);

    var enemies = enemy_group(ctx.faction, ctx.diff, ctx.elite, ctx.boss);
    for (var e = 0; e < array_length(enemies); e++) {
        enemies[e].shield_cur = car_shield_max(enemies[e]);
    }

    var drone_count = car_drones(player);
    var drones = [];
    for (var i = 0; i < drone_count; i++) array_push(drones, { fac: -1 });

    global.cb = {
        player: player,
        enemies: enemies,
        ctx: ctx,

        shots: [],
        pops: [],           // floating damage numbers
        log: [],

        paused: false,
        over: "",           // "" | "win" | "lose" | "fled"
        over_t: 0,
        exiting: false,
        bay_due: false,     // a win earns a chassis bay
        time: 0,

        sel_weapon: -1,     // which player weapon is being aimed
        drones: drones,

        layout_p: { px: 0, py: 0, cs: 0 },
        layout_e: [],

        shake: 0,
        reward: 0,

        // Whatever weather the node you're parked in is having. Resolved once
        // here rather than per-frame, so a headless balance sim with no map
        // simply fights in clear country.
        hz: hazard(hazard_here()),
        hz_t: 0,            // seconds until the next drip
    };

    combat_layout();
    combat_log(string_upper(faction_name(ctx.faction)) + " on the road ahead.");
    if (ctx.boss)  combat_log("It isn't slowing down. It doesn't have to.");
    if (ctx.elite) combat_log("Recovery crew. There Next Tuesday came to take the load off you.");
    if (global.cb.hz != undefined) combat_log(global.cb.hz.name + " — " + global.cb.hz.blurb);

    // Aim everything at something sensible so the fight starts immediately.
    combat_autotarget_all();
}

/// Screen rectangles for every car. Shots and mouse picking both read these.
function combat_layout() {
    var cb = global.cb;
    var p = cb.player;

    // The player's cells shrink a little once the chassis has been widened.
    var pcs = (cb.player.gw > 6) ? 40 : 46;
    var ph  = cb.player.gh * pcs;
    cb.layout_p = { px: 118, py: 328 - ph * 0.5, cs: pcs };

    var n = array_length(cb.enemies);
    cb.layout_e = [];

    if (n == 1) {
        var e = cb.enemies[0];
        var cs = (e.gw >= 7) ? 40 : 46;
        array_push(cb.layout_e, { px: 1162 - e.gw * cs, py: 328 - e.gh * cs * 0.5, cs: cs });
        return;
    }

    // Two to four vehicles. Each gets a cell size that fits its own grid, so a
    // 3x3 hauler and a 1x1 drone can share the screen without either becoming
    // unreadable, and the slot spread changes with the count so two cars don't
    // huddle in one corner.
    var slots;
    if (n == 2)      slots = [[1035, 200], [835, 380]];
    else if (n == 3) slots = [[1035, 130], [835, 290], [1035, 440]];
    else             slots = [[1035, 140], [825, 140], [1035, 392], [825, 392]];

    for (var i = 0; i < n; i++) {
        var ec = cb.enemies[i];
        var s  = slots[i % array_length(slots)];
        var cs = min(42, floor(126 / max(1, ec.gw)), floor(116 / max(1, ec.gh)));
        array_push(cb.layout_e, { px: s[0], py: s[1], cs: max(22, cs) });
    }
}

function combat_log(_msg) {
    array_push(global.cb.log, _msg);
    while (array_length(global.cb.log) > 7) array_delete(global.cb.log, 0, 1);
}

function combat_pop(_px, _py, _text, _col) {
    array_push(global.cb.pops, { px: _px, py: _py, text: _text, col: _col, t: 0 });
}

// --- helpers ----------------------------------------------------------------

/// Car struct for an index: -1 is the player, 0..n the enemies.
function combat_car(_i) {
    return (_i < 0) ? global.cb.player : global.cb.enemies[_i];
}

function combat_layout_for(_i) {
    return (_i < 0) ? global.cb.layout_p : global.cb.layout_e[_i];
}

/// Centre of a facility on screen — where shots fly from and to.
function combat_fac_pos(_car_i, _fac_i) {
    var lay = combat_layout_for(_car_i);
    var car = combat_car(_car_i);
    if (_fac_i < 0 || _fac_i >= array_length(car.facs)) {
        return [lay.px + car.gw * lay.cs * 0.5, lay.py + car.gh * lay.cs * 0.5];
    }
    var f = car.facs[_fac_i];
    var ext = shape_extent(f.cells);
    return [lay.px + (f.ox + ext[0] * 0.5) * lay.cs,
            lay.py + (f.oy + ext[1] * 0.5) * lay.cs];
}

function combat_enemy_alive(_i) {
    return (_i >= 0 && _i < array_length(global.cb.enemies) && global.cb.enemies[_i].hull > 0);
}

function combat_any_enemy_alive() {
    for (var i = 0; i < array_length(global.cb.enemies); i++) if (combat_enemy_alive(i)) return true;
    return false;
}

function combat_first_live_enemy() {
    for (var i = 0; i < array_length(global.cb.enemies); i++) if (combat_enemy_alive(i)) return i;
    return -1;
}

/// A facility worth shooting at on this car — intact ones first.
function combat_pick_fac(_car, _prefer_cats) {
    var cands = [];
    for (var i = 0; i < array_length(_car.facs); i++) {
        if (_car.facs[i].hp > 0) array_push(cands, i);
    }
    if (array_length(cands) == 0) return -1;

    if (is_array(_prefer_cats) && array_length(_prefer_cats) > 0) {
        var pref = [];
        for (var i = 0; i < array_length(cands); i++) {
            var cat = fac(_car.facs[cands[i]].def).cat;
            for (var c = 0; c < array_length(_prefer_cats); c++) {
                if (cat == _prefer_cats[c]) array_push(pref, cands[i]);
            }
        }
        if (array_length(pref) > 0) return pref[irandom(array_length(pref) - 1)];
    }
    return cands[irandom(array_length(cands) - 1)];
}

/// A cell orthogonally adjacent to the intended target — where a dodged shot
/// ends up. The cell may hold another facility or be bare grid; either is a
/// legitimate place for a stray round to land.
/// Returns { fac, px, py } (fac -1 = bare chassis), or undefined if the shot
/// had nothing next to it to clip.
function combat_stray(_car_i, _fac_i) {
    var car = combat_car(_car_i);
    var lay = combat_layout_for(_car_i);

    if (_fac_i < 0 || _fac_i >= array_length(car.facs)) return undefined;

    var f = car.facs[_fac_i];
    var dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    var cand = [];

    for (var c = 0; c < array_length(f.cells); c++) {
        var cx = f.ox + f.cells[c][0];
        var cy = f.oy + f.cells[c][1];
        for (var d = 0; d < 4; d++) {
            var nx = cx + dirs[d][0];
            var ny = cy + dirs[d][1];
            if (!car_cell_exists(car, nx, ny)) continue;
            if (car_at(car, nx, ny) == _fac_i) continue;   // still the same facility
            array_push(cand, [nx, ny]);
        }
    }
    if (array_length(cand) == 0) return undefined;

    var pick = cand[irandom(array_length(cand) - 1)];
    return {
        fac: car_at(car, pick[0], pick[1]),
        px: lay.px + (pick[0] + 0.5) * lay.cs,
        py: lay.py + (pick[1] + 0.5) * lay.cs,
    };
}

/// Point every player weapon at something so the fight can't stall on turn one.
function combat_autotarget_all() {
    var cb = global.cb;
    var ei = combat_first_live_enemy();
    if (ei == -1) return;
    for (var i = 0; i < array_length(cb.player.facs); i++) {
        var f = cb.player.facs[i];
        if (fac(f.def).charge <= 0) continue;
        if (f.target_car == -1 || !combat_enemy_alive(f.target_car)) {
            f.target_car = ei;
            f.target_fac = combat_pick_fac(cb.enemies[ei], []);
        }
    }
}

// --- damage -----------------------------------------------------------------

/// Land a hit. `_fac_i` of -1 means it struck bare chassis.
function combat_damage(_car_i, _fac_i, _dmg, _hull_bonus, _pierce) {
    var car = combat_car(_car_i);

    // Armour blunts a hit; it never stops one dead. Without this floor, plate 2
    // makes every damage-1 weapon in the game do literally nothing to that
    // target — an auto-loss for any build that didn't happen to bring acid.
    var armour = max(0, car_armour(car) - _pierce);
    var dmg = (_dmg > 0) ? max(1, _dmg - armour) : 0;

    var pos = combat_fac_pos(_car_i, _fac_i);

    if (dmg <= 0 && _hull_bonus <= 0) {
        combat_pop(pos[0], pos[1], "CLANG", global.PAL.text_dim);
        return 0;
    }

    var hull_dmg = _hull_bonus;

    if (_fac_i >= 0 && _fac_i < array_length(car.facs)) {
        var f = car.facs[_fac_i];
        dmg = round(dmg * status_damage_mult(f));   // acid amplifies
        var before = f.hp;
        f.hp = max(0, f.hp - dmg);
        f.flash = 0.2;
        var absorbed = before - f.hp;
        var overflow = dmg - absorbed;              // past a wreck, into the frame
        hull_dmg += ceil(absorbed * HULL_SPILL) + overflow * 0.6;
        if (before > 0 && f.hp <= 0) {
            combat_log(car.name + ": " + fac(f.def).name + " WRECKED");
        }
    } else {
        hull_dmg += dmg;
    }

    car.hull = max(0, car.hull - hull_dmg);
    combat_pop(pos[0], pos[1], "-" + string(round(max(dmg, hull_dmg))), global.PAL.danger);

    // A lost reactor can push the rig over its power budget.
    car_enforce_power(car);
    return dmg;
}

// --- firing -----------------------------------------------------------------

/// Spawn the projectiles for one weapon discharge.
function combat_fire(_src_car_i, _src_fac_i) {
    var cb = global.cb;
    var src = combat_car(_src_car_i);
    var f = src.facs[_src_fac_i];
    var d = fac(f.def);

    var tc = f.target_car;
    if (tc == _src_car_i) return;
    var tgt = combat_car(tc);
    if (tgt == undefined) return;
    if (tc >= 0 && !combat_enemy_alive(tc)) return;
    if (tc < 0 && cb.player.hull <= 0) return;

    var from = combat_fac_pos(_src_car_i, _src_fac_i);

    for (var s = 0; s < d.shots; s++) {
        var dst_fac = f.target_fac;
        if (d.scatter) dst_fac = combat_pick_fac(tgt, []);   // can't be aimed
        if (dst_fac >= array_length(tgt.facs)) dst_fac = -1;
        if (dst_fac >= 0 && tgt.facs[dst_fac].hp <= 0 && !d.scatter) {
            // Wrecked already — roll onto something still working.
            var alt = combat_pick_fac(tgt, []);
            if (alt != -1) dst_fac = alt;
        }

        var to = combat_fac_pos(tc, dst_fac);
        var dist = point_distance(from[0], from[1], to[0], to[1]);

        array_push(cb.shots, {
            x0: from[0], y0: from[1],
            x1: to[0] + irandom_range(-6, 6), y1: to[1] + irandom_range(-6, 6),
            t: -s * 0.12,                 // stagger multi-shot volleys
            dur: max(0.18, dist / SHOT_SPEED),
            src: _src_car_i,
            dst: tc,
            dst_fac: dst_fac,
            dmg: d.dmg,
            pierce: d.pierce,
            hull_bonus: d.hull_bonus,
            applies: d.applies,
            applies_dur: d.applies_dur,
            harpoon: d.harpoon,
            family: d.family,
            col: cat_colour(d.cat),
        });
    }

    f.charge = 0;
}

/// Resolve a projectile that has reached its destination.
function combat_resolve(_shot) {
    var cb = global.cb;
    var tgt = combat_car(_shot.dst);
    if (tgt == undefined) return;
    if (_shot.dst >= 0 && tgt.hull <= 0) return;

    var pos = combat_fac_pos(_shot.dst, _shot.dst_fac);

    // 1. Point defence.
    if (random(1) < car_intercept(tgt)) {
        combat_pop(pos[0], pos[1], "INTERCEPT", global.PAL.cat_defence);
        return;
    }

    // 2. Evasion. A dodged shot doesn't always vanish — it can clip whatever
    //    sits next to what it was aimed at, so evasion buys you a lot but never
    //    everything, and a packed grid is riskier than a sparse one.
    var stray = false;
    var dst_fac = _shot.dst_fac;
    // A dust storm blinds both sides, so it rides on top of the target's own
    // evasion rather than replacing it.
    var haz_evade = (global.cb.hz == undefined) ? 0 : global.cb.hz.evade_bonus;
    if (random(1) < car_evade(tgt) + haz_evade) {
        var s = combat_stray(_shot.dst, dst_fac);
        if (s == undefined || random(1) >= STRAY_CHANCE) {
            combat_pop(pos[0], pos[1], "MISS", global.PAL.text_dim);
            return;
        }
        stray   = true;
        dst_fac = s.fac;
        pos     = [s.px, s.py];
        combat_pop(pos[0], pos[1] - 15, "GRAZE", global.PAL.warn);
    }

    // 3. Shields eat a whole shot per layer — which is why volume beats size.
    //    A stray still has to get through them.
    if (tgt.shield_cur > 0) {
        tgt.shield_cur -= 1;
        tgt.shield_timer = 0;
        combat_pop(pos[0], pos[1], "SHIELD", global.PAL.cat_defence);
        return;
    }

    // 4. Armour, facility damage, hull spill. A graze lands at reduced force.
    var dmg   = _shot.dmg;
    var hbon  = _shot.hull_bonus;
    if (stray) {
        if (dmg  > 0) dmg  = max(1, ceil(dmg * STRAY_DAMAGE));
        if (hbon > 0) hbon = max(1, ceil(hbon * STRAY_DAMAGE));
    }
    combat_damage(_shot.dst, dst_fac, dmg, hbon, _shot.pierce);

    // 5. Status payload — a graze still splashes, for half as long.
    if (_shot.applies != "" && dst_fac >= 0) {
        var dur = stray ? _shot.applies_dur * STRAY_DAMAGE : _shot.applies_dur;
        var ignited = status_apply(tgt, dst_fac, _shot.applies, dur);
        if (ignited) {
            combat_pop(pos[0], pos[1] - 16, "OIL IGNITES", global.PAL.st_fire);
            combat_log(tgt.name + ": the slick went up.");
        }
    }

    // 6. Harpoon — the reason you can't simply drive away from bandits. A
    //    glancing hit doesn't get the barbs in.
    if (_shot.harpoon > 0 && !stray) {
        tgt.harpoon = max(tgt.harpoon, _shot.harpoon);
        combat_pop(pos[0], pos[1] - 16, "HARPOONED", global.PAL.st_fire);
        if (_shot.dst < 0) combat_log("Cable in the chassis. You're not leaving yet.");
    }

    cb.shake = max(cb.shake, (_shot.dst < 0) ? 5 : 2.5);
}

// --- per-frame simulation ---------------------------------------------------

/// Wind the screen shake down.
///
/// This is presentation, not simulation, so it lives outside combat_update and
/// runs every frame regardless. It used to decay inside the update, which is
/// only called while the fight is live and unpaused — so the hit that ended a
/// fight left the shake frozen at full strength and the rig buzzed on the
/// results screen forever. Pausing on a hit did the same thing.
function combat_shake_decay(_dt) {
    if (!variable_global_exists("cb") || !is_struct(global.cb)) return;
    var cb = global.cb;
    if (cb.shake > 0) cb.shake = max(0, cb.shake - _dt * 18);
}

function combat_update(_dt) {
    var cb = global.cb;
    cb.time += _dt;

    // --- statuses, shields, regen, clocks ---
    var cars = [-1];
    for (var i = 0; i < array_length(cb.enemies); i++) array_push(cars, i);

    for (var ci = 0; ci < array_length(cars); ci++) {
        var idx = cars[ci];
        var car = combat_car(idx);
        if (idx >= 0 && car.hull <= 0) continue;

        car.hull = max(0, car.hull - status_tick(car, _dt));

        // Shield regeneration. A no-repair hull gets one use of each layer and
        // that's it — nothing on it ever comes back.
        var smax = car_shield_max(car);
        if (car.shield_cur > smax) car.shield_cur = smax;
        if (car.shield_cur < smax && !car.no_repair) {
            car.shield_timer += _dt;
            var need = car_shield_regen(car);
            if (need < 900 && car.shield_timer >= need) {
                car.shield_timer = 0;
                car.shield_cur += 1;
            }
        }

        if (car.harpoon > 0) car.harpoon = max(0, car.harpoon - _dt);

        // Insect self-repair, spread over whatever is damaged.
        if (car.regen > 0 && !car.no_repair) {
            var pool = car.regen * _dt;
            for (var i = 0; i < array_length(car.facs) && pool > 0; i++) {
                var f = car.facs[i];
                if (f.hp < f.hp_max && f.st.fire <= 0) {
                    var give = min(pool, f.hp_max - f.hp);
                    f.hp += give;
                    pool -= give;
                }
            }
        }

        // Corporate repossession clock: outlasting them is not an option.
        if (car.repo_max > 0 && car.hull > 0) {
            car.repo += _dt;
            if (car.repo >= car.repo_max) {
                car.repo = 0;
                cb.player.hull = max(0, cb.player.hull - 12);
                cb.shake = 8;
                combat_log("REPOSSESSION ORDER EXECUTED — 12 hull seized.");
                combat_pop(cb.layout_p.px + 80, cb.layout_p.py - 20, "SEIZED -12", global.PAL.danger);
            }
        }
    }

    // --- player break-away ---
    // The drive spools on its own and then holds at full. Leaving is the
    // decision: you choose the moment, weighed against the salvage you forfeit.
    if (cb.player.harpoon <= 0) {
        var esc_mult = (cb.hz == undefined) ? 1 : cb.hz.escape_mult;
        cb.player.escape = min(1, cb.player.escape + car_escape_rate(cb.player) * esc_mult * _dt);
    }

    // --- weather ---
    // A dripping hazard lands its status on one random live facility per car,
    // both sides, so bad country is a leveller rather than a tax on the player.
    if (cb.hz != undefined && cb.hz.drip != "" && cb.over == "") {
        cb.hz_t -= _dt;
        if (cb.hz_t <= 0) {
            cb.hz_t += cb.hz.drip_every;
            for (var ci = 0; ci < array_length(cars); ci++) {
                var hcar = combat_car(cars[ci]);
                if (hcar == undefined || (cars[ci] >= 0 && hcar.hull <= 0)) continue;

                var live = [];
                for (var fi = 0; fi < array_length(hcar.facs); fi++) {
                    if (fac_alive(hcar.facs[fi])) array_push(live, fi);
                }
                if (array_length(live) == 0) continue;
                status_apply(hcar, live[irandom(array_length(live) - 1)],
                             cb.hz.drip, cb.hz.drip_dur);
            }
        }
    }

    // --- enemy decisions ---
    ai_update(_dt);

    // --- weapon charging, both sides ---
    for (var ci = 0; ci < array_length(cars); ci++) {
        var idx = cars[ci];
        var car = combat_car(idx);
        if (idx >= 0 && car.hull <= 0) continue;

        var mult = car_charge_mult(car);
        for (var i = 0; i < array_length(car.facs); i++) {
            var f = car.facs[i];
            var d = fac(f.def);
            if (d.charge <= 0) continue;
            if (!fac_active(f)) continue;

            f.charge += (_dt / d.charge) * mult * status_rate_mult(f);
            if (f.charge >= 1) {
                var valid;
                if (idx < 0) {
                    // The thing you were aimed at may be a wreck by now. Fall
                    // back to whatever is still standing rather than sitting at
                    // full charge doing nothing — against a bandit pack or a
                    // drone escort that would silence you on your first kill.
                    if (!combat_enemy_alive(f.target_car)) combat_autotarget_all();
                    valid = combat_enemy_alive(f.target_car);
                } else {
                    valid = (cb.player.hull > 0);
                }
                if (valid) combat_fire(idx, i);
                else f.charge = 1;   // hold at full until a target exists
            }
        }
    }

    // --- projectiles ---
    for (var i = array_length(cb.shots) - 1; i >= 0; i--) {
        var s = cb.shots[i];
        s.t += _dt;
        if (s.t >= s.dur) {
            combat_resolve(s);
            array_delete(cb.shots, i, 1);
        }
    }

    // --- repair drones ---
    // A static field doesn't stop them, it just slows everything they do — so
    // it scales the work rate, not the repair threshold.
    var drone_rate = (cb.hz == undefined) ? 1 : cb.hz.repair_mult;
    for (var i = 0; i < array_length(cb.drones); i++) {
        var dr = cb.drones[i];
        if (dr.fac < 0 || dr.fac >= array_length(cb.player.facs)) { dr.fac = -1; continue; }
        var f = cb.player.facs[dr.fac];

        if (f.st.fire > 0) {
            f.st.fire = max(0, f.st.fire - DRONE_DOUSE_RATE * drone_rate * _dt);
            if (f.st.fire <= 0) combat_log("Fire out on " + fac(f.def).name + ".");
        } else if (f.hp < f.hp_max) {
            f.repair_t += _dt * drone_rate;
            while (f.repair_t >= DRONE_REPAIR_TIME && f.hp < f.hp_max) {
                f.repair_t -= DRONE_REPAIR_TIME;
                f.hp += 1;
                if (f.hp == 1) car_enforce_power(cb.player);
            }
        } else {
            dr.fac = -1;   // job done, drone goes idle
        }
    }

    // --- floating text ---
    for (var i = array_length(cb.pops) - 1; i >= 0; i--) {
        cb.pops[i].t += _dt;
        if (cb.pops[i].t > 1.1) array_delete(cb.pops, i, 1);
    }

    // --- resolution ---
    if (cb.over == "") {
        if (cb.player.hull <= 0) combat_finish("lose");
        else if (!combat_any_enemy_alive()) combat_finish("win");
        else if (cb.time > 240) combat_finish("fled");   // both sides toothless
    } else {
        cb.over_t += _dt;
    }
}

function combat_finish(_result) {
    var cb = global.cb;
    cb.over = _result;
    cb.over_t = 0;

    switch (_result) {
        case "win":
            cb.reward = run_combat_reward(cb.ctx.elite, cb.ctx.boss);
            // Every wreck you strip is another cell of deck. Chassis growth is
            // earned in the road, not bought at a counter.
            cb.bay_due = car_can_upgrade_bay(cb.player);
            combat_log("Road's clear. Salvage: " + string(cb.reward) + " scrap.");
            if (cb.bay_due) combat_log("Enough plate off the wreck to weld on another bay.");
            break;
        case "fled":
            combat_log("Break-away complete. No salvage, but you're still driving.");
            break;
        case "lose":
            combat_log("Chassis failure. The rig goes over.");
            break;
    }
}

/// Apply the outcome to the run and leave the combat room.
function combat_exit() {
    var cb = global.cb;
    var r = global.run;

    // The fade takes a moment and the button stays on screen; without this the
    // salvage would be banked once per click.
    if (cb.exiting) return;
    cb.exiting = true;

    if (cb.over == "win") {
        run_add_scrap(cb.reward);
        r.kills += 1;

        // Applied on the way out rather than mid-overlay, so the grid doesn't
        // reshape underneath the victory panel.
        if (cb.bay_due && car_upgrade_bay(r.car)) {
            run_log("Welded another bay onto the back — " + string(car_cell_count(r.car)) + " cells now.");
        }

        if (cb.ctx.boss) {
            r.boss_beaten = true;
            run_end("won");
            goto_room(rm_gameover);
            return;
        }
    } else if (cb.over == "lose") {
        run_end("dead");
        goto_room(rm_gameover);
        return;
    }

    // Statuses never survive a fight; wrecked facilities stay wrecked until
    // repaired, so a bad fight still costs you.
    for (var i = 0; i < array_length(r.car.facs); i++) {
        status_clear_all(r.car.facs[i]);
        r.car.facs[i].charge = 0;
        r.car.facs[i].powered = true;
    }
    r.car.harpoon = 0;
    r.car.escape = 0;
    car_enforce_power(r.car);

    goto_room(rm_map);
}

// --- player input helpers ---------------------------------------------------

/// Assign the selected weapon (or all weapons) to a target.
function combat_set_target(_enemy_i, _fac_i) {
    var cb = global.cb;
    if (!combat_enemy_alive(_enemy_i)) return;

    if (cb.sel_weapon >= 0 && cb.sel_weapon < array_length(cb.player.facs)) {
        var f = cb.player.facs[cb.sel_weapon];
        f.target_car = _enemy_i;
        f.target_fac = _fac_i;
        cb.sel_weapon = -1;
    } else {
        // No weapon selected: point everything at it.
        for (var i = 0; i < array_length(cb.player.facs); i++) {
            var g = cb.player.facs[i];
            if (fac(g.def).charge <= 0) continue;
            g.target_car = _enemy_i;
            g.target_fac = _fac_i;
        }
    }
}

/// Is the drive up to speed and the road clear?
function combat_can_escape() {
    var cb = global.cb;
    return (cb.over == "" && cb.player.escape >= 1 && cb.player.harpoon <= 0);
}

/// Take the gap. The meter fills itself and then holds; spending it is the
/// decision — every second you wait is salvage you might still win, or hull
/// you're about to lose.
function combat_try_escape() {
    var cb = global.cb;
    if (cb.over != "") return;

    if (cb.player.harpoon > 0) {
        combat_log("Cable's still in you. Cut them loose first.");
        return;
    }
    if (cb.player.escape < 1) {
        combat_log("Drive isn't up to speed yet.");
        return;
    }

    combat_finish("fled");
}

/// Send a free drone to a facility, or recall the one already there.
function combat_toggle_drone(_fac_i) {
    var cb = global.cb;
    for (var i = 0; i < array_length(cb.drones); i++) {
        if (cb.drones[i].fac == _fac_i) { cb.drones[i].fac = -1; return; }
    }
    for (var i = 0; i < array_length(cb.drones); i++) {
        if (cb.drones[i].fac == -1) { cb.drones[i].fac = _fac_i; return; }
    }
    // All busy — reassign the first.
    cb.drones[0].fac = _fac_i;
}

function combat_drone_on(_fac_i) {
    var cb = global.cb;
    for (var i = 0; i < array_length(cb.drones); i++) if (cb.drones[i].fac == _fac_i) return true;
    return false;
}

function combat_drones_idle() {
    var n = 0;
    for (var i = 0; i < array_length(global.cb.drones); i++) if (global.cb.drones[i].fac == -1) n += 1;
    return n;
}

/// Toggle a facility's power, refusing to switch on what the reactor can't feed.
function combat_toggle_power(_fac_i) {
    var cb = global.cb;
    var f = cb.player.facs[_fac_i];
    var d = fac(f.def);
    if (d.power <= 0 || !fac_alive(f)) return;

    if (f.powered) {
        f.powered = false;
        f.manual_off = true;    // stays off until the player says otherwise
    } else {
        if (car_power_use(cb.player) + d.power > car_power_gen(cb.player)) {
            combat_log("Not enough power. Shut something else down first.");
            return;
        }
        f.powered = true;
        f.manual_off = false;
    }
}
