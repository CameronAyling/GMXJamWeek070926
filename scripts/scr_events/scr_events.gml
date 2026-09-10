/// scr_events — roadside vignettes.
///
/// Each choice's `act` runs the outcome and returns the line shown afterwards.
/// A choice may carry a `req` predicate; when it fails the option is visible but
/// locked, so the player learns what a sensor mast or a cargo rack would buy.

/// Is any facility of this family fitted and intact?
function has_family(_family) {
    var c = global.run.car;
    for (var i = 0; i < array_length(c.facs); i++) {
        if (c.facs[i].hp > 0 && fac(c.facs[i].def).family == _family) return true;
    }
    return false;
}

/// Put a facility straight onto the car if it fits, else into the trailer.
function grant_facility(_id) {
    var c = global.run.car;
    var spot = car_find_space(c, fac(_id).cells);
    if (is_array(spot) && car_power_demand(c) + fac(_id).power <= car_power_cap(c)) {
        car_place(c, _id, spot[0], spot[1], 0);
        return fac(_id).name + " bolted straight on.";
    }
    array_push(global.run.inv, _id);
    return fac(_id).name + " stowed in the trailer.";
}

function events_db() {
    return [
    {
        title: "TOLL GANTRY",
        body: "An automated gantry straddles the road, scanners still live decades after "
            + "the authority that built it dissolved. It wants forty scrap or it drops the barrier.",
        choices: [
            { label: "Pay the toll", hint: "-40 scrap",
              req: function() { return global.run.scrap >= 40; },
              req_text: "need 40 scrap",
              act: function() { run_add_scrap(-40); return "The barrier lifts. Somewhere, a ledger updates for nobody."; } },
            { label: "Ram the barrier", hint: "hull damage",
              act: function() { var d = irandom_range(4, 9); run_damage_hull(d); return "You take " + string(d) + " hull, and the gantry takes worse."; } },
            { label: "Spoof the transponder", hint: "needs a sensor mast",
              req: function() { return has_family("sen"); },
              req_text: "needs SENSOR MAST",
              act: function() { run_add_scrap(15); return "You echo an exemption code back at it. It even refunds you 15 scrap."; } },
        ],
    },
    {
        title: "JACKKNIFED HAULER",
        body: "A freight rig lies folded across both lanes, cab crushed, trailer intact. "
            + "The cargo doors are unlocked. That is either luck or bait.",
        choices: [
            { label: "Strip the trailer", hint: "scrap, maybe trouble",
              act: function() {
                  if (random(1) < 0.32) {
                      global.run.pending_fight = "bandits";
                      return "Bait. Engines start up behind you.";
                  }
                  var s = irandom_range(30, 55);
                  run_add_scrap(s);
                  return "Clean haul: " + string(s) + " scrap.";
              } },
            { label: "Siphon the tanks", hint: "+2 fuel",
              act: function() { run_add_fuel(2); return "Two litres of something that burns. Close enough."; } },
            { label: "Drive on", hint: "nothing ventured",
              act: function() { return "You keep both hands on the wheel and don't look."; } },
        ],
    },
    {
        title: "SIGNAL FROM THE VERGE",
        body: "A repeating distress loop, low power, six kilometres off the highway. "
            + "It's been running long enough that the voice on it has stopped sounding hopeful.",
        choices: [
            { label: "Detour and help", hint: "-1 fuel",
              act: function() {
                  run_add_fuel(-1);
                  if (random(1) < 0.62) return grant_facility(choose("rep_1", "plt_1", "srg_1", "scb_1"));
                  run_add_scrap(24);
                  return "Nobody left to help. You take the 24 scrap they no longer need.";
              } },
            { label: "Triangulate first", hint: "needs a sensor mast",
              req: function() { return has_family("sen"); },
              req_text: "needs SENSOR MAST",
              act: function() { return "The loop is a lure — three heat signatures waiting. You reroute and lose nothing."; } },
            { label: "Leave it looping", hint: "",
              act: function() { return "It's still transmitting in your mirrors. Then it isn't."; } },
        ],
    },
    {
        title: "CHOP SHOP UNDER THE OVERPASS",
        body: "Sodium lamps, a hand-painted sign, and a mechanic who doesn't ask where "
            + "anything came from. Cash only, and she means scrap.",
        choices: [
            { label: "Buy a part sight-unseen", hint: "-45 scrap",
              req: function() { return global.run.scrap >= 45; },
              req_text: "need 45 scrap",
              act: function() {
                  run_add_scrap(-45);
                  var pool = ["las_1", "tes_1", "flm_1", "acd_1", "oil_1", "hrp_1", "pdc_1", "col_1", "tgt_1", "shd_1"];
                  return grant_facility(pool[irandom(array_length(pool) - 1)]);
              } },
            { label: "Get the hull beaten out", hint: "-25 scrap, +8 hull",
              req: function() { return global.run.scrap >= 25; },
              req_text: "need 25 scrap",
              act: function() { run_add_scrap(-25); run_repair_hull(8); return "Panel beaters work fast when you don't ask for paint."; } },
            { label: "Move along", hint: "",
              act: function() { return "You don't like how many rigs are up on blocks out back."; } },
        ],
    },
    {
        title: "REFINERY FLARE STACK",
        body: "A working refinery, which shouldn't exist. A supervisor waves you into a bay "
            + "and offers a full tank in exchange for hauling a sealed crate two sectors on.",
        choices: [
            { label: "Take the job", hint: "+4 fuel, cargo risk",
              act: function() {
                  run_add_fuel(4);
                  if (random(1) < 0.4) { global.run.pending_fight = "corps"; return "Tank's full. So is the road behind you — somebody wants that crate back."; }
                  return "Tank's full and nobody has come looking. Yet.";
              } },
            { label: "Sell them scrap instead", hint: "+35 scrap",
              act: function() { run_add_scrap(35); return "They pay well for parts. That's never a good sign."; } },
            { label: "Don't stop", hint: "",
              act: function() { return "Nothing that still has power is friendly."; } },
        ],
    },
    {
        title: "THE CHOIR ON THE OPEN CHANNEL",
        body: "Every band carries the same layered hymn — twelve robot voices in something "
            + "close to harmony. They are broadcasting an invitation to pull over.",
        choices: [
            { label: "Pull over and listen", hint: "risky",
              act: function() {
                  if (random(1) < 0.5) { global.run.pending_fight = "robots"; return "The hymn resolves into a targeting tone."; }
                  return grant_facility("srg_1");
              } },
            { label: "Jam the channel", hint: "needs a sensor mast",
              req: function() { return has_family("sen"); },
              req_text: "needs SENSOR MAST",
              act: function() { run_add_scrap(20); return "You flood their band with static and lift 20 scrap of relay hardware on the way past."; } },
            { label: "Floor it", hint: "-1 fuel",
              act: function() { run_add_fuel(-1); return "You burn a litre getting clear of the broadcast radius."; } },
        ],
    },
    {
        title: "WEIGH STATION",
        body: "An automated weigh station with the barrier already up. Its diagnostic port "
            + "is exposed, and the terminal is still accepting maintenance sessions.",
        choices: [
            { label: "Pull the maintenance stock", hint: "",
              act: function() {
                  var s = irandom_range(18, 34);
                  run_add_scrap(s);
                  return "Spare parts crate: " + string(s) + " scrap.";
              } },
            { label: "Overweight declaration", hint: "needs a cargo rack",
              req: function() { return has_family("crg"); },
              req_text: "needs CARGO RACK",
              act: function() { run_add_scrap(48); run_add_fuel(1); return "You declare a load you aren't carrying and collect the haulage subsidy: 48 scrap and a litre."; } },
            { label: "Roll through", hint: "",
              act: function() { return "The scales read your weight to an empty office."; } },
        ],
    },
    {
        title: "SWARM CROSSING",
        body: "The road ahead is carpeted in chitin — thousands of them, migrating, "
            + "indifferent. The column will take an hour to pass. The schedule will not wait an hour.",
        choices: [
            { label: "Wait it out", hint: "lose ground on the schedule",
              act: function() { global.run.deadline += 0.7; return "They pass. An hour you will not get back."; } },
            { label: "Drive through them", hint: "hull damage, acid",
              act: function() {
                  var d = irandom_range(5, 11);
                  run_damage_hull(d);
                  return "Acid and shell. " + string(d) + " hull, and the paint is gone for good.";
              } },
            { label: "Detour on the service road", hint: "-2 fuel",
              req: function() { return global.run.fuel >= 2; },
              req_text: "need 2 fuel",
              act: function() { run_add_fuel(-2); return "Longer, rougher, and entirely uneventful."; } },
        ],
    },
    {
        title: "VANTAGE MUTUAL FIELD OFFICE",
        body: "A prefab office in the middle of nothing, lit and staffed. An adjuster steps "
            + "out with a tablet and asks, politely, whether you'd like to restructure.",
        choices: [
            { label: "Sign the restructure", hint: "+70 scrap, lose ground on the schedule",
              act: function() {
                  run_add_scrap(70);
                  global.run.deadline += 0.5;
                  return "Seventy scrap up front, and a signature that quietly rewrites your delivery window in their favour.";
              } },
            { label: "Decline politely", hint: "",
              act: function() { return "She smiles, notes something, and goes back inside."; } },
            { label: "Take the office apart", hint: "starts a fight",
              act: function() { global.run.pending_fight = "corps"; return "The prefab has a garage. The garage has an adjuster unit in it."; } },
        ],
    },
    {
        title: "FUEL CACHE, UNMARKED",
        body: "Drums stacked behind a collapsed billboard, tarped and strapped. "
            + "Somebody's reserve. Somebody who is not here right now.",
        choices: [
            { label: "Take all of it", hint: "+3 fuel, risk",
              act: function() {
                  run_add_fuel(3);
                  if (random(1) < 0.3) { global.run.pending_fight = "bandits"; return "Three litres, and the owners came back."; }
                  return "Three litres richer and nobody the wiser.";
              } },
            { label: "Take one and leave the rest", hint: "+1 fuel",
              act: function() { run_add_fuel(1); return "One drum. Road etiquette still counts for something."; } },
            { label: "Rig it and move on", hint: "+20 scrap",
              act: function() { run_add_scrap(20); return "You strip the strapping and the fittings for 20 scrap and leave the fuel."; } },
        ],
    },
    {
        title: "HITCHHIKER",
        body: "A figure on the hard shoulder with a toolbox and no vehicle. They claim to be "
            + "a mechanic. The toolbox looks real, at least.",
        choices: [
            { label: "Let them ride", hint: "repairs, maybe",
              act: function() {
                  if (random(1) < 0.72) {
                      var c = global.run.car;
                      var fixed = 0;
                      for (var i = 0; i < array_length(c.facs); i++) {
                          if (c.facs[i].hp <= 0) { c.facs[i].hp = c.facs[i].hp_max; fixed += 1; }
                          else if (c.facs[i].hp < c.facs[i].hp_max) { c.facs[i].hp = c.facs[i].hp_max; fixed += 1; }
                      }
                      run_repair_hull(6);
                      return (fixed > 0)
                          ? "They work the whole way. " + string(fixed) + " facilities back to spec, and 6 hull."
                          : "Nothing to fix, so they patch 6 hull and tell you about the road ahead.";
                  }
                  var s = min(global.run.scrap, irandom_range(20, 40));
                  run_add_scrap(-s);
                  return "You wake at the next stop with " + string(s) + " scrap missing and the door open.";
              } },
            { label: "Buy the toolbox", hint: "-30 scrap",
              req: function() { return global.run.scrap >= 30; },
              req_text: "need 30 scrap",
              act: function() { run_add_scrap(-30); return grant_facility("rep_1"); } },
            { label: "Drive past", hint: "",
              act: function() { return "In the mirror they don't even lower their arm."; } },
        ],
    },
    {
        title: "STORM FRONT",
        body: "A wall of ochre dust across the whole horizon, shot through with the "
            + "static of something industrial burning inside it.",
        choices: [
            { label: "Drive into it", hint: "hull damage, gain on the schedule",
              act: function() {
                  var d = irandom_range(3, 8);
                  run_damage_hull(d);
                  global.run.deadline -= 0.8;
                  return "Grit strips " + string(d) + " hull off you — but you come out the far side ahead of where you went in.";
              } },
            { label: "Shelter under an overpass", hint: "lose ground on the schedule",
              act: function() { global.run.deadline += 0.55; return "You sit it out. Tuesday does not."; } },
            { label: "Skirt the edge", hint: "-1 fuel",
              act: function() { run_add_fuel(-1); return "A litre spent going the long way round. Worth it."; } },
        ],
    },
    {
        title: "DEAD ROBOT, STILL WARM",
        body: "A Choir unit off the shoulder, chassis split, core still ticking over. "
            + "Its weapon mounts are intact and nothing is guarding it.",
        choices: [
            { label: "Cut the mounts free", hint: "",
              act: function() { return grant_facility(choose("las_1", "tes_1", "las_2")); } },
            { label: "Pull the core", hint: "risky, big payoff",
              act: function() {
                  if (random(1) < 0.35) { run_damage_hull(10); return "It discharges into your arms. 10 hull gone and your ears ringing."; }
                  return grant_facility("reac_2");
              } },
            { label: "Strip it for scrap", hint: "+40 scrap",
              act: function() { run_add_scrap(40); return "Forty scrap of chrome. It sings the whole time you're cutting."; } },
        ],
    },
    {
        title: "THE LAST DINER",
        body: "Neon in the window, one truck in the lot, and a handwritten sheet of road "
            + "conditions taped to the door — updated today.",
        choices: [
            { label: "Read the board and eat", hint: "-15 scrap",
              req: function() { return global.run.scrap >= 15; },
              req_text: "need 15 scrap",
              act: function() {
                  run_add_scrap(-15);
                  global.run.deadline -= 0.6;
                  return "Back roads nobody has mapped. You claw back hours you had already written off.";
              } },
            { label: "Trade road news", hint: "+1 fuel",
              act: function() { run_add_fuel(1); return "The other driver swaps you a litre for what you've seen. Fair deal."; } },
            { label: "Sleep in the cab", hint: "+5 hull, lose ground on the schedule",
              act: function() { run_repair_hull(5); global.run.deadline += 0.45; return "Four hours. You needed them. The delivery window did not care."; } },
        ],
    },
    ];
}

/// A random event, avoiding an immediate repeat of the last one.
function event_pick() {
    var db = events_db();
    var last = variable_global_exists("last_event") ? global.last_event : -1;
    var i = irandom(array_length(db) - 1);
    if (i == last && array_length(db) > 1) i = (i + 1) mod array_length(db);
    global.last_event = i;
    return db[i];
}
