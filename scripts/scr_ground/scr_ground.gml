/// scr_ground — how the fight sits on the desert.
///
/// How much of the photograph the UI is allowed to flatten. A flat wash of
/// paper colour at 0.55 alpha used to cover the whole photo — put there when
/// the UI palette was still dark and never revised once the game went to paper,
/// so it was tan over tan and bleached the sand out. There is no wash now;
/// contrast is bought at the edges with a warm vignette instead.
///
/// Two heavier variants were tried and rejected — a light 0.18 haze (kept some
/// paper feel but put the glare back) and an overhead-sun version (planted hard
/// but the corners went dark and it lost the atmosphere).
///
/// Vehicles cast nothing. The shadow silhouettes and the soft contact patch
/// that used to ground them are both gone.

function ground_style() {
    return {
        scrim:    0.00,   // flat wash over the photo. None: the edges do the work.
        vignette: 0.34,   // warm edge darkening, for UI contrast
        // Nothing is drawn under the vehicles. Both the shadow silhouettes and
        // the soft contact patch are gone: the rigs sit flat on the road.
    };
}
