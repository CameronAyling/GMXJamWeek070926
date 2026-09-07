show_debug_message("Hello, gmx!");

// Texture smoothing: filtered, mipmapped, anisotropic sampling. Scaled or
// rotated art shimmers and pixelates without it. Disable only as a conscious
// choice, for crisp pixel art.
gpu_set_tex_filter(true);
gpu_set_tex_mip_enable(mip_on);
gpu_set_tex_mip_filter(tf_anisotropic);
gpu_set_tex_max_aniso(16);
