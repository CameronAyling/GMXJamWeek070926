/// scr_status — the four status effects.
///
///   ELECTRICITY  the facility is offline entirely while it lasts
///   FIRE         chews through the facility over time and spreads to neighbours
///   OIL          halves the facility's rate of work, and ignites into a long fire
///   ACID         amplifies damage taken and dissolves armour contribution
///
/// Durations are seconds. Re-applying refreshes to whichever is longer rather
/// than stacking, so a fast weapon can't lock a facility down forever.

#macro FIRE_TICK    1.6     // seconds between fire damage ticks
#macro FIRE_DMG     1       // facility damage per tick
#macro FIRE_HULL    0.5     // hull damage per tick once the facility is wrecked
#macro FIRE_SPREAD  3.5     // seconds between spread attempts
#macro FIRE_CHANCE  0.45    // chance a spread attempt takes
#macro OIL_IGNITE   2.5     // fire duration multiplier when it lands on oil
#macro ACID_AMP     1.5     // incoming damage multiplier on an acid-soaked facility

/// Apply a status to one facility, honouring the car's resist rigs.
/// Returns true if oil ignited, so the caller can play the bigger effect.
function status_apply(_car, _idx, _key, _dur) {
    if (_idx < 0 || _idx >= array_length(_car.facs)) return false;
    if (_key == "" || _dur <= 0) return false;

    var f = _car.facs[_idx];
    var dur = _dur * car_resist_mult(_car, _key);
    var ignited = false;

    // Oil is the combo piece: set fire to a slick and it burns far longer.
    if (_key == "fire" && f.st.oil > 0) {
        dur *= OIL_IGNITE;
        f.st.oil = 0;
        ignited = true;
    }

    var cur = variable_struct_get(f.st, _key);
    variable_struct_set(f.st, _key, max(cur, dur));
    return ignited;
}

function status_clear(_f, _key) {
    variable_struct_set(_f.st, _key, 0);
}

function status_clear_all(_f) {
    _f.st.elec = 0;
    _f.st.fire = 0;
    _f.st.oil  = 0;
    _f.st.acid = 0;
    _f.burn_t = 0;
    _f.spread_t = 0;
}

function status_active(_f) {
    return (_f.st.elec > 0 || _f.st.fire > 0 || _f.st.oil > 0 || _f.st.acid > 0);
}

/// Active status keys on a facility, for badge drawing.
function status_keys(_f) {
    var out = [];
    if (_f.st.elec > 0) array_push(out, "elec");
    if (_f.st.fire > 0) array_push(out, "fire");
    if (_f.st.oil  > 0) array_push(out, "oil");
    if (_f.st.acid > 0) array_push(out, "acid");
    return out;
}

/// Advance every status on a car by `_dt` seconds.
/// Returns hull damage caused by fires burning in already-wrecked facilities.
function status_tick(_car, _dt) {
    var hull_dmg = 0;

    // A coolant rig smothers fires across the whole rig, not just where it sits.
    var cooling = 0;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var cf = _car.facs[i];
        if (fac_active(cf) && fac(cf.def).resist == "fire") cooling += 1.5;
    }
    // Likewise a scrubber burns off slicks everywhere.
    var scrubbing = 0;
    for (var i = 0; i < array_length(_car.facs); i++) {
        var sf = _car.facs[i];
        if (fac_active(sf) && fac(sf.def).resist == "oil") scrubbing += 1.5;
    }

    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];

        if (f.flash > 0) f.flash = max(0, f.flash - _dt);
        if (f.st.elec > 0) f.st.elec = max(0, f.st.elec - _dt);
        if (f.st.acid > 0) f.st.acid = max(0, f.st.acid - _dt);
        if (f.st.oil  > 0) f.st.oil  = max(0, f.st.oil  - _dt * (1 + scrubbing));

        if (f.st.fire > 0) {
            f.st.fire = max(0, f.st.fire - _dt * (1 + cooling));

            f.burn_t += _dt;
            while (f.burn_t >= FIRE_TICK) {
                f.burn_t -= FIRE_TICK;
                if (f.hp > 0) {
                    f.hp = max(0, f.hp - FIRE_DMG);
                    f.flash = 0.12;
                } else {
                    // Nothing left to burn but the chassis itself.
                    hull_dmg += FIRE_HULL;
                }
            }

            f.spread_t += _dt;
            while (f.spread_t >= FIRE_SPREAD) {
                f.spread_t -= FIRE_SPREAD;
                if (random(1) < FIRE_CHANCE) {
                    var nb = car_neighbours(_car, i);
                    if (array_length(nb) > 0) {
                        var pick = nb[irandom(array_length(nb) - 1)];
                        var tgt = _car.facs[pick];
                        if (tgt.st.fire <= 0) {
                            status_apply(_car, pick, "fire", f.st.fire * 0.6 + 2);
                        }
                    }
                }
            }
        } else {
            f.burn_t = 0;
            f.spread_t = 0;
        }
    }

    // Losing a reactor to fire or a short pushes the rig over budget; getting it
    // back has to switch the shed facilities on again.
    car_enforce_power(_car);
    car_restore_power(_car);

    return hull_dmg;
}

/// Damage multiplier for a hit landing on this facility.
function status_damage_mult(_f) {
    return (_f.st.acid > 0) ? ACID_AMP : 1;
}

/// Rate multiplier for work done by this facility (weapon charge, repairs).
function status_rate_mult(_f) {
    return (_f.st.oil > 0) ? 0.5 : 1;
}

/// Short human-readable line for tooltips.
function status_describe(_f) {
    var keys = status_keys(_f);
    if (array_length(keys) == 0) return "";
    var s = "";
    for (var i = 0; i < array_length(keys); i++) {
        if (i > 0) s += ", ";
        var k = keys[i];
        s += string_upper(k) + " " + ui_secs(variable_struct_get(_f.st, k));
    }
    return s;
}
