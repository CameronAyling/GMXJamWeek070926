var p = global.PAL;
var W = display_get_gui_width(), H = display_get_gui_height();
var vpx = W * 0.5;

// ---------------------------------------------------------------- the cover
// This is the front of the atlas the map screen is a page from: same stock,
// same banner, same badges.
draw_backdrop();

// --------------------------------------------------------------- the route
// A sample route printed across the lower half, ink lines with a lighter core
// exactly as the atlas draws its roads.
for (var i = 0; i < array_length(cover_route) - 1; i++) {
    var a = cover_route[i], b2 = cover_route[i + 1];
    draw_set_alpha(0.30);
    draw_line_width_colour(a.px, a.py, b2.px, b2.py, 6, p.atlas_ink, p.atlas_ink);
    draw_set_alpha(0.80);
    draw_line_width_colour(a.px, a.py, b2.px, b2.py, 3, p.atlas_live, p.atlas_live);
    draw_set_alpha(1);
}
for (var i = 0; i < array_length(cover_badges); i++) {
    var bd  = cover_badges[i];
    var nd  = cover_route[bd.at];
    var ics = 40;
    draw_sprite_ext(bd.spr, 0, nd.px, nd.py,
                    ics / sprite_get_width(bd.spr), ics / sprite_get_height(bd.spr),
                    0, c_white, 0.92);
}

// ---------------------------------------------------------------- masthead
draw_label(vpx, 62, "GENE INCORPORATED  ·  MOTORISTS' ATLAS  ·  47TH EDITION",
           p.text_dim, fa_center, fa_middle, fnt_small);

draw_glow_text(vpx, 126, "FASTER THAN FUEL", p.atlas_ink, fa_center, fa_middle, fnt_title);

// The orange banner the map screen wears under its masthead.
var bnx = 268, bny = 172, bnw = 744, bnh = 34;
draw_rectangle_colour(bnx, bny, bnx + bnw, bny + bnh,
    make_colour_rgb(232, 106, 74), make_colour_rgb(236, 118, 78),
    make_colour_rgb(226,  96, 66), make_colour_rgb(230, 108, 72), false);
draw_set_alpha(0.5);
draw_rectangle_colour(bnx, bny, bnx + bnw, bny + bnh, p.atlas_ink, p.atlas_ink, p.atlas_ink, p.atlas_ink, true);
draw_set_alpha(1);
draw_label(vpx, bny + bnh * 0.5, "A LONG HAUL THROUGH THE CREDITOR STATES",
           make_colour_rgb(58, 30, 22), fa_center, fa_middle, fnt_term);

// Twin rules under the banner, the map's masthead trick.
draw_set_alpha(0.55);
draw_line_width_colour(bnx, bny + bnh + 6, bnx + bnw, bny + bnh + 6, 2, p.atlas_live, p.atlas_live);
draw_line_width_colour(bnx, bny + bnh + 11, bnx + bnw, bny + bnh + 11, 1, p.atlas_live, p.atlas_live);
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

// ------------------------------------------------------------ imprint
// The publisher's roundel, top-right, exactly where the atlas page carries it.
var gix = 1216, giy = 58, gir = 30;
draw_circle_colour(gix, giy, gir, p.atlas_live, merge_colour(p.atlas_live, p.shade, 0.3), false);
draw_set_alpha(0.45);
draw_circle_colour(gix, giy, gir, p.atlas_ink, p.atlas_ink, true);
draw_set_alpha(1);
draw_label(gix, giy, "GI", p.atlas_cream, fa_center, fa_middle, fnt_term_big);

draw_label(30, H - 30, "LEGALLY NOT A MONOPOLY", p.text_mute, fa_left, fa_middle, fnt_small);
draw_label(W - 30, H - 30, "GENE INCORPORATED  ·  EVERYTHING TOMORROW NEEDS",
           p.text_dim, fa_right, fa_middle, fnt_small);

ui_draw_tooltip();
