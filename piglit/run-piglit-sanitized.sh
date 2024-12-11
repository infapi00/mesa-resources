#!/bin/sh

# This script runs a sanitized subset of the piglit full suite. This
# removes slow tests, unstable tests, and memory consuming tests.
#
# This is tailored for embedded drivers, like v3d and panfrost, so it
# also do a skip of extensions that usually are not supported on those
# drivers. We noted that helped on the time required for the full run.

PIGLITSKIPPEDTESTS="-x arb_gpu_shader_fp64 -x arb_gpu_shader_int64 -x arb_gpu_shader5 -x arb_vertex_attrib_64bit -x arb_shader_image_load_store -x arb_shader_group_vote -x arb_shader_image_size -x  arb_shader_precision -x arb_shader_stencil_export -x arb_shader_storage_buffer_object -x arb_shader_subroutine -x arb_shader_texture_image_samples -x arb_shading_language_packing -x arb_sparse_buffer -x arb_tessellation_shader -x arb_texture_barrier -x arb_texture_cube_map_array -x arb_texture_gather -x arb_texture_query_lod -x ext_shader_framebuffer_fetch -x ext_shader_framebuffer_fetch_non_coherent -x amd_conservative_depth -x amd_depth_clamp_separate -x amd_vertex_shader_layer -x amd_vertex_shader_viewport_index -x arb_bindless_texture -x arb_blend_func_extended -x arb_shader_ballot -x arb_shader_clock -x arb_shader_draw_parameters -x arb_timer_query -x arb_transform_feedback_overflow_query -x arb_viewport_array -x egl_android_native_fence_sync -x tcs- -x tessellation -x \\\.tese -x \\\.tesc  -x \\\@tes -x \\\@tcs"
PIGLITUNSTABLETESTS="-x max-texture-size -x glx-multi-context-single-window -x arb_texture_multisample@large-float-texture-fp16 -x longprim"
PIGLITSLOWTESTS="-x tex3d-maxsize -x texture-env-combine -x glx-visuals-depth -x glx-visuals-stencil"

./piglit run -c -l verbose --timeout 90 --overwrite $PIGLITUNSTABLETESTS $PIGLITSLOWTESTS $PIGLITSKIPPEDTESTS all ../piglit_results

