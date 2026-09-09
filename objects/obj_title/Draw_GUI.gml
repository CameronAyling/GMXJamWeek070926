var p = global.PAL;
var W = display_get_gui_width(), H = display_get_gui_height();

// ---------------------------------------------------------------- backdrop
draw_rectangle_colour(0, 0, W, H * 0.62, make_colour_rgb(38, 10, 52), make_colour_rgb(38, 10, 52),
                                          make_colour_rgb(96, 18, 74), make_colour_rgb(96, 18, 74), false);
draw_rectangle_colour(0, H * 0.62, W, H, p.bg, p.bg, make_colour_rgb(16, 8, 30), make_colour_rgb(16, 8, 30), false);

// Low sun behind the skyline.
var sun_y = H * 0.50;
for (var i = 10; i >= 0; i--) {
    draw_set_alpha(0.05 + i * 0.012);
    draw_circle_colour(W * 0.5, sun_y, 120 + i * 9, p.magenta, make_colour_rgb(60, 12, 60), false);
    draw_set_alpha(1);
}
draw_circle_colour(W * 0.5, sun_y, 118, make_colour_rgb(255, 150, 80), p.magenta, false);
// Scanline slices across the sun disc — the retro-futurist cliché, earned.
for (var yy = sun_y - 118; yy < sun_y + 118; yy += 12) {
    draw_set_alpha(0.55);
    draw_rectangle_colour(W * 0.5 - 130, yy, W * 0.5 + 130, yy + 4,
        make_colour_rgb(38, 10, 52), make_colour_rgb(38, 10, 52),
        make_colour_rgb(38, 10, 52), make_colour_rgb(38, 10, 52), false);
    draw_set_alpha(1);
}

// ---------------------------------------------------------------- skyline
var horizon = H * 0.615;
for (var i = 0; i < array_length(skyline); i++) {
    var b = skyline[i];
    var bh = b.h;
    draw_rectangle_colour(b.px, horizon - bh, b.px + b.w, horizon,
        make_colour_rgb(14, 8, 26), make_colour_rgb(14, 8, 26),
        make_colour_rgb(8, 5, 16), make_colour_rgb(8, 5, 16), false);
    // A few lit windows.
    for (var wy = horizon - bh + 8; wy < horizon - 8; wy += 14) {
        for (var wx = b.px + 6; wx < b.px + b.w - 8; wx += 12) {
            if (((wx + wy + b.lit * 7) mod 37) < 9) {
                draw_set_alpha(0.5);
                draw_rectangle_colour(wx, wy, wx + 4, wy + 6, p.amber, p.amber, p.amber, p.amber, false);
                draw_set_alpha(1);
            }
        }
    }
}

// ---------------------------------------------------------------- road grid
var vpx = W * 0.5, vpy = horizon;
draw_set_alpha(0.30);
for (var i = -12; i <= 12; i++) {
    var col = (abs(i) < 3) ? p.cyan : p.violet;
    draw_line_colour(vpx, vpy, vpx + i * 150, H, col, merge_colour(col, p.bg, 0.85));
}
var scroll = 1 - frac(t * 0.55);
for (var k = 0; k < 20; k++) {
    var z = k + scroll;
    var yy = vpy + (H - vpy) / (1 + z * 0.48);
    if (yy > H || yy < vpy + 1) continue;
    var a = 0.42 * (1 - (yy - vpy) / max(1, H - vpy) * 0.15) * min(1, (yy - vpy) / 30);
    draw_set_alpha(a);
    draw_line_colour(0, yy, W, yy, p.cyan, p.magenta);
}
draw_set_alpha(1);

// ---------------------------------------------------------------- title
var bob = dsin(t * 40) * 3;

draw_set_font(fnt_title);
var title = "FASTER THAN FUEL";
// Chromatic split, then the clean pass on top.
draw_set_alpha(0.55);
draw_label(vpx - 4, 132 + bob, title, make_colour_rgb(255, 40, 90), fa_center, fa_middle);
draw_label(vpx + 4, 132 + bob, title, make_colour_rgb(40, 220, 255), fa_center, fa_middle);
draw_set_alpha(1);
draw_label(vpx, 132 + bob, title, c_white, fa_center, fa_middle);

