/// scr_vfx — hit feedback for the fight: frame animations plus particle bursts.
///
/// Everything draws in GUI space, because the combat scene does. A room-space
/// effect would be painted over by the GUI pass and never seen, so the particle
/// system runs with automatic draw AND update switched off; obj_combat steps it
/// by hand from Step and paints it from Draw GUI. That hand-stepping is also
/// what makes the whole lot freeze correctly when you hit pause.
///
/// Frame animations carry the per-shot load — they are one draw_sprite_ext each.
/// Particle bursts are reserved for the rare loud moments.
///
/// The live/dead state of the particle system is tracked in `global.vfx_ps_ok`
/// rather than asked for with part_system_exists: that function faults on an id
/// that has already been destroyed, which is exactly the state we need to test.

/// Master switch for the particle half. Turn off to fall back to frame
/// animations only.
#macro VFX_PARTICLES true

/// Effect table. `cells` is the drawn size as a multiple of the rig's cell size,
/// so an effect scales with whatever it lands on. Swap a sprite here to restyle.
///
/// Blend choice is driven by the paper palette: on a cream ground, additive
/// washes pale art out to nothing, so only genuinely hot things get it. The
/// pack's own art is mostly cream-white, so the readable ones are tinted into
/// the palette instead — that is what `tint` is for.
function vfx_def(_kind) {
    var p = global.PAL;
    switch (_kind) {
        // Hits.
        case "impact":   return { sprite: Spr_Vfx_Impact,   fps: 34, additive: false, tint: c_white,   cells: 1.5 };
        case "shock":    return { sprite: Spr_Vfx_Shock,    fps: 20, additive: false, tint: p.st_elec, cells: 2.2 };
        case "acid":     return { sprite: Spr_Vfx_Acid,     fps: 28, additive: false, tint: c_white,   cells: 1.6 };
        case "puff":     return { sprite: Spr_Vfx_Puff,     fps: 30, additive: false, tint: c_white,   cells: 2.0 };

        // Firing.
        case "muzzle":   return { sprite: Spr_Vfx_Muzzle,   fps: 34, additive: false, tint: c_white,   cells: 1.3 };
        case "gunsmoke": return { sprite: Spr_Vfx_GunSmoke, fps: 20, additive: false, tint: c_white,   cells: 1.2 };

        // Destruction. The source is a blood burst, so it is pushed to soot and
        // rust with a tint rather than left red.
        case "blast":    return { sprite: Spr_Vfx_Blast,    fps: 24, additive: false, tint: p.atlas_ink, cells: 3.4 };

        // Persistent / ambient.
        case "flame":    return { sprite: Spr_Vfx_Flame,    fps: 16, additive: false, tint: c_white,   cells: 0.8 };
        case "smoke":    return { sprite: Spr_Vfx_Smoke,    fps: 12, additive: false, tint: c_white,   cells: 2.0 };
        case "dust":     return { sprite: Spr_Vfx_Dust,     fps: 18, additive: false, tint: c_white,   cells: 1.1 };
    }
    return undefined;
}

/// Which impact a weapon family leaves behind.
function vfx_for_family(_family) {
    switch (_family) {
        case "tes": case "srg": return "shock";
        case "acd":             return "acid";
        default:                return "impact";
    }
}

/// True once vfx_init has run and the effect list is safe to touch.
function vfx_ready() {
    return variable_global_exists("vfx");
}

function vfx_init() {
    vfx_shutdown();
    global.vfx = [];
    global.vfx_amb = 0;     // ambient re-arm timer (dust, wreck smoke)

    if (VFX_PARTICLES) {
        // On a real layer and non-persistent, so the room tears it down for us.
        // The layerless part_system_create() puts it on an internal "managed"
        // layer instead, and that combination faults the runner on exit.
        global.vfx_ps = part_system_create_layer("Instances", false);
        part_system_automatic_draw(global.vfx_ps, false);
        part_system_automatic_update(global.vfx_ps, false);
        global.vfx_ps_ok = true;
    }
}

/// Drop the particle system between fights that share a room. Leaving the room
/// needs nothing — a non-persistent system dies with it, and destroying it here
/// as well would be a double free.
function vfx_shutdown() {
    global.vfx = [];
    if (variable_global_exists("vfx_ps_ok") && global.vfx_ps_ok) {
        part_system_destroy(global.vfx_ps);
    }
    global.vfx_ps_ok = false;
}

/// Let go of the handle without freeing it. Leaving the room already destroyed
/// the system for us (it is non-persistent), so the handle is stale from here —
/// and freeing a stale one faults the runner rather than erroring.
function vfx_forget() {
    global.vfx = [];
    global.vfx_ps_ok = false;
}

