game_init();

show_briefing = false;
t = 0;

// Skyline silhouette, generated once so it doesn't crawl between frames.
skyline = [];
var sx = -40;
while (sx < 1340) {
    var w = irandom_range(40, 110);
    var h = irandom_range(30, 150);
    array_push(skyline, { px: sx, w: w, h: h, lit: irandom(3) });
    sx += w + irandom_range(4, 22);
}
