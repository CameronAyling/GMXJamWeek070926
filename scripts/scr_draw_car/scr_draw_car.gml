/// scr_draw_car — renders a car as a neon cutaway schematic.
///
/// Shared by the combat screen and the garage so a rig looks identical whether
/// you're rebuilding it or watching it burn. Facilities are drawn as merged
/// regions (interior edges suppressed) so a 3-cell laser reads as one object
/// rather than three squares.

// --- glyph primitives -------------------------------------------------------
// Coordinates are normalised -1..1 around the glyph centre, so a glyph scales
// to any cell size.

function _gl(_cx, _cy, _s, _x1, _y1, _x2, _y2, _w = 2) {
    draw_line_width(_cx + _x1 * _s, _cy + _y1 * _s, _cx + _x2 * _s, _cy + _y2 * _s, _w);
}

function _gc(_cx, _cy, _s, _x, _y, _r, _outline = true) {
    draw_circle(_cx + _x * _s, _cy + _y * _s, _r * _s, _outline);
}

function _gr(_cx, _cy, _s, _x1, _y1, _x2, _y2, _outline = true) {
    draw_rectangle(_cx + _x1 * _s, _cy + _y1 * _s, _cx + _x2 * _s, _cy + _y2 * _s, _outline);
}

/// Draw a facility's icon centred at (_cx, _cy), scaled by _s (half-extent px).
function draw_fac_glyph(_family, _cx, _cy, _s, _col) {
    draw_set_colour(_col);
    var w = max(1.5, _s * 0.14);

    switch (_family) {
        case "reac":   // hex core with a hot centre
            var n = 6;
            for (var i = 0; i < n; i++) {
                var a1 = i * 60, a2 = (i + 1) * 60;
                _gl(_cx, _cy, _s, dcos(a1) * 0.75, -dsin(a1) * 0.75,
                                  dcos(a2) * 0.75, -dsin(a2) * 0.75, w);
            }
            _gc(_cx, _cy, _s, 0, 0, 0.26, false);
            break;

        case "drv":    // three speed chevrons
            for (var i = -1; i <= 1; i++) {
                _gl(_cx, _cy, _s, -0.75 + i * 0.05, -0.6, -0.15 + i * 0.05, 0, w);
                _gl(_cx, _cy, _s, -0.15 + i * 0.05,  0,   -0.75 + i * 0.05, 0.6, w);
            }
            _gl(_cx, _cy, _s, 0.45, -0.6, 0.45, 0.6, w);
            break;

        case "las":    // barrel with a beam
            _gr(_cx, _cy, _s, -0.8, -0.28, 0.1, 0.28, true);
            _gl(_cx, _cy, _s, 0.1, 0, 0.85, 0, w * 1.4);
            break;

        case "riv":    // heavy slug
            _gr(_cx, _cy, _s, -0.8, -0.4, 0.15, 0.4, true);
            _gl(_cx, _cy, _s, 0.15, -0.4, 0.8, 0, w);
            _gl(_cx, _cy, _s, 0.15,  0.4, 0.8, 0, w);
            _gl(_cx, _cy, _s, -0.45, -0.4, -0.45, 0.4, w);
            break;

        case "tes":    // lightning bolt
            _gl(_cx, _cy, _s,  0.25, -0.85, -0.35, -0.05, w * 1.3);
            _gl(_cx, _cy, _s, -0.35, -0.05,  0.15, -0.05, w * 1.3);
            _gl(_cx, _cy, _s,  0.15, -0.05, -0.25,  0.85, w * 1.3);
            break;

        case "flm":    // flame
            _gl(_cx, _cy, _s,  0,   -0.85, -0.55, 0.1, w);
            _gl(_cx, _cy, _s, -0.55, 0.1,   0,    0.8, w);
            _gl(_cx, _cy, _s,  0,    0.8,   0.55, 0.1, w);
            _gl(_cx, _cy, _s,  0.55, 0.1,   0,   -0.85, w);
            _gc(_cx, _cy, _s, 0, 0.35, 0.22, false);
            break;

        case "acd":    // corroding droplet
            _gl(_cx, _cy, _s, 0, -0.8, -0.5, 0.25, w);
            _gl(_cx, _cy, _s, 0, -0.8,  0.5, 0.25, w);
            _gc(_cx, _cy, _s, 0, 0.3, 0.42, true);
            _gl(_cx, _cy, _s, -0.75, 0.8, -0.45, 0.55, w);
            _gl(_cx, _cy, _s,  0.75, 0.8,  0.45, 0.55, w);
            break;

        case "oil":    // slick puddle
            _gc(_cx, _cy, _s, 0, 0.15, 0.5, true);
            _gl(_cx, _cy, _s, -0.85, 0.7, 0.85, 0.7, w);
            _gl(_cx, _cy, _s, -0.3, -0.75, -0.3, -0.35, w);
            _gl(_cx, _cy, _s,  0.35, -0.6,  0.35, -0.3, w);
            break;

        case "hrp":    // barbed hook on a cable
            _gl(_cx, _cy, _s, -0.85, -0.5, 0.3, -0.5, w);
            _gl(_cx, _cy, _s,  0.3, -0.5, 0.8, 0, w);
            _gl(_cx, _cy, _s,  0.8, 0, 0.3, 0.5, w);
            _gl(_cx, _cy, _s,  0.3, 0.5, 0.45, 0.05, w);
            break;

        case "drn":    // a rotor ring around a tiny core
            _gc(_cx, _cy, _s, 0, 0, 0.28, false);
            for (var a = 45; a < 360; a += 90) {
                _gl(_cx, _cy, _s, dcos(a) * 0.34, -dsin(a) * 0.34,
                                  dcos(a) * 0.72, -dsin(a) * 0.72, w);
                _gc(_cx, _cy, _s, dcos(a) * 0.82, -dsin(a) * 0.82, 0.17, true);
            }
            break;

        case "sct":    // pellet spread
            _gl(_cx, _cy, _s, -0.85, 0, -0.2, 0, w);
            for (var i = -1; i <= 1; i++) {
                _gl(_cx, _cy, _s, -0.2, 0, 0.8, i * 0.6, w * 0.8);
                _gc(_cx, _cy, _s, 0.8, i * 0.6, 0.13, false);
            }
            break;

        case "plt":    // layered plate
            for (var i = 0; i < 3; i++) {
                var yy = -0.5 + i * 0.5;
                _gl(_cx, _cy, _s, -0.8, yy, 0.8, yy, w * 1.5);
            }
            break;

        case "shd":    // deflector arc
            for (var i = 0; i < 2; i++) {
                var r = 0.45 + i * 0.35;
                for (var a = -70; a < 70; a += 20) {
                    _gl(_cx, _cy, _s, dcos(a) * r, -dsin(a) * r,
                                      dcos(a + 20) * r, -dsin(a + 20) * r, w);
                }
            }
            break;

        case "pdc":    // interception crosshair
            _gc(_cx, _cy, _s, 0, 0, 0.5, true);
            _gl(_cx, _cy, _s, -0.9, 0, -0.55, 0, w);
            _gl(_cx, _cy, _s,  0.55, 0, 0.9, 0, w);
            _gl(_cx, _cy, _s, 0, -0.9, 0, -0.55, w);
            _gl(_cx, _cy, _s, 0,  0.55, 0, 0.9, w);
            break;

        case "col":    // coolant star
            for (var a = 0; a < 180; a += 60) {
                _gl(_cx, _cy, _s, dcos(a) * 0.8, -dsin(a) * 0.8,
                                 -dcos(a) * 0.8,  dsin(a) * 0.8, w);
            }
            _gc(_cx, _cy, _s, 0, 0, 0.2, false);
            break;

        case "srg":    // broken bolt — a grounded surge
            _gl(_cx, _cy, _s, 0.2, -0.85, -0.3, -0.1, w);
            _gl(_cx, _cy, _s, 0.25, 0.1, -0.2, 0.85, w);
            _gl(_cx, _cy, _s, -0.8, 0, 0.8, 0, w * 1.3);
            break;

        case "scb":    // scrubber brush
            _gr(_cx, _cy, _s, -0.7, -0.7, 0.7, -0.25, true);
            for (var i = -2; i <= 2; i++) _gl(_cx, _cy, _s, i * 0.3, -0.25, i * 0.3, 0.75, w);
            break;

        case "rep":    // spanner cross
            _gl(_cx, _cy, _s, -0.8, 0, 0.8, 0, w * 1.6);
            _gl(_cx, _cy, _s, 0, -0.8, 0, 0.8, w * 1.6);
            _gc(_cx, _cy, _s, 0, 0, 0.3, true);
            break;

        case "tgt":    // targeting reticle
            _gc(_cx, _cy, _s, 0, 0, 0.55, true);
            _gc(_cx, _cy, _s, 0, 0, 0.16, false);
            for (var a = 0; a < 360; a += 90) {
                _gl(_cx, _cy, _s, dcos(a) * 0.6, -dsin(a) * 0.6,
                                  dcos(a) * 0.95, -dsin(a) * 0.95, w);
            }
            break;

        case "crg":    // strapped crate
            _gr(_cx, _cy, _s, -0.8, -0.6, 0.8, 0.7, true);
            _gl(_cx, _cy, _s, -0.8, -0.15, 0.8, -0.15, w);
            _gl(_cx, _cy, _s, -0.15, -0.6, -0.15, 0.7, w);
            break;

        case "sen":    // antenna mast with signal arcs
            _gl(_cx, _cy, _s, 0, 0.8, 0, -0.5, w);
            _gl(_cx, _cy, _s, -0.35, 0.8, 0.35, 0.8, w);
            for (var i = 1; i <= 2; i++) {
                var r = 0.3 * i;
                for (var a = 30; a < 150; a += 30) {
                    _gl(_cx, _cy, _s, dcos(a) * r, -0.5 - dsin(a) * r,
                                      dcos(a + 30) * r, -0.5 - dsin(a + 30) * r, w * 0.8);
                }
            }
            break;

        default:
            _gr(_cx, _cy, _s, -0.6, -0.6, 0.6, 0.6, true);
            break;
    }
    draw_set_colour(c_white);
}

