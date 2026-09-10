var p  = global.PAL;
var cb = global.cb;
var W  = display_get_gui_width();
var H  = display_get_gui_height();

// Reset the ink register for this frame — without this the reservations from
// every previous frame pile up and eventually nothing can be placed.
labels_begin();

var scroll = (cb.paused || cb.over != "") ? 0 : cb.time;

// ------------------------------------------------------------- the ground
// Scrolling desert under the whole fight. This is drawn here rather than as a
// room background layer because the combat scene lives in GUI space, and the
// GUI pass paints over every room layer — a background layer never shows.
// Scaled to the GUI height at draw time, so the 1920x1080 source is untouched.
var bg_rate  = 0.60;    // tile widths per second
var gst      = ground_style();
var bg_s  = H / sprite_get_height(Spr_BG_Scroll);
var bg_w  = sprite_get_width(Spr_BG_Scroll) * bg_s;
var bg_ox = sprite_get_xoffset(Spr_BG_Scroll) * bg_s;
var bg_oy = sprite_get_yoffset(Spr_BG_Scroll) * bg_s;
for (var bx = -frac(scroll * bg_rate) * bg_w; bx < W; bx += bg_w) {
    draw_sprite_ext(Spr_BG_Scroll, 0, bx + bg_ox, bg_oy, bg_s, bg_s, 0, c_white, 1);
}

// The old flat 0.55 wash of paper colour over the whole photograph is what
// made the desert look bleached. Contrast for the UI comes from the edges now
// — a warm vignette — with at most a light haze across the middle.
if (gst.scrim > 0) {
    draw_set_alpha(gst.scrim);
    draw_rectangle_colour(0, 0, W, H, p.bg_grad, p.bg_grad, p.bg, p.bg, false);
    draw_set_alpha(1);
}
if (gst.vignette > 0) {
    var vg = 150;
    draw_set_alpha(gst.vignette);
    draw_rectangle_colour(0, 0, W, vg, p.shade, p.shade, p.bg, p.bg, false);
    draw_rectangle_colour(0, H - vg, W, H, p.bg, p.bg, p.shade, p.shade, false);
    draw_set_alpha(gst.vignette * 0.7);
    draw_rectangle_colour(0, 0, vg, H, p.shade, p.bg, p.bg, p.shade, false);
    draw_rectangle_colour(W - vg, 0, W, H, p.bg, p.shade, p.shade, p.bg, false);
    draw_set_alpha(1);
}

// Screen shake on hits.
var kx = 0, ky = 0;
if (cb.shake > 0) {
    kx = random_range(-cb.shake, cb.shake);
    ky = random_range(-cb.shake, cb.shake);
}

// The tarmac band, its violet edge rules and the scrolling lane dashes used to
// live here. The scrolling desert above does that job now.

// ---------------------------------------------------------------- cars
// Player.
var lp = cb.layout_p;
draw_car(cb.player, lp.px + kx, lp.py + ky, lp.cs, {
    flip: false,
    show_charge: true,
    hover_fac: (hover_car == -1) ? hover_fac : -1,
    selected_fac: cb.sel_weapon,
});

// Enemies.
for (var e = 0; e < array_length(cb.enemies); e++) {
    var ec = cb.enemies[e];
    var le = cb.layout_e[e];

    if (ec.hull <= 0) {
        // Wreck: dimmed, no charge bars, struck through.
        draw_set_alpha(0.32);
        draw_car(ec, le.px, le.py, le.cs, { flip: false, show_charge: false, outline: p.text_mute });
        draw_set_alpha(1);
        draw_label(le.px + ec.gw * le.cs * 0.5, le.py + ec.gh * le.cs * 0.5,
                   "WRECKED", p.danger, fa_center, fa_middle, fnt_term_big);
        continue;
    }

    // Which of this enemy's facilities the player's weapons are aimed at.
    var tgt = -1;
    if (cb.sel_weapon >= 0 && cb.sel_weapon < array_length(cb.player.facs)) {
        var sw = cb.player.facs[cb.sel_weapon];
        if (sw.target_car == e) tgt = sw.target_fac;
    } else {
        for (var i = 0; i < array_length(cb.player.facs); i++) {
            var f = cb.player.facs[i];
            if (fac(f.def).charge > 0 && f.target_car == e) { tgt = f.target_fac; break; }
        }
    }

    // Nose-right, the same way the player is pointed. Everyone out here is
    // driving down the same road in the same direction — turning the enemies
    // around to face you made every fight read as a head-on joust instead of
    // a running battle at speed.
    draw_car(ec, le.px + kx * 0.5, le.py + ky * 0.5, le.cs, {
        flip: false,
        show_charge: car_has_sensors(cb.player),   // sensors reveal their timers
        hover_fac: (hover_car == e) ? hover_fac : -1,
        target_fac: tgt,
        outline: faction_colour(ec.faction),
    });
}

