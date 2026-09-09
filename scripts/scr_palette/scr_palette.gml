/// scr_palette — colours and the neon-terminal draw vocabulary.
///
/// Everything in the combat/garage screens is drawn from these helpers so the
/// CRT look stays consistent. The atlas map deliberately breaks from it and
/// uses the PAPER_* colours instead.

function palette_init() {
    global.PAL = {
        // --- terminal chrome ---
        bg          : make_colour_rgb(  7,   6,  13),
        bg_grad     : make_colour_rgb( 18,  14,  34),
        panel       : make_colour_rgb( 18,  16,  31),
        panel_hi    : make_colour_rgb( 30,  26,  50),
        edge        : make_colour_rgb( 42,  37,  66),
        edge_hot    : make_colour_rgb( 90,  70, 140),

        // --- neon accents ---
        magenta     : make_colour_rgb(255,  46, 136),
        cyan        : make_colour_rgb( 34, 226, 245),
        amber       : make_colour_rgb(255, 177,  59),
        lime        : make_colour_rgb(124, 255,  79),
        violet      : make_colour_rgb(167, 106, 255),

        // --- text ---
        text        : make_colour_rgb(216, 212, 240),
        text_dim    : make_colour_rgb(110, 104, 144),
        text_mute   : make_colour_rgb( 72,  68, 100),

        // --- states ---
        danger      : make_colour_rgb(255,  59,  59),
        ok          : make_colour_rgb( 90, 230, 140),
        warn        : make_colour_rgb(255, 190,  60),

        // --- status effects (must stay visually distinct) ---
        st_elec     : make_colour_rgb(111, 233, 255),
        st_fire     : make_colour_rgb(255, 107,  33),
        st_oil      : make_colour_rgb(126, 108, 168),
        st_acid     : make_colour_rgb(157, 255,  60),

        // --- facility categories ---
        cat_power   : make_colour_rgb(255, 196,  64),
        cat_move    : make_colour_rgb( 90, 230, 190),
        cat_weapon  : make_colour_rgb(255,  80, 130),
        cat_defence : make_colour_rgb( 92, 168, 255),
        cat_utility : make_colour_rgb(186, 130, 255),

        // --- road atlas ---
        paper       : make_colour_rgb(237, 227, 200),
        paper_dark  : make_colour_rgb(216, 203, 168),
        paper_ink   : make_colour_rgb( 43,  42,  38),
        paper_faint : make_colour_rgb(178, 166, 136),
        route_red   : make_colour_rgb(201,  67,  47),
        route_blue  : make_colour_rgb( 47,  93, 168),
        route_ochre : make_colour_rgb(196, 148,  56),
        convoy      : make_colour_rgb(168,  32,  32),
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

/// Full-screen dark gradient backdrop for the terminal screens.
function draw_backdrop() {
    var p = global.PAL;
    var w = display_get_gui_width(), h = display_get_gui_height();
    draw_rectangle_colour(0, 0, w, h, p.bg_grad, p.bg_grad, p.bg, p.bg, false);
}

/// A bordered panel. `_glow` tints the border; pass -1 for the default edge.
function draw_panel(_x1, _y1, _x2, _y2, _glow = -1, _fill_alpha = 0.92) {
    var p = global.PAL;
    var col = (_glow == -1) ? p.edge : _glow;

    draw_set_alpha(_fill_alpha);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, p.panel_hi, p.panel_hi, p.panel, p.panel, false);
    draw_set_alpha(1);

    // Outer border plus a soft inner halo so it reads as emissive.
    draw_set_alpha(0.25);
    draw_rectangle_colour(_x1 - 1, _y1 - 1, _x2 + 1, _y2 + 1, col, col, col, col, true);
    draw_set_alpha(1);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, col, col, col, col, true);

    // Corner ticks — cheap way to make a plain rect feel like an instrument.
    var t = 8;
    draw_line_colour(_x1, _y1, _x1 + t, _y1, col, col);
    draw_line_colour(_x1, _y1, _x1, _y1 + t, col, col);
    draw_line_colour(_x2, _y2, _x2 - t, _y2, col, col);
    draw_line_colour(_x2, _y2, _x2, _y2 - t, col, col);
}