// --- chassis ----------------------------------------------------------------

/// The vehicle seen from directly overhead, wrapped around its cell grid:
/// bonnet at the front, wheels straddling both flanks, exhausts out the back.
/// `_flip` points the rig left instead of right.
///
/// Top-down matches the rest of the game — the road markings under the fight
/// and the atlas itself are both overhead views.
function draw_chassis(_car, _px, _py, _cs, _col, _flip = false) {
    var p   = global.PAL;
    var pad = _cs * 0.30;
    var gw  = _car.gw * _cs;
    var gh  = _car.gh * _cs;

    // The body starts after any trailer columns.
    var x0  = car_body_x0(_car);
    var bx1 = _px + x0 * _cs - pad, by1 = _py - pad;
    var bx2 = _px + gw + pad,       by2 = _py + gh + pad;

    var dir  = _flip ? -1 : 1;              // +1 = nose points right
    var nose = _cs * 0.9;
    var nx1  = _flip ? bx1 : bx2;           // where the bonnet meets the body
    var nx2  = nx1 + dir * nose;            // its leading edge
    var taper = (by2 - by1) * 0.17;
    var ny1 = by1 + taper, ny2 = by2 - taper;

    var dim = merge_colour(_col, p.bg, 0.55);

    // --- wheels, drawn first so the body sits over their inner edge ---------
    // From above a wheel is a slab: long along travel, narrow across, poking
    // out past the flank.
    var wl = _cs * 0.32;
    var ww = _cs * 0.15;
    var pairs = max(2, floor(_car.gw / 2) + 1);
    for (var i = 0; i < pairs; i++) {
        var t  = (pairs == 1) ? 0.5 : (i / (pairs - 1));
        var wx = lerp(bx1 + wl * 1.5, bx2 - wl * 1.5, t);
        for (var s = 0; s < 2; s++) {
            var wy = (s == 0) ? (by1 - ww * 0.55) : (by2 + ww * 0.55);
            draw_rectangle_colour(wx - wl, wy - ww, wx + wl, wy + ww,
                                  p.bg, p.bg, p.bg, p.bg, false);
            draw_rectangle_colour(wx - wl, wy - ww, wx + wl, wy + ww,
                                  _col, _col, _col, _col, true);
            // Tread bars across the contact patch.
            draw_line_colour(wx - wl * 0.35, wy - ww, wx - wl * 0.35, wy + ww, dim, dim);
            draw_line_colour(wx + wl * 0.35, wy - ww, wx + wl * 0.35, wy + ww, dim, dim);
        }
    }

    // --- bonnet -------------------------------------------------------------
    draw_set_alpha(0.5);
    draw_triangle_colour(nx1, by1, nx2, ny1, nx2, ny2, p.panel_hi, p.bg, p.bg, false);
    draw_triangle_colour(nx1, by1, nx1, by2, nx2, ny2, p.panel_hi, p.panel_hi, p.bg, false);
    draw_set_alpha(1);
    draw_line_width_colour(nx1, by1, nx2, ny1, 2, _col, _col);
    draw_line_width_colour(nx2, ny1, nx2, ny2, 2, _col, _col);
    draw_line_width_colour(nx2, ny2, nx1, by2, 2, _col, _col);

    // Headlights on the leading edge.
    var hx = nx2 - dir * _cs * 0.13;
    draw_circle_colour(hx, ny1 + _cs * 0.11, _cs * 0.075, p.amber, merge_colour(p.amber, p.bg, 0.7), false);
    draw_circle_colour(hx, ny2 - _cs * 0.11, _cs * 0.075, p.amber, merge_colour(p.amber, p.bg, 0.7), false);

    // --- body ---------------------------------------------------------------
    draw_set_alpha(0.55);
    draw_rectangle_colour(bx1, by1, bx2, by2, p.panel, p.panel, p.bg, p.bg, false);
    draw_set_alpha(1);
    draw_ink_rect(bx1, by1, bx2, by2, _col, 0.85, 3);

    // Windscreen: a bar across the cab end of the roof.
    var wsx = nx1 - dir * _cs * 0.2;
    draw_line_width_colour(wsx, by1 + 4, wsx, by2 - 4, 3, dim, dim);

    // --- rear: bumper and twin exhausts -------------------------------------
    // Skipped once a trailer is on the back — the coupling is there instead.
    if (!_car.trailer) {
        var rx = _flip ? bx2 : bx1;
        draw_line_width_colour(rx - dir * _cs * 0.13, by1 + 5, rx - dir * _cs * 0.13, by2 - 5, 3, dim, dim);
        for (var i = 0; i < 2; i++) {
            var ey = lerp(by1, by2, (i == 0) ? 0.3 : 0.7);
            draw_rectangle_colour(rx - dir * _cs * 0.26, ey - _cs * 0.05,
                                  rx,                    ey + _cs * 0.05,
                                  _col, _col, dim, dim, false);
        }
    }

    // --- trailer ------------------------------------------------------------
    // Butted straight onto the back with a heavy coupling bar, the way an
    // articulated rig reads from above.
    if (_car.trailer) {
        var ty0 = _car.gh;
        var ty1 = 0;
        for (var gy = 0; gy < _car.gh; gy++) {
            if (car_cell_exists(_car, 0, gy)) { ty0 = min(ty0, gy); ty1 = max(ty1, gy + 1); }
        }
        if (ty1 > ty0) {
            var tp  = _cs * 0.22;
            var tx1 = _px - tp,             tx2 = _px + 2 * _cs;
            var tv1 = _py + ty0 * _cs - tp, tv2 = _py + ty1 * _cs + tp;

            // Trailer bogie, on both flanks at the rear.
            var twl = _cs * 0.28, tww = _cs * 0.13;
            for (var s = -1; s <= 1; s += 2) {
                var wy2 = (s < 0) ? (tv1 - tww * 0.55) : (tv2 + tww * 0.55);
                var wx2 = tx1 + twl * 1.6;
                draw_rectangle_colour(wx2 - twl, wy2 - tww, wx2 + twl, wy2 + tww,
                                      p.bg, p.bg, p.bg, p.bg, false);
                draw_rectangle_colour(wx2 - twl, wy2 - tww, wx2 + twl, wy2 + tww,
                                      _col, _col, _col, _col, true);
            }

            draw_set_alpha(0.5);
            draw_rectangle_colour(tx1, tv1, tx2, tv2, p.panel, p.panel, p.bg, p.bg, false);
            draw_set_alpha(1);
            draw_ink_rect(tx1, tv1, tx2, tv2, _col, 0.7, 2);

            // Coupling bar at the join.
            draw_line_width_colour(tx2, tv1 + 3, tx2, tv2 - 3, 4, _col, dim);
        }
    }

    draw_set_colour(c_white);
}

