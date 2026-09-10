var p   = global.PAL;
var W   = display_get_gui_width();
var H   = display_get_gui_height();
var r   = global.run;
var car = r.car;
var ctx = global.garage_ctx;

draw_backdrop();

// ---------------------------------------------------------------- header
draw_set_alpha(0.85);
draw_rectangle_colour(0, 0, W, 58, p.panel, p.panel, p.bg, p.bg, false);
draw_set_alpha(1);
draw_line_width_colour(0, 58, W, 58, 2, p.edge, p.edge);

draw_label(22, 12, ctx.shop ? "TRUCK STOP — CHASSIS BAY" : "CHASSIS FIT-OUT",
           p.cyan, fa_left, fa_top, fnt_term_big);
draw_label(22, 38, car.name + "   " + string(car_cell_count(car)) + " CELLS"
         + (car.trailer ? "   + TRAILER"
                        : ("   BAY " + string(car.bays) + "/" + string(car_max_bays(car)))),
           p.text_dim, fa_left, fa_top, fnt_small);

draw_label(W - 22, 12, "SCRAP " + string(r.scrap), p.amber, fa_right, fa_top, fnt_term_big);
draw_label(W - 22, 40, "FUEL " + string(r.fuel) + "    SECTOR " + string(r.sector),
           p.text_dim, fa_right, fa_top, fnt_small);

// ---------------------------------------------------------------- the rig
// Above the bodywork: with the art hung off the deck the van's roofline now
// reaches up to y~115, and these used to end up printed across the bonnet.
draw_label(gx, 70, "CHASSIS", p.text_dim, fa_left, fa_top, fnt_small);
draw_label(gx, 86, held == ""
    ? "LMB lift  ·  RMB strip to trailer"
    : "LMB drop  ·  R rotate  ·  ESC stow",
    held == "" ? p.text_mute : p.ok, fa_left, fa_top, fnt_small);

var hover_fi = -1;
var cell = car_cell_at(car, gx, gy, cs, ui_mx(), ui_my());
if (is_array(cell) && held == "") hover_fi = car_at(car, cell[0], cell[1]);

draw_car(car, gx, gy, cs, { show_charge: false, hover_fac: hover_fi });

// Ghost preview of the held piece.
if (held != "") {
    var hd = fac(held);
    var hcells = shape_rotated(hd.cells, held_rot);

    if (is_array(cell)) {
        var ok = car_can_place(car, hcells, cell[0], cell[1]);
        var col = ok ? p.ok : p.danger;
        for (var i = 0; i < array_length(hcells); i++) {
            var cx = gx + (cell[0] + hcells[i][0]) * cs;
            var cy = gy + (cell[1] + hcells[i][1]) * cs;
            draw_set_alpha(0.28);
            draw_rectangle_colour(cx + 2, cy + 2, cx + cs - 2, cy + cs - 2, col, col, col, col, false);
            draw_set_alpha(0.95);
            draw_rectangle_colour(cx + 2, cy + 2, cx + cs - 2, cy + cs - 2, col, col, col, col, true);
            draw_set_alpha(1);
        }
        var ext = shape_extent(hcells);
        draw_fac_glyph(hd.family,
            gx + (cell[0] + ext[0] * 0.5) * cs,
            gy + (cell[1] + ext[1] * 0.5) * cs,
            cs * 0.32, col);
    } else {
        // Held but off the grid — carry it on the cursor.
        var mx = ui_mx(), my = ui_my();
        var gcs = 30;
        for (var i = 0; i < array_length(hcells); i++) {
            var cx = mx + hcells[i][0] * gcs + 12;
            var cy = my + hcells[i][1] * gcs + 12;
            draw_set_alpha(0.55);
            draw_rectangle_colour(cx, cy, cx + gcs - 2, cy + gcs - 2,
                cat_colour(hd.cat), cat_colour(hd.cat), cat_colour(hd.cat), cat_colour(hd.cat), false);
            draw_set_alpha(1);
        }
    }

    draw_label(gx, 478, "HOLDING  " + hd.name + "   [" + fac_stat_line(held) + "]",
               p.ok, fa_left, fa_top, fnt_small);
}

if (hover_fi != -1) {
    var hf = car.facs[hover_fi];
    var hdd = fac(hf.def);
    var extra = hdd.desc;
    if (hf.hp <= 0) extra = "WRECKED — repair at a truck stop. " + extra;
    ui_tooltip(hdd.name + "  [" + fac_stat_line(hf.def) + "]", extra);
}

