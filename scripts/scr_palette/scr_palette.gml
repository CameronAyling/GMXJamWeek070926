/// scr_palette — colours and the printed-page draw vocabulary.
///
/// The whole game is one document: a road atlas with the fight, the garage and
/// the title all printed on the same warm stock. Every screen draws through
/// these helpers so the paper look stays consistent, and the atlas map is the
/// reference the rest of it is matched to.
///
/// Two colours do the shading work everywhere: `shade` is what you merge
/// toward for depth, `lift` for a highlight. On paper those are ink and cream
/// rather than black and white, which is why callers never reach for c_black.

function palette_init() {
    global.PAL = {
        // --- the stock itself ---
        bg          : make_colour_rgb(214, 188, 146),
        bg_grad     : make_colour_rgb(236, 218, 184),
        panel       : make_colour_rgb(240, 224, 192),
        panel_hi    : make_colour_rgb(250, 240, 214),
        edge        : make_colour_rgb(150, 112,  82),
        edge_hot    : make_colour_rgb(214,  88,  54),

        // --- spot inks. A cheap press run: five plates plus black. ---
        magenta     : make_colour_rgb(176,  46,  86),
        cyan        : make_colour_rgb( 40, 106, 138),
        amber       : make_colour_rgb(198, 132,  32),
        lime        : make_colour_rgb(104, 134,  46),
        violet      : make_colour_rgb(110,  74, 132),

        // --- text ---
        text        : make_colour_rgb( 58,  34,  22),
        text_dim    : make_colour_rgb(122,  86,  62),
        text_mute   : make_colour_rgb(138, 108,  78),

        // --- states ---
        danger      : make_colour_rgb(168,  38,  30),
        ok          : make_colour_rgb( 78, 122,  56),
        warn        : make_colour_rgb(198, 132,  32),

        // --- status effects. Saturated on purpose: these are spot plates
        // printed over tan stock, and a muted ink just turns to mud. ---
        st_elec     : make_colour_rgb( 26, 122, 176),
        st_fire     : make_colour_rgb(226,  74,  20),
        st_oil      : make_colour_rgb( 86,  56, 128),
        st_acid     : make_colour_rgb(128, 168,  24),

        // --- facility categories, same reasoning ---
        cat_power   : make_colour_rgb(222, 146,  26),
        cat_move    : make_colour_rgb( 26, 132, 112),
        cat_weapon  : make_colour_rgb(198,  44,  38),
        cat_defence : make_colour_rgb( 40,  92, 166),
        cat_utility : make_colour_rgb(124,  60, 156),

        // --- shading directions, used instead of black/white ---
        shade       : make_colour_rgb( 62,  38,  26),
        lift        : make_colour_rgb(252, 243, 222),

        // --- road atlas ---
        paper       : make_colour_rgb(237, 227, 200),
        paper_dark  : make_colour_rgb(216, 203, 168),
        paper_ink   : make_colour_rgb( 43,  42,  38),
        paper_faint : make_colour_rgb(178, 166, 136),
        route_red   : make_colour_rgb(201,  67,  47),
        route_blue  : make_colour_rgb( 47,  93, 168),
        route_ochre : make_colour_rgb(196, 148,  56),

        // --- sampled from Spr_Map_01_Base so the drawn overlay sits in the
        // same palette as the printed atlas underneath it ---
        atlas_ink    : make_colour_rgb( 74,  43,  30),
        atlas_road   : make_colour_rgb(122,  74,  48),
        atlas_live   : make_colour_rgb(214,  88,  54),
        atlas_alert  : make_colour_rgb(158,  38,  30),
        atlas_cream  : make_colour_rgb(246, 226, 192),
        atlas_dim    : make_colour_rgb(150, 112,  82),

        // Matched to the map icon sprites so a hand-drawn badge sits in the
        // same set: dark rim, warm face, mid-brown glyph.
        badge_rim    : make_colour_rgb( 88,  44,  28),
        badge_face   : make_colour_rgb(240, 214, 176),
        badge_glyph  : make_colour_rgb(150,  92,  58),
    };
}

/// Category colour for a facility definition.
function cat_colour(_cat) {
    var p = global.PAL;
    switch (_cat) {
        case "power":   return p.cat_power;
        case "move":    return p.cat_move;
        case "weapon":  return p.cat_weapon;
        case "defence": return p.cat_defence;
        default:        return p.cat_utility;
    }
}

/// Colour for a status effect key.
function status_colour(_key) {
    var p = global.PAL;
    switch (_key) {
        case "elec": return p.st_elec;
        case "fire": return p.st_fire;
        case "oil":  return p.st_oil;
        case "acid": return p.st_acid;
        default:     return p.text_dim;
    }
}