/// Solid deck: chassis floor with no bay cut into it yet. Hatched so it reads
/// as plating rather than as space you could drop something onto.
function draw_deck_plate(_x1, _y1, _x2, _y2) {
    var p = global.PAL;
    draw_set_alpha(0.6);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, p.panel, p.panel, p.bg, p.bg, false);
    draw_set_alpha(0.28);
    for (var i = 1; i <= 5; i++) {
        var t = i / 6;
        draw_line_colour(lerp(_x1, _x2, t), _y1, _x1, lerp(_y1, _y2, t), p.edge_hot, p.edge_hot);
        draw_line_colour(_x2, lerp(_y1, _y2, t), lerp(_x1, _x2, t), _y2, p.edge_hot, p.edge_hot);
    }
    draw_set_alpha(1);
}

/// Empty-cell hatching so unused grid space reads as "space you could fill".
/// On the painted deck the cell has to be picked out in light rather than in
/// ink — a brown rule on a black roof is nothing at all.
function draw_empty_cell(_x1, _y1, _x2, _y2, _dark = false) {
    var p = global.PAL;
    if (_dark) {
        draw_set_alpha(0.16);
        draw_rectangle_colour(_x1, _y1, _x2, _y2, p.lift, p.lift, p.lift, p.lift, false);
        draw_set_alpha(0.40);
        draw_rectangle_colour(_x1, _y1, _x2, _y2, p.lift, p.lift, p.lift, p.lift, true);
        draw_set_alpha(1);
        return;
    }
    draw_set_alpha(0.30);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, p.bg, p.bg, p.bg, p.bg, false);
    draw_set_alpha(0.22);
    draw_rectangle_colour(_x1, _y1, _x2, _y2, p.edge, p.edge, p.edge, p.edge, true);
    draw_set_alpha(1);
}

