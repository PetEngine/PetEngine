//
// This file was auto-generated using the following command:
//
// jai build.jai - shaderc
//



shaderc_target_env :: enum s32 {
    vulkan        :: 0;
    opengl        :: 1;

    opengl_compat :: 2;

    webgpu        :: 3;

    default       :: 0;
}

shaderc_env_version :: enum s32 {
    vulkan_1_0 :: 4194304;
    vulkan_1_1 :: 4198400;
    vulkan_1_2 :: 4202496;
    vulkan_1_3 :: 4206592;
    vulkan_1_4 :: 4210688;

    opengl_4_5 :: 450;
    webgpu     :: 451;
}

// The known versions of SPIR-V.
shaderc_spirv_version :: enum s32 {
    _1_0 :: 65536;
    _1_1 :: 65792;
    _1_2 :: 66048;
    _1_3 :: 66304;
    _1_4 :: 66560;
    _1_5 :: 66816;
    _1_6 :: 67072;
}

// Indicate the status of a compilation.
shaderc_compilation_status :: enum s32 {
    success              :: 0;
    invalid_stage        :: 1;
    compilation_error    :: 2;
    internal_error       :: 3;
    null_result_object   :: 4;
    invalid_assembly     :: 5;
    validation_error     :: 6;
    transformation_error :: 7;
    configuration_error  :: 8;
}

// Source language kind.
shaderc_source_language :: enum s32 {
    glsl :: 0;
    hlsl :: 1;
}

shaderc_shader_kind :: enum s32 {
    vertex_shader                       :: 0;
    fragment_shader                     :: 1;
    compute_shader                      :: 2;
    geometry_shader                     :: 3;
    tess_control_shader                 :: 4;
    tess_evaluation_shader              :: 5;

    glsl_vertex_shader                  :: 0;
    glsl_fragment_shader                :: 1;
    glsl_compute_shader                 :: 2;
    glsl_geometry_shader                :: 3;
    glsl_tess_control_shader            :: 4;
    glsl_tess_evaluation_shader         :: 5;

    glsl_infer_from_source              :: 6;

    glsl_default_vertex_shader          :: 7;
    glsl_default_fragment_shader        :: 8;
    glsl_default_compute_shader         :: 9;
    glsl_default_geometry_shader        :: 10;
    glsl_default_tess_control_shader    :: 11;
    glsl_default_tess_evaluation_shader :: 12;
    spirv_assembly                      :: 13;
    raygen_shader                       :: 14;
    anyhit_shader                       :: 15;
    closesthit_shader                   :: 16;
    miss_shader                         :: 17;
    intersection_shader                 :: 18;
    callable_shader                     :: 19;
    glsl_raygen_shader                  :: 14;
    glsl_anyhit_shader                  :: 15;
    glsl_closesthit_shader              :: 16;
    glsl_miss_shader                    :: 17;
    glsl_intersection_shader            :: 18;
    glsl_callable_shader                :: 19;
    glsl_default_raygen_shader          :: 20;
    glsl_default_anyhit_shader          :: 21;
    glsl_default_closesthit_shader      :: 22;
    glsl_default_miss_shader            :: 23;
    glsl_default_intersection_shader    :: 24;
    glsl_default_callable_shader        :: 25;
    task_shader                         :: 26;
    mesh_shader                         :: 27;
    glsl_task_shader                    :: 26;
    glsl_mesh_shader                    :: 27;
    glsl_default_task_shader            :: 28;
    glsl_default_mesh_shader            :: 29;
}

shaderc_profile :: enum s32 {
    none          :: 0;

    core          :: 1;
    compatibility :: 2;
    es            :: 3;
}

// Optimization level.
shaderc_optimization_level :: enum s32 {
    zero        :: 0;
    size        :: 1;
    performance :: 2;
}

