var p = global.PAL;
var W = display_get_gui_width();
var H = display_get_gui_height();
var r = global.run;
var m = r.map;

// ---------------------------------------------------------------- the paper
draw_rectangle_colour(0, 0, W, H, p.paper, p.paper, p.paper_dark, p.paper_dark, false);

// Faint "urban area" patches.
for (var i = 0; i < array_length(m.blobs); i++) {
    var b = m.blobs[i];
    draw_set_alpha(0.16);
    draw_ellipse_colour(b.px - b.rx, b.py - b.ry, b.px + b.rx, b.py + b.ry,
                        p.route_ochre, p.paper_dark, false);
    draw_set_alpha(1);
}

// Survey grid.
draw_set_alpha(0.14);
for (var gx2 = 60; gx2 < W; gx2 += 96) draw_line_colour(gx2, 96, gx2, H - 78, p.paper_faint, p.paper_faint);
for (var gy2 = 120; gy2 < H - 78; gy2 += 92) draw_line_colour(40, gy2, W - 40, gy2, p.paper_faint, p.paper_faint);
draw_set_alpha(1);

// County boundaries.
draw_set_alpha(0.35);
draw_dashed_line(40, 232, W - 40, 258, p.paper_faint, 9, 7, 1);
draw_dashed_line(560, 96, 606, H - 78, p.paper_faint, 9, 7, 1);
draw_set_alpha(1);

// Coffee rings, because it's a real atlas that lives in a real cab.
for (var i = 0; i < array_length(m.stains); i++) {
    var s = m.stains[i];
    draw_set_alpha(0.13);
    draw_circle_colour(s.px, s.py, s.r, p.route_ochre, p.route_ochre, true);
    draw_circle_colour(s.px, s.py, s.r - 2, p.route_ochre, p.route_ochre, true);
    draw_set_alpha(0.05);
    draw_circle_colour(s.px, s.py, s.r, p.route_ochre, p.paper, false);
    draw_set_alpha(1);
}

// Fold crease.
draw_set_alpha(0.20);
draw_line_width_colour(m.crease, 96, m.crease - 14, H - 78, 3, p.paper_faint, p.paper_faint);
draw_set_alpha(0.10);
draw_line_width_colour(m.crease + 4, 96, m.crease - 10, H - 78, 8, p.paper_dark, p.paper_dark);
draw_set_alpha(1);

// ---------------------------------------------------------------- roads
for (var i = 0; i < array_length(m.edges); i++) {
    var e = m.edges[i];
    var a = m.nodes[e.a], b2 = m.nodes[e.b];
    var mxp = (a.px + b2.px) * 0.5 + e.ox;
    var myp = (a.py + b2.py) * 0.5 + e.oy;

    // Roads are two-way, so either end being your current town lights it up.
    var live = (r.node == e.a || r.node == e.b);
    var col  = live ? p.route_red : p.route_blue;
    var casing = merge_colour(col, c_black, 0.45);

    // A two-segment polyline through the bend point reads as a real road.
    draw_line_width_colour(a.px, a.py, mxp, myp, live ? 8 : 6, casing, casing);
    draw_line_width_colour(mxp, myp, b2.px, b2.py, live ? 8 : 6, casing, casing);
    draw_line_width_colour(a.px, a.py, mxp, myp, live ? 5 : 3, col, col);
    draw_line_width_colour(mxp, myp, b2.px, b2.py, live ? 5 : 3, col, col);
}

// ---------------------------------------------------------------- repo line
var cvx = map_convoy_x();
if (cvx > 20) {
    draw_set_alpha(0.16);
    draw_rectangle_colour(0, 96, cvx, H - 78, p.convoy, p.convoy, p.convoy, p.convoy, false);
    draw_set_alpha(0.30);
    for (var hy = 96; hy < H - 78; hy += 14) {
        draw_line_width_colour(max(0, cvx - 60), hy, cvx, hy - 30, 2, p.convoy, p.convoy);
    }
    draw_set_alpha(1);

    var wob = dsin(t * 90) * 3;
    draw_line_width_colour(cvx + wob, 96, cvx - wob, H - 78, 4, p.convoy, p.convoy);
    draw_label(cvx - 8, 104, "REPOSSESSION LINE", p.convoy, fa_right, fa_top, fnt_small);
}