/// Draw one facility as a merged region with glyph, bars and status badges.
function draw_facility(_car, _idx, _px, _py, _cs, _opts) {
    var p = global.PAL;
    var f = _car.facs[_idx];
    var d = fac(f.def);

    var base = cat_colour(d.cat);
    var alive = fac_alive(f);
    var active = fac_active(f);

    // Tint by the dominant status — a burning facility must be unmistakable.
    var col = base;
    if (!alive)            col = merge_colour(p.text_mute, base, 0.25);
    else if (f.st.fire > 0) col = merge_colour(base, p.st_fire, 0.72);
    else if (f.st.elec > 0) col = merge_colour(base, p.st_elec, 0.68);
    else if (f.st.acid > 0) col = merge_colour(base, p.st_acid, 0.55);
    else if (f.st.oil  > 0) col = merge_colour(base, p.st_oil,  0.6);
    else if (!f.powered)    col = merge_colour(base, p.text_mute, 0.62);

    if (f.flash > 0) col = merge_colour(col, p.lift, min(1, f.flash * 5));

    // Fires flicker; electricity strobes. Kept shallow — on cream stock a dip
    // in alpha reads as the mark fading off the page, not as animation.
    var pulse = 1;
    if (f.st.fire > 0) pulse = 0.88 + 0.12 * dsin(current_time * 0.7 + _idx * 90);
    if (f.st.elec > 0) pulse = (dsin(current_time * 1.6 + _idx * 50) > 0) ? 1 : 0.78;

    // Dominant status drives the overlay. Fire beats everything, because a
    // facility that's burning is the thing you must deal with right now.
    var st_key = "";
    if      (f.st.fire > 0) st_key = "fire";
    else if (f.st.elec > 0) st_key = "elec";
    else if (f.st.acid > 0) st_key = "acid";
    else if (f.st.oil  > 0) st_key = "oil";

    // Fill each cell. Afflicted facilities fill harder so they read at a
    // glance — on paper that means laying down more ink, not more light.
    // On the painted roof the cells sit on near-black, so they fill harder and
    // every line and glyph in them flips from ink to cream. On paper it stays
    // as it was: a dark keyline plate under colour.
    var dark = (variable_struct_exists(_opts, "dark") && _opts.dark);
    if (dark) col = merge_colour(col, p.lift, 0.36);

    var fill_a = dark ? ((st_key == "") ? 0.74 : 0.92)
                      : ((st_key == "") ? 0.42 : 0.74);
    for (var c = 0; c < array_length(f.cells); c++) {
        var cx = _px + (f.ox + f.cells[c][0]) * _cs;
        var cy = _py + (f.oy + f.cells[c][1]) * _cs;
        draw_set_alpha(fill_a * pulse);
        draw_rectangle_colour(cx + 1, cy + 1, cx + _cs - 1, cy + _cs - 1, col, col, merge_colour(col, p.shade, 0.45), merge_colour(col, p.shade, 0.45), false);
        draw_set_alpha(1);
    }

    // Outline only the edges that face outside this facility.
    var own = {};
    for (var c = 0; c < array_length(f.cells); c++) {
        variable_struct_set(own, string(f.cells[c][0]) + "," + string(f.cells[c][1]), true);
    }
    // One dark keyline plate under every colour fill, exactly how the atlas is
    // printed. Tinting the keyline per-facility instead just makes mud.
    var keyl = dark ? p.lift : p.atlas_ink;
    draw_set_alpha(pulse);
    for (var c = 0; c < array_length(f.cells); c++) {
        var lx = f.cells[c][0], ly = f.cells[c][1];
        var cx = _px + (f.ox + lx) * _cs;
        var cy = _py + (f.oy + ly) * _cs;
        if (!variable_struct_exists(own, string(lx) + "," + string(ly - 1)))
            draw_line_width_colour(cx, cy, cx + _cs, cy, 2, keyl, keyl);
        if (!variable_struct_exists(own, string(lx) + "," + string(ly + 1)))
            draw_line_width_colour(cx, cy + _cs, cx + _cs, cy + _cs, 2, keyl, keyl);
        if (!variable_struct_exists(own, string(lx - 1) + "," + string(ly)))
            draw_line_width_colour(cx, cy, cx, cy + _cs, 2, keyl, keyl);
        if (!variable_struct_exists(own, string(lx + 1) + "," + string(ly)))
            draw_line_width_colour(cx + _cs, cy, cx + _cs, cy + _cs, 2, keyl, keyl);
    }
    draw_set_alpha(1);

    // Status overlay: an inset ring in the effect's colour plus a per-effect
    // motif, drawn on every occupied cell. This is the main read during a fight,
    // so it deliberately shouts.
    if (st_key != "") {
        var scol = status_colour(st_key);
        for (var c = 0; c < array_length(f.cells); c++) {
            var cx = _px + (f.ox + f.cells[c][0]) * _cs;
            var cy = _py + (f.oy + f.cells[c][1]) * _cs;
            var ph = _idx * 37 + c * 61;   // de-sync the animation per cell

            // A heavy inset rule in the effect's ink, doubled so it has the
            // weight of an overprinted warning box.
            var sdk = dark ? merge_colour(scol, p.lift, 0.45) : merge_colour(scol, p.shade, 0.35);
            draw_set_alpha(pulse);
            draw_rectangle_colour(cx + 4, cy + 4, cx + _cs - 4, cy + _cs - 4,
                                  sdk, sdk, sdk, sdk, true);
            draw_rectangle_colour(cx + 5, cy + 5, cx + _cs - 5, cy + _cs - 5,
                                  sdk, sdk, sdk, sdk, true);
            draw_set_alpha(1);

            // The cell is already flooded with the effect's ink, so the motif
            // is knocked out of it in cream — a light mark on a dark plate,
            // the way a warning symbol is reversed out of a printed panel.
            var mk = p.lift;
            draw_set_colour(mk);

            switch (st_key) {
                case "fire":
                    // Tongues licking up from the bottom of the cell.
                    for (var k = 0; k < 3; k++) {
                        var fx = cx + _cs * (0.26 + k * 0.24);
                        var fh = _cs * (0.24 + 0.14 * dsin(current_time * 0.55 + ph + k * 120));
                        draw_line_width_colour(fx, cy + _cs - 6, fx - _cs * 0.05, cy + _cs - 6 - fh, 2, mk, mk);
                        draw_line_width_colour(fx, cy + _cs - 6, fx + _cs * 0.05, cy + _cs - 6 - fh * 0.7, 2, mk, mk);
                    }
                    break;

                case "elec":
                    // An arc jumping across the cell.
                    var ex0 = cx + 7, ey0 = cy + _cs * 0.5;
                    var seg = 4;
                    for (var k = 1; k <= seg; k++) {
                        var nx2 = cx + 7 + (_cs - 14) * (k / seg);
                        var ny2 = cy + _cs * 0.5 + dsin(current_time * 1.9 + ph + k * 90) * _cs * 0.18;
                        draw_line_width_colour(ex0, ey0, nx2, ny2, 2, mk, mk);
                        ex0 = nx2; ey0 = ny2;
                    }
                    break;

                case "oil":
                    // A slick pooling at the bottom, dark against the plate.
                    draw_set_alpha(0.7);
                    draw_rectangle_colour(cx + 5, cy + _cs - 13, cx + _cs - 5, cy + _cs - 5,
                                          sdk, sdk, sdk, sdk, false);
                    draw_set_alpha(1);
                    draw_line_width_colour(cx + 6, cy + _cs - 13, cx + _cs - 6, cy + _cs - 13, 2, mk, mk);
                    break;

                case "acid":
                    // Bubbles eating into the plate.
                    for (var k = 0; k < 4; k++) {
                        var ax = cx + _cs * (0.2 + k * 0.2);
                        var ay = cy + _cs * 0.72 - abs(dsin(current_time * 0.5 + ph + k * 95)) * _cs * 0.34;
                        draw_circle_colour(ax, ay, 2.5, mk, mk, false);
                        draw_circle_colour(ax, ay, 2.5, sdk, sdk, true);
                    }
                    break;
            }
            draw_set_colour(c_white);
        }
    }

    // Glyph in the middle of the footprint's bounding box.
    var ext = shape_extent(f.cells);
    var gx = _px + (f.ox + ext[0] * 0.5) * _cs;
    var gy = _py + (f.oy + ext[1] * 0.5) * _cs;
    var gs = _cs * 0.30 * min(2, min(ext[0], ext[1]) * 0.85 + 0.35);
    draw_set_alpha(alive ? pulse : 0.4);
    // The fill under the glyph is bright either way, so the glyph stays dark;
    // only the dead-facility grey has to change side.
    var glyph_col = alive ? (dark ? merge_colour(p.lift, col, 0.30) : merge_colour(col, p.shade, 0.45))
                          : (dark ? merge_colour(p.lift, p.shade, 0.45) : p.text_mute);
    draw_fac_glyph(d.family, gx, gy, gs, glyph_col);
    draw_set_alpha(1);

    // Tier pips, top-left of the footprint.
    var tx = _px + f.ox * _cs + 4;
    var ty = _py + f.oy * _cs + 4;
    for (var i = 0; i < d.tier; i++) {
        draw_rectangle_colour(tx + i * 5, ty, tx + i * 5 + 3, ty + 3, col, col, col, col, false);
    }

    // Health bar along the bottom of the footprint.
    var hx1 = _px + f.ox * _cs + 3;
    var hx2 = _px + (f.ox + ext[0]) * _cs - 3;
    var hy  = _py + (f.oy + ext[1]) * _cs - 5;
    var hp_frac = f.hp / max(1, f.hp_max);
    if (hp_frac < 1) {
        var hcol = (hp_frac > 0.5) ? p.ok : ((hp_frac > 0.25) ? p.warn : p.danger);
        draw_set_alpha(0.35);
        var trc = dark ? p.lift : p.shade;
        draw_rectangle_colour(hx1, hy, hx2, hy + 3, trc, trc, trc, trc, false);
        draw_set_alpha(1);
        if (hp_frac > 0) draw_rectangle_colour(hx1, hy, hx1 + (hx2 - hx1) * hp_frac, hy + 3, hcol, hcol, hcol, hcol, false);
    }

    // Weapon charge bar along the top.
    if (_opts.show_charge && d.charge > 0 && alive) {
        var cy2 = _py + f.oy * _cs + 1;
        var ccol = (f.charge >= 1) ? p.amber : merge_colour(p.cyan, p.edge, 0.3);
        draw_set_alpha(0.30);
        var trc2 = dark ? p.lift : p.shade;
        draw_rectangle_colour(hx1, cy2, hx2, cy2 + 3, trc2, trc2, trc2, trc2, false);
        draw_set_alpha(active ? 1 : 0.35);
        draw_rectangle_colour(hx1, cy2, hx1 + (hx2 - hx1) * clamp(f.charge, 0, 1), cy2 + 3, ccol, ccol, ccol, ccol, false);
        draw_set_alpha(1);
    }

    // Status badges, bottom-right.
    var keys = status_keys(f);
    var bx = _px + (f.ox + ext[0]) * _cs - 7;
    var by = _py + (f.oy + ext[1]) * _cs - 12;
    for (var i = 0; i < array_length(keys); i++) {
        var kc = status_colour(keys[i]);
        draw_circle_colour(bx - i * 9, by, 3.5, kc, merge_colour(kc, p.shade, 0.4), false);
    }

    // Unpowered / wrecked overlays.
    if (!alive) {
        draw_set_alpha(0.85);
        var wx1 = _px + f.ox * _cs, wy1 = _py + f.oy * _cs;
        var wx2 = _px + (f.ox + ext[0]) * _cs, wy2 = _py + (f.oy + ext[1]) * _cs;
        draw_line_width_colour(wx1 + 5, wy1 + 5, wx2 - 5, wy2 - 5, 2, p.danger, p.danger);
        draw_line_width_colour(wx2 - 5, wy1 + 5, wx1 + 5, wy2 - 5, 2, p.danger, p.danger);
        draw_set_alpha(1);
    } else if (!f.powered) {
        draw_label(_px + (f.ox + ext[0] * 0.5) * _cs, _py + (f.oy + ext[1]) * _cs - 15,
                   "OFF", dark ? p.lift : p.text_mute, fa_center, fa_middle, fnt_small);
    }
}