// Resource limits.
shaderc_limit :: enum s32 {
    max_lights                                    :: 0;
    max_clip_planes                               :: 1;
    max_texture_units                             :: 2;
    max_texture_coords                            :: 3;
    max_vertex_attribs                            :: 4;
    max_vertex_uniform_components                 :: 5;
    max_varying_floats                            :: 6;
    max_vertex_texture_image_units                :: 7;
    max_combined_texture_image_units              :: 8;
    max_texture_image_units                       :: 9;
    max_fragment_uniform_components               :: 10;
    max_draw_buffers                              :: 11;
    max_vertex_uniform_vectors                    :: 12;
    max_varying_vectors                           :: 13;
    max_fragment_uniform_vectors                  :: 14;
    max_vertex_output_vectors                     :: 15;
    max_fragment_input_vectors                    :: 16;
    min_program_texel_offset                      :: 17;
    max_program_texel_offset                      :: 18;
    max_clip_distances                            :: 19;
    max_compute_work_group_count_x                :: 20;
    max_compute_work_group_count_y                :: 21;
    max_compute_work_group_count_z                :: 22;
    max_compute_work_group_size_x                 :: 23;
    max_compute_work_group_size_y                 :: 24;
    max_compute_work_group_size_z                 :: 25;
    max_compute_uniform_components                :: 26;
    max_compute_texture_image_units               :: 27;
    max_compute_image_uniforms                    :: 28;
    max_compute_atomic_counters                   :: 29;
    max_compute_atomic_counter_buffers            :: 30;
    max_varying_components                        :: 31;
    max_vertex_output_components                  :: 32;
    max_geometry_input_components                 :: 33;
    max_geometry_output_components                :: 34;
    max_fragment_input_components                 :: 35;
    max_image_units                               :: 36;
    max_combined_image_units_and_fragment_outputs :: 37;
    max_combined_shader_output_resources          :: 38;
    max_image_samples                             :: 39;
    max_vertex_image_uniforms                     :: 40;
    max_tess_control_image_uniforms               :: 41;
    max_tess_evaluation_image_uniforms            :: 42;
    max_geometry_image_uniforms                   :: 43;
    max_fragment_image_uniforms                   :: 44;
    max_combined_image_uniforms                   :: 45;
    max_geometry_texture_image_units              :: 46;
    max_geometry_output_vertices                  :: 47;
    max_geometry_total_output_components          :: 48;
    max_geometry_uniform_components               :: 49;
    max_geometry_varying_components               :: 50;
    max_tess_control_input_components             :: 51;
    max_tess_control_output_components            :: 52;
    max_tess_control_texture_image_units          :: 53;
    max_tess_control_uniform_components           :: 54;
    max_tess_control_total_output_components      :: 55;
    max_tess_evaluation_input_components          :: 56;
    max_tess_evaluation_output_components         :: 57;
    max_tess_evaluation_texture_image_units       :: 58;
    max_tess_evaluation_uniform_components        :: 59;
    max_tess_patch_components                     :: 60;
    max_patch_vertices                            :: 61;
    max_tess_gen_level                            :: 62;
    max_viewports                                 :: 63;
    max_vertex_atomic_counters                    :: 64;
    max_tess_control_atomic_counters              :: 65;
    max_tess_evaluation_atomic_counters           :: 66;
    max_geometry_atomic_counters                  :: 67;
    max_fragment_atomic_counters                  :: 68;
    max_combined_atomic_counters                  :: 69;
    max_atomic_counter_bindings                   :: 70;
    max_vertex_atomic_counter_buffers             :: 71;
    max_tess_control_atomic_counter_buffers       :: 72;
    max_tess_evaluation_atomic_counter_buffers    :: 73;
    max_geometry_atomic_counter_buffers           :: 74;
    max_fragment_atomic_counter_buffers           :: 75;
    max_combined_atomic_counter_buffers           :: 76;
    max_atomic_counter_buffer_size                :: 77;
    max_transform_feedback_buffers                :: 78;
    max_transform_feedback_interleaved_components :: 79;
    max_cull_distances                            :: 80;
    max_combined_clip_and_cull_distances          :: 81;
    max_samples                                   :: 82;
    max_mesh_output_vertices_nv                   :: 83;
    max_mesh_output_primitives_nv                 :: 84;
    max_mesh_work_group_size_x_nv                 :: 85;
    max_mesh_work_group_size_y_nv                 :: 86;
    max_mesh_work_group_size_z_nv                 :: 87;
    max_task_work_group_size_x_nv                 :: 88;
    max_task_work_group_size_y_nv                 :: 89;
    max_task_work_group_size_z_nv                 :: 90;
    max_mesh_view_count_nv                        :: 91;
    max_mesh_output_vertices_ext                  :: 92;
    max_mesh_output_primitives_ext                :: 93;
    max_mesh_work_group_size_x_ext                :: 94;
    max_mesh_work_group_size_y_ext                :: 95;
    max_mesh_work_group_size_z_ext                :: 96;
    max_task_work_group_size_x_ext                :: 97;
    max_task_work_group_size_y_ext                :: 98;
    max_task_work_group_size_z_ext                :: 99;
    max_mesh_view_count_ext                       :: 100;
    max_dual_source_draw_buffers_ext              :: 101;
}