// ---------------------------------------------------------------- drones
// A dispatched drone is drawn hovering over the facility it's working on, with
// a beam down into the plating. Before this the only sign a drone was doing
// anything was a number in the side panel, so dispatching one felt like it had
// been swallowed.
for (var i = 0; i < array_length(cb.drones); i++) {
    var dr = cb.drones[i];
    if (dr.fac < 0 || dr.fac >= array_length(cb.player.facs)) continue;

    var df = cb.player.facs[dr.fac];
    var dp = combat_fac_pos(-1, dr.fac);
    var dcx = dp[0] + kx, dcy = dp[1] + ky;

    // Dousing a fire reads orange, patching plate reads green — the same
    // colours the effect and the repair use everywhere else.
    var busy   = (df.st.fire > 0);
    var dcol   = busy ? p.st_fire : p.ok;
    var phase  = current_time * 0.004 + i * 2.1;

    // Station off the corner of the cell so the glyph underneath stays legible,
    // bobbing on station rather than sitting still.
    var hov_x = dcx + 17 + dsin(phase * 40) * 3;
    var hov_y = dcy - 19 + dcos(phase * 55) * 3;

    // Working beam, plus a spatter of sparks where it lands.
    draw_set_alpha(0.55 + 0.25 * dsin(phase * 220));
    draw_line_width_colour(hov_x, hov_y + 6, dcx, dcy, 3, dcol, dcol);
    draw_set_alpha(1);
    for (var k = 0; k < 3; k++) {
        var sa = phase * 190 + k * 120;
        draw_circle_colour(dcx + dcos(sa) * 4, dcy + dsin(sa) * 4, 1.5, dcol, dcol, false);
    }

    // The drone: a lozenge body under a blurred rotor disc.
    draw_circle_colour(hov_x, hov_y, 8.5, merge_colour(dcol, p.shade, 0.25),
                                          merge_colour(dcol, p.shade, 0.45), false);
    draw_circle_colour(hov_x, hov_y, 8.5, p.atlas_ink, p.atlas_ink, true);
    draw_set_alpha(0.45);
    var rr2 = 12 + dsin(phase * 300) * 1.6;
    draw_circle_colour(hov_x, hov_y, rr2, p.lift, p.lift, true);
    draw_set_alpha(1);
    draw_circle_colour(hov_x, hov_y, 2.6, p.lift, p.lift, false);
}

// ---------------------------------------------------------------- headers
var heads = [{ car: cb.player, lay: lp, mine: true }];
for (var e = 0; e < array_length(cb.enemies); e++) {
    array_push(heads, { car: cb.enemies[e], lay: cb.layout_e[e], mine: false });
}