/// The page every screen is printed on: warm stock, a faint survey grid, and
/// the fold creases the atlas has baked into its own art.
function draw_backdrop() {
    var p = global.PAL;
    var w = display_get_gui_width(), h = display_get_gui_height();

    draw_rectangle_colour(0, 0, w, h, p.bg_grad, p.bg_grad, p.bg, p.bg, false);

    // The atlas's lat/long grid, carried onto the other pages so the whole
    // game reads as one document rather than a map plus some menus.
    draw_set_alpha(0.09);
    for (var gx = 64; gx < w; gx += 64) draw_line_colour(gx, 0, gx, h, p.edge, p.edge);
    for (var gy = 64; gy < h; gy += 64) draw_line_colour(0, gy, w, gy, p.edge, p.edge);
    draw_set_alpha(1);

    // Creases: one down the middle, one across, where the sheet was folded to
    // fit a glovebox.
    draw_set_alpha(0.10);
    draw_line_width_colour(w * 0.5, 0, w * 0.5, h, 3, p.shade, p.shade);
    draw_line_width_colour(0, h * 0.5, w, h * 0.5, 3, p.shade, p.shade);
    draw_set_alpha(0.13);
    draw_line_colour(w * 0.5 + 2, 0, w * 0.5 + 2, h, p.lift, p.lift);
    draw_line_colour(0, h * 0.5 + 2, w, h * 0.5 + 2, p.lift, p.lift);
    draw_set_alpha(1);
}

/// A printed card: cream stock, a drop shadow so it sits on the page, and a
/// spot-ink rule around it. `_glow` tints the rule; pass -1 for the default.
function draw_panel(_x1, _y1, _x2, _y2, _glow = -1, _fill_alpha = 0.97) {
    var p = global.PAL;
    var col = (_glow == -1) ? p.edge : _glow;

    // Shadow first — a card laid on the page, not a hole cut in it.
    draw_set_alpha(0.16);
    draw_rectangle_colour(_x1 + 4, _y1 + 5, _x2 + 4, _y2 + 5,
                          p.shade, p.shade, p.shade, p.shade, false);
    draw_set_alpha(_fill_alpha);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, p.panel_hi, p.panel_hi, p.panel, p.panel, false);
    draw_set_alpha(1);

    // Double rule: a heavy outer and a hairline inset, the way a printed box
    // on a map legend is ruled.
    draw_rectangle_colour(_x1, _y1, _x2, _y2, col, col, col, col, true);
    draw_set_alpha(0.45);
    draw_rectangle_colour(_x1 + 3, _y1 + 3, _x2 - 3, _y2 - 3, col, col, col, col, true);
    draw_set_alpha(1);

    // Corner ticks — registration marks.
    var t = 8;
    draw_line_colour(_x1, _y1, _x1 + t, _y1, col, col);
    draw_line_colour(_x1, _y1, _x1, _y1 + t, col, col);
    draw_line_colour(_x2, _y2, _x2 - t, _y2, col, col);
    draw_line_colour(_x2, _y2, _x2, _y2 - t, col, col);
}

/// Rectangle outline with a soft ink bleed around it — the printed equivalent
/// of a glow, used for selection and chassis outlines.
function draw_ink_rect(_x1, _y1, _x2, _y2, _col, _alpha = 1, _spread = 3) {
    for (var i = _spread; i >= 1; i--) {
        draw_set_alpha(_alpha * 0.13 * (1 - (i - 1) / _spread));
        draw_rectangle_colour(_x1 - i, _y1 - i, _x2 + i, _y2 + i, _col, _col, _col, _col, true);
    }
    draw_set_alpha(_alpha);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, _col, _col, _col, _col, true);
    draw_set_alpha(1);
}

/// Horizontal gauge, printed: a cream trough with an ink hairline and a solid
/// fill. `_frac` is clamped 0..1.
function draw_bar(_x, _y, _w, _h, _frac, _col, _bg = -1) {
    var p = global.PAL;
    var bg = (_bg == -1) ? merge_colour(p.panel, p.shade, 0.10) : _bg;
    var f  = clamp(_frac, 0, 1);

    draw_rectangle_colour(_x, _y, _x + _w, _y + _h, bg, bg, bg, bg, false);
    if (f > 0) {
        var fw = max(1, _w * f);
        var lo = merge_colour(_col, p.shade, 0.30);
        draw_rectangle_colour(_x, _y, _x + fw, _y + _h, _col, _col, lo, lo, false);
    }
    var e = merge_colour(_col, p.edge, 0.45);
    draw_rectangle_colour(_x, _y, _x + _w, _y + _h, e, e, e, e, true);
}

