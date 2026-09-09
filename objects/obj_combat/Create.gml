game_init();

// Fallback so the combat room is still playable if it's opened directly
// (running the project from this room rather than through the title).
if (!run_exists()) run_new();
if (!variable_global_exists("combat_ctx")) {
    global.combat_ctx = { faction: "bandits", elite: false, boss: false, diff: 1 };
}

combat_init();

hover_car = -2;     // -2 nothing, -1 player, >=0 enemy index
hover_fac = -1;
