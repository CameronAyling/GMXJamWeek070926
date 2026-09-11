var p = global.PAL;
var W = display_get_gui_width(), H = display_get_gui_height();

// ---------------------------------------------------------------- the cover
// The painted cover carries the masthead, the sample route, the imprint and
// the printed border — everything this screen used to fake with primitives.
draw_sprite_ext(Spr_BG_Main_Menu, 0, 0, 0,
                W / sprite_get_width(Spr_BG_Main_Menu),
                H / sprite_get_height(Spr_BG_Main_Menu),
                0, c_white, 1);

// ---------------------------------------------------------------- menu
// Three painted keys. The "selected" art is the lit face; BRIEFING also stays
// lit while its panel is open, so the button reads as a toggle.
for (var i = 0; i < array_length(menu_items); i++) {
    var lit = (menu_sel == i) || (i == 1 && show_briefing);
    var spr = lit ? menu_items[i].sel : menu_items[i].spr;

    draw_set_alpha(0.18);
    draw_sprite_ext(spr, 0, menu_items[i].x1 + 3, menu_items[i].y1 + 4,
                    menu_scale, menu_scale, 0, p.shade, 1);
    draw_set_alpha(1);
    draw_sprite_ext(spr, 0, menu_items[i].x1, menu_items[i].y1,
                    menu_scale, menu_scale, 0, c_white, 1);
}

// ---------------------------------------------------------------- briefing
// Slots into the empty desert below the keys, so the stack stays clickable
// while it's open and BRIEFING still toggles it shut.
if (show_briefing) {
    var px1 = 90, py1 = 508, px2 = 1190, py2 = 712;
    draw_panel(px1, py1, px2, py2, p.violet, 0.95);

    draw_set_font(fnt_term_big);
    draw_label(px1 + 22, py1 + 12, "DRIVER'S BRIEFING", p.cyan);
    draw_label(px2 - 22, py1 + 18, "ESC TO CLOSE", p.text_mute, fa_right, fa_top, fnt_small);

    draw_set_font(fnt_small);
    var lx = px1 + 22, ly = py1 + 40, colw = 330;

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

    // The bottom band is short, so its heading sits inline with the entries
    // rather than costing a whole line of its own.
    draw_set_font(fnt_small);
    var sy = py2 - 40;
    draw_label(lx, sy + 6, "STATUS EFFECTS", p.amber);
    var eff = [["ELECTRICITY", "elec", "facility offline"],
               ["FIRE", "fire", "burns it down, spreads"],
               ["OIL", "oil", "half speed, and it lights"],
               ["ACID", "acid", "melts armour, amplifies hits"]];
    for (var i = 0; i < 4; i++) {
        var ex = lx + 128 + i * 228;
        draw_circle_colour(ex + 5, sy + 7, 4, status_colour(eff[i][1]), status_colour(eff[i][1]), false);
        draw_label(ex + 16, sy, eff[i][0], status_colour(eff[i][1]));
        draw_label(ex + 16, sy + 14, eff[i][2], p.text_dim);
    }
}

ui_draw_tooltip();
