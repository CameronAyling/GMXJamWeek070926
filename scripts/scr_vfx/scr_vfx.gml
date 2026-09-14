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
        // A wreck going up. Its own soot-and-fire art already sits in the palette,
        // so it stays c_white and normal-blended. `cells: 1` because the caller
        // sizes each blast directly through `_cs` (see vfx_explode_car).
        case "explosion": return { sprite: Spr_VFX_Explosion, fps: 30, additive: false, tint: c_white, cells: 1.0 };

        // Persistent / ambient.
        case "flame":    return { sprite: Spr_Vfx_Flame,    fps: 16, additive: false, tint: c_white,   cells: 0.8 };
        case "smoke":    return { sprite: Spr_Vfx_Smoke,    fps: 12, additive: false, tint: c_white,   cells: 2.0 };
        // Sand off the tyres: a pale warm tint so it reads as kicked-up sand,
        // flipped to trail behind the nose-right rigs, sized to cover the wheels,
        // knocked back in alpha to stay a haze, blended additive so it glows off
        // the sand, and marked `under` so it paints beneath the bodywork.
        case "dust":     return { sprite: Spr_Vfx_Dust,     fps: 18, additive: true,  tint: merge_colour(p.bg, p.lift, 0.55), cells: 1.7, flip: true, alpha: 0.5, under: true };
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
/// of the car it belongs to; `_loop_for` > 0 keeps it alive that many seconds;
/// `_delay` > 0 holds the effect invisible for that many seconds before it plays
/// (so a cluster of bursts can chain rather than fire in lockstep).
function vfx_burst(_kind, _x, _y, _cs = 46, _rot = 0, _loop_for = 0, _delay = 0) {
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
        delay: _delay,              // > 0 = wait this long before playing
        x: _x, y: _y,
        rot: _rot,
        scale: (_cs * d.cells) / max(1, sprite_get_width(d.sprite)),
        flip:  (variable_struct_exists(d, "flip")  ? d.flip  : false),
        alpha: (variable_struct_exists(d, "alpha") ? d.alpha : 1),
        under: (variable_struct_exists(d, "under") ? d.under : false),
    });
}

/// Burst a particle system asset at a point.
function vfx_particles(_sys, _x, _y) {
    if (!variable_global_exists("vfx_ps_ok") || !global.vfx_ps_ok) return;
    part_particles_burst(global.vfx_ps, _x, _y, _sys);
}

/// A rig going up: a cluster of Spr_VFX_Explosion bursts scattered across the
/// car's footprint rather than one puff, so the whole chassis appears to blow.
/// The cluster is sized to the vehicle — a bigger rig throws more blasts, each
/// bigger — and every burst gets a jittered scale and a short random start
/// delay so it reads as a chain reaction instead of one stamped copy.
/// (_cx, _cy) is the centre of the rig; _gw/_gh its grid size, _cs the cell.
function vfx_explode_car(_cx, _cy, _gw, _gh, _cs) {
    if (!vfx_ready()) return;

    var w  = _gw * _cs;
    var h  = _gh * _cs;
    var x0 = _cx - w * 0.5;
    var y0 = _cy - h * 0.5;

    // More blasts for a bigger footprint, clamped so a light rig still gets a
    // few and a huge one doesn't swamp the screen.
    var n = clamp(round(_gw * _gh * 0.5) + 2, 3, 9);

    // Base blast size (in cells): roughly the short side of the rig, so each
    // fireball is proportional to the vehicle before per-burst jitter.
    var base = min(_gw, _gh) + 1;

    for (var i = 0; i < n; i++) {
        var ex, ey, delay;
        if (i == 0) {
            // Lead blast: dead centre, immediate — the initial hit.
            ex = _cx; ey = _cy; delay = 0;
        } else {
            // The rest scatter across the body and stagger their start.
            ex = x0 + random(w);
            ey = y0 + random(h);
            delay = random(0.30);
        }
        // Vary the scale per blast; drawn size = _cs * cells (def cells is 1).
        var cells = base * random_range(0.65, 1.35);
        vfx_burst("explosion", ex, ey, _cs * cells, irandom(359), 0, delay);
    }
}