/// The painted car art, fitted to the chassis footprint so the wireframe and
/// its readouts sit over the top of it.
///
/// The art is placed FROM the grid, not the other way round: the sprite is
/// scaled and offset so its roof panel lands exactly on the cell grid, and the
/// cab, bonnet and wheels hang off wherever that puts them. The grid stays the
/// authority, so hit-testing is untouched — and a facility always sits on the
/// deck rather than floating over a wing.
///
/// The two axes scale independently unless the car asks otherwise. The roof is
/// roughly square and the rig grows to twice as wide as it is tall, so a
/// uniform scale would either overflow the vehicle or shrink the cells to
/// nothing; letting the van lengthen with the chassis is both the readable
/// choice and the honest one — you really are bolting more deck onto it.
///
/// Nothing is drawn under the vehicles. The rigs sit flat on the road.
function draw_car_art(_car, _px, _py, _cs, _sprite, _flip) {
    if (_sprite == -1) return;

    // Two flips, and they mean different things: the caller's, which points
    // the whole rig the other way, and the art's own, which only says which
    // way the sprite was painted. A nose-left sprite drawn nose-right is the
    // two of them cancelling out.
    var af   = variable_struct_exists(_car, "art_flip") ? bool(_car.art_flip) : false;
    var flip = (bool(_flip) != af);

    var box = car_art_rect(_car, _px, _py, _cs, flip);
    var dx = box[0], dy = box[1];
    var dw = box[2] - box[0], dh = box[3] - box[1];

    var sw = sprite_get_width(_sprite), sh = sprite_get_height(_sprite);
    var xs = dw / sw, ys = dh / sh;
    if (flip) xs = -xs;

    // Respect any alpha the caller set — wrecks are drawn dimmed.
    var a = draw_get_alpha();

    draw_art_sprite(_sprite, 0, dx, dy, dw, dh, xs, ys, c_white, a);

    // Wings sit over the body — a Chitin drifter is a beetle, and the flap is
    // the only thing on the road that says so. Placed and sized against the
    // body sprite's own canvas, so it rides along with every rescale.
    var wing = variable_struct_exists(_car, "art_wings") ? _car.art_wings : -1;
    if (wing != -1) {
        var at = variable_struct_exists(_car, "art_wings_at") ? _car.art_wings_at : [0.5, 0.5];
        var wk = variable_struct_exists(_car, "art_wings_scale") ? _car.art_wings_scale : 1;
        var wcx = dx + (flip ? (1 - at[0]) : at[0]) * dw;
        var wcy = dy + at[1] * dh;
        var wxs = xs * wk, wys = ys * wk;
        // Free-running off the wall clock rather than the fight timer, so the
        // beetle keeps flapping in the garage and on the end-of-run manifest.
        var wfps = max(1, sprite_get_speed(wing));
        var wf   = floor(current_time * 0.001 * wfps) mod sprite_get_number(wing);
        draw_sprite_ext(wing, wf,
                        wcx - (sprite_get_width(wing)  * 0.5 - sprite_get_xoffset(wing)) * wxs,
                        wcy - (sprite_get_height(wing) * 0.5 - sprite_get_yoffset(wing)) * wys,
                        wxs, wys, 0, c_white, a);
    }

    draw_set_alpha(a);
}

