goto_flush();   // start any queued room change — must happen before any Draw event

ui_begin();

var cb = global.cb;

// SPACE freezes the clock but not the interface — that's the whole point of
// real-time-with-pause.
if (keyboard_check_pressed(vk_space) && cb.over == "") cb.paused = !cb.paused;

// Always, even over and even paused — a frozen shake is a permanent vibration.
combat_shake_decay(dt());

if (cb.over == "" && !cb.paused) combat_update(dt());
else if (cb.over != "") cb.over_t += dt();
if (cb.over == "" && !cb.paused) {
    combat_update(dt());
    // Stepped by hand, so effects and particles freeze with the fight on pause.
    vfx_update(dt());
    vfx_ambient(dt());
} else if (cb.over != "") cb.over_t += dt();

// ---------------------------------------------------------------- hover
hover_car = -2;
hover_fac = -1;

var mx = ui_mx(), my = ui_my();

var lp = cb.layout_p;
var pf = car_fac_at_point(cb.player, lp.px, lp.py, lp.cs, mx, my);
if (pf != -1 || is_array(car_cell_at(cb.player, lp.px, lp.py, lp.cs, mx, my))) {
    hover_car = -1;
    hover_fac = pf;
}

for (var e = 0; e < array_length(cb.enemies); e++) {
    if (!combat_enemy_alive(e)) continue;
    var le = cb.layout_e[e];
    var ef = car_fac_at_point(cb.enemies[e], le.px, le.py, le.cs, mx, my);
    if (ef != -1 || is_array(car_cell_at(cb.enemies[e], le.px, le.py, le.cs, mx, my))) {
        hover_car = e;
        hover_fac = ef;
    }
}

// ---------------------------------------------------------------- clicks
if (cb.over == "") {
    if (hover_car >= 0 && hover_fac != -1) {
        // Aim at an enemy facility.
        if (global.ui_click) {
            global.ui_click = false;
            combat_set_target(hover_car, hover_fac);
        }
    } else if (hover_car == -1 && hover_fac != -1) {
        // Left click your own rig: dispatch or recall a repair drone.
        if (global.ui_click) {
            global.ui_click = false;
            combat_toggle_drone(hover_fac);
        }
        // Right click: cut or restore power.
        if (global.ui_rclick) {
            global.ui_rclick = false;
            combat_toggle_power(hover_fac);
        }
    }

    // Number keys select weapons, 0 clears the selection.
    var wlist = car_facs_of_cat(cb.player, "weapon");
    for (var i = 0; i < min(9, array_length(wlist)); i++) {
        if (keyboard_check_pressed(ord(string(i + 1)))) cb.sel_weapon = wlist[i];
    }
    if (keyboard_check_pressed(ord("0"))) cb.sel_weapon = -1;
    if (keyboard_check_pressed(vk_escape)) cb.sel_weapon = -1;

    // E takes the break-away, once the drive is up to speed.
    if (keyboard_check_pressed(ord("E"))) combat_try_escape();
}