// ---------------------------------------------------------------- nodes
for (var i = 0; i < array_length(m.nodes); i++) {
    var n = m.nodes[i];
    var here     = (i == r.node);
    var reach    = map_is_reachable(i) && !here;
    var lost     = map_node_lost(i) && !here;
    var done     = n.resolved && !here;
    var known    = n.visited || reach || car_has_sensors(r.car);

    var ink = p.paper_ink;
    var accent = p.route_blue;
    if (n.kind == "fight") accent = p.convoy;
    if (n.kind == "shop")  accent = make_colour_rgb(28, 120, 82);
    if (n.kind == "fuel")  accent = p.route_ochre;
    if (n.kind == "exit")  accent = make_colour_rgb(60, 60, 60);
    // Somewhere you've already been reads as spent, so the eye goes to what's new.
    if (done && n.kind != "exit") accent = p.paper_faint;

    var rad = here ? 19 : 15;

    // Reachable nodes with something left in them pulse, so the next real
    // choice is obvious even on a busy graph you can cross in any direction.
    if (reach && !lost && !done) {
        var pulse = 0.35 + 0.25 * dsin(t * 150);
        draw_set_alpha(pulse);
        draw_circle_colour(n.px, n.py, rad + 9, p.route_red, p.paper, false);
        draw_set_alpha(1);
    }

    // Route-shield plate.
    draw_set_alpha(lost ? 0.32 : 1);
    draw_circle_colour(n.px, n.py, rad + 2, ink, ink, false);
    draw_circle_colour(n.px, n.py, rad, p.paper, p.paper, false);
    draw_circle_colour(n.px, n.py, rad, ink, ink, true);

    // Icon.
    draw_set_colour(known ? accent : p.paper_faint);
    if (!known) {
        draw_label(n.px, n.py, "?", p.paper_faint, fa_center, fa_middle, fnt_term_big);
    } else {
        switch (n.kind) {
            case "fight":
                // Crossed slash — a hazard marker.
                draw_line_width_colour(n.px - 7, n.py - 7, n.px + 7, n.py + 7, 3, accent, accent);
                draw_line_width_colour(n.px + 7, n.py - 7, n.px - 7, n.py + 7, 3, accent, accent);
                break;
            case "shop":
                draw_rectangle_colour(n.px - 7, n.py - 6, n.px + 7, n.py + 7, accent, accent, accent, accent, true);
                draw_line_width_colour(n.px - 7, n.py - 2, n.px + 7, n.py - 2, 2, accent, accent);
                break;
            case "fuel":
                draw_line_width_colour(n.px, n.py - 8, n.px - 6, n.py + 3, 2, accent, accent);
                draw_line_width_colour(n.px, n.py - 8, n.px + 6, n.py + 3, 2, accent, accent);
                draw_circle_colour(n.px, n.py + 3, 5, accent, accent, true);
                break;
            case "event":
                draw_label(n.px, n.py - 1, "?", accent, fa_center, fa_middle, fnt_term_big);
                break;
            case "exit":
                draw_line_width_colour(n.px - 6, n.py - 7, n.px + 5, n.py, 3, accent, accent);
                draw_line_width_colour(n.px + 5, n.py, n.px - 6, n.py + 7, 3, accent, accent);
                break;
            default:
                draw_circle_colour(n.px, n.py, 5, ink, ink, false);
                break;
        }
    }
    draw_set_alpha(1);

    // Route label under the shield.
    if (known) {
        draw_label(n.px, n.py + rad + 4, map_node_title(n),
                   lost ? p.paper_faint : ink, fa_center, fa_top, fnt_small);
    }

    if (lost) {
        draw_line_width_colour(n.px - rad, n.py, n.px + rad, n.py, 2, p.convoy, p.convoy);
    } else if (done) {
        // Small tick: been here, done it.
        draw_line_width_colour(n.px + rad - 4, n.py - rad + 1, n.px + rad + 2, n.py - rad + 7, 2, ink, ink);
        draw_line_width_colour(n.px + rad + 2, n.py - rad + 7, n.px + rad + 11, n.py - rad - 5, 2, ink, ink);
    }

    // You are here — a small rig parked on the node.
    if (here) {
        draw_circle_colour(n.px, n.py, rad + 6, p.route_red, p.route_red, true);

        // Your rig, parked above the town — overhead, like everything else.
        var bob = dsin(t * 200) * 1.5;
        var cy2 = n.py - rad - 16 + bob;
        for (var s = -1; s <= 1; s += 2) {
            for (var w2 = -1; w2 <= 1; w2 += 2) {
                draw_rectangle_colour(n.px + w2 * 7 - 3, cy2 + s * 7 - 2,
                                      n.px + w2 * 7 + 3, cy2 + s * 7 + 2,
                                      p.paper_ink, p.paper_ink, p.paper_ink, p.paper_ink, false);
            }
        }
        draw_rectangle_colour(n.px - 11, cy2 - 6, n.px + 8, cy2 + 6,
                              p.route_red, p.route_red, p.convoy, p.convoy, false);
        draw_triangle_colour(n.px + 8, cy2 - 6, n.px + 13, cy2 - 3,
                             n.px + 13, cy2 + 3, p.route_red, p.convoy, p.convoy, false);
        draw_triangle_colour(n.px + 8, cy2 - 6, n.px + 8, cy2 + 6,
                             n.px + 13, cy2 + 3, p.route_red, p.route_red, p.convoy, false);
        draw_line_width_colour(n.px + 4, cy2 - 5, n.px + 4, cy2 + 5, 2, p.paper_ink, p.paper_ink);
    }
}