for (var i = 0; i < array_length(heads); i++) {
    var hc = heads[i].car;
    var hl = heads[i].lay;
    var mine = heads[i].mine;
    if (!mine && hc.hull <= 0) continue;

    // Narrow enough that two single-cell drones side by side don't collide.
    var hw = max(112, hc.gw * hl.cs);
    var hx = hl.px;
    // A repossession clock needs an extra row, so lift the block to make room —
    // and clear the bodywork, whose roofline reaches above the top row of cells
    // on anything with painted art.
    var lift_by = max(hl.cs * 0.34 + 46, car_art_rise(hc, hl.cs) + 34);
    var hy = hl.py - lift_by - ((hc.repo_max > 0) ? 14 : 0);
    var hcol = mine ? p.cyan : faction_colour(hc.faction);

    // The name is the anchor for this car's whole block, so it claims its
    // space before any of the status text that sits around it.
    var nsz = label_measure(hc.name, fnt_small);
    draw_label(hx, hy, hc.name, hcol, fa_left, fa_top, fnt_small);
    label_reserve(hx - 2, hy - 2, hx + nsz[0] + 2, hy + nsz[1] + 2);

    var frac_hull = hc.hull / max(1, hc.hull_max);
    var bcol = (frac_hull > 0.5) ? p.ok : ((frac_hull > 0.25) ? p.warn : p.danger);
    draw_bar(hx, hy + 15, hw, 9, frac_hull, bcol);
    draw_label(hx + hw + 6, hy + 14, string(ceil(hc.hull)) + "/" + string(hc.hull_max),
               p.text_dim, fa_left, fa_top, fnt_small);

    // Shield pips.
    var smax = car_shield_max(hc);
    if (smax > 0) draw_pips(hx, hy + 28, 16, 6, smax, hc.shield_cur, p.cat_defence);

    // Corporate repossession clock — the reason you can't just turtle back.
    if (hc.repo_max > 0) {
        var rx = hx, ry = hy + 28 + (smax > 0 ? 11 : 0);
        draw_label(rx, ry - 1, "REPO", p.danger, fa_left, fa_top, fnt_small);
        draw_bar(rx + 38, ry, hw - 38, 7, hc.repo / hc.repo_max, p.danger);
    }

    // Harpoon warning. It wants to sit on the name's line, out to the right —
    // but a long name on a narrow car leaves no room there, and the two used to
    // print straight through each other. If the line is full it drops below the
    // block instead.
    if (hc.harpoon > 0) {
        var htxt = "HARPOONED " + ui_secs(hc.harpoon);
        var hsz2 = label_measure(htxt, fnt_small);
        var inline_x1 = hx + hw - hsz2[0];
        if (inline_x1 > hx + nsz[0] + 10) {
            draw_label(hx + hw, hy, htxt, p.st_fire, fa_right, fa_top, fnt_small);
            label_reserve(inline_x1 - 2, hy - 2, hx + hw + 2, hy + hsz2[1] + 2);
        } else {
            var hby = hy + 28 + ((smax > 0) ? 11 : 0) + ((hc.repo_max > 0) ? 11 : 0);
            draw_label(hx, hby, htxt, p.st_fire, fa_left, fa_top, fnt_small);
            label_reserve(hx - 2, hby - 2, hx + hsz2[0] + 2, hby + hsz2[1] + 2);
        }
    }
}

// ---------------------------------------------------------------- shots
for (var i = 0; i < array_length(cb.shots); i++) {
    var s = cb.shots[i];
    if (s.t < 0) continue;
    var tt = clamp(s.t / s.dur, 0, 1);
    var cx = lerp(s.x0, s.x1, tt);
    var cy = lerp(s.y0, s.y1, tt);

    if (s.family == "hrp") {
        // The cable stays attached all the way out.
        draw_line_width_colour(s.x0, s.y0, cx, cy, 2, p.st_fire, p.amber);
        draw_circle_colour(cx, cy, 5, p.amber, p.st_fire, false);
    } else if (s.family == "tes") {
        // Jagged arc rather than a clean line.
        var prev_x = s.x0, prev_y = s.y0;
        for (var k = 1; k <= 6; k++) {
            var kt = tt * (k / 6);
            var nx = lerp(s.x0, s.x1, kt) + random_range(-7, 7);
            var ny = lerp(s.y0, s.y1, kt) + random_range(-7, 7);
            draw_line_width_colour(prev_x, prev_y, nx, ny, 2, p.st_elec, c_white);
            prev_x = nx; prev_y = ny;
        }
    } else {
        var tail = (s.family == "riv") ? 0.06 : 0.14;
        var bx = lerp(s.x0, s.x1, max(0, tt - tail));
        var by = lerp(s.y0, s.y1, max(0, tt - tail));
        var wdt = (s.family == "riv") ? 5 : ((s.family == "sct") ? 2 : 3);

        draw_set_alpha(0.30);
        draw_line_width_colour(bx, by, cx, cy, wdt + 4, s.col, s.col);
        draw_set_alpha(1);
        draw_line_width_colour(bx, by, cx, cy, wdt, c_white, s.col);
        if (s.family == "riv") draw_circle_colour(cx, cy, 4, c_white, s.col, false);
        if (s.family == "flm") draw_circle_colour(cx, cy, 6, p.st_fire, p.amber, false);
        if (s.family == "acd") draw_circle_colour(cx, cy, 5, p.st_acid, p.lime, false);
        if (s.family == "oil") draw_circle_colour(cx, cy, 5, p.st_oil, p.violet, false);
    }
}