// Uniform resource kinds.
// In Vulkan, uniform resources are bound to the pipeline via descriptors
// with numbered bindings and sets.
shaderc_uniform_kind :: enum s32 {
    image                 :: 0;

    sampler               :: 1;

    texture               :: 2;

    buffer                :: 3;

    storage_buffer        :: 4;

    unordered_access_view :: 5;
}

shaderc_compiler :: struct {}
// An opaque handle to an object that manages all compiler state.
shaderc_compiler_t :: *shaderc_compiler;

// Returns a shaderc_compiler_t that can be used to compile modules.
// A return of NULL indicates that there was an error initializing the compiler.
// Any function operating on shaderc_compiler_t must offer the basic
// thread-safety guarantee.
// [http://herbsutter.com/2014/01/13/gotw-95-solution-thread-safety-and-synchronization/]
// That is: concurrent invocation of these functions on DIFFERENT objects needs
// no synchronization; concurrent invocation of these functions on the SAME
// object requires synchronization IF AND ONLY IF some of them take a non-const
// argument.
shaderc_compiler_initialize :: () -> shaderc_compiler_t #foreign shaderc;

// Releases the resources held by the shaderc_compiler_t.
// After this call it is invalid to make any future calls to functions
// involving this shaderc_compiler_t.
shaderc_compiler_release :: (unknown0: shaderc_compiler_t) -> void #foreign shaderc;

shaderc_compile_options :: struct {}
// An opaque handle to an object that manages options to a single compilation
// result.
shaderc_compile_options_t :: *shaderc_compile_options;

// Returns a default-initialized shaderc_compile_options_t that can be used
// to modify the functionality of a compiled module.
// A return of NULL indicates that there was an error initializing the options.
// Any function operating on shaderc_compile_options_t must offer the
// basic thread-safety guarantee.
shaderc_compile_options_initialize :: () -> shaderc_compile_options_t #foreign shaderc;

// Returns a copy of the given shaderc_compile_options_t.
// If NULL is passed as the parameter the call is the same as
// shaderc_compile_options_init.
shaderc_compile_options_clone :: (options: shaderc_compile_options_t) -> shaderc_compile_options_t #foreign shaderc;

// Releases the compilation options. It is invalid to use the given
// shaderc_compile_options_t object in any future calls. It is safe to pass
// NULL to this function, and doing such will have no effect.
shaderc_compile_options_release :: (options: shaderc_compile_options_t) -> void #foreign shaderc;

// Adds a predefined macro to the compilation options. This has the same
// effect as passing -Dname=value to the command-line compiler.  If value
// is NULL, it has the same effect as passing -Dname to the command-line
// compiler. If a macro definition with the same name has previously been
// added, the value is replaced with the new value. The macro name and
// value are passed in with char pointers, which point to their data, and
// the lengths of their data. The strings that the name and value pointers
// point to must remain valid for the duration of the call, but can be
// modified or deleted after this function has returned. In case of adding
// a valueless macro, the value argument should be a null pointer or the
// value_length should be 0u.
shaderc_compile_options_add_macro_definition :: (options: shaderc_compile_options_t, name: *u8, name_length: u64, value: *u8, value_length: u64) -> void #foreign shaderc;

