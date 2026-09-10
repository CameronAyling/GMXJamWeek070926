var p = global.PAL;
var W = display_get_gui_width();
var H = display_get_gui_height();
var r = global.run;
var m = r.map;

// ---------------------------------------------------------------- the atlas
// Spr_Map_01_Base is the whole printed page — masthead, stat swatches, border
// and footer are all baked in at 1920x1080. Everything below is drawn into the
// blanks it leaves.
var sx = W / sprite_get_width(Spr_Map_01_Base);
var sy = H / sprite_get_height(Spr_Map_01_Base);
draw_sprite_ext(Spr_Map_01_Base, 0, 0, 0, sx, sy, 0, c_white, 1);

// ---------------------------------------------------------------- hazards
// Bad country, shaded onto the page before the roads go down — the way an
// atlas prints marsh or scree under the network rather than over it. The
// outline is sampled from the same radius function that decides which stops
// are inside, so what you see is exactly what bites.
if (variable_struct_exists(m, "hazards")) {
    // The printed page area. A region may run past it — there are no stops out
    // there, so trimming the drawing to the border changes nothing about what
    // is affected, and reads as the weather carrying on off the edge.
    var PX0 = 24, PX1 = 1256, PY0 = 122, PY1 = 686;

    for (var hi = 0; hi < array_length(m.hazards); hi++) {
        var reg  = m.hazards[hi];
        var hcol = hazard_colour(reg.id);
        var pts  = hazard_region_points(reg, 40);

        // Trim the outline to the page.
        for (var k = 0; k < array_length(pts); k++) {
            pts[k] = [clamp(pts[k][0], PX0, PX1), clamp(pts[k][1], PY0, PY1)];
        }

        // Wash. The alpha has to ride on the vertices — draw_set_alpha does not
        // reach a primitive built from draw_vertex_colour.
        draw_primitive_begin(pr_trianglefan);
        draw_vertex_colour(clamp(reg.cx, PX0, PX1), clamp(reg.cy, PY0, PY1), hcol, 0.17);
        for (var k = 0; k <= array_length(pts); k++) {
            var pt = pts[k mod array_length(pts)];
            draw_vertex_colour(pt[0], pt[1], hcol, 0.17);
        }
        draw_primitive_end();

        // Hatching, on a diagonal grid clipped to the same shape.
        draw_set_alpha(0.34);
        var step = 15;
        for (var gy2 = reg.cy - reg.base * 1.5; gy2 < reg.cy + reg.base * 1.5; gy2 += step) {
            if (gy2 < PY0 || gy2 > PY1) continue;
            var row = floor((gy2 - reg.cy) / step);
            for (var gx2 = reg.cx - reg.base * 1.5 + (row mod 2) * step * 0.5;
                 gx2 < reg.cx + reg.base * 1.5; gx2 += step) {
                if (gx2 < PX0 || gx2 > PX1) continue;
                if (!hazard_region_contains(reg, gx2, gy2)) continue;
                draw_line_width_colour(gx2 - 4, gy2 + 4, gx2 + 4, gy2 - 4, 1, hcol, hcol);
            }
        }

        // Edge: a heavier boundary so the region reads as a mapped area.
        draw_set_alpha(0.70);
        for (var k = 0; k < array_length(pts); k++) {
            var a1 = pts[k], b1 = pts[(k + 1) mod array_length(pts)];
            draw_line_width_colour(a1[0], a1[1], b1[0], b1[1], 2, hcol, hcol);
        }
        draw_set_alpha(1);

        // Name it along the top edge of the blob, kept on the page.
        var lab_y = clamp(reg.cy - hazard_region_radius(reg, 90) - 13, PY0 + 4, PY1 - 16);
        draw_map_label(clamp(reg.cx, PX0 + 60, PX1 - 60), lab_y, hazard(reg.id).name, hcol);
    }
}