// ---------------------------------------------------------------- pops
// A damage number rises out of the facility it happened to. Left alone it will
// climb straight through the car's name plate, so it stops just under whatever
// text is already there rather than being nudged sideways — a floating number
// that jitters is worse than one that hangs.
draw_set_font(fnt_small);
for (var i = 0; i < array_length(cb.pops); i++) {
    var pop = cb.pops[i];
    var a = 1 - (pop.t / 1.1);
    var psz = label_measure(pop.text, fnt_small);
    var py = pop.py - pop.t * 34;
    var guard = 0;
    while (guard < 6 && label_hits(pop.px - psz[0] * 0.5, py - psz[1] * 0.5,
                                   pop.px + psz[0] * 0.5, py + psz[1] * 0.5)) {
        py += 6;      // slide back down out of the plate
        guard += 1;
    }
    draw_set_alpha(a);
    draw_label(pop.px, py, pop.text, pop.col, fa_center, fa_middle);
    draw_set_alpha(1);
}

// ---------------------------------------------------------------- top bar
draw_set_alpha(0.85);
draw_rectangle_colour(0, 0, W, 60, p.panel, p.panel, p.bg, p.bg, false);
draw_set_alpha(1);
draw_line_width_colour(0, 60, W, 60, 2, p.edge, p.edge);

var fc = faction_colour(cb.ctx.faction);
draw_label(W * 0.5, 16, string_upper(faction_name(cb.ctx.faction)), fc, fa_center, fa_top, fnt_term_big);
var tagline = cb.ctx.boss ? "FINAL CREDITOR" : (cb.ctx.elite ? "RECOVERY CREW" : faction_blurb(cb.ctx.faction));
draw_set_font(fnt_small);
if (string_width(tagline) > 620) tagline = cb.ctx.faction == "" ? "" : "ENGAGED";
draw_label(W * 0.5, 42, tagline, p.text_dim, fa_center, fa_top, fnt_small);

draw_label(18, 14, "SECTOR " + string(global.run.sector) + " — " + sector_name(global.run.sector),
           p.text_dim, fa_left, fa_top, fnt_small);

// Weather stamp, just under the top bar — you need to be able to see why your
// shots keep going wide without reading the log.
//
// This used to hang off the tarmac band's top edge. That band went when the
// scrolling desert replaced it, taking road_y0 with it, and the stamp was left
// reading a variable that no longer existed — a crash, but only ever on the
// one screen nobody had rendered: a fight inside a hazard.
if (cb.hz != undefined) {
    var HZ_TOP = 68;
    var hzc = hazard_colour(cb.hz.id);
    var hzs = cb.hz.name + "  ·  " + hazard_effect_line(cb.hz.id);
    draw_set_font(fnt_small);
    var hzw = string_width(hzs) + 26;
    var hzx = W * 0.5 - hzw * 0.5;
    draw_set_alpha(0.90);
    draw_roundrect_colour(hzx, HZ_TOP, hzx + hzw, HZ_TOP + 22, p.atlas_cream, p.atlas_cream, false);
    draw_set_alpha(1);
    draw_roundrect_colour(hzx, HZ_TOP, hzx + hzw, HZ_TOP + 22, hzc, hzc, true);
    draw_label(W * 0.5, HZ_TOP + 11, hzs, hzc, fa_center, fa_middle, fnt_small);
    label_reserve(hzx - 2, HZ_TOP - 2, hzx + hzw + 2, HZ_TOP + 24);
}
draw_label(18, 32, "SCRAP " + string(global.run.scrap), p.amber, fa_left, fa_top, fnt_term);