/// Rectangle outline with a glow halo around it.
function draw_neon_rect(_x1, _y1, _x2, _y2, _col, _alpha = 1, _spread = 3) {
    for (var i = _spread; i >= 1; i--) {
        draw_set_alpha(_alpha * 0.10 * (1 - (i - 1) / _spread));
        draw_rectangle_colour(_x1 - i, _y1 - i, _x2 + i, _y2 + i, _col, _col, _col, _col, true);
    }
    draw_set_alpha(_alpha);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, _col, _col, _col, _col, true);
    draw_set_alpha(1);
}

/// Horizontal progress bar. `_frac` is clamped 0..1.
function draw_bar(_x, _y, _w, _h, _frac, _col, _bg = -1) {
    var p = global.PAL;
    var bg = (_bg == -1) ? p.panel_hi : _bg;
    var f  = clamp(_frac, 0, 1);

    draw_rectangle_colour(_x, _y, _x + _w, _y + _h, bg, bg, bg, bg, false);
    if (f > 0) {
        var fw = max(1, _w * f);
        var lo = merge_colour(_col, c_black, 0.35);
        draw_rectangle_colour(_x, _y, _x + fw, _y + _h, _col, _col, lo, lo, false);
    }
    var e = merge_colour(_col, p.edge, 0.5);
    draw_rectangle_colour(_x, _y, _x + _w, _y + _h, e, e, e, e, true);
}

/// Segmented bar — reads as discrete pips (power, shields, drones).
function draw_pips(_x, _y, _pip_w, _pip_h, _count, _filled, _col, _gap = 3) {
    var p = global.PAL;
    for (var i = 0; i < _count; i++) {
        var px = _x + i * (_pip_w + _gap);
        if (i < _filled) {
            draw_rectangle_colour(px, _y, px + _pip_w, _y + _pip_h, _col, _col, _col, _col, false);
        } else {
            draw_set_alpha(0.5);
            draw_rectangle_colour(px, _y, px + _pip_w, _y + _pip_h, p.text_mute, p.text_mute, p.text_mute, p.text_mute, true);
            draw_set_alpha(1);
        }
    }
}

/// Text with a faint chromatic-aberration bloom. Restores draw state.
function draw_glow_text(_x, _y, _str, _col, _halign = fa_left, _valign = fa_top, _font = -1, _glow = 0.35) {
    if (_font != -1) draw_set_font(_font);
    draw_set_halign(_halign);
    draw_set_valign(_valign);

    if (_glow > 0) {
        draw_set_alpha(_glow * 0.5);
        draw_set_colour(_col);
        draw_text(_x - 1, _y, _str);
        draw_text(_x + 1, _y, _str);
        draw_text(_x, _y - 1, _str);
        draw_text(_x, _y + 1, _str);
        draw_set_alpha(1);
    }

    draw_set_colour(_col);
    draw_text(_x, _y, _str);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_colour(c_white);
}

/// Plain text helper — no bloom, for dense UI where glow would smear.
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

/// Scanlines + vignette. Call from Draw_GUI_End so it sits over everything.
function crt_overlay(_scan_alpha = 0.055) {
    var w = display_get_gui_width(), h = display_get_gui_height();

    draw_set_alpha(_scan_alpha);
    draw_set_colour(c_black);
    for (var yy = 0; yy < h; yy += 3) draw_rectangle(0, yy, w, yy + 1, false);

    // Vignette: four edge gradients, cheaper than a radial shader.
    var v = 90;
    draw_set_alpha(0.30);
    draw_rectangle_colour(0, 0, w, v, c_black, c_black, c_black, c_black, false);
    draw_rectangle_colour(0, h - v, w, h, c_black, c_black, c_black, c_black, false);
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