// ---------------------------------------------------------------- roads
// Ink lines on printed paper: a dark casing with a lighter core, and the roads
// leading out of where you're parked picked out in red.
for (var i = 0; i < array_length(m.edges); i++) {
    var e = m.edges[i];
    var a = m.nodes[e.a], b2 = m.nodes[e.b];
    var mxp = (a.px + b2.px) * 0.5 + e.ox;
    var myp = (a.py + b2.py) * 0.5 + e.oy;

    var live = (r.node == e.a || r.node == e.b);
    var col  = live ? p.atlas_live : p.atlas_road;

    draw_set_alpha(live ? 0.75 : 0.30);
    draw_line_width_colour(a.px, a.py, mxp, myp, live ? 6 : 4, p.atlas_ink, p.atlas_ink);
    draw_line_width_colour(mxp, myp, b2.px, b2.py, live ? 6 : 4, p.atlas_ink, p.atlas_ink);
    draw_set_alpha(live ? 1 : 0.75);
    draw_line_width_colour(a.px, a.py, mxp, myp, live ? 3 : 2, col, col);
    draw_line_width_colour(mxp, myp, b2.px, b2.py, live ? 3 : 2, col, col);
    draw_set_alpha(1);
}

// ---------------------------------------------------------------- dead-line
// The schedule, drawn onto the page as a rule sweeping left to right. Behind
// it is time you no longer have: hatched out, and struck off the timetable.
var cvx = map_deadline_x();
if (cvx > MAP_X0 - 40) {
    var top = 176, bot = 648;
    draw_set_alpha(0.16);
    draw_rectangle_colour(30, top, cvx, bot, p.atlas_alert, p.atlas_alert,
                                             p.atlas_alert, p.atlas_alert, false);
    draw_set_alpha(0.30);
    for (var hy = top; hy < bot; hy += 15) {
        draw_line_width_colour(max(30, cvx - 55), hy, cvx, hy - 28, 2, p.atlas_alert, p.atlas_alert);
    }
    draw_set_alpha(1);

    // The rule itself, ticked off like a timetable margin — every tick an hour
    // of the delivery window already spent.
    var wob = dsin(t * 90) * 2;
    draw_line_width_colour(cvx + wob, top, cvx - wob, bot, 4, p.atlas_alert, p.atlas_alert);
    for (var ty = top + 10; ty < bot; ty += 26) {
        var tw2 = ((ty - top) div 26) mod 4 == 0 ? 11 : 6;
        draw_line_width_colour(cvx, ty, cvx - tw2, ty, 2, p.atlas_alert, p.atlas_alert);
    }

    draw_label(cvx - 16, top + 6, "THE DEAD-LINE", p.atlas_alert, fa_right, fa_top, fnt_small);
    draw_label(cvx - 16, top + 20, "BEHIND SCHEDULE", p.atlas_alert, fa_right, fa_top, fnt_small);
}

// ---------------------------------------------------------------- nodes
var ICON = 46;   // on-screen badge size; the art is 68px square

