goto_flush();   // start any queued room change — must happen before any Draw event

ui_begin();
t += dt();

// ENTER or SPACE starts a run, same path as the NEW RUN button.
if (!transitioning() && (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space))) {
    run_new();
    goto_room(rm_garage);
}
