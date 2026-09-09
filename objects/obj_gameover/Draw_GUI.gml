var p = global.PAL;
var W = display_get_gui_width();
var H = display_get_gui_height();
var r = global.run;

draw_backdrop();

var accent = won ? global.PAL.ok : global.PAL.danger;

// Horizon glow — sunrise if you made it, burning wreck if you didn't.
for (var i = 12; i >= 0; i--) {
    draw_set_alpha(0.035 + i * 0.008);
    draw_circle_colour(W * 0.5, won ? H * 0.30 : H * 0.62, 130 + i * 16,
                       accent, p.bg, false);
    draw_set_alpha(1);
}

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