for (var i = 0; i < array_length(m.nodes); i++) {
    var n = m.nodes[i];
    var here  = (i == r.node);
    var reach = map_is_reachable(i) && !here;
    var lost  = map_node_lost(i) && !here;
    // A truck stop you've used isn't spent — it's a shop, and it's still open.
    // It only earns the "done" tick once you've cleared its shelves.
    var bare  = (n.kind == "shop") && is_array(n.stock) && (array_length(n.stock) == 0);
    var done  = !here && (bare || (n.resolved && n.kind != "shop"));
    var known = n.visited || reach || car_has_sensors(r.car);

    // A stop inside a region gets a ring in the hazard's ink. The shaded area
    // already says where the weather is; this says, without ambiguity at the
    // boundary, that this particular stop is in it.
    if (n.hazard != "" && known) {
        var hcol = hazard_colour(n.hazard);
        draw_set_alpha(0.85 * a);
        draw_circle_colour(n.px, n.py, ICON * 0.60, hcol, hcol, true);
        draw_circle_colour(n.px, n.py, ICON * 0.63, hcol, hcol, true);
        draw_set_alpha(1);
    }

    // "You could go here" ring, pulsing, behind the badge.
    if (reach && !lost && !done) {
        var pu = 0.55 + 0.35 * dsin(t * 150);
        var rs = ICON * 1.5 * (1 + 0.04 * dsin(t * 150));
        draw_sprite_ext(Spr_Icon_Map_Option_Here, 0, n.px, n.py,
                        rs / sprite_get_width(Spr_Icon_Map_Option_Here),
                        rs / sprite_get_height(Spr_Icon_Map_Option_Here),
                        0, c_white, pu);
    }

    var spr = map_node_sprite(n, known);
    // Faint but still legible — the strike-through has to read as crossing an
    // icon, not floating on its own.
    var a   = lost ? 0.5 : (done ? 0.62 : 1);
    var tint = lost ? make_colour_rgb(170, 160, 152) : c_white;

    if (spr != -1) {
        draw_sprite_ext(spr, 0, n.px, n.py,
                        ICON / sprite_get_width(spr), ICON / sprite_get_height(spr),
                        0, tint, a);
    } else {
        // The on-ramp and the staging yard have no art in the set, so they're
        // built to match it: same dark rim, same warm face, same mid-brown
        // glyph weight as the printed badges beside them.
        var rr = ICON * 0.5;
        draw_set_alpha(a);
        draw_circle_colour(n.px, n.py, rr,        p.badge_rim,  p.badge_rim,  false);
        draw_circle_colour(n.px, n.py, rr * 0.79, p.badge_face, p.badge_face, false);
        draw_set_colour(p.badge_glyph);

        if (n.kind == "exit") {
            // Chevrons peeling off the page — a slip road.
            for (var k = -1; k <= 1; k++) {
                var kx = n.px - 8 + k * 8;
                draw_line_width(kx, n.py - 8, kx + 6, n.py,     4);
                draw_line_width(kx + 6, n.py, kx,     n.py + 8, 4);
            }
        } else {
            // The yard: a depot ring with a pin in it.
            draw_circle(n.px, n.py, rr * 0.46, true);
            draw_circle(n.px, n.py, rr * 0.46, true);
            draw_circle(n.px, n.py, rr * 0.17, false);
        }

        draw_set_alpha(1);
        draw_set_colour(c_white);
    }

    // Where you're parked.
    if (here) {
        var hs = ICON * 1.95;
        draw_sprite_ext(Spr_Icon_Map_You_are_Here, 0, n.px, n.py,
                        hs / sprite_get_width(Spr_Icon_Map_You_are_Here),
                        hs / sprite_get_height(Spr_Icon_Map_You_are_Here),
                        0, c_white, 1);
    }

    // Label under the badge.
    if (known) {
        draw_map_label(n.px, n.py + ICON * 0.66, map_node_title(n),
                       lost ? p.atlas_dim : p.atlas_ink);
    }

    if (lost) {
        draw_line_width_colour(n.px - ICON * 0.5, n.py, n.px + ICON * 0.5, n.py,
                               3, p.atlas_alert, p.atlas_alert);
    } else if (done) {
        draw_line_width_colour(n.px + 12, n.py - 15, n.px + 17, n.py - 10, 3, p.atlas_ink, p.atlas_ink);
        draw_line_width_colour(n.px + 17, n.py - 10, n.px + 25, n.py - 22, 3, p.atlas_ink, p.atlas_ink);
    }
}