// Sets the source language.  The default is GLSL.
shaderc_compile_options_set_source_language :: (options: shaderc_compile_options_t, lang: shaderc_source_language) -> void #foreign shaderc;

// Sets the compiler mode to generate debug information in the output.
shaderc_compile_options_set_generate_debug_info :: (options: shaderc_compile_options_t) -> void #foreign shaderc;

// Sets the compiler optimization level to the given level. Only the last one
// takes effect if multiple calls of this function exist.
shaderc_compile_options_set_optimization_level :: (options: shaderc_compile_options_t, level: shaderc_optimization_level) -> void #foreign shaderc;

// Forces the GLSL language version and profile to a given pair. The version
// number is the same as would appear in the #version annotation in the source.
// Version and profile specified here overrides the #version annotation in the
// source. Use profile: 'shaderc_profile_none' for GLSL versions that do not
// define profiles, e.g. versions below 150.
shaderc_compile_options_set_forced_version_profile :: (options: shaderc_compile_options_t, version: s32, profile: shaderc_profile) -> void #foreign shaderc;

// An include result.
shaderc_include_result :: struct {
    // The name of the source file.  The name should be fully resolved
    // in the sense that it should be a unique name in the context of the
    // includer.  For example, if the includer maps source names to files in
    // a filesystem, then this name should be the absolute path of the file.
    // For a failed inclusion, this string is empty.
    source_name:        *u8;
    source_name_length: u64;

    // The text contents of the source file in the normal case.
    // For a failed inclusion, this contains the error message.
    content:            *u8;
    content_length:     u64;

    // User data to be passed along with this request.
    user_data:          *void;
}

// The kinds of include requests.
shaderc_include_type :: enum s32 {
    relative :: 0;
    standard :: 1;
}

// An includer callback type for mapping an #include request to an include
// result.  The user_data parameter specifies the client context.  The
// requested_source parameter specifies the name of the source being requested.
// The type parameter specifies the kind of inclusion request being made.
// The requesting_source parameter specifies the name of the source containing
// the #include request.  The includer owns the result object and its contents,
// and both must remain valid until the release callback is called on the result
// object.
shaderc_include_resolve_fn :: #type (user_data: *void, requested_source: *u8, type: s32, requesting_source: *u8, include_depth: u64) -> *shaderc_include_result #c_call;

// An includer callback type for destroying an include result.
shaderc_include_result_release_fn :: #type (user_data: *void, include_result: *shaderc_include_result) -> void #c_call;

// Sets includer callback functions.
shaderc_compile_options_set_include_callbacks :: (options: shaderc_compile_options_t, resolver: shaderc_include_resolve_fn, result_releaser: shaderc_include_result_release_fn, user_data: *void) -> void #foreign shaderc;

// Sets the compiler mode to suppress warnings, overriding warnings-as-errors
// mode. When both suppress-warnings and warnings-as-errors modes are
// turned on, warning messages will be inhibited, and will not be emitted
// as error messages.
shaderc_compile_options_set_suppress_warnings :: (options: shaderc_compile_options_t) -> void #foreign shaderc;

// Sets the target shader environment, affecting which warnings or errors will
// be issued.  The version will be for distinguishing between different versions
// of the target environment.  The version value should be either 0 or
// a value listed in shaderc_env_version.  The 0 value maps to Vulkan 1.0 if
// |target| is Vulkan, and it maps to OpenGL 4.5 if |target| is OpenGL.
shaderc_compile_options_set_target_env :: (options: shaderc_compile_options_t, target: shaderc_target_env, version: u32) -> void #foreign shaderc;

