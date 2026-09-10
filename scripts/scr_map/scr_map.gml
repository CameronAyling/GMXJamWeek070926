/// scr_map — the road atlas.
///
/// A sector is a left-to-right column graph drawn as a folded paper road map.
/// You burn a litre of fuel per hop, and the dead-line creeps in from the left
/// eating columns behind you — the reason you can't sightsee the whole sector.

// Node bounds, kept inside the printed border of Spr_Map_01_Base with enough
// margin for a 44px badge plus its label underneath.
#macro MAP_X0        112
#macro MAP_X1        1168
#macro MAP_Y0        186
#macro MAP_Y1        628
#macro DEADLINE_STEP   0.55    // columns the dead-line advances per hop
#macro HAZARD_COVER    0.40    // most of a sector that may sit inside a hazard

/// Pick a faction for a fight node, weighted by how deep the run is.
function map_pick_faction(_sector) {
    // The road changes hands as you go. The Rust Kings own the near end and are
    // gone by the far one; the Chitin are the reverse. Sector 2 is where the two
    // territories overlap and you can meet anything.
    var w;
    switch (_sector) {
        case 1:  w = [["bandits", 60], ["robots", 26], ["insects",  0], ["corps", 14]]; break;
        case 2:  w = [["bandits", 24], ["robots", 30], ["insects", 24], ["corps", 22]]; break;
        default: w = [["bandits",  0], ["robots", 26], ["insects", 38], ["corps", 36]]; break;
    }
    var total = 0;
    for (var i = 0; i < array_length(w); i++) total += w[i][1];
    var roll = irandom(total - 1);
    for (var i = 0; i < array_length(w); i++) {
        roll -= w[i][1];
        if (roll < 0) return w[i][0];
    }
    return "bandits";
}

function map_node_new(_col, _row, _px, _py, _kind) {
    return {
        col: _col, row: _row,
        px: _px, py: _py,
        kind: _kind,
        faction: "",
        links: [],
        visited: false,
        resolved: false,     // its encounter has been played out
        label: "",
        hazard: "",          // scr_hazards id, or "" for clear country
        stock: undefined,    // a truck stop's shelves, rolled on first arrival
    };
}

