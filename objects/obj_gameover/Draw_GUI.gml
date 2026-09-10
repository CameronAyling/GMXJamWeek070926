var p = global.PAL;
var W = display_get_gui_width();
var H = display_get_gui_height();
var r = global.run;

draw_backdrop();

var accent = won ? global.PAL.ok : global.PAL.danger;

// The verdict, banged across the page in rubber: a ruled box on a slant with
// the word inside it and the ink deliberately imperfect.
var stamp = won ? "CLEARED" : "REPOSSESSED";
var sang  = won ? -7 : 9;
draw_set_font(fnt_title);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
// Banged into the empty left gutter, clear of the manifest — a stamp over the
// figures would be authentic and unreadable. One scale drives box and text so
// the rule always frames the word.
var ssc = 0.40;
var sw = string_width(stamp) * ssc * 0.5 + 18;
var sh = string_height(stamp) * ssc * 0.5 + 12;
var scx = 208, scy = 352;

draw_set_alpha(0.26);
for (var pass = 0; pass < 2; pass++) {
    // Two passes offset by a pixel — the double-strike of a stamp rocked on
    // its pad.
    var jx = pass * 2, jy = pass * 2;
    for (var b = 0; b < 2; b++) {
        var ex = sw - b * 8, ey = sh - b * 8;
        var cs2 = dcos(sang), sn = dsin(sang);
        var cnr = [[-ex, -ey], [ex, -ey], [ex, ey], [-ex, ey]];
        for (var k = 0; k < 4; k++) {
            var k2 = (k + 1) mod 4;
            draw_line_width_colour(
                scx + jx + cnr[k][0]  * cs2 - cnr[k][1]  * sn,
                scy + jy + cnr[k][0]  * sn  + cnr[k][1]  * cs2,
                scx + jx + cnr[k2][0] * cs2 - cnr[k2][1] * sn,
                scy + jy + cnr[k2][0] * sn  + cnr[k2][1] * cs2,
                5, accent, accent);
        }
    }
    draw_text_transformed_colour(scx + jx, scy + jy, stamp, ssc, ssc, sang,
                                 accent, accent, accent, accent, 1);
}
draw_set_alpha(1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

draw_glow_text(W * 0.5, 150, won ? "BORDER CLEARED" : "END OF THE LINE",
               accent, fa_center, fa_middle, fnt_title);

draw_set_font(fnt_term);
var sub = won
    ? "The barrier lifts, the ledger closes, and nobody follows you across."
    : "They'll strip the rig by morning and file the paperwork by noon.";
draw_label(W * 0.5, 208, sub, p.text_dim, fa_center, fa_middle, fnt_term);

// ---------------------------------------------------------------- summary
var bx1 = 400, by1 = 258, bx2 = 880, by2 = 508;
draw_panel(bx1, by1, bx2, by2, accent, 0.95);
draw_label(bx1 + 22, by1 + 16, "MANIFEST", p.text_dim, fa_left, fa_top, fnt_small);

var used = 0;
for (var i = 0; i < array_length(r.car.facs); i++) used += array_length(r.car.facs[i].cells);

var rows = [
    ["SECTOR REACHED", string(r.sector) + " / " + string(SECTOR_COUNT)],
    ["ROADBLOCKS CLEARED", string(r.kills)],
    ["HOPS DRIVEN", string(r.moves)],
    ["SCRAP ON HAND", string(r.scrap)],
    ["FUEL LEFT", string(r.fuel)],
    ["HULL", string(ceil(r.car.hull)) + " / " + string(r.car.hull_max)],
    ["GRID FILLED", string(used) + " / " + string(car_cell_count(r.car)) + " cells"],
];

draw_set_font(fnt_term);
for (var i = 0; i < array_length(rows); i++) {
    var ry = by1 + 44 + i * 28;
    draw_label(bx1 + 22, ry, rows[i][0], p.text_mute, fa_left, fa_top, fnt_small);
    draw_label(bx2 - 22, ry - 3, rows[i][1], p.text, fa_right, fa_top, fnt_term);
}

// The rig you finished with, small.
draw_label(940, by1 + 16, "THE RIG", p.text_dim, fa_left, fa_top, fnt_small);
draw_car(r.car, 950, by1 + 56, 26, { show_charge: false });

// ---------------------------------------------------------------- buttons
draw_set_font(fnt_term_big);
if (ui_button(W * 0.5 - 250, 556, W * 0.5 - 20, 604, "ANOTHER RUN", t > 0.4, p.cyan)) {
    run_new();
    goto_room(rm_garage);
}
if (ui_button(W * 0.5 + 20, 556, W * 0.5 + 250, 604, "TITLE", t > 0.4, p.violet)) {
    goto_room(rm_title);
}

draw_label(W * 0.5, 640, won
    ? "Try it again with a leaner rig — see how few cells you can win on."
    : "Different loadout, different road. The grid is the game.",
    p.text_mute, fa_center, fa_middle, fnt_small);

ui_draw_tooltip();