// Hover readout.
if (hover_node != -1 && ev == undefined) {
    var hn = m.nodes[hover_node];
    var can = map_can_travel(hover_node) && hover_node != r.node;
    var txt = map_node_title(hn);
    if (hover_node == r.node)               txt = "YOU ARE HERE";
    else if (!map_is_reachable(hover_node)) txt = "NO ROAD FROM HERE";
    else if (map_node_lost(hover_node))     txt = "CUT OFF — the repo line has it";
    else {
        if (hn.resolved) txt += "  —  already done";
        if (r.fuel <= 0) txt += "  —  NO FUEL: costs 4 hull";
        else             txt += "  —  1 fuel";
    }

    draw_label(hn.px, hn.py - 40, txt, can ? p.route_red : p.paper_faint, fa_center, fa_bottom, fnt_term);
}

// ---------------------------------------------------------------- header
draw_set_alpha(0.92);
draw_rectangle_colour(0, 0, W, 88, p.paper, p.paper, p.paper_dark, p.paper_dark, false);
draw_set_alpha(1);
draw_line_width_colour(0, 88, W, 88, 2, p.paper_ink, p.paper_ink);

draw_label(24, 12, "SECTOR " + string(r.sector) + " OF " + string(SECTOR_COUNT)
         + " — " + sector_name(r.sector), p.paper_ink, fa_left, fa_top, fnt_term_big);
draw_label(24, 40, "STATE ROAD ATLAS  ·  REVISED EDITION  ·  ROUTES SUBJECT TO SEIZURE",
           p.paper_faint, fa_left, fa_top, fnt_small);

// Resources, as a paper ledger strip.
var rx = 690;
var res = [
    ["SCRAP", string(r.scrap),                                              p.route_ochre],
    ["FUEL",  string(r.fuel),                                               p.route_blue],
    ["HULL",  string(ceil(r.car.hull)) + "/" + string(r.car.hull_max),      p.convoy],
    ["DRONES", string(car_drones(r.car)),                                   make_colour_rgb(28, 120, 82)],
];
for (var i = 0; i < array_length(res); i++) {
    var cx2 = rx + i * 148;
    draw_label(cx2, 16, res[i][0], p.paper_faint, fa_left, fa_top, fnt_small);
    draw_label(cx2, 32, res[i][1], res[i][2], fa_left, fa_top, fnt_term_big);
}
if (r.fuel <= 0) {
    draw_label(rx + 148, 62, "DRY — hops cost hull", p.convoy, fa_left, fa_top, fnt_small);
}

// ---------------------------------------------------------------- footer
draw_set_alpha(0.92);
draw_rectangle_colour(0, H - 74, W, H, p.paper_dark, p.paper_dark, p.paper, p.paper, false);
draw_set_alpha(1);
draw_line_width_colour(0, H - 74, W, H - 74, 2, p.paper_ink, p.paper_ink);

