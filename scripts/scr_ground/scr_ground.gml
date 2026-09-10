/// scr_ground — how the fight sits on the desert.
///
/// Two things are tuned together here, because they were the same problem: how
/// much of the photograph the UI is allowed to flatten, and how firmly the rigs
/// are planted on it.
///
/// What was wrong before: a flat wash of paper colour at 0.55 alpha covered the
/// whole photo — put there when the UI palette was still dark and never revised
/// once the game went to paper, so it was tan over tan and bleached the sand
/// out. And the shadow art is a solid mid-brown silhouette, which was being
/// drawn at full opacity offset down and right by the difference in canvas
/// size: a brown halo beside the van rather than a shadow under it.
///
/// The fix, in three parts: no wash at all, contrast bought at the edges with a
/// warm vignette instead; the shadow art inked down and made translucent; and a
/// soft contact patch under the whole vehicle, measured off the drawn sprite
/// rather than off the deck, so the bonnet is grounded too and not just the
/// back half.
///
/// Two heavier variants were tried and rejected — a light 0.18 haze (kept some
/// paper feel but put the glare back) and an overhead-sun version (planted hard
/// but the corners went dark and it lost the atmosphere).

function ground_style() {
    return {
        scrim:    0.00,   // flat wash over the photo. None: the edges do the work.
        vignette: 0.34,   // warm edge darkening, for UI contrast
        sh_dark:  0.80,   // how far the shadow art is tinted toward ink
        sh_a:     0.45,   // shadow opacity
        sh_off:   0.015,  // downward throw, as a fraction of the drawn height
        contact:  0.32,   // the patch that actually plants the vehicle
    };
}