draw_set_font(fnt_term);
draw_label(vpx, 186 + bob, "A LONG HAUL THROUGH THE CREDITOR STATES", p.magenta, fa_center, fa_middle);

// Rule under the title.
draw_set_alpha(0.7);
draw_line_width_colour(vpx - 280, 208, vpx + 280, 208, 2, p.violet, p.violet);
draw_set_alpha(1);

// ---------------------------------------------------------------- menu
var bw = 250, bh = 44, bx = vpx - bw * 0.5, by = 250;

draw_set_font(fnt_term_big);
if (ui_button(bx, by, bx + bw, by + bh, "NEW RUN", true, p.cyan)) {
    run_new();
    goto_room(rm_garage);
}
draw_set_font(fnt_term);
if (ui_button(bx, by + 56, bx + bw, by + 56 + bh, show_briefing ? "HIDE BRIEFING" : "BRIEFING", true, p.violet)) {
    show_briefing = !show_briefing;   //gmx-lint-ignore draw-event-mutation
}
if (ui_button(bx, by + 112, bx + bw, by + 112 + bh, "QUIT", true, p.text_dim)) {
    game_end();
}
draw_label(vpx, by + 172, "or press ENTER", p.text_mute, fa_center, fa_middle, fnt_small);

// ---------------------------------------------------------------- briefing
if (show_briefing) {
    var px1 = 176, py1 = 418, px2 = 1104, py2 = 664;
    draw_panel(px1, py1, px2, py2, p.violet, 0.95);

    draw_set_font(fnt_term_big);
    draw_label(px1 + 22, py1 + 16, "DRIVER'S BRIEFING", p.cyan);

    draw_set_font(fnt_small);
    var lx = px1 + 22, ly = py1 + 52, colw = 288;

    draw_label(lx, ly, "THE RIG", p.amber);
    ui_text_block(lx, ly + 18,
        "Your car is a grid. Facilities occupy cells, and the bigger the tier the "
      + "uglier the shape. Everything drawing power has to fit under the reactor "
      + "budget, so every upgrade is a trade.", colw, p.text, 14);

    draw_label(lx + colw + 26, ly, "THE FIGHT", p.amber);
    ui_text_block(lx + colw + 26, ly + 18,
        "Real time. SPACE pauses so you can retarget. Click a weapon, then click "
      + "the enemy facility you want it on. Shields eat one whole shot per layer; "
      + "armour just subtracts. Your drive spools on its own — once the BREAK AWAY "
      + "meter is full, press E to take the gap and leave the salvage.", colw, p.text, 14);

    draw_label(lx + (colw + 26) * 2, ly, "WHAT'S OUT THERE", p.amber);
    ui_text_block(lx + (colw + 26) * 2, ly + 18,
        "Robots short you out. Bandits harpoon you so you can't run, then set you "
      + "alight. Corporations turtle behind shields on a repossession clock. "
      + "Insects eat armour with acid and heal what you break.", colw, p.text, 14);

    draw_set_font(fnt_small);
    var sy = py2 - 46;
    draw_label(lx, sy, "STATUS EFFECTS", p.amber);
    var eff = [["ELECTRICITY", "elec", "facility offline"],
               ["FIRE", "fire", "burns it down, spreads"],
               ["OIL", "oil", "half speed, and it lights"],
               ["ACID", "acid", "melts armour, amplifies hits"]];
    for (var i = 0; i < 4; i++) {
        var ex = lx + i * 228;
        draw_circle_colour(ex + 5, sy + 26, 4, status_colour(eff[i][1]), status_colour(eff[i][1]), false);
        draw_label(ex + 16, sy + 19, eff[i][0], status_colour(eff[i][1]));
        draw_label(ex + 16, sy + 31, eff[i][2], p.text_dim);
    }
}

ui_draw_tooltip();