/// Build a fresh sector graph into global.run.map.
///
/// Roads are two-way: `links` holds both directions, so you can double back,
/// cut sideways within a column, or take the long way round. The graph is laid
/// out in columns anyway, because that is what makes the dead-line legible —
/// going backwards means driving towards it.
function map_generate() {
    var r = global.run;
    var cols = 7;
    var nodes = [];
    var col_members = [];

    for (var c = 0; c < cols; c++) {
        var count;
        if (c == 0 || c == cols - 1) count = 1;
        else count = irandom_range(2, 4);

        var members = [];
        for (var i = 0; i < count; i++) {
            var tx = (cols == 1) ? 0.5 : (c / (cols - 1));
            var px = lerp(MAP_X0, MAP_X1, tx) + irandom_range(-16, 16);

            var jit = (count >= 4) ? 15 : 26;
            var ty = (count == 1) ? 0.5 : (i / (count - 1));
            var py = lerp(MAP_Y0 + 40, MAP_Y1 - 40, ty) + irandom_range(-jit, jit);
            if (count == 1) py = (MAP_Y0 + MAP_Y1) * 0.5 + irandom_range(-20, 20);

            var kind;
            if (c == 0) kind = "start";
            else if (c == cols - 1) kind = "exit";
            else {
                // No fuel depots — the tank is topped up at truck stops and by
                // roadside events, so the share they held goes to both.
                var roll = irandom(99);
                if      (roll < 52) kind = "fight";
                else if (roll < 82) kind = "event";
                else                kind = "shop";
            }

            var n = map_node_new(c, i, px, py, kind);
            if (kind == "fight") n.faction = map_pick_faction(r.sector);
            n.label = "RT " + string(irandom_range(2, 99));

            array_push(nodes, n);
            array_push(members, array_length(nodes) - 1);
        }
        array_push(col_members, members);
    }

    // Guarantee one truck stop per sector — you must be able to spend scrap.
    var has_shop = false;
    for (var i = 0; i < array_length(nodes); i++) if (nodes[i].kind == "shop") has_shop = true;
    if (!has_shop) {
        var mid = col_members[irandom_range(2, cols - 3)];
        var pick = mid[irandom(array_length(mid) - 1)];
        nodes[pick].kind = "shop";
        nodes[pick].faction = "";
    }

    // --- hazard regions ----------------------------------------------------
    // Bad country comes in patches, so a hazard is an area of the page that
    // happens to contain some stops rather than a label pinned to one. Two
    // rules keep it from taking over: the yard and the on-ramp are always in
    // clear air, and no more than HAZARD_COVER of the sector can be inside a
    // region, so there is always a clean way through to route for.
    var regions = [];
    var want_regions = 1 + irandom(1) + ((r.sector >= 3) ? 1 : 0);
    var cover_cap = max(1, floor(array_length(nodes) * HAZARD_COVER));
    var covered = 0;

    for (var attempt = 0; attempt < 40 && array_length(regions) < want_regions; attempt++) {
        // Seed on a node so a region always has something in it, then drift the
        // centre off that node so the shape doesn't look pinned.
        var seed_i = irandom(array_length(nodes) - 1);
        if (nodes[seed_i].kind == "start" || nodes[seed_i].kind == "exit") continue;
        if (nodes[seed_i].hazard != "") continue;

        var hid = hazard_pick_any();

        // Drift the centre off the seed node so the shape doesn't look pinned,
        // and most of the time shove it toward the nearest edge of the sheet as
        // well. Weather doesn't stop at the border of a printed page, and a
        // region that runs off it reads as country continuing past the map
        // rather than a blob that happens to fit. Anything pushed so far out
        // that it stops covering a stop is thrown away by the checks below.
        var hcx = nodes[seed_i].px + random_range(-40, 40);
        var hcy = nodes[seed_i].py + random_range(-30, 30);
        var hbase = random_range(124, 176);

        if (irandom(99) < 62) {
            var mid_y = (MAP_Y0 + MAP_Y1) * 0.5;
            var shove = hbase * random_range(0.40, 0.85);
            if (hcy < mid_y) hcy -= shove; else hcy += shove;
            // Near the ends of the run, let it bleed sideways instead.
            if (hcx < MAP_X0 + 170)      hcx -= shove * 0.7;
            else if (hcx > MAP_X1 - 170) hcx += shove * 0.7;
        }

        var reg = hazard_region_new(hid, hcx, hcy, hbase);

        // Who would this cover, and is that allowed?
        var inside = [];
        var ok = true;
        var bites = false;
        for (var i = 0; i < array_length(nodes) && ok; i++) {
            if (!hazard_region_contains(reg, nodes[i].px, nodes[i].py)) continue;
            // Never swallow the endpoints, and never double up on a node that
            // is already inside another region.
            if (nodes[i].kind == "start" || nodes[i].kind == "exit") ok = false;
            else if (nodes[i].hazard != "") ok = false;
            else {
                array_push(inside, i);
                if (!hazard(hid).combat || nodes[i].kind == "fight") bites = true;
            }
        }

        // A region has to contain something, has to actually do something to at
        // least one of those stops, and has to fit under the cover cap.
        if (!ok || !bites) continue;
        if (array_length(inside) == 0) continue;
        if (covered + array_length(inside) > cover_cap) continue;

        for (var i = 0; i < array_length(inside); i++) nodes[inside[i]].hazard = hid;
        covered += array_length(inside);
        array_push(regions, reg);
    }

    // --- edges -------------------------------------------------------------
    // Every road is two-way: both endpoints get the other in `links`, and the
    // edge is recorded once for drawing.
    var edges = [];
    var add_edge = function(_edges, _nodes, _a, _b) {
        if (_a == _b) return;
        for (var i = 0; i < array_length(_edges); i++) {
            var e = _edges[i];
            if ((e.a == _a && e.b == _b) || (e.a == _b && e.b == _a)) return;
        }
        var same_col = (_nodes[_a].col == _nodes[_b].col);
        array_push(_edges, {
            a: _a, b: _b,
            // Lateral roads bow sideways; cross-column roads bow vertically.
            ox: same_col ? (choose(-1, 1) * random_range(20, 38)) : 0,
            oy: same_col ? 0 : random_range(-22, 22),
        });
        array_push(_nodes[_a].links, _b);
        array_push(_nodes[_b].links, _a);
    };

    for (var c = 0; c < cols - 1; c++) {
        var here = col_members[c];
        var next = col_members[c + 1];

        // Every node needs a way forward.
        for (var i = 0; i < array_length(here); i++) {
            var a = here[i];
            var best = next[0], best_d = 99999;
            for (var j = 0; j < array_length(next); j++) {
                var d = abs(nodes[next[j]].py - nodes[a].py) + irandom(70);
                if (d < best_d) { best_d = d; best = next[j]; }
            }
            add_edge(edges, nodes, a, best);
        }

        // Every node needs a way in, or it's unreachable from the start.
        for (var j = 0; j < array_length(next); j++) {
            var b = next[j];
            var incoming = false;
            for (var i = 0; i < array_length(here); i++) {
                var links = nodes[here[i]].links;
                for (var k = 0; k < array_length(links); k++) if (links[k] == b) incoming = true;
            }
            if (!incoming) {
                var best2 = here[0], bd = 99999;
                for (var i = 0; i < array_length(here); i++) {
                    var d2 = abs(nodes[here[i]].py - nodes[b].py);
                    if (d2 < bd) { bd = d2; best2 = here[i]; }
                }
                add_edge(edges, nodes, best2, b);
            }
        }

        // Extra branches so routes are a choice rather than a corridor.
        var extra = irandom_range(1, 2);
        for (var e = 0; e < extra; e++) {
            var a2 = here[irandom(array_length(here) - 1)];
            var b2 = next[irandom(array_length(next) - 1)];
            add_edge(edges, nodes, a2, b2);
        }
    }

    // Lateral roads: link vertically neighbouring towns inside a column, so you
    // can slide up and down a column instead of only crossing it.
    for (var c = 1; c < cols - 1; c++) {
        var mem = col_members[c];
        for (var i = 0; i < array_length(mem) - 1; i++) {
            if (random(1) < 0.55) add_edge(edges, nodes, mem[i], mem[i + 1]);
        }
    }

    // --- paper decoration, baked once so it doesn't shimmer per frame -------
    var stains = [];
    for (var i = 0; i < 3; i++) {
        array_push(stains, {
            px: irandom_range(120, 1160), py: irandom_range(130, 620),
            r: irandom_range(26, 54),
        });
    }
    var blobs = [];   // faint "urban area" patches
    for (var i = 0; i < 7; i++) {
        array_push(blobs, {
            px: irandom_range(140, 1140), py: irandom_range(140, 610),
            rx: irandom_range(40, 110), ry: irandom_range(26, 70),
        });
    }

    r.map = {
        cols: cols,
        nodes: nodes,
        edges: edges,
        col_members: col_members,
        hazards: regions,
        stains: stains,
        blobs: blobs,
        crease: irandom_range(520, 760),
    };
    r.node = 0;
    nodes[0].visited = true;
    nodes[0].resolved = true;
}