/// The vehicle art, laid into the box (_dx, _dy, _dw x _dh).
///
/// The sprites come in with whatever origin the artist saved — the corporate
/// saloon is centred, the rest are top-left — so the origin is subtracted here
/// rather than assumed away. `_xs` is already negative for a flipped rig, which
/// is what puts the drawn image's right edge on the box's right edge.
function draw_art_sprite(_spr, _frame, _dx, _dy, _dw, _dh, _xs, _ys, _col, _alpha) {
    var ox = (_xs < 0 ? _dx + _dw : _dx) + sprite_get_xoffset(_spr) * _xs;
    var oy = _dy + sprite_get_yoffset(_spr) * _ys;
    draw_sprite_ext(_spr, _frame, ox, oy, _xs, _ys, 0, _col, _alpha);
}

/// The screen box the painted bodywork fills, as [x1, y1, x2, y2] — the grid
/// box itself for a car drawn as a cutaway.
///
/// The art is placed FROM the grid, not the other way round: the sprite is
/// scaled so its roof fraction lands exactly on the cell grid, and the cab,
/// bonnet and wheels hang off wherever that puts them. Flipping mirrors the
/// hangover without moving the deck, so a nose-left sprite can be pointed the
/// same way as everything else on the road and still keep its facilities on
/// its own cargo bed.
/// `art_uniform` opts a vehicle out of the independent axes: it is drawn at the
/// proportions it was painted at, sized so the roof still covers the deck, and
/// the deck is then centred on it. The saloon needs that — it is two and a half
/// times as long as it is wide, and stretching a square grid across it turned a
/// limousine into a van.
function car_art_rect(_car, _px, _py, _cs, _flip = undefined) {
    var gw = _px + _car.gw * _cs, gh = _py + _car.gh * _cs;
    if (!variable_struct_exists(_car, "art") || _car.art == -1) return [_px, _py, gw, gh];

    var roof = variable_struct_exists(_car, "art_roof") ? _car.art_roof : [0, 0, 1, 1];
    var flip = (_flip != undefined) ? _flip
             : (variable_struct_exists(_car, "art_flip") ? _car.art_flip : false);

    // Scale the whole sprite so its roof fraction covers exactly the deck.
    var dw = (gw - _px) / max(0.01, roof[2] - roof[0]);
    var dh = (gh - _py) / max(0.01, roof[3] - roof[1]);

    if (variable_struct_exists(_car, "art_uniform") && _car.art_uniform) {
        var sw = sprite_get_width(_car.art), sh = sprite_get_height(_car.art);
        var s  = max(dw / sw, dh / sh);     // the tighter axis wins, so the roof still covers
        dw = sw * s;
        dh = sh * s;
    }

    // Hang the sprite off the middle of the deck. Identical to pinning the
    // roof's top-left corner when the axes scale independently, and the only
    // placement that makes sense once they don't.
    var rcx = (roof[0] + roof[2]) * 0.5;
    var dx = (_px + gw) * 0.5 - (flip ? (1 - rcx) : rcx) * dw;
    var dy = (_py + gh) * 0.5 - (roof[1] + roof[3]) * 0.5 * dh;
    return [dx, dy, dx + dw, dy + dh];
}

