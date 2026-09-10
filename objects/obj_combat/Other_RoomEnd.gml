// The particle system is non-persistent, so leaving the room frees it. Drop our
// handle rather than free it ourselves — a double free faults the runner.
vfx_forget();