draw_label(24, H - 66, "LOG", p.paper_faint, fa_left, fa_top, fnt_small);
var start = max(0, array_length(r.log) - 3);
for (var i = start; i < array_length(r.log); i++) {
    draw_label(64, H - 66 + (i - start) * 17, r.log[i], p.paper_ink, fa_left, fa_top, fnt_small);
}

draw_label(W - 24, H - 66, "Click any connected town — roads run both ways.", p.paper_ink, fa_right, fa_top, fnt_small);
draw_label(W - 24, H - 48, "The repo line advances every hop, and takes what it passes.",
           p.paper_faint, fa_right, fa_top, fnt_small);
draw_label(W - 24, H - 30, "Sector exit is the on-ramp on the far right.",
           p.paper_faint, fa_right, fa_top, fnt_small);

// ---------------------------------------------------------------- event
if (ev != undefined) {
    draw_set_alpha(0.68);
    draw_rectangle_colour(0, 0, W, H, c_black, c_black, c_black, c_black, false);
    draw_set_alpha(1);

    // Size the panel to its contents rather than leaving a slab of dead space.
    var ex1 = 268, ex2 = 1012;
    var inner = ex2 - ex1 - 52;

    draw_set_font(fnt_term);
    var body_lines = ui_wrap(ev.body, inner);
    var body_h = array_length(body_lines) * 20;

    var tail_h;
    var res_lines = [];
    if (ev_result == "") {
        tail_h = array_length(ev.choices) * 56;
    } else {
        res_lines = ui_wrap(ev_result, inner);
        tail_h = array_length(res_lines) * 20 + 24 + 48;
    }
    var content_h = 58 + body_h + 24 + tail_h + 20;
    var ey1 = clamp(360 - content_h * 0.5, 112, 300);
    var ey2 = ey1 + content_h;

    draw_panel(ex1, ey1, ex2, ey2, p.violet, 0.97);

    draw_label(ex1 + 26, ey1 + 20, ev.title, p.cyan, fa_left, fa_top, fnt_term_big);
    draw_set_font(fnt_term);
    for (var i = 0; i < array_length(body_lines); i++) {
        draw_label(ex1 + 26, ey1 + 58 + i * 20, body_lines[i], p.text, fa_left, fa_top, fnt_term);
    }

    var cy3 = ey1 + 58 + body_h + 24;

    if (ev_result == "") {
        for (var i = 0; i < array_length(ev.choices); i++) {
            var ch = ev.choices[i];
            var allowed = true;
            if (variable_struct_exists(ch, "req")) allowed = ch.req();

            var b1 = ex1 + 26, b2 = ex2 - 26;
            var t1 = cy3 + i * 56, t2 = t1 + 46;

            var hov = allowed && ui_hover(b1, t1, b2, t2);
            var col = allowed ? (hov ? p.cyan : p.violet) : p.text_mute;

            draw_set_alpha(hov ? 0.18 : 0.07);
            draw_rectangle_colour(b1, t1, b2, t2, col, col, col, col, false);
            draw_set_alpha(1);
            draw_rectangle_colour(b1, t1, b2, t2, col, col, col, col, true);

            draw_label(b1 + 14, t1 + 6, ch.label, allowed ? p.text : p.text_mute, fa_left, fa_top, fnt_term);
            var sub = allowed ? ch.hint : ("LOCKED — " + ch.req_text);
            draw_label(b1 + 14, t1 + 26, sub, allowed ? p.text_dim : p.danger, fa_left, fa_top, fnt_small);

            if (allowed && ui_clicked(b1, t1, b2, t2)) {
                ev_result = ch.act();   //gmx-lint-ignore draw-event-mutation
                run_log(ev.title + ": " + ev_result);
            }
        }
    } else {
        draw_set_font(fnt_term);
        for (var i = 0; i < array_length(res_lines); i++) {
            draw_label(ex1 + 26, cy3 + i * 20, res_lines[i], p.amber, fa_left, fa_top, fnt_term);
        }

        draw_set_font(fnt_term_big);
        var okx = (ex1 + ex2) * 0.5 - 100;
        if (ui_button(okx, ey2 - 68, okx + 200, ey2 - 20, "DRIVE ON", true, p.cyan)) {
            ev = undefined;     //gmx-lint-ignore draw-event-mutation
            ev_result = "";     //gmx-lint-ignore draw-event-mutation
        }
    }
}

ui_draw_tooltip();
