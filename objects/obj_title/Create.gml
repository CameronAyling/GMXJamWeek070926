game_init();

show_briefing = false;
t = 0;

// A sample route printed across the bottom of the cover, the way an atlas
// shows off what's inside. Generated once so it doesn't crawl between frames.
cover_route = [];
var rx = 74;
while (rx < 1250) {
    array_push(cover_route, { px: rx, py: 566 + irandom_range(-40, 40) });
    rx += irandom_range(118, 178);
}

// A handful of the route's stops get a real map badge — the same art the
// atlas screen uses, so the cover promises the thing you actually get.
cover_badges = [];
var kinds = [Spr_Icon_Map_Bandits, Spr_Icon_Map_Shop, Spr_Icon_Map_BOTS,
             Spr_Icon_Map_Unknown, Spr_Icon_Map_Ants, Spr_Icon_Map_CORPORATE_];
for (var i = 1; i < array_length(cover_route) - 1; i += 2) {
    array_push(cover_badges, { at: i, spr: kinds[(i div 2) mod array_length(kinds)] });
}
