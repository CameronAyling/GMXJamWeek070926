goto_flush();   // start any queued room change — must happen before any Draw event

ui_begin();
t += dt();

// All menu input lives here so Draw_GUI stays a pure paint of the cover art.
var n = array_length(menu_items);

// Pointer takes focus wherever it lands — mouse and keyboard drive the same
// highlight, so the painted "selected" key always means the same thing.
for (var i = 0; i < n; i++) {
    if (ui_hover(menu_items[i].x1, menu_items[i].y1, menu_items[i].x2, menu_items[i].y2)) menu_sel = i;
}

if (keyboard_check_pressed(vk_up)    || keyboard_check_pressed(ord("W"))) menu_sel = (menu_sel + n - 1) mod n;
if (keyboard_check_pressed(vk_down)  || keyboard_check_pressed(ord("S"))) menu_sel = (menu_sel + 1) mod n;

// Which item fired: a click on it, or ENTER/SPACE on the focused one.
var fired = -1;
for (var i = 0; i < n; i++) {
    if (ui_clicked(menu_items[i].x1, menu_items[i].y1, menu_items[i].x2, menu_items[i].y2)) fired = i;
}
if (!transitioning() && (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space))) fired = menu_sel;

switch (fired) {
    case 0:
        run_new();
        goto_room(rm_garage);
        break;
    case 1:
        show_briefing = !show_briefing;
        break;
    case 2:
        game_end();
        break;
}

if (show_briefing && keyboard_check_pressed(vk_escape)) show_briefing = false;