draw_label(W - 18, 14, cb.paused ? "PAUSED" : "RUNNING", cb.paused ? p.amber : p.ok, fa_right, fa_top, fnt_term);
draw_label(W - 18, 36, "SPACE pause  ·  1-9 weapon  ·  E run  ·  RMB power", p.text_mute, fa_right, fa_top, fnt_small);

// ---------------------------------------------------------------- bottom
var by0 = 570;
draw_panel(12, by0, W - 12, H - 10, p.edge, 0.92);

// --- weapons ---
draw_label(26, by0 + 8, "WEAPONS", p.text_dim, fa_left, fa_top, fnt_small);

var weapons = car_facs_of_cat(cb.player, "weapon");
var wx = 26, wy = by0 + 26, wh = 74;

// Share the strip out between however many guns are fitted rather than
// running off the edge of the panel.
var wcount = min(array_length(weapons), 8);
var wavail = 664;
var ww = (wcount > 0) ? min(148, (wavail - (wcount - 1) * 8) / wcount) : 148;

for (var i = 0; i < wcount; i++) {
    var wi = weapons[i];
    var f  = cb.player.facs[wi];
    var d  = fac(f.def);
    var bx1 = wx + i * (ww + 8);
    var bx2 = bx1 + ww, by1 = wy, by2 = wy + wh;

    var sel = (cb.sel_weapon == wi);
    var ok  = fac_active(f);
    var col = sel ? p.cyan : (ok ? cat_colour(d.cat) : p.text_mute);

    draw_set_alpha(sel ? 0.20 : 0.08);
    draw_rectangle_colour(bx1, by1, bx2, by2, col, col, col, col, false);
    draw_set_alpha(1);
    draw_rectangle_colour(bx1, by1, bx2, by2, col, col, col, col, true);

    draw_set_font(fnt_small);
    draw_label(bx1 + 6, by1 + 5, ui_ellipsis(string(i + 1) + " " + d.name, ww - 12),
               ok ? p.text : p.text_mute, fa_left, fa_top, fnt_small);

    // Charge.
    var ccol = (f.charge >= 1) ? p.amber : p.cyan;
    if (!ok) ccol = p.text_mute;
    draw_bar(bx1 + 6, by1 + 24, ww - 12, 8, f.charge, ccol);
    var cs_txt = (f.charge >= 1) ? "READY"
               : ui_secs((1 - f.charge) * d.charge / max(0.01, car_charge_mult(cb.player) * status_rate_mult(f)));
    draw_label(bx1 + 6, by1 + 35, cs_txt, ccol, fa_left, fa_top, fnt_small);

    // What it's pointed at.
    var tstr = "NO TARGET";
    var tcol = p.text_mute;
    if (d.scatter) {
        tstr = "SCATTER";
        tcol = p.text_dim;
    } else if (combat_enemy_alive(f.target_car)) {
        var tc = cb.enemies[f.target_car];
        if (f.target_fac >= 0 && f.target_fac < array_length(tc.facs)) {
            tstr = fac(tc.facs[f.target_fac].def).name;
        } else {
            tstr = "CHASSIS";
        }
        tcol = p.magenta;
    }
    draw_set_font(fnt_small);
    draw_label(bx1 + 6, by1 + 51, ui_ellipsis(tstr, ww - 12), tcol, fa_left, fa_top, fnt_small);

    // Offline reason.
    if (!fac_alive(f))      draw_label(bx2 - 6, by1 + 35, "WRECKED", p.danger, fa_right, fa_top, fnt_small);
    else if (f.st.elec > 0) draw_label(bx2 - 6, by1 + 35, "SHORTED", p.st_elec, fa_right, fa_top, fnt_small);
    else if (!f.powered)    draw_label(bx2 - 6, by1 + 35, "NO PWR", p.text_mute, fa_right, fa_top, fnt_small);
    else if (f.st.oil > 0)  draw_label(bx2 - 6, by1 + 35, "OILED", p.st_oil, fa_right, fa_top, fnt_small);

    if (cb.over == "" && ui_clicked(bx1, by1, bx2, by2)) {
        cb.sel_weapon = (cb.sel_weapon == wi) ? -1 : wi;
    }
    if (ui_hover(bx1, by1, bx2, by2)) ui_tooltip(d.name, d.desc);
}

