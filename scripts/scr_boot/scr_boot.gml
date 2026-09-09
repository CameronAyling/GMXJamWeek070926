/// scr_boot — one-time global setup.
///
/// Idempotent and called from the Create event of every screen controller, so
/// it doesn't matter which room the game starts in and there's no persistent
/// boot object to accidentally duplicate on returning to the title.

function game_init() {
    if (variable_global_exists("game_inited")) return;
    global.game_inited = true;

    // Fixed GUI space. Everything draws in Draw_GUI and hit-tests against
    // device_mouse_*_to_gui, so this is the one coordinate system that matters.
    // GameMaker starts every launch on the SAME seed so crashes reproduce.
    // For a roguelike that means an identical atlas, identical enemy loadouts
    // and identical events on every single run, so seed from the clock here.
    // Gametests re-fix the seed themselves with random_set_seed() on frame 0,
    // which keeps `gmx test` reproducible without costing real play its variety.
    randomise();

    display_set_gui_size(1280, 720);

    // Carried over from the gmx scaffold: scaled and rotated art shimmers
    // without filtered, mipmapped, anisotropic sampling.
    gpu_set_tex_filter(true);
    gpu_set_tex_mip_enable(mip_on);
    gpu_set_tex_mip_filter(tf_anisotropic);
    gpu_set_tex_max_aniso(16);

    draw_set_circle_precision(32);

    palette_init();
    facility_db_init();

    global.ui_mx = 0;
    global.ui_my = 0;
    global.ui_click = false;
    global.ui_rclick = false;
    global.ui_held = false;
    global.ui_release = false;
    global.ui_tip = "";
    global.ui_tip_title = "";

    global.pending_room = -1;
    global.pending_time = 0.35;
}

/// Frame time in seconds, clamped so an alt-tab hitch can't teleport the
/// combat sim forwards. Every real-time system multiplies by this.
function dt() {
    return min(delta_time / 1000000, 1 / 20);
}

/// True while a room change is queued or a fade is still playing. Room changes
/// are asynchronous — the outgoing screen keeps running its Step — so
/// controllers must stop accepting input, or you can travel twice or bank a
/// reward twice on the way out.
function transitioning() {
    if (variable_global_exists("pending_room") && global.pending_room != -1) return true;
    return (variable_global_exists("active_transition") && global.active_transition != -1);
}

/// Ask for a room change. ALWAYS use this instead of calling the transition
/// directly.
///
/// obj_transition captures the outgoing frame by calling surface_set_target()
/// in Pre-Draw and surface_reset_target() in Draw-GUI-End. Creating it from a
/// Draw event — which every immediate-mode button does — means Pre-Draw has
/// already run for that frame, so it resets a surface target that was never
/// set and the runtime aborts. Queuing here and starting the transition from
/// Step (see goto_flush) guarantees the object always exists before Pre-Draw.
function goto_room(_room, _time = 0.35) {
    if (transitioning()) return;
    global.pending_room = _room;
    global.pending_time = _time;
}

/// Start any queued room change. Called first thing in every controller's Step,
/// and the only place the transition is ever kicked off.
function goto_flush() {
    if (!variable_global_exists("pending_room") || global.pending_room == -1) return;
    var rm = global.pending_room;
    var tm = global.pending_time;
    global.pending_room = -1;
    ::transition_base::goto(rm, tm);
}