// ---------------------------------------------------------------- stats
var s1 = 28, s2 = 470, sy1 = 496, sy2 = 636;
draw_panel(s1, sy1, s2, sy2, p.edge, 0.9);
draw_label(s1 + 14, sy1 + 8, "PERFORMANCE", p.text_dim, fa_left, fa_top, fnt_small);

var used_cells = 0;
for (var i = 0; i < array_length(car.facs); i++) used_cells += array_length(car.facs[i].cells);

var rows = [
    ["ARMOUR",      string(car_armour(car)),                                    p.cat_defence],
    ["SHIELDS",     string(car_shield_max(car)) + " layer"
                    + (car_shield_max(car) == 1 ? "" : "s"),                    p.cat_defence],
    ["EVASION",     string(round(car_evade(car) * 100)) + "%",                  p.cat_move],
    ["BREAK-AWAY",  (car_escape_rate(car) > 0)
                    ? ui_secs(1 / car_escape_rate(car)) : "NO DRIVE",           p.cat_move],
    ["DRONES",      string(car_drones(car)),                                    p.ok],
    ["CHARGE",      "+" + string(round((car_charge_mult(car) - 1) * 100)) + "%", p.cat_weapon],
    ["INTERCEPT",   string(round(car_intercept(car) * 100)) + "%",              p.cat_defence],
    ["CELLS",       string(used_cells) + "/" + string(car_cell_count(car)),     p.text_dim],
];

draw_set_font(fnt_small);
for (var i = 0; i < array_length(rows); i++) {
    var rx = s1 + 14 + (i mod 2) * 216;
    var ry = sy1 + 28 + floor(i / 2) * 26;
    draw_label(rx, ry, rows[i][0], p.text_mute, fa_left, fa_top, fnt_small);
    draw_label(rx + 104, ry - 2, rows[i][1], rows[i][2], fa_left, fa_top, fnt_term);
}

// ---------------------------------------------------------------- inventory
var ix1 = 500;
var ix2 = ctx.shop ? 866 : 1252;
var iy1 = 78, iy2 = 636;
draw_panel(ix1, iy1, ix2, iy2, p.violet, 0.9);
draw_label(ix1 + 14, iy1 + 10, "IN THE TRAILER", p.violet, fa_left, fa_top, fnt_term);
draw_label(ix2 - 14, iy1 + 12, string(array_length(r.inv)) + " spare"
         + (array_length(r.inv) == 1 ? "" : "s"), p.text_dim, fa_right, fa_top, fnt_small);

if (array_length(r.inv) == 0) {
    draw_label(ix1 + 14, iy1 + 44, "Empty. Strip something off the rig, or buy at a truck stop.",
               p.text_mute, fa_left, fa_top, fnt_small);
}

var row_h = 44;
for (var i = 0; i < array_length(r.inv); i++) {
    var ry1 = iy1 + 40 + i * row_h;
    var ry2 = ry1 + row_h - 6;
    if (ry2 > iy2 - 10) {
        draw_label(ix1 + 14, ry1, "...and " + string(array_length(r.inv) - i) + " more",
                   p.text_mute, fa_left, fa_top, fnt_small);
        break;
    }

    var did = r.inv[i];
    var d = fac(did);
    var hov = ui_hover(ix1 + 8, ry1, ix2 - 8, ry2);
    var ccol = cat_colour(d.cat);

    draw_set_alpha(hov ? 0.18 : 0.07);
    draw_rectangle_colour(ix1 + 8, ry1, ix2 - 8, ry2, ccol, ccol, ccol, ccol, false);
    draw_set_alpha(1);
    draw_rectangle_colour(ix1 + 8, ry1, ix2 - 8, ry2, hov ? ccol : merge_colour(ccol, p.edge, 0.6),
                          hov ? ccol : merge_colour(ccol, p.edge, 0.6),
                          hov ? ccol : merge_colour(ccol, p.edge, 0.6),
                          hov ? ccol : merge_colour(ccol, p.edge, 0.6), true);

    draw_fac_glyph(d.family, ix1 + 30, (ry1 + ry2) * 0.5, 13, ccol);
    draw_label(ix1 + 52, ry1 + 5, d.name, p.text, fa_left, fa_top, fnt_term);
    draw_label(ix1 + 52, ry1 + 24, fac_stat_line(did), p.text_dim, fa_left, fa_top, fnt_small);

    if (ctx.shop) {
        // On the stat-line row: names can be long, stat lines never reach here.
        draw_label(ix2 - 18, ry1 + 24, "SELL " + string(sell_price(did)),
                   p.amber, fa_right, fa_top, fnt_small);
    }

    if (hov) ui_tooltip(d.name, d.desc);

    if (held == "" && ui_clicked(ix1 + 8, ry1, ix2 - 8, ry2)) {
        // Immediate-mode widget: the click is only known at draw time.
        held = did;         //gmx-lint-ignore draw-event-mutation
        held_rot = 0;       //gmx-lint-ignore draw-event-mutation
        held_from = i;      //gmx-lint-ignore draw-event-mutation
        array_delete(r.inv, i, 1);
        break;
    }
    if (ctx.shop && ui_rclicked(ix1 + 8, ry1, ix2 - 8, ry2)) {
        run_add_scrap(sell_price(did));
        garage_msg("Sold " + d.name + ".");
        array_delete(r.inv, i, 1);
        break;
    }
}

