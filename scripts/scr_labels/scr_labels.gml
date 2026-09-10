/// scr_labels — keeps drawn text off other drawn text.
///
/// Every screen that puts free-floating labels on a busy background registers
/// the rectangles it has already inked this frame. A later label asks for a
/// slot near where it wants to be, and gets the first candidate position that
/// lands on clear paper.
///
/// The order you draw in IS the priority order: whatever is reserved first
/// keeps its spot, and later labels move around it. So draw the things the
/// player must be able to read — place names, vehicle names — before the
/// commentary that can afford to shuffle.
///
/// Call labels_begin() once at the top of the Draw_GUI event.

function labels_begin() {
    global.LBL = [];
    global.LBL_AVOID = [];
}

/// Mark a rectangle as inked.
function label_reserve(_x1, _y1, _x2, _y2) {
    array_push(global.LBL, [_x1, _y1, _x2, _y2]);
}

/// Mark a line as something a label would rather not sit across. Cheaper and
/// softer than a reservation: it never blocks a slot outright, it just makes
/// candidates that cross it lose to candidates that don't.
function label_avoid_line(_x1, _y1, _x2, _y2) {
    array_push(global.LBL_AVOID, [_x1, _y1, _x2, _y2]);
}

/// True if the rectangle overlaps anything already reserved.
function label_hits(_x1, _y1, _x2, _y2) {
    var L = global.LBL;
    for (var i = 0; i < array_length(L); i++) {
        var r = L[i];
        if (_x1 < r[2] && _x2 > r[0] && _y1 < r[3] && _y2 > r[1]) return true;
    }
    return false;
}

/// How many avoid-lines pass through the rectangle. Segment/rect test done as
/// four segment/segment tests plus a containment check.
function label_crossings(_x1, _y1, _x2, _y2) {
    var n = 0;
    var L = global.LBL_AVOID;
    for (var i = 0; i < array_length(L); i++) {
        var s = L[i];
        if (_seg_hits_rect(s[0], s[1], s[2], s[3], _x1, _y1, _x2, _y2)) n += 1;
    }
    return n;
}

function _seg_cross(_ax, _ay, _bx, _by, _cx, _cy, _dx, _dy) {
    var d1 = (_dx - _cx) * (_ay - _cy) - (_dy - _cy) * (_ax - _cx);
    var d2 = (_dx - _cx) * (_by - _cy) - (_dy - _cy) * (_bx - _cx);
    var d3 = (_bx - _ax) * (_cy - _ay) - (_by - _ay) * (_cx - _ax);
    var d4 = (_bx - _ax) * (_dy - _ay) - (_by - _ay) * (_dx - _ax);
    return (((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0)));
}

function _seg_hits_rect(_ax, _ay, _bx, _by, _x1, _y1, _x2, _y2) {
    // Either end inside is a hit, otherwise test the four edges.
    if (_ax >= _x1 && _ax <= _x2 && _ay >= _y1 && _ay <= _y2) return true;
    if (_bx >= _x1 && _bx <= _x2 && _by >= _y1 && _by <= _y2) return true;
    if (_seg_cross(_ax, _ay, _bx, _by, _x1, _y1, _x2, _y1)) return true;
    if (_seg_cross(_ax, _ay, _bx, _by, _x2, _y1, _x2, _y2)) return true;
    if (_seg_cross(_ax, _ay, _bx, _by, _x2, _y2, _x1, _y2)) return true;
    if (_seg_cross(_ax, _ay, _bx, _by, _x1, _y2, _x1, _y1)) return true;
    return false;
}

/// Width and height of a string in a font, without disturbing the caller's
/// alignment settings.
function label_measure(_str, _font) {
    draw_set_font(_font);
    return [string_width(_str), string_height(_str)];
}

/// Find somewhere to put a centred label.
///
/// `_cands` is a list of [cx, cy] centre-top anchors in preference order. The
/// first one that lands clear of every reservation wins; among otherwise-equal
/// candidates the one crossing the fewest avoid-lines wins. If every candidate
/// collides, the least-bad one is used anyway — a label that moves is better
/// than a label that vanishes.
///
/// Returns [x, y] and reserves the space.
function label_place(_w, _h, _cands, _pad = 2) {
    var best = 0;
    var best_score = 999999;

    for (var i = 0; i < array_length(_cands); i++) {
        var cx = _cands[i][0], cy = _cands[i][1];
        var x1 = cx - _w * 0.5 - _pad, y1 = cy - _pad;
        var x2 = cx + _w * 0.5 + _pad, y2 = cy + _h + _pad;

        // A collision is disqualifying in all but the last resort, so weight it
        // far above any number of crossings.
        var sc = (label_hits(x1, y1, x2, y2) ? 1000 : 0)
                  + label_crossings(x1, y1, x2, y2)
                  + i * 0.01;          // ties go to the earlier preference

        if (sc < best_score) { best_score = sc; best = i; }
        if (sc < 1) break;          // clear paper and no crossings: done
    }

    var fx = _cands[best][0], fy = _cands[best][1];
    label_reserve(fx - _w * 0.5 - _pad, fy - _pad, fx + _w * 0.5 + _pad, fy + _h + _pad);
    return [fx, fy];
}