// Sets the target SPIR-V version. The generated module will use this version
// of SPIR-V.  Each target environment determines what versions of SPIR-V
// it can consume.  Defaults to the highest version of SPIR-V 1.0 which is
// required to be supported by the target environment.  E.g. Default to SPIR-V
// 1.0 for Vulkan 1.0 and SPIR-V 1.3 for Vulkan 1.1.
shaderc_compile_options_set_target_spirv :: (options: shaderc_compile_options_t, version: shaderc_spirv_version) -> void #foreign shaderc;

// Sets the compiler mode to treat all warnings as errors. Note the
// suppress-warnings mode overrides this option, i.e. if both
// warning-as-errors and suppress-warnings modes are set, warnings will not
// be emitted as error messages.
shaderc_compile_options_set_warnings_as_errors :: (options: shaderc_compile_options_t) -> void #foreign shaderc;

// Sets a resource limit.
shaderc_compile_options_set_limit :: (options: shaderc_compile_options_t, limit: shaderc_limit, value: s32) -> void #foreign shaderc;

// Sets whether the compiler should automatically assign bindings to uniforms
// that aren't already explicitly bound in the shader source.
shaderc_compile_options_set_auto_bind_uniforms :: (options: shaderc_compile_options_t, auto_bind: bool) -> void #foreign shaderc;

// Sets whether the compiler should automatically remove sampler variables
// and convert image variables to combined image-sampler variables.
shaderc_compile_options_set_auto_combined_image_sampler :: (options: shaderc_compile_options_t, upgrade: bool) -> void #foreign shaderc;

// Sets whether the compiler should use HLSL IO mapping rules for bindings.
// Defaults to false.
shaderc_compile_options_set_hlsl_io_mapping :: (options: shaderc_compile_options_t, hlsl_iomap: bool) -> void #foreign shaderc;

// Sets whether the compiler should determine block member offsets using HLSL
// packing rules instead of standard GLSL rules.  Defaults to false.  Only
// affects GLSL compilation.  HLSL rules are always used when compiling HLSL.
shaderc_compile_options_set_hlsl_offsets :: (options: shaderc_compile_options_t, hlsl_offsets: bool) -> void #foreign shaderc;

// Sets the base binding number used for for a uniform resource type when
// automatically assigning bindings.  For GLSL compilation, sets the lowest
// automatically assigned number.  For HLSL compilation, the regsiter number
// assigned to the resource is added to this specified base.
shaderc_compile_options_set_binding_base :: (options: shaderc_compile_options_t, kind: shaderc_uniform_kind, base: u32) -> void #foreign shaderc;

// Like shaderc_compile_options_set_binding_base, but only takes effect when
// compiling a given shader stage.  The stage is assumed to be one of vertex,
// fragment, tessellation evaluation, tesselation control, geometry, or compute.
shaderc_compile_options_set_binding_base_for_stage :: (options: shaderc_compile_options_t, shader_kind: shaderc_shader_kind, kind: shaderc_uniform_kind, base: u32) -> void #foreign shaderc;

// Sets whether the compiler should preserve all bindings, even when those
// bindings are not used.
shaderc_compile_options_set_preserve_bindings :: (options: shaderc_compile_options_t, preserve_bindings: bool) -> void #foreign shaderc;

shaderc_compile_options_set_max_id_bound :: (options: shaderc_compile_options_t, max_id_bound: u32) -> void #foreign shaderc;

// Sets whether the compiler should automatically assign locations to
// uniform variables that don't have explicit locations in the shader source.
shaderc_compile_options_set_auto_map_locations :: (options: shaderc_compile_options_t, auto_map: bool) -> void #foreign shaderc;

// Sets a descriptor set and binding for an HLSL register in the given stage.
// This method keeps a copy of the string data.
shaderc_compile_options_set_hlsl_register_set_and_binding_for_stage :: (options: shaderc_compile_options_t, shader_kind: shaderc_shader_kind, reg: *u8, set: *u8, binding: *u8) -> void #foreign shaderc;