/// Draw a whole car. `_opts` fields: flip, show_charge, hover_fac, target_fac,
/// selected_fac, dim, sprite.
function draw_car(_car, _px, _py, _cs, _opts = undefined) {
    var p = global.PAL;
    var o = {
        flip: false, show_charge: true,
        hover_fac: -1, target_fac: -1, selected_fac: -1,
        outline: -1, dim: false, dark: false,
        // Default to whatever bodywork the car carries, so a caller only has to
        // name a sprite when it wants to override one.
        sprite: variable_struct_exists(_car, "art") ? _car.art : -1,
    };
    if (_opts != undefined) {
        var keys = variable_struct_get_names(_opts);
        for (var i = 0; i < array_length(keys); i++) {
            variable_struct_set(o, keys[i], variable_struct_get(_opts, keys[i]));
        }
    }

    var hull_frac = _car.hull / max(1, _car.hull_max);
    var chassis_col = (o.outline != -1) ? o.outline
                    : ((hull_frac > 0.5) ? p.cyan : ((hull_frac > 0.25) ? p.warn : p.danger));

    // Painted art stands in for the wireframe entirely — the readouts and
    // facility panels still draw over the top of it.
    // The painted deck is a near-black cargo roof, the wireframe deck is cream
    // paper. Everything drawn into the cells has to know which, because the
    // dark keylines and dark glyphs that make a facility read on paper vanish
    // completely against the roof.
    var has_art = (o.sprite != -1);
    o.dark = has_art;

    draw_car_art(_car, _px, _py, _cs, o.sprite, o.flip);

    if (!has_art) draw_chassis(_car, _px, _py, _cs, chassis_col, o.flip);

    // Empty cells first, so facilities draw over the hatching. Cells that
    // don't exist at all are drawn as solid deck instead.
    for (var gy = 0; gy < _car.gh; gy++) {
        for (var gx = 0; gx < _car.gw; gx++) {
            var qx = _px + gx * _cs, qy = _py + gy * _cs;
            if (!car_cell_exists(_car, gx, gy)) {
                // Unbuilt deck only exists inside the body. A trailer column
                // outside the 2x2 block is empty air, not plating. With art
                // underneath, the painted bodywork already reads as plating.
                if (gx >= car_body_x0(_car) && !has_art) draw_deck_plate(qx, qy, qx + _cs, qy + _cs);
            } else if (car_at(_car, gx, gy) == -1) {
                draw_empty_cell(qx, qy, qx + _cs, qy + _cs, has_art);
            }
        }
    }

    for (var i = 0; i < array_length(_car.facs); i++) {
        draw_facility(_car, i, _px, _py, _cs, o);
    }

    // Selection and targeting rings sit above everything. On the dark roof the
    // ink-coloured hover ring is invisible, so it goes cream instead.
    if (o.selected_fac >= 0 && o.selected_fac < array_length(_car.facs)) {
        var selc = has_art ? merge_colour(p.cyan, p.lift, 0.45) : p.cyan;
        draw_fac_ring(_car, o.selected_fac, _px, _py, _cs, selc, false);
    }
    if (o.hover_fac >= 0 && o.hover_fac < array_length(_car.facs)) {
        draw_fac_ring(_car, o.hover_fac, _px, _py, _cs, has_art ? p.lift : p.text, false);
    }
    if (o.target_fac >= 0 && o.target_fac < array_length(_car.facs)) {
        draw_fac_ring(_car, o.target_fac, _px, _py, _cs, p.magenta, true);
    }
}

