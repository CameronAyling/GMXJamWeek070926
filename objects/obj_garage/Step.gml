goto_flush();   // start any queued room change — must happen before any Draw event

ui_begin();

if (msg_t > 0) msg_t -= dt();

var car = global.run.car;

// R rotates the held piece; ESC / right-click puts it back.
if (held != "") {
    if (keyboard_check_pressed(ord("R"))) held_rot = (held_rot + 1) mod 4;
    if (keyboard_check_pressed(vk_escape)) garage_stow();
}

// ---------------------------------------------------------------- the grid
var cell = car_cell_at(car, gx, gy, cs, ui_mx(), ui_my());
var over_grid = is_array(cell);

if (over_grid) {
    if (held != "") {
        // Drop the held piece.
        if (global.ui_click) {
            global.ui_click = false;
            var cells = shape_rotated(fac(held).cells, held_rot);
            if (car_can_place(car, cells, cell[0], cell[1])) {
                car_place(car, held, cell[0], cell[1], held_rot);
                held = "";
                held_rot = 0;
                held_from = -1;
            } else {
                garage_msg("It won't fit there.");
            }
        }
        if (global.ui_rclick) {
            global.ui_rclick = false;
            garage_stow();
        }
    } else {
        var fi = car_at(car, cell[0], cell[1]);
        if (fi != -1) {
            // Lift a facility off the car onto the cursor.
            if (global.ui_click) {
                global.ui_click = false;
                held = car.facs[fi].def;
                held_rot = car.facs[fi].rot;
                held_from = -1;
                car_remove(car, fi);
            }
            // Right click strips it straight to the inventory.
            if (global.ui_rclick) {
                global.ui_rclick = false;
                var def_id = car_remove(car, fi);
                if (def_id != "") array_push(global.run.inv, def_id);
            }
        }
    }
}

// Clicking off the grid while holding something stows it.
if (held != "" && !over_grid && global.ui_rclick) {
    global.ui_rclick = false;
    garage_stow();
}