// Like shaderc_compile_options_set_hlsl_register_set_and_binding_for_stage,
// but affects all shader stages.
shaderc_compile_options_set_hlsl_register_set_and_binding :: (options: shaderc_compile_options_t, reg: *u8, set: *u8, binding: *u8) -> void #foreign shaderc;

// Sets whether the compiler should enable extension
// SPV_GOOGLE_hlsl_functionality1.
shaderc_compile_options_set_hlsl_functionality1 :: (options: shaderc_compile_options_t, enable: bool) -> void #foreign shaderc;

// Sets whether 16-bit types are supported in HLSL or not.
shaderc_compile_options_set_hlsl_16bit_types :: (options: shaderc_compile_options_t, enable: bool) -> void #foreign shaderc;

// Enables or disables relaxed Vulkan rules.
//
// This allows most OpenGL shaders to compile under Vulkan semantics.
shaderc_compile_options_set_vulkan_rules_relaxed :: (options: shaderc_compile_options_t, enable: bool) -> void #foreign shaderc;

// Sets whether the compiler should invert position.Y output in vertex shader.
shaderc_compile_options_set_invert_y :: (options: shaderc_compile_options_t, enable: bool) -> void #foreign shaderc;

// Sets whether the compiler generates code for max and min builtins which,
// if given a NaN operand, will return the other operand. Similarly, the clamp
// builtin will favour the non-NaN operands, as if clamp were implemented
// as a composition of max and min.
shaderc_compile_options_set_nan_clamp :: (options: shaderc_compile_options_t, enable: bool) -> void #foreign shaderc;

shaderc_compilation_result :: struct {}
// An opaque handle to the results of a call to any shaderc_compile_into_*()
// function.
shaderc_compilation_result_t :: *shaderc_compilation_result;

// Takes a GLSL source string and the associated shader kind, input file
// name, compiles it according to the given additional_options. If the shader
// kind is not set to a specified kind, but shaderc_glslc_infer_from_source,
// the compiler will try to deduce the shader kind from the source
// string and a failure in deducing will generate an error. Currently only
// #pragma annotation is supported. If the shader kind is set to one of the
// default shader kinds, the compiler will fall back to the default shader
// kind in case it failed to deduce the shader kind from source string.
// The input_file_name is a null-termintated string. It is used as a tag to
// identify the source string in cases like emitting error messages. It
// doesn't have to be a 'file name'.
// The source string will be compiled into SPIR-V binary and a
// shaderc_compilation_result will be returned to hold the results.
// The entry_point_name null-terminated string defines the name of the entry
// point to associate with this GLSL source. If the additional_options
// parameter is not null, then the compilation is modified by any options
// present.  May be safely called from multiple threads without explicit
// synchronization. If there was failure in allocating the compiler object,
// null will be returned.
shaderc_compile_into_spv :: (compiler: shaderc_compiler_t, source_text: *u8, source_text_size: u64, shader_kind: shaderc_shader_kind, input_file_name: *u8, entry_point_name: *u8, additional_options: shaderc_compile_options_t) -> shaderc_compilation_result_t #foreign shaderc;

// Like shaderc_compile_into_spv, but the result contains SPIR-V assembly text
// instead of a SPIR-V binary module.  The SPIR-V assembly syntax is as defined
// by the SPIRV-Tools open source project.
shaderc_compile_into_spv_assembly :: (compiler: shaderc_compiler_t, source_text: *u8, source_text_size: u64, shader_kind: shaderc_shader_kind, input_file_name: *u8, entry_point_name: *u8, additional_options: shaderc_compile_options_t) -> shaderc_compilation_result_t #foreign shaderc;

// Like shaderc_compile_into_spv, but the result contains preprocessed source
// code instead of a SPIR-V binary module
shaderc_compile_into_preprocessed_text :: (compiler: shaderc_compiler_t, source_text: *u8, source_text_size: u64, shader_kind: shaderc_shader_kind, input_file_name: *u8, entry_point_name: *u8, additional_options: shaderc_compile_options_t) -> shaderc_compilation_result_t #foreign shaderc;