if (array_length(weapons) == 0) {
    draw_label(26, wy + 24, "NO WEAPONS FITTED — break away or die trying.", p.danger, fa_left, fa_top, fnt_term);
}

// --- systems column ---
var sx0 = 712, sy0 = by0 + 8;
draw_line_width_colour(sx0 - 14, by0 + 6, sx0 - 14, H - 18, 1, p.edge, p.edge);
draw_label(sx0, sy0, "RIG", p.text_dim, fa_left, fa_top, fnt_small);

// Power.
var gen = car_power_gen(cb.player), use = car_power_use(cb.player);
draw_label(sx0, sy0 + 20, "POWER", p.amber, fa_left, fa_top, fnt_small);
draw_pips(sx0 + 54, sy0 + 20, 11, 10, max(gen, use), use, (use > gen) ? p.danger : p.amber);
draw_label(sx0 + 54 + max(gen, use) * 14 + 6, sy0 + 19, string(use) + "/" + string(gen),
           (use > gen) ? p.danger : p.text_dim, fa_left, fa_top, fnt_small);

// Drones.
draw_label(sx0, sy0 + 42, "DRONES", p.ok, fa_left, fa_top, fnt_small);
draw_pips(sx0 + 54, sy0 + 42, 11, 10, array_length(cb.drones), combat_drones_idle(), p.ok);
draw_label(sx0 + 54 + array_length(cb.drones) * 14 + 6, sy0 + 41,
           string(combat_drones_idle()) + " idle", p.text_dim, fa_left, fa_top, fnt_small);

// Break-away — the drive spools by itself and holds at full. The button only
// comes alive once it's ready, so the decision is when to spend it.
var esc_rate = car_escape_rate(cb.player);
var pinned   = (cb.player.harpoon > 0);
var stalled  = (esc_rate <= 0 && cb.player.escape < 1);
var ready    = combat_can_escape();

var esc_col;
var esc_label;
if (ready) {
    // Pulse so a ready drive catches the eye mid-fight.
    esc_col   = merge_colour(p.amber, c_white, 0.35 + 0.35 * dsin(current_time * 0.35));
    esc_label = "BREAK AWAY NOW  [E]";
} else if (pinned) {
    esc_col   = p.danger;
    esc_label = "PINNED";
} else if (stalled) {
    esc_col   = p.text_mute;
    esc_label = "NO DRIVE";
} else {
    esc_col   = p.cat_move;
    esc_label = "DRIVE SPOOLING";
}

draw_set_font(fnt_small);
if (ui_button(sx0, sy0 + 60, sx0 + 200, sy0 + 88, esc_label, ready, esc_col)) {
    combat_try_escape();
}

// Meter, with its readout sitting inside it so the column stays narrow.
draw_bar(sx0, sy0 + 91, 200, 16, cb.player.escape, pinned ? p.danger : esc_col);

// White, because it sits on top of the filled meter.
var esc_read = "";
var read_col = c_white;
if (pinned)                    { esc_read = "CABLE " + ui_secs(cb.player.harpoon); }
else if (ready)                { esc_read = "READY"; }
else if (esc_rate <= 0)        { esc_read = "DRIVE DOWN"; }
else                           { esc_read = ui_secs((1 - cb.player.escape) / esc_rate); }

if (esc_read != "") {
    draw_label(sx0 + 195, sy0 + 99, esc_read, read_col, fa_right, fa_middle, fnt_small);
}

draw_label(sx0, sy0 + 113, "LMB rig = drone   RMB rig = power", p.text_mute, fa_left, fa_top, fnt_small);

// --- log column ---
var lx0 = 980;
draw_line_width_colour(lx0 - 14, by0 + 6, lx0 - 14, H - 18, 1, p.edge, p.edge);
draw_label(lx0, by0 + 8, "CHATTER", p.text_dim, fa_left, fa_top, fnt_small);
draw_set_font(fnt_small);

