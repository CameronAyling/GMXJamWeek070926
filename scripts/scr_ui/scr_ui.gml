/// scr_ui — immediate-mode widgets in GUI space.
///
/// Every screen draws through Draw_GUI at a fixed 1280x720, so mouse position
/// comes from device_mouse_x_to_gui() and hit-testing is plain rectangles.
/// Call ui_begin() once at the top of a controller's Step.

function ui_begin() {
    global.ui_mx        = device_mouse_x_to_gui(0);
    global.ui_my        = device_mouse_y_to_gui(0);
    global.ui_click     = mouse_check_button_pressed(mb_left);
    global.ui_rclick    = mouse_check_button_pressed(mb_right);
    global.ui_held      = mouse_check_button(mb_left);
    global.ui_release   = mouse_check_button_released(mb_left);
    global.ui_tip       = "";
    global.ui_tip_title = "";

    // Room changes fade rather than cut, and the outgoing screen keeps running.
    // Swallow input for the duration so a click can't land on a screen that is
    // already on its way out.
    if (transitioning()) {
        global.ui_click   = false;
        global.ui_rclick  = false;
        global.ui_held    = false;
        global.ui_release = false;
    }
}

function ui_mx() { return global.ui_mx; }
function ui_my() { return global.ui_my; }

/// True while the pointer is inside the rect.
function ui_hover(_x1, _y1, _x2, _y2) {
    return point_in_rectangle(global.ui_mx, global.ui_my, _x1, _y1, _x2, _y2);
}

/// True on the frame the rect is left-clicked. Consumes the click so two
/// overlapping widgets can't both fire.
function ui_clicked(_x1, _y1, _x2, _y2) {
    if (global.ui_click && ui_hover(_x1, _y1, _x2, _y2)) {
        global.ui_click = false;
        return true;
    }
    return false;
}

/// As ui_clicked but for the right button.
function ui_rclicked(_x1, _y1, _x2, _y2) {
    if (global.ui_rclick && ui_hover(_x1, _y1, _x2, _y2)) {
        global.ui_rclick = false;
        return true;
    }
    return false;
}

/// Queue a hover tooltip. Drawn later by ui_draw_tooltip() so it lands on top.
function ui_tooltip(_title, _body) {
    global.ui_tip_title = _title;
    global.ui_tip       = _body;
}

/// Draw + hit-test a button in one call. Returns true when clicked.
/// A printed key: a cream face with a spot-ink rule, which inks in solid when
/// the pointer lands on it — the press is the ink going down, not a glow.
function ui_button(_x1, _y1, _x2, _y2, _label, _enabled = true, _col = -1, _font = -1) {
    var p    = global.PAL;
    var col  = (_col == -1) ? p.cyan : _col;
    var hov  = _enabled && ui_hover(_x1, _y1, _x2, _y2);
    var edge = _enabled ? col : p.text_mute;
    var txt  = _enabled ? (hov ? p.lift : col) : p.text_mute;

    // Sits on the page, so it casts a little shadow.
    draw_set_alpha(_enabled ? 0.18 : 0.08);
    draw_rectangle_colour(_x1 + 3, _y1 + 4, _x2 + 3, _y2 + 4, p.shade, p.shade, p.shade, p.shade, false);
    draw_set_alpha(1);

    if (hov) {
        var lo = merge_colour(col, p.shade, 0.28);
        draw_rectangle_colour(_x1, _y1, _x2, _y2, col, col, lo, lo, false);
    } else {
        // Near-opaque: buttons often sit over busy artwork and must stay legible.
        draw_set_alpha(0.96);
        draw_rectangle_colour(_x1, _y1, _x2, _y2, p.panel_hi, p.panel_hi, p.panel, p.panel, false);
        draw_set_alpha(1);
    }
    draw_rectangle_colour(_x1, _y1, _x2, _y2, edge, edge, edge, edge, true);
    draw_set_alpha(hov ? 0.45 : 0.30);
    draw_rectangle_colour(_x1 + 3, _y1 + 3, _x2 - 3, _y2 - 3, hov ? p.lift : edge, hov ? p.lift : edge,
                                                              hov ? p.lift : edge, hov ? p.lift : edge, true);
    draw_set_alpha(1);

    if (_font != -1) draw_set_font(_font);
    draw_label((_x1 + _x2) * 0.5, (_y1 + _y2) * 0.5, _label, txt, fa_center, fa_middle);

    return _enabled && ui_clicked(_x1, _y1, _x2, _y2);
}

/// Word-wrap a string to a pixel width using the current font.
function ui_wrap(_str, _width) {
    var words = string_split(_str, " ");
    var lines = [];
    var cur   = "";
    for (var i = 0; i < array_length(words); i++) {
        var trial = (cur == "") ? words[i] : cur + " " + words[i];
        if (string_width(trial) > _width && cur != "") {
            array_push(lines, cur);
            cur = words[i];
        } else {
            cur = trial;
        }
    }
    if (cur != "") array_push(lines, cur);
    return lines;
}

/// Trim a string to fit a pixel width in the current font, adding an ellipsis.
function ui_ellipsis(_str, _width) {
    if (string_width(_str) <= _width) return _str;
    var s = _str;
    while (string_length(s) > 1 && string_width(s + "…") > _width) {
        s = string_copy(s, 1, string_length(s) - 1);
    }
    return s + "…";
}

/// Draw wrapped text, returning the height consumed.
function ui_text_block(_x, _y, _str, _width, _col, _line_h = 16) {
    var lines = ui_wrap(_str, _width);
    for (var i = 0; i < array_length(lines); i++) {
        draw_label(_x, _y + i * _line_h, lines[i], _col);
    }
    return array_length(lines) * _line_h;
}

/// Flush the queued tooltip near the cursor, clamped on screen.
function ui_draw_tooltip() {
    if (global.ui_tip == "" && global.ui_tip_title == "") return;

    var p = global.PAL;
    draw_set_font(fnt_small);

    var wrap  = 260;
    var lines = (global.ui_tip == "") ? [] : ui_wrap(global.ui_tip, wrap);
    var line_h = 15;
    var tw = (global.ui_tip_title == "") ? 0 : string_width(global.ui_tip_title);
    for (var i = 0; i < array_length(lines); i++) tw = max(tw, string_width(lines[i]));

    var pad = 9;
    var bw  = tw + pad * 2;
    var bh  = pad * 2 + (global.ui_tip_title == "" ? 0 : 18) + array_length(lines) * line_h;

    var bx = global.ui_mx + 18;
    var by = global.ui_my + 18;
    bx = min(bx, display_get_gui_width()  - bw - 6);
    by = min(by, display_get_gui_height() - bh - 6);

    draw_panel(bx, by, bx + bw, by + bh, p.violet, 0.97);

    var ty = by + pad;
    if (global.ui_tip_title != "") {
        draw_label(bx + pad, ty, global.ui_tip_title, p.cyan);
        ty += 18;
    }
    for (var i = 0; i < array_length(lines); i++) {
        draw_label(bx + pad, ty + i * line_h, lines[i], p.text);
    }

    global.ui_tip = "";
    global.ui_tip_title = "";
}

/// Roman numerals for facility tiers — I, II, III.
function ui_roman(_n) {
    switch (_n) {
        case 1:  return "I";
        case 2:  return "II";
        case 3:  return "III";
        default: return string(_n);
    }
}

/// Seconds -> "3.4s", for charge readouts.
function ui_secs(_s) {
    if (_s <= 0) return "0.0s";
    return string_format(_s, 1, 1) + "s";
}
