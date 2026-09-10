var p  = global.PAL;
var cb = global.cb;
var W  = display_get_gui_width();
var H  = display_get_gui_height();

draw_backdrop();

// Screen shake on hits.
var kx = 0, ky = 0;
if (cb.shake > 0) {
    kx = random_range(-cb.shake, cb.shake);
    ky = random_range(-cb.shake, cb.shake);
}

// ---------------------------------------------------------------- the road
// Scrolling tarmac under both rigs so the fight reads as happening at speed.
// Printed as a road is on the atlas: a band of tarmac laid on the paper with
// a dark casing either side and cream dashes running down it.
var road_y0 = 108, road_y1 = 556;
// Kept pale: on a map the carriageway is a fill a shade off the paper, not a
// dark slab. Anything heavier and the rigs stop reading as ink on a page.
var tar_hi = merge_colour(p.bg, p.shade, 0.15);
var tar_lo = merge_colour(p.bg, p.shade, 0.24);
draw_rectangle_colour(0, road_y0, W, road_y1, tar_hi, tar_hi, tar_lo, tar_lo, false);

// Hard shoulder hatching along both kerbs.
draw_set_alpha(0.20);
for (var hx = -24; hx < W + 24; hx += 16) {
    draw_line_width_colour(hx, road_y0 + 13, hx + 10, road_y0 + 1, 2, p.atlas_ink, p.atlas_ink);
    draw_line_width_colour(hx, road_y1 - 1,  hx + 10, road_y1 - 13, 2, p.atlas_ink, p.atlas_ink);
}
draw_set_alpha(1);

var scroll = (cb.paused || cb.over != "") ? 0 : cb.time;
draw_set_alpha(0.55);
for (var i = 0; i < 7; i++) {
    var ly = road_y0 + 34 + i * 68;
    var off = frac(scroll * (0.35 + i * 0.05)) * 190;
    for (var dx = -190; dx < W + 190; dx += 190) {
        draw_line_width_colour(dx + off, ly, dx + off + 84, ly, 3, p.atlas_cream, p.atlas_cream);
    }
}
draw_set_alpha(1);

// Kerb lines: heavy ink casing, the way a road is drawn on the map.
draw_line_width_colour(0, road_y0, W, road_y0, 3, p.atlas_ink, p.atlas_ink);
draw_line_width_colour(0, road_y1, W, road_y1, 3, p.atlas_ink, p.atlas_ink);
draw_set_alpha(0.5);
draw_line_width_colour(0, road_y0 + 3, W, road_y0 + 3, 1, p.atlas_cream, p.atlas_cream);
draw_line_width_colour(0, road_y1 - 3, W, road_y1 - 3, 1, p.atlas_cream, p.atlas_cream);
draw_set_alpha(1);

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
        draw_car(ec, le.px, le.py, le.cs, { flip: true, show_charge: false, outline: p.text_mute });
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

    draw_car(ec, le.px + kx * 0.5, le.py + ky * 0.5, le.cs, {
        flip: true,
        show_charge: car_has_sensors(cb.player),   // sensors reveal their timers
        hover_fac: (hover_car == e) ? hover_fac : -1,
        target_fac: tgt,
        outline: faction_colour(ec.faction),
    });
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
    // A repossession clock needs an extra row, so lift the block to make room.
    var hy = hl.py - hl.cs * 0.34 - 46 - ((hc.repo_max > 0) ? 14 : 0);
    var hcol = mine ? p.cyan : faction_colour(hc.faction);

    draw_label(hx, hy, hc.name, hcol, fa_left, fa_top, fnt_small);

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

    // Harpoon warning.
    if (hc.harpoon > 0) {
        draw_label(hx + hw, hy, "HARPOONED " + ui_secs(hc.harpoon), p.st_fire, fa_right, fa_top, fnt_small);
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
draw_set_font(fnt_small);
for (var i = 0; i < array_length(cb.pops); i++) {
    var pop = cb.pops[i];
    var a = 1 - (pop.t / 1.1);
    draw_set_alpha(a);
    draw_label(pop.px, pop.py - pop.t * 34, pop.text, pop.col, fa_center, fa_middle);
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

// Weather stamp, over the road itself — you need to be able to see why your
// shots keep going wide without reading the log.
if (cb.hz != undefined) {
    var hzc = hazard_colour(cb.hz.id);
    var hzs = cb.hz.name + "  ·  " + hazard_effect_line(cb.hz.id);
    draw_set_font(fnt_small);
    var hzw = string_width(hzs) + 26;
    var hzx = W * 0.5 - hzw * 0.5;
    draw_set_alpha(0.90);
    draw_roundrect_colour(hzx, road_y0 + 8, hzx + hzw, road_y0 + 30, p.atlas_cream, p.atlas_cream, false);
    draw_set_alpha(1);
    draw_roundrect_colour(hzx, road_y0 + 8, hzx + hzw, road_y0 + 30, hzc, hzc, true);
    draw_label(W * 0.5, road_y0 + 19, hzs, hzc, fa_center, fa_middle, fnt_small);
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