// ---------------------------------------------------------------- shop
if (ctx.shop) {
    var sx1 = 880, sx2 = 1252;
    draw_panel(sx1, iy1, sx2, iy2, p.amber, 0.9);
    draw_label(sx1 + 14, iy1 + 10, "FOR SALE", p.amber, fa_left, fa_top, fnt_term);

    for (var i = 0; i < array_length(ctx.stock); i++) {
        var ry1 = iy1 + 40 + i * row_h;
        var ry2 = ry1 + row_h - 6;
        var did = ctx.stock[i];
        var d = fac(did);
        var afford = (r.scrap >= d.cost);
        var hov = ui_hover(sx1 + 8, ry1, sx2 - 8, ry2);
        var ccol = afford ? cat_colour(d.cat) : p.text_mute;

        draw_set_alpha(hov && afford ? 0.18 : 0.07);
        draw_rectangle_colour(sx1 + 8, ry1, sx2 - 8, ry2, ccol, ccol, ccol, ccol, false);
        draw_set_alpha(1);
        draw_rectangle_colour(sx1 + 8, ry1, sx2 - 8, ry2, ccol, ccol, ccol, ccol, true);

        draw_fac_glyph(d.family, sx1 + 30, (ry1 + ry2) * 0.5, 13, ccol);
        draw_label(sx1 + 52, ry1 + 5, d.name, afford ? p.text : p.text_mute, fa_left, fa_top, fnt_term);
        draw_label(sx1 + 52, ry1 + 24, fac_stat_line(did), p.text_dim, fa_left, fa_top, fnt_small);
        draw_label(sx2 - 18, ry1 + 6, string(d.cost), afford ? p.amber : p.danger, fa_right, fa_top, fnt_term);

        if (hov) ui_tooltip(d.name + "   " + string(d.cost) + " scrap", d.desc);

        if (afford && ui_clicked(sx1 + 8, ry1, sx2 - 8, ry2)) {
            run_add_scrap(-d.cost);
            array_push(r.inv, did);
            array_delete(ctx.stock, i, 1);
            garage_msg("Bought " + d.name + ". It's in the trailer.");
            break;
        }
    }

    // --- services ---
    var svy = iy2 - 154;
    draw_line_width_colour(sx1 + 10, svy - 10, sx2 - 10, svy - 10, 1, p.edge, p.edge);
    draw_label(sx1 + 14, svy - 4, "SERVICES", p.text_dim, fa_left, fa_top, fnt_small);

    var bw = sx2 - sx1 - 28, bh = 30;

    // Hull.
    var hull_missing = car.hull_max - car.hull;
    var hull_cost = min(r.scrap, hull_missing * HULL_REPAIR_COST);
    var hull_amt = floor(hull_cost / HULL_REPAIR_COST);
    draw_set_font(fnt_small);
    if (ui_button(sx1 + 14, svy + 14, sx1 + 14 + bw, svy + 14 + bh,
        (hull_missing <= 0) ? "HULL INTACT"
                            : ("PATCH HULL +" + string(hull_amt) + "  (" + string(hull_amt * HULL_REPAIR_COST) + ")"),
        hull_missing > 0 && hull_amt > 0, p.ok)) {
        run_add_scrap(-hull_amt * HULL_REPAIR_COST);
        run_repair_hull(hull_amt);
        garage_msg("Hull patched.");
    }

    // Wrecked facilities.
    var wrecked = run_wrecked_count();
    var wcost = wrecked * FAC_REPAIR_COST;
    if (ui_button(sx1 + 14, svy + 50, sx1 + 14 + bw, svy + 50 + bh,
        (wrecked == 0) ? "NOTHING WRECKED"
                       : ("REBUILD " + string(wrecked) + " FACILITY"
                          + (wrecked == 1 ? "" : "S") + "  (" + string(wcost) + ")"),
        wrecked > 0 && r.scrap >= wcost, p.cyan)) {
        run_add_scrap(-wcost);
        for (var i = 0; i < array_length(car.facs); i++) {
            if (car.facs[i].hp <= 0) car.facs[i].hp = car.facs[i].hp_max;
        }
        garage_msg("Everything's turning over again.");
    }

    // Fuel.
    if (ui_button(sx1 + 14, svy + 86, sx1 + 14 + bw, svy + 86 + bh,
        "FUEL +3  (" + string(FUEL_COST * 3) + ")", r.scrap >= FUEL_COST * 3, p.amber)) {
        run_add_scrap(-FUEL_COST * 3);
        run_add_fuel(3);
        garage_msg("Three more in the tank.");
    }

    // Chassis extension — the big scrap sink, and the only way to get more room.
    // Chassis growth: bays come free with every win, or dearly over the counter
    // if you can't wait. The trailer only ever comes over the counter.
    var up_label, up_cost, up_ok;
    if (car_can_upgrade_bay(car)) {
        up_cost  = bay_cost(car);
        up_label = "BUY A BAY  +1 CELL  " + string(car.bays) + "/" + string(car_max_bays(car))
                 + "  (" + string(up_cost) + ")";
        up_ok    = (r.scrap >= up_cost);
    } else if (car_can_attach_trailer(car)) {
        up_cost  = trailer_cost();
        up_label = "HITCH A TRAILER  +2x2  (" + string(up_cost) + ")";
        up_ok    = (r.scrap >= up_cost);
    } else {
        up_cost  = 0;
        up_label = "CHASSIS MAXED";
        up_ok    = false;
    }

    if (ui_button(sx1 + 14, svy + 122, sx1 + 14 + bw, svy + 122 + bh, up_label, up_ok, p.violet)) {
        run_add_scrap(-up_cost);
        if (car_can_upgrade_bay(car)) {
            car_upgrade_bay(car);
            garage_msg(car_can_upgrade_bay(car)
                ? "One more cell of deck — cheaper to win the next one."
                : "Rear bay finished. Now about that trailer...");
        } else {
            car_attach_trailer(car);
            garage_msg("Trailer on the hitch. Four more cells, dragging behind you.");
        }
        garage_fit();
    }
}