// Wrap to the column so long lines don't run off the screen edge, and show the
// most recent entries that fit.
var chat_w = W - 26 - lx0;
var chat = [];
for (var i = 0; i < array_length(cb.log); i++) {
    var wrapped = ui_wrap(cb.log[i], chat_w);
    for (var k = 0; k < array_length(wrapped); k++) array_push(chat, wrapped[k]);
}
var max_lines = 8;
var from = max(0, array_length(chat) - max_lines);
for (var i = from; i < array_length(chat); i++) {
    var age = array_length(chat) - i;
    draw_set_alpha(clamp(1 - age * 0.08, 0.4, 1));
    draw_label(lx0, by0 + 26 + (i - from) * 15, chat[i], p.text, fa_left, fa_top, fnt_small);
    draw_set_alpha(1);
}

// ---------------------------------------------------------------- overlays
if (cb.paused && cb.over == "") {
    draw_set_alpha(0.35);
    draw_rectangle_colour(0, 60, W, 560, p.bg, p.bg, p.bg, p.bg, false);
    draw_set_alpha(1);
    draw_glow_text(W * 0.5, 96, "PAUSED", p.amber, fa_center, fa_middle, fnt_term_big);
    draw_label(W * 0.5, 120, "pick targets, move drones, cut power — then SPACE to roll",
               p.text_dim, fa_center, fa_middle, fnt_small);
}

if (cb.sel_weapon >= 0 && cb.over == "") {
    draw_label(W * 0.5, 560 - 22, "AIMING " + fac(cb.player.facs[cb.sel_weapon].def).name
             + " — click an enemy facility  (ESC to cancel)", p.cyan, fa_center, fa_middle, fnt_term);
}

if (cb.over != "") {
    draw_set_alpha(0.72);
    draw_rectangle_colour(0, 0, W, H, p.bg, p.bg, p.bg, p.bg, false);
    draw_set_alpha(1);

    var ox1 = 360, oy1 = 220, ox2 = 920, oy2 = 500;
    var ocol = (cb.over == "win") ? p.ok : ((cb.over == "fled") ? p.amber : p.danger);
    draw_panel(ox1, oy1, ox2, oy2, ocol, 0.97);

    var head = (cb.over == "win") ? "ROAD CLEAR"
             : ((cb.over == "fled") ? "BROKE AWAY" : "TOTAL LOSS");
    draw_glow_text((ox1 + ox2) * 0.5, oy1 + 46, head, ocol, fa_center, fa_middle, fnt_term_big);

    draw_set_font(fnt_term);
    var body;
    if (cb.over == "win") {
        body = "Salvage recovered: " + string(cb.reward) + " scrap.";
        if (cb.bay_due) body += "   +1 CHASSIS BAY";
    } else if (cb.over == "fled") {
        body = "You left the fight and the salvage with it.";
    } else {
        body = "The rig is scrap. Somebody else will strip it by morning.";
    }
    draw_label((ox1 + ox2) * 0.5, oy1 + 96, body, p.text, fa_center, fa_middle, fnt_term);

    // What it cost you.
    var wrecked = 0;
    for (var i = 0; i < array_length(cb.player.facs); i++) if (cb.player.facs[i].hp <= 0) wrecked += 1;
    draw_label((ox1 + ox2) * 0.5, oy1 + 128,
        "HULL " + string(ceil(cb.player.hull)) + "/" + string(cb.player.hull_max)
      + "    FACILITIES DOWN " + string(wrecked), p.text_dim, fa_center, fa_middle, fnt_small);

    if (cb.over != "lose" && wrecked > 0) {
        draw_label((ox1 + ox2) * 0.5, oy1 + 150,
            "Wrecked facilities stay wrecked. Repair them at a truck stop.",
            p.warn, fa_center, fa_middle, fnt_small);
    }

    draw_set_font(fnt_term_big);
    var cbx = (ox1 + ox2) * 0.5 - 110;
    if (ui_button(cbx, oy2 - 74, cbx + 220, oy2 - 26, "CONTINUE", cb.over_t > 0.35, ocol)) {
        combat_exit();
    }
}

ui_draw_tooltip();