/// How far above the grid the painted bodywork reaches, in pixels — zero for a
/// car drawn as a cutaway. Callers stack their readouts clear of this, because
/// the art is hung off the deck and a big rig's roofline now climbs well above
/// the top row of cells.
function car_art_rise(_car, _cs) {
    return -car_art_rect(_car, 0, 0, _cs)[1];
}

/// Highlight ring around a facility's bounding box. `_dashed` marks a target.
function draw_fac_ring(_car, _idx, _px, _py, _cs, _col, _dashed) {
    var f = _car.facs[_idx];
    var ext = shape_extent(f.cells);
    var x1 = _px + f.ox * _cs - 2;
    var y1 = _py + f.oy * _cs - 2;
    var x2 = _px + (f.ox + ext[0]) * _cs + 2;
    var y2 = _py + (f.oy + ext[1]) * _cs + 2;

    if (_dashed) {
        draw_dashed_line(x1, y1, x2, y1, _col, 7, 5, 2);
        draw_dashed_line(x2, y1, x2, y2, _col, 7, 5, 2);
        draw_dashed_line(x2, y2, x1, y2, _col, 7, 5, 2);
        draw_dashed_line(x1, y2, x1, y1, _col, 7, 5, 2);
        // Corner brackets make it read as a weapon lock.
        var t = 9;
        draw_line_width_colour(x1 - 3, y1 - 3, x1 - 3 + t, y1 - 3, 2, _col, _col);
        draw_line_width_colour(x1 - 3, y1 - 3, x1 - 3, y1 - 3 + t, 2, _col, _col);
        draw_line_width_colour(x2 + 3, y2 + 3, x2 + 3 - t, y2 + 3, 2, _col, _col);
        draw_line_width_colour(x2 + 3, y2 + 3, x2 + 3, y2 + 3 - t, 2, _col, _col);
    } else {
        draw_ink_rect(x1, y1, x2, y2, _col, 0.9, 2);
    }
}

/// Grid cell under a point, as [cx, cy], or -1 if outside the grid.
function car_cell_at(_car, _px, _py, _cs, _mx, _my) {
    var gx = floor((_mx - _px) / _cs);
    var gy = floor((_my - _py) / _cs);
    if (!car_in_bounds(_car, gx, gy)) return -1;
    return [gx, gy];
}

/// Facility index under a point, or -1.
function car_fac_at_point(_car, _px, _py, _cs, _mx, _my) {
    var cell = car_cell_at(_car, _px, _py, _cs, _mx, _my);
    if (!is_array(cell)) return -1;
    return car_at(_car, cell[0], cell[1]);
}

/// Total drawn footprint of a car from above, including padding, bonnet and
/// the wheels straddling each flank, as [w, h].
function car_draw_size(_car, _cs) {
    var pad = _cs * 0.30;
    return [_car.gw * _cs + pad * 2 + _cs * 1.2, _car.gh * _cs + pad * 2 + _cs * 0.3];
}
