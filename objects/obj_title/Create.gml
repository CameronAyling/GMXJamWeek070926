game_init();

show_briefing = false;
t = 0;

// The cover is painted art (Spr_BG_Main_Menu) — masthead, route and imprint are
// all in the image, so this screen only has to lay the buttons on top of it.
//
// The keys are drawn 354x86 but the cover is a 1920x1080 painting squeezed into
// a 1280x720 GUI, so they ride the same 2/3 reduction. That keeps them the size
// they are against the scenery in the mockup rather than towering over it.
menu_scale = 2 / 3;
menu_w     = sprite_get_width(Spr_Button_Main_Menu_New_Run)  * menu_scale;
menu_h     = sprite_get_height(Spr_Button_Main_Menu_New_Run) * menu_scale;
menu_x     = 640 - menu_w * 0.5;
menu_y     = 293;
menu_gap   = 73;   // top-to-top, so the keys sit a shade apart

// One layout table, read by both Step (hit-testing, keyboard) and Draw, with
// x2/y2 baked in so the hit rects and the draws can never drift apart.
menu_items = [];
var faces = [[Spr_Button_Main_Menu_New_Run,  Spr_Button_Main_Menu_New_Run_Selected],
             [Spr_Button_Main_Menu_Briefing, Spr_Button_Main_Menu_Briefing_Selected],
             [Spr_Button_Main_Menu_Quit,     Spr_Button_Main_Menu_Quit_Selected]];
for (var i = 0; i < array_length(faces); i++) {
    array_push(menu_items, {
        spr : faces[i][0],
        sel : faces[i][1],
        x1  : menu_x,
        y1  : menu_y + i * menu_gap,
        x2  : menu_x + menu_w,
        y2  : menu_y + i * menu_gap + menu_h,
    });
}

// Keyboard focus. Starts on NEW RUN so ENTER still just starts a run.
menu_sel = 0;