/// Queue a one-shot frame animation centred on (_x, _y). `_cs` is the cell size
/// of the car it belongs to; `_loop_for` > 0 keeps it alive that many seconds.
function vfx_burst(_kind, _x, _y, _cs = 46, _rot = 0, _loop_for = 0) {
    if (!vfx_ready()) return;
    var d = vfx_def(_kind);
    if (d == undefined) return;

    var frames = sprite_get_number(d.sprite);
    array_push(global.vfx, {
        sprite: d.sprite,
        additive: d.additive,
        tint: d.tint,
        t: 0,
        dur: frames / d.fps,
        life: _loop_for,            // > 0 = keep looping for this long
        x: _x, y: _y,
        rot: _rot,
        scale: (_cs * d.cells) / max(1, sprite_get_width(d.sprite)),
    });
}

/// Burst a particle system asset at a point.
function vfx_particles(_sys, _x, _y) {
    if (!variable_global_exists("vfx_ps_ok") || !global.vfx_ps_ok) return;
    part_particles_burst(global.vfx_ps, _x, _y, _sys);
}

function vfx_update(_dt) {
    if (!vfx_ready()) return;

    for (var i = array_length(global.vfx) - 1; i >= 0; i--) {
        var v = global.vfx[i];
        v.t += _dt;
        if (v.life > 0) {
            v.life -= _dt;
            if (v.t >= v.dur) v.t -= v.dur;         // loop
            if (v.life <= 0) array_delete(global.vfx, i, 1);
        } else if (v.t >= v.dur) {
            array_delete(global.vfx, i, 1);
        }
    }

    if (global.vfx_ps_ok) part_system_update(global.vfx_ps);
}

/// Ambient effects, re-armed on a timer rather than tracked per entity: dust off
/// both rigs, and smoke off anything already wrecked.
function vfx_ambient(_dt) {
    if (!vfx_ready()) return;
    var cb = global.cb;
    global.vfx_amb -= _dt;
    if (global.vfx_amb > 0) return;
    global.vfx_amb = 0.22;

    // Dust kicks off the back of each rig — the painted animation rather than a
    // particle burst, so it reads at a glance against the moving sand.
    var lp = cb.layout_p;
    if (cb.player.hull > 0) {
        vfx_burst("dust", lp.px - lp.cs * 0.5,
                  lp.py + cb.player.gh * lp.cs * random_range(0.2, 0.8), lp.cs);
    }

    for (var e = 0; e < array_length(cb.enemies); e++) {
        var ec = cb.enemies[e];
        var le = cb.layout_e[e];
        if (ec.hull > 0) {
            vfx_burst("dust", le.px + ec.gw * le.cs + le.cs * 0.5,
                      le.py + ec.gh * le.cs * random_range(0.2, 0.8), le.cs);
        } else if (irandom(1) == 0) {
            vfx_particles(Ps_Smoke_Plumes,
                          le.px + ec.gw * le.cs * 0.5,
                          le.py + ec.gh * le.cs * 0.5);
        }
    }

    // A burning facility keeps a flame sitting on it.
    vfx_status_flames(-1, cb.player, lp);
    for (var e = 0; e < array_length(cb.enemies); e++) {
        if (cb.enemies[e].hull > 0) vfx_status_flames(e, cb.enemies[e], cb.layout_e[e]);
    }
}

/// One short-lived flame per facility currently on fire. They are re-armed every
/// ambient tick, so they simply stop when the fire goes out.
function vfx_status_flames(_car_i, _car, _lay) {
    for (var i = 0; i < array_length(_car.facs); i++) {
        var f = _car.facs[i];
        if (f.hp <= 0) continue;
        if (f.st.fire <= 0) continue;
        var pos = combat_fac_pos(_car_i, i);
        vfx_burst("flame", pos[0], pos[1] - _lay.cs * 0.2, _lay.cs, 0, 0.24);
    }
}

/// Paint every live effect. Call from Draw GUI, above the cars.
function vfx_draw() {
    if (!vfx_ready()) return;

    // Two passes so the blendmode is set twice per frame rather than per effect.
    for (var pass = 0; pass < 2; pass++) {
        var additive = (pass == 1);
        if (additive) gpu_set_blendmode(bm_add);

        for (var i = 0; i < array_length(global.vfx); i++) {
            var v = global.vfx[i];
            if (v.additive != additive) continue;
            var frames = sprite_get_number(v.sprite);
            var idx = clamp(floor(v.t / v.dur * frames), 0, frames - 1);
            draw_sprite_ext(v.sprite, idx, v.x, v.y, v.scale, v.scale,
                            v.rot, v.tint, 1);
        }

        if (additive) gpu_set_blendmode(bm_normal);
    }

    if (global.vfx_ps_ok) part_system_drawit(global.vfx_ps);
}