// Takes an assembly string of the format defined in the SPIRV-Tools project
// (https://github.com/KhronosGroup/SPIRV-Tools/blob/master/syntax.md),
// assembles it into SPIR-V binary and a shaderc_compilation_result will be
// returned to hold the results.
// The assembling will pick options suitable for assembling specified in the
// additional_options parameter.
// May be safely called from multiple threads without explicit synchronization.
// If there was failure in allocating the compiler object, null will be
// returned.
shaderc_assemble_into_spv :: (compiler: shaderc_compiler_t, source_assembly: *u8, source_assembly_size: u64, additional_options: shaderc_compile_options_t) -> shaderc_compilation_result_t #foreign shaderc;

// Releases the resources held by the result object. It is invalid to use the
// result object for any further operations.
shaderc_result_release :: (result: shaderc_compilation_result_t) -> void #foreign shaderc;

// Returns the number of bytes of the compilation output data in a result
// object.
shaderc_result_get_length :: (result: shaderc_compilation_result_t) -> u64 #foreign shaderc;

// Returns the number of warnings generated during the compilation.
shaderc_result_get_num_warnings :: (result: shaderc_compilation_result_t) -> u64 #foreign shaderc;

// Returns the number of errors generated during the compilation.
shaderc_result_get_num_errors :: (result: shaderc_compilation_result_t) -> u64 #foreign shaderc;

// Returns the compilation status, indicating whether the compilation succeeded,
// or failed due to some reasons, like invalid shader stage or compilation
// errors.
shaderc_result_get_compilation_status :: (unknown0: shaderc_compilation_result_t) -> shaderc_compilation_status #foreign shaderc;

// Returns a pointer to the start of the compilation output data bytes, either
// SPIR-V binary or char string. When the source string is compiled into SPIR-V
// binary, this is guaranteed to be castable to a uint32_t*. If the result
// contains assembly text or preprocessed source text, the pointer will point to
// the resulting array of characters.
shaderc_result_get_bytes :: (result: shaderc_compilation_result_t) -> *u8 #foreign shaderc;

// Returns a null-terminated string that contains any error messages generated
// during the compilation.
shaderc_result_get_error_message :: (result: shaderc_compilation_result_t) -> *u8 #foreign shaderc;

// Provides the version & revision of the SPIR-V which will be produced
shaderc_get_spv_version :: (version: *u32, revision: *u32) -> void #foreign shaderc;

// Parses the version and profile from a given null-terminated string
// containing both version and profile, like: '450core'. Returns false if
// the string can not be parsed. Returns true when the parsing succeeds. The
// parsed version and profile are returned through arguments.
shaderc_parse_version_profile :: (str: *u8, version: *s32, profile: *shaderc_profile) -> bool #foreign shaderc;

#scope_file

#import "Basic"; // For assert

shaderc :: #library "bin/shaderc_shared";

#run {
    {
        info := type_info(shaderc_include_result);
        for info.members {
            if it.name == {
                case "source_name";
                    assert(it.offset_in_bytes == 0, "shaderc_include_result.source_name has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "shaderc_include_result.source_name has unexpected size % instead of 8", it.type.runtime_size);
                case "source_name_length";
                    assert(it.offset_in_bytes == 8, "shaderc_include_result.source_name_length has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "shaderc_include_result.source_name_length has unexpected size % instead of 8", it.type.runtime_size);
                case "content";
                    assert(it.offset_in_bytes == 16, "shaderc_include_result.content has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "shaderc_include_result.content has unexpected size % instead of 8", it.type.runtime_size);
                case "content_length";
                    assert(it.offset_in_bytes == 24, "shaderc_include_result.content_length has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "shaderc_include_result.content_length has unexpected size % instead of 8", it.type.runtime_size);
                case "user_data";
                    assert(it.offset_in_bytes == 32, "shaderc_include_result.user_data has unexpected offset % instead of 32", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "shaderc_include_result.user_data has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(shaderc_include_result) == 40, "shaderc_include_result has size % instead of 40", size_of(shaderc_include_result));
    }
}