/// Segmented gauge — reads as discrete printed boxes (power, shields, drones).
function draw_pips(_x, _y, _pip_w, _pip_h, _count, _filled, _col, _gap = 3) {
    var p = global.PAL;
    for (var i = 0; i < _count; i++) {
        var px = _x + i * (_pip_w + _gap);
        if (i < _filled) {
            var lo = merge_colour(_col, p.shade, 0.25);
            draw_rectangle_colour(px, _y, px + _pip_w, _y + _pip_h, _col, _col, lo, lo, false);
        } else {
            draw_set_alpha(0.30);
            draw_rectangle_colour(px, _y, px + _pip_w, _y + _pip_h, p.panel, p.panel, p.panel, p.panel, false);
            draw_set_alpha(0.75);
            draw_rectangle_colour(px, _y, px + _pip_w, _y + _pip_h, p.text_mute, p.text_mute, p.text_mute, p.text_mute, true);
            draw_set_alpha(1);
        }
    }
}

/// Display text with a cream halo, so it stays legible over the survey grid
/// and the road — the way a place name is printed over detail on an atlas.
function draw_glow_text(_x, _y, _str, _col, _halign = fa_left, _valign = fa_top, _font = -1, _glow = 0.85) {
    var p = global.PAL;
    if (_font != -1) draw_set_font(_font);
    draw_set_halign(_halign);
    draw_set_valign(_valign);

    if (_glow > 0) {
        draw_set_alpha(_glow);
        draw_set_colour(p.lift);
        for (var ox = -2; ox <= 2; ox += 2) {
            for (var oy = -2; oy <= 2; oy += 2) {
                if (ox == 0 && oy == 0) continue;
                draw_text(_x + ox, _y + oy, _str);
            }
        }
        draw_set_alpha(1);
    }

    draw_set_colour(_col);
    draw_text(_x, _y, _str);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
}

/// Place name with a cream halo, so it stays legible where a road runs under
/// it — the way names are printed over detail on a real atlas. Lives here
/// rather than in the map event so anything drawn before the roads can use it.
function draw_map_label(_x, _y, _str, _col, _halign = fa_center) {
    var cream = global.PAL.atlas_cream;
    draw_set_alpha(0.85);
    for (var ox = -1; ox <= 1; ox++) {
        for (var oy = -1; oy <= 1; oy++) {
            if (ox == 0 && oy == 0) continue;
            draw_label(_x + ox, _y + oy, _str, cream, _halign, fa_top, fnt_small);
        }
    }
    draw_set_alpha(1);
    draw_label(_x, _y, _str, _col, _halign, fa_top, fnt_small);
}

/// Plain text helper — no halo, for dense UI where it would smear.
function draw_label(_x, _y, _str, _col, _halign = fa_left, _valign = fa_top, _font = -1) {
    if (_font != -1) draw_set_font(_font);
    draw_set_halign(_halign);
    draw_set_valign(_valign);
    draw_set_colour(_col);
    draw_text(_x, _y, _str);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
}

/// Page furniture over the top of everything: the printed border, warm edge
/// darkening where the sheet has been handled, and worn corners.
/// Call from Draw_GUI_End.
function paper_overlay(_wear = 1) {
    var p = global.PAL;
    var w = display_get_gui_width(), h = display_get_gui_height();

    // Vignette: warm brown rather than black, four edge gradients.
    var v = 90;
    draw_set_alpha(0.10 * _wear);
    draw_rectangle_colour(0, 0, w, v, p.shade, p.shade, p.bg, p.bg, false);
    draw_rectangle_colour(0, h - v, w, h, p.bg, p.bg, p.shade, p.shade, false);
    draw_rectangle_colour(0, 0, v, h, p.shade, p.bg, p.bg, p.shade, false);
    draw_rectangle_colour(w - v, 0, w, h, p.bg, p.shade, p.shade, p.bg, false);
    draw_set_alpha(1);

    // The printed border the atlas page has, so every screen is framed alike.
    var m = 14;
    draw_set_alpha(0.55);
    draw_rectangle_colour(m, m, w - m, h - m, p.edge, p.edge, p.edge, p.edge, true);
    draw_set_alpha(0.30);
    draw_rectangle_colour(m + 4, m + 4, w - m - 4, h - m - 4, p.edge, p.edge, p.edge, p.edge, true);
    draw_set_alpha(1);

    draw_set_colour(c_white);
}

/// Dashed line, used for targeting reticles and map borders.
function draw_dashed_line(_x1, _y1, _x2, _y2, _col, _dash = 6, _gap = 5, _width = 1) {
    var len = point_distance(_x1, _y1, _x2, _y2);
    if (len <= 0) return;
    var dir = point_direction(_x1, _y1, _x2, _y2);
    var step = _dash + _gap;
    var travelled = 0;
    while (travelled < len) {
        var seg = min(_dash, len - travelled);
        var ax = _x1 + lengthdir_x(travelled, dir);
        var ay = _y1 + lengthdir_y(travelled, dir);
        var bx = _x1 + lengthdir_x(travelled + seg, dir);
        var by = _y1 + lengthdir_y(travelled + seg, dir);
        draw_line_width_colour(ax, ay, bx, by, _width, _col, _col);
        travelled += step;
    }
}
