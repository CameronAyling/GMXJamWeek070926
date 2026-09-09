/// scr_map — the road atlas.
///
/// A sector is a left-to-right column graph drawn as a folded paper road map.
/// You burn a litre of fuel per hop, and the repo line creeps in from the left
/// eating columns behind you — the reason you can't sightsee the whole sector.

#macro MAP_X0        150
#macro MAP_X1        1120
#macro MAP_Y0        150
#macro MAP_Y1        600
#macro CONVOY_STEP   0.55    // columns the repo line advances per hop

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
    };
}

/// Build a fresh sector graph into global.run.map.
///
/// Roads are two-way: `links` holds both directions, so you can double back,
/// cut sideways within a column, or take the long way round. The graph is laid
/// out in columns anyway, because that's what makes the repo line legible —
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
                var roll = irandom(99);
                if      (roll < 55) kind = "fight";
                else if (roll < 75) kind = "event";
                else if (roll < 87) kind = "fuel";
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

/// A node is gone once the repo line has swept past its column.
function map_node_lost(_i) {
    return map_node(_i).col <= global.run.convoy;
}

/// Can you make this hop right now? Running dry doesn't strand you — it just
/// costs hull instead of fuel, so an empty tank is a slow bleed, not a dead end.
/// Roads are two-way, but the repo line is a wall: anything it has already
/// swept is gone, and doubling back into it isn't a choice you get to make.
function map_can_travel(_i) {
    if (!map_is_reachable(_i)) return false;
    if (map_node_lost(_i)) return false;
    return true;
}

/// Commit the hop: burn fuel, advance the repo line, mark the node visited.
/// Returns "caught" if the convoy overran you on arrival, else "".
function map_travel(_i) {
    var r = global.run;
    if (r.fuel > 0) {
        r.fuel -= 1;
    } else {
        run_damage_hull(4);
        run_log("Running on fumes — you tore 4 hull out of the rig to make that hop.");
    }
    r.node = _i;
    r.moves += 1;
    r.convoy += CONVOY_STEP;

    var n = map_node(_i);
    n.visited = true;

    if (n.col <= r.convoy) {
        run_log("The repo line rolled over you before the dust settled.");
        return "caught";
    }
    return "";
}

/// Convoy pixel x for drawing the sweep line.
function map_convoy_x() {
    var r = global.run;
    var cols = r.map.cols;
    var t = (r.convoy) / max(1, cols - 1);
    return lerp(MAP_X0, MAP_X1, t);
}

function map_node_title(_n) {
    switch (_n.kind) {
        case "start": return "STAGING YARD";
        case "exit":  return "ON-RAMP";
        case "shop":  return "TRUCK STOP";
        case "fuel":  return "FUEL DEPOT";
        case "event": return "WAYPOINT";
        case "fight": return string_upper(faction_name(_n.faction));
        default:      return "WAYPOINT";
    }
}