function map_node(_i) { return global.run.map.nodes[_i]; }

function map_current() { return map_node(global.run.node); }

/// Nodes reachable in one hop from where you are.
function map_reachable() {
    return map_current().links;
}

function map_is_reachable(_i) {
    var l = map_reachable();
    for (var k = 0; k < array_length(l); k++) if (l[k] == _i) return true;
    return false;
}

/// A node is gone once the dead-line has swept past its column.
function map_node_lost(_i) {
    return map_node(_i).col <= global.run.deadline;
}

/// Can you make this hop right now? Running dry doesn't strand you — it just
/// costs hull instead of fuel, so an empty tank is a slow bleed, not a dead end.
/// Roads are two-way, but the dead-line is a wall: anything it has already
/// swept is gone, and doubling back into it isn't a choice you get to make.
function map_can_travel(_i) {
    if (!map_is_reachable(_i)) return false;
    if (map_node_lost(_i)) return false;
    return true;
}

/// Commit the hop: burn fuel, advance the dead-line, mark the node visited.
/// Returns "caught" if the dead-line overran you on arrival, else "".
function map_travel(_i) {
    var r = global.run;

    // Rough country charges by the litre, so pay it a litre at a time and take
    // the fumes penalty for each one you haven't got.
    var cost = hazard_fuel_cost(map_node(_i));
    var dry  = 0;
    for (var k = 0; k < cost; k++) {
        if (r.fuel > 0) r.fuel -= 1;
        else            dry += 1;
    }
    if (dry > 0) {
        run_damage_hull(4 * dry);
        run_log("Running on fumes — you tore " + string(4 * dry) + " hull out of the rig to make that hop.");
    } else if (cost > 1) {
        run_log("Broken ground the whole way. That crossing cost " + string(cost) + " litres.");
    }

    r.node = _i;
    r.moves += 1;
    r.deadline += DEADLINE_STEP;

    var n = map_node(_i);
    n.visited = true;

    if (n.col <= r.deadline) {
        run_log("The dead-line swept past you before the dust settled. You are officially late.");
        return "caught";
    }
    return "";
}

/// Dead-line pixel x for drawing the sweep.
function map_deadline_x() {
    var r = global.run;
    var cols = r.map.cols;
    var t = (r.deadline) / max(1, cols - 1);
    return lerp(MAP_X0, MAP_X1, t);
}

/// Badge art for a node, or -1 when there's no sprite for that kind and it
/// gets drawn by hand instead (fuel, on-ramp, the staging yard).
function map_node_sprite(_n, _known) {
    if (!_known) return Spr_Icon_Map_Unknown;

    switch (_n.kind) {
        case "shop":  return Spr_Icon_Map_Shop;
        case "event": return Spr_Icon_Map_Unknown;   // a waypoint IS an unknown
        case "fight":
            switch (_n.faction) {
                case "bandits": return Spr_Icon_Map_Bandits;
                case "robots":  return Spr_Icon_Map_BOTS;
                case "corps":   return Spr_Icon_Map_CORPORATE_;
                case "insects": return Spr_Icon_Map_Ants;
            }
            return Spr_Icon_Map_Unknown;
    }
    return -1;
}

function map_node_title(_n) {
    switch (_n.kind) {
        case "start": return "STAGING YARD";
        case "exit":  return "ON-RAMP";
        case "shop":  return "TRUCK STOP";
        case "event": return "WAYPOINT";
        case "fight": return string_upper(faction_name(_n.faction));
        default:      return "WAYPOINT";
    }
}