function vfx_update(_dt) {
    if (!vfx_ready()) return;

    for (var i = array_length(global.vfx) - 1; i >= 0; i--) {
        var v = global.vfx[i];
        if (v.delay > 0) { v.delay -= _dt; continue; }  // still holding, don't age
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

    // Dust kicks off every tyre of each rig — the painted animation rather than
    // a particle burst, so it reads at a glance against the moving sand.
    var lp = cb.layout_p;
    if (cb.player.hull > 0) vfx_dust_wheels(cb.player, lp);

    for (var e = 0; e < array_length(cb.enemies); e++) {
        var ec = cb.enemies[e];
        var le = cb.layout_e[e];
        if (ec.hull > 0) {
            // Flyers (wasp, winged chitin) never touch the sand, so no dust.
            if (!faction_flies(ec.faction)) vfx_dust_wheels(ec, le);
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

/// A dust puff at each tyre of a rig. The wheel positions mirror the ones
/// draw_chassis lays down — a pair per two grid columns, straddling both flanks
/// — so the sand kicks up exactly where the tyres are. A little jitter keeps the
/// four puffs from looking stamped out in lockstep.
function vfx_dust_wheels(_car, _lay) {
    var cs  = _lay.cs, px = _lay.px, py = _lay.py;
    var pad = cs * 0.30;
    var x0  = car_body_x0(_car);
    var bx1 = px + x0 * cs - pad,        by1 = py - pad;
    var bx2 = px + _car.gw * cs + pad,   by2 = py + _car.gh * cs + pad;
    var wl  = cs * 0.32, ww = cs * 0.15;
    var pairs = max(2, floor(_car.gw / 2) + 1);

    for (var i = 0; i < pairs; i++) {
        var t  = (pairs == 1) ? 0.5 : (i / (pairs - 1));
        var wx = lerp(bx1 + wl * 1.5, bx2 - wl * 1.5, t) + random_range(-cs * 0.08, cs * 0.08);
        vfx_burst("dust", wx, by1 - ww * 0.55 + random_range(-cs * 0.06, cs * 0.06), cs);
        vfx_burst("dust", wx, by2 + ww * 0.55 + random_range(-cs * 0.06, cs * 0.06), cs);
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

/// Paint the effects that sit UNDER the cars (tyre dust). Call from Draw GUI
/// after the ground but before the rigs are drawn.
function vfx_draw_under() {
    vfx_draw_layer(true);
}

/// Paint every effect that sits ABOVE the cars — everything but the under-layer.
/// Call from Draw GUI, above the cars.
function vfx_draw() {
    vfx_draw_layer(false);
    if (global.vfx_ps_ok) part_system_drawit(global.vfx_ps);
}

/// A flamethrower stream, drawn as a run of Spr_Vfx_Flame sprites marched from
/// the muzzle out to the shot's leading edge. Additive, so the fire actually
/// glows hot against the sand instead of reading as a pale line. Each puff picks
/// its own churning frame and a little perpendicular wobble so the jet boils
/// rather than sliding as one rigid blob, and it fattens and reddens toward the
/// tip the way a real gout billows out at the end of its throw.
///
/// Called straight from the combat shots pass with the blendmode at normal; it
/// sets additive for the run and puts it back before returning.
function vfx_flame_jet(_x0, _y0, _x1, _y1, _cs, _seed) {
    var p   = global.PAL;
    var spr = Spr_Vfx_Flame;
    var frames = sprite_get_number(spr);
    var sw  = sprite_get_width(spr);

    var len = point_distance(_x0, _y0, _x1, _y1);
    if (len < 1) return;
    var ang  = point_direction(_x0, _y0, _x1, _y1);
    var perp = ang + 90;

    // A puff roughly every third of a cell, so a longer throw carries more fire.
    var n  = max(3, ceil(len / max(_cs * 0.32, 9)));
    var ph = current_time * 0.02;    // shared churn clock

    gpu_set_blendmode(bm_add);
    for (var i = 0; i <= n; i++) {
        var f  = i / n;                          // 0 at muzzle, 1 at the tip
        var bx = lerp(_x0, _x1, f);
        var by = lerp(_y0, _y1, f);

        // Deterministic wobble: churns over time, differs per shot and per puff.
        var r   = _seed * 2.3 + i * 1.7;
        var wob = sin(ph + r) * _cs * 0.12 * (f + 0.25);
        var fx  = bx + lengthdir_x(wob, perp);
        var fy  = by + lengthdir_y(wob, perp);

        var cells = lerp(0.45, 1.20, f);          // billows out toward the tip
        var scale = (_cs * cells) / sw;
        var idx   = floor(ph + i * 3 + _seed * 2) mod frames;
        var rot   = ang - 90 + sin(r) * 22;       // long axis roughly along travel
        var tint  = merge_colour(p.amber, p.st_fire, f);
        var al    = lerp(0.45, 0.8, f);

        draw_sprite_ext(spr, idx, fx, fy, scale, scale, rot, tint, al);
    }
    gpu_set_blendmode(bm_normal);
}

/// Shared painter for one z-layer. `_under` picks which set of effects to draw.
function vfx_draw_layer(_under) {
    if (!vfx_ready()) return;

    // Two passes so the blendmode is set twice per frame rather than per effect.
    for (var pass = 0; pass < 2; pass++) {
        var additive = (pass == 1);
        if (additive) gpu_set_blendmode(bm_add);

        for (var i = 0; i < array_length(global.vfx); i++) {
            var v = global.vfx[i];
            if (v.delay > 0) continue;                 // not on screen yet
            if (v.additive != additive) continue;
            if (v.under != _under) continue;
            var frames = sprite_get_number(v.sprite);
            var idx = clamp(floor(v.t / v.dur * frames), 0, frames - 1);
            // A flipped effect gets a negative x-scale — the sprite's own origin
            // keeps it pinned in place while it mirrors.
            draw_sprite_ext(v.sprite, idx, v.x, v.y, v.scale * (v.flip ? -1 : 1), v.scale,
                            v.rot, v.tint, v.alpha);
        }

        if (additive) gpu_set_blendmode(bm_normal);
    }
}