// ---------------------------------------------------------------- readout
if (hover_node != -1 && ev == undefined) {
    var hn = m.nodes[hover_node];
    var can = map_can_travel(hover_node) && hover_node != r.node;

    var txt = map_node_title(hn);
    if (hover_node == r.node)               txt = "YOU ARE HERE";
    else if (!map_is_reachable(hover_node)) txt = "NO ROAD FROM HERE";
    else if (map_node_lost(hover_node))     txt = "CUT OFF";
    else {
        if (hn.kind == "shop") {
            // Say what's left on the shelf rather than "done" — the whole point
            // of a stop staying open is knowing whether it's worth the fuel.
            if (is_array(hn.stock)) {
                txt += (array_length(hn.stock) > 0)
                     ? "  ·  " + string(array_length(hn.stock)) + " ON THE SHELF"
                     : "  ·  SOLD OUT, PUMPS OPEN";
            }
        } else if (hn.resolved) {
            txt += "  ·  ALREADY DONE";
        }
        var hcost = hazard_fuel_cost(hn);
        if (r.fuel < hcost) txt += "  ·  NO FUEL: " + string(4 * (hcost - r.fuel)) + " HULL";
        else                txt += "  ·  " + string(hcost) + " FUEL";
        if (hn.hazard != "") {
            txt += "  ·  " + hazard(hn.hazard).name + ": " + hazard_effect_line(hn.hazard);
        }
    }

    draw_set_font(fnt_small);
    var tw = string_width(txt) + 16;
    var bx = clamp(hn.px - tw * 0.5, 34, W - tw - 34);
    var by = hn.py - ICON * 0.62 - 24;

    draw_set_alpha(0.88);
    draw_roundrect_colour(bx, by, bx + tw, by + 19, p.atlas_cream, p.atlas_cream, false);
    draw_set_alpha(1);
    draw_roundrect_colour(bx, by, bx + tw, by + 19, p.atlas_ink, p.atlas_ink, true);
    draw_label(bx + tw * 0.5, by + 9, txt, can ? p.atlas_live : p.atlas_dim, fa_center, fa_middle, fnt_small);
}

// ---------------------------------------------------------------- swatches
// The four coloured boxes at the top of the printed page are blanks; the value
// goes in the lower half of each, under the baked label.
var swatch_y = 74;
var swatch_x = [484, 608, 733, 934];
var vals = [string(r.scrap),
            string(r.fuel),
            string(ceil(r.car.hull)) + "/" + string(r.car.hull_max),
            string(car_drones(r.car))];

for (var i = 0; i < 4; i++) {
    draw_label(swatch_x[i], swatch_y, vals[i], p.atlas_ink, fa_center, fa_middle, fnt_term_big);
}
if (r.fuel <= 0) {
    draw_label(swatch_x[1], swatch_y + 22, "DRY", p.atlas_alert, fa_center, fa_middle, fnt_small);
}

// The masthead banner is printed reading "SECTOR 1 OF 3"; patch it when the
// run has moved on, in the banner's own colour so it reads as printed.
if (r.sector != 1) {
    draw_rectangle_colour(26, 74, 396, 100,
        make_colour_rgb(232, 106, 74), make_colour_rgb(236, 118, 78),
        make_colour_rgb(226,  96, 66), make_colour_rgb(230, 108, 72), false);
    draw_label(40, 87, "SECTOR " + string(r.sector) + " OF " + string(SECTOR_COUNT),
               make_colour_rgb(58, 30, 22), fa_left, fa_middle, fnt_term);
}

// Sector name and the latest log line live inside the printed border, top-left
// and bottom-left — the swatch row above has no free space.
draw_map_label(42, 128, string_upper(sector_name(r.sector)), p.atlas_ink, fa_left);
if (array_length(r.log) > 0) {
    draw_map_label(42, 654, r.log[array_length(r.log) - 1], p.atlas_road, fa_left);
}

// ------------------------------------------------------------- the rig
// Sits in the clear band between the masthead and the top row of stops, so
// it's reachable from anywhere on the atlas without covering a road.
if (ev == undefined) {
    draw_set_font(fnt_small);
    var rbx1 = 1004, rby1 = 126, rbx2 = 1248, rby2 = 162;
    if (ui_button(rbx1, rby1, rbx2, rby2, "RE-PACK THE RIG   (G)", true, p.atlas_live, fnt_small)) {
        garage_open(false, true);
    }
    if (ui_hover(rbx1, rby1, rbx2, rby2)) {
        ui_tooltip("THE RIG", "Move facilities around the chassis. You can do this anywhere on the atlas — it costs nothing and takes no time.");
    }
}

// ---------------------------------------------------------------- event
if (ev != undefined) {
    // A warm wash rather than a black scrim — the page is still paper, just
    // in shadow while you read the card on top of it.
    draw_set_alpha(0.62);
    draw_rectangle_colour(0, 0, W, H, p.shade, p.shade, p.shade, p.shade, false);
    draw_set_alpha(1);

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