// ---------------------------------------------------------------- bottom bar
var by1 = 648;
draw_set_alpha(0.9);
draw_rectangle_colour(0, by1, W, H, p.panel, p.panel, p.bg, p.bg, false);
draw_set_alpha(1);
draw_line_width_colour(0, by1, W, by1, 2, p.edge, p.edge);

var demand = car_power_demand(car);
var capp   = car_power_cap(car);
var over   = (demand > capp);

draw_label(22, by1 + 10, "REACTOR BUDGET", p.text_dim, fa_left, fa_top, fnt_small);
draw_pips(22, by1 + 28, 13, 14, max(demand, capp), demand, over ? p.danger : p.amber);
draw_label(22 + max(demand, capp) * 16 + 10, by1 + 26,
           string(demand) + " / " + string(capp), over ? p.danger : p.text, fa_left, fa_top, fnt_term);

var hx = 420;
draw_label(hx, by1 + 10, "HULL", p.text_dim, fa_left, fa_top, fnt_small);
var hfrac = car.hull / max(1, car.hull_max);
draw_bar(hx, by1 + 28, 190, 14, hfrac, (hfrac > 0.5) ? p.ok : ((hfrac > 0.25) ? p.warn : p.danger));
draw_label(hx + 198, by1 + 26, string(ceil(car.hull)) + "/" + string(car.hull_max),
           p.text_dim, fa_left, fa_top, fnt_term);

// Warnings — the reasons you can't leave yet.
var warn = "";
if (over) warn = "OVER BUDGET — strip " + string(demand - capp) + " power of kit, or fit a bigger reactor.";
else if (held != "") warn = "You're still holding something. Fit it or stow it.";
else if (array_length(car_facs_of_cat(car, "weapon")) == 0
      && car_escape_rate(car) <= 0) warn = "No weapons and no drive. That's a coffin.";
else if (run_wrecked_count() > 0) warn = string(run_wrecked_count()) + " facility(s) wrecked and dead weight.";

if (msg_t > 0) {
    draw_label(700, by1 + 12, msg, p.ok, fa_left, fa_top, fnt_small);
} else if (warn != "") {
    draw_label(700, by1 + 12, warn, over ? p.danger : p.warn, fa_left, fa_top, fnt_small);
}

draw_set_font(fnt_term_big);
var can_go = !over && held == "";
if (ui_button(W - 322, by1 + 14, W - 22, by1 + 56,
              (ctx.shop || ctx.from_map) ? "BACK TO THE ATLAS" : "HIT THE ROAD",
              can_go, can_go ? p.cyan : p.text_mute)) {
    goto_room(rm_map);
}

ui_draw_tooltip();
