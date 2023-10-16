// Copyright 2015 The Shaderc Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Source language kind.
shaderc_source_language :: enum s32 {
    shaderc_source_language_glsl;
    shaderc_source_language_hlsl;
}

shaderc_shader_kind :: enum s32 {
    // Forced shader kinds. These shader kinds force the compiler to compile the
    // source code as the specified kind of shader.
    shaderc_vertex_shader;
    shaderc_fragment_shader;
    shaderc_compute_shader;
    shaderc_geometry_shader;
    shaderc_tess_control_shader;
    shaderc_tess_evaluation_shader;

    shaderc_glsl_vertex_shader :: shaderc_vertex_shader;
    shaderc_glsl_fragment_shader :: shaderc_fragment_shader;
    shaderc_glsl_compute_shader :: shaderc_compute_shader;
    shaderc_glsl_geometry_shader :: shaderc_geometry_shader;
    shaderc_glsl_tess_control_shader :: shaderc_tess_control_shader;
    shaderc_glsl_tess_evaluation_shader :: shaderc_tess_evaluation_shader;

    // Deduce the shader kind from #pragma annotation in the source code. Compiler
    // will emit error if #pragma annotation is not found.
    shaderc_glsl_infer_from_source;
    // Default shader kinds. Compiler will fall back to compile the source code as
    // the specified kind of shader when #pragma annotation is not found in the
    // source code.
    shaderc_glsl_default_vertex_shader;
    shaderc_glsl_default_fragment_shader;
    shaderc_glsl_default_compute_shader;
    shaderc_glsl_default_geometry_shader;
    shaderc_glsl_default_tess_control_shader;
    shaderc_glsl_default_tess_evaluation_shader;
    shaderc_spirv_assembly;
    shaderc_raygen_shader;
    shaderc_anyhit_shader;
    shaderc_closesthit_shader;
    shaderc_miss_shader;
    shaderc_intersection_shader;
    shaderc_callable_shader;
    shaderc_glsl_raygen_shader :: shaderc_raygen_shader;
    shaderc_glsl_anyhit_shader :: shaderc_anyhit_shader;
    shaderc_glsl_closesthit_shader :: shaderc_closesthit_shader;
    shaderc_glsl_miss_shader :: shaderc_miss_shader;
    shaderc_glsl_intersection_shader :: shaderc_intersection_shader;
    shaderc_glsl_callable_shader :: shaderc_callable_shader;
    shaderc_glsl_default_raygen_shader;
    shaderc_glsl_default_anyhit_shader;
    shaderc_glsl_default_closesthit_shader;
    shaderc_glsl_default_miss_shader;
    shaderc_glsl_default_intersection_shader;
    shaderc_glsl_default_callable_shader;
    shaderc_task_shader;
    shaderc_mesh_shader;
    shaderc_glsl_task_shader :: shaderc_task_shader;
    shaderc_glsl_mesh_shader :: shaderc_mesh_shader;
    shaderc_glsl_default_task_shader;
    shaderc_glsl_default_mesh_shader;
}

shaderc_profile :: enum s32 {
    shaderc_profile_none;  // Used if and only if GLSL version did not specify
                           // profiles.
    shaderc_profile_core;
    shaderc_profile_compatibility;  // Disabled. This generates an error
    shaderc_profile_es;
}

// Optimization level.
shaderc_optimization_level :: enum s32 {
  shaderc_optimization_level_zero;  // no optimization
  shaderc_optimization_level_size;  // optimize towards reducing code size
  shaderc_optimization_level_performance;  // optimize towards performance
}

// Uniform resource kinds.
// In Vulkan, uniform resources are bound to the pipeline via descriptors
// with numbered bindings and sets.
shaderc_uniform_kind :: enum s32 {
    // Image and image buffer.
    shaderc_uniform_kind_image;
    // Pure sampler.
    shaderc_uniform_kind_sampler;
    // Sampled texture in GLSL, and Shader Resource View in HLSL.
    shaderc_uniform_kind_texture;
    // Uniform Buffer Object (UBO) in GLSL.  Cbuffer in HLSL.
    shaderc_uniform_kind_buffer;
    // Shader Storage Buffer Object (SSBO) in GLSL.
    shaderc_uniform_kind_storage_buffer;
    // Unordered Access View, in HLSL.  (Writable storage image or storage
    // buffer.)
    shaderc_uniform_kind_unordered_access_view;
}

// An opaque handle to an object that manages all compiler state.
shaderc_compiler   :: struct {}
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
shaderc_compiler_initialize :: (
) -> shaderc_compiler_t #foreign shaderc;

// Releases the resources held by the shaderc_compiler_t.
// After this call it is invalid to make any future calls to functions
// involving this shaderc_compiler_t.
shaderc_compiler_release :: (
    compiler : shaderc_compiler_t
) #foreign shaderc;

// An opaque handle to an object that manages options to a single compilation
// result.
shaderc_compile_options   :: struct {}
shaderc_compile_options_t :: *shaderc_compile_options;

// Returns a default-initialized shaderc_compile_options_t that can be used
// to modify the functionality of a compiled module.
// A return of NULL indicates that there was an error initializing the options.
// Any function operating on shaderc_compile_options_t must offer the
// basic thread-safety guarantee.
shaderc_compile_options_initialize :: (
) -> shaderc_compile_options_t #foreign shaderc;

// Releases the compilation options. It is invalid to use the given
// shaderc_compile_options_t object in any future calls. It is safe to pass
// NULL to this function, and doing such will have no effect.
shaderc_compile_options_release :: (
    options : shaderc_compile_options_t
) #foreign shaderc;

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
shaderc_compile_options_add_macro_definition :: (
    options      : shaderc_compile_options_t,
    name         : *s8,
    name_length  : size_t,
    value        : *s8,
    value_length : size_t
) #foreign shaderc;

// Sets the source language.  The default is GLSL.
shaderc_compile_options_set_source_language :: (
    options : shaderc_compile_options_t,
    lang    : shaderc_source_language
) #foreign shaderc;

// Sets the compiler mode to generate debug information in the output.
shaderc_compile_options_set_generate_debug_info :: (
    options : shaderc_compile_options_t
) #foreign shaderc;

// Sets the compiler optimization level to the given level. Only the last one
// takes effect if multiple calls of this function exist.
shaderc_compile_options_set_optimization_level :: (
    options : shaderc_compile_options_t,
    level   : shaderc_optimization_level
) #foreign shaderc;

// Forces the GLSL language version and profile to a given pair. The version
// number is the same as would appear in the #version annotation in the source.
// Version and profile specified here overrides the #version annotation in the
// source. Use profile: 'shaderc_profile_none' for GLSL versions that do not
// define profiles, e.g. versions below 150.
shaderc_compile_options_set_forced_version_profile :: (
    options : shaderc_compile_options_t,
    version : s32,
    profile : shaderc_profile
) #foreign shaderc;

shaderc_target_env :: enum s32 {
    shaderc_target_env_vulkan;  // SPIR-V under Vulkan semantics
    shaderc_target_env_opengl;  // SPIR-V under OpenGL semantics
    // NOTE: SPIR-V code generation is not supported for shaders under OpenGL
    // compatibility profile.
    shaderc_target_env_opengl_compat;  // SPIR-V under OpenGL semantics,
                                       // including compatibility profile
                                       // functions
    shaderc_target_env_webgpu;         // Deprecated, SPIR-V under WebGPU
                                       // semantics
    shaderc_target_env_default :: shaderc_target_env_vulkan;
}

shaderc_env_version :: enum s32 {
    // For Vulkan, use Vulkan's mapping of version numbers to integers.
    // See vulkan.h
    shaderc_env_version_vulkan_1_0 :: ((1 << 22));
    shaderc_env_version_vulkan_1_1 :: ((1 << 22) | (1 << 12));
    shaderc_env_version_vulkan_1_2 :: ((1 << 22) | (2 << 12));
    shaderc_env_version_vulkan_1_3 :: ((1 << 22) | (3 << 12));
    // For OpenGL, use the number from #version in shaders.
    // TODO(dneto): Currently no difference between OpenGL 4.5 and 4.6.
    // See glslang/Standalone/Standalone.cpp
    // TODO(dneto): Glslang doesn't accept a OpenGL client version of 460.
    shaderc_env_version_opengl_4_5 :: 450;
    shaderc_env_version_webgpu; // Deprecated, WebGPU env never defined versions
}

// Sets the target shader environment, affecting which warnings or errors will
// be issued.  The version will be for distinguishing between different versions
// of the target environment.  The version value should be either 0 or
// a value listed in shaderc_env_version.  The 0 value maps to Vulkan 1.0 if
// |target| is Vulkan, and it maps to OpenGL 4.5 if |target| is OpenGL.
shaderc_compile_options_set_target_env :: (
    options : shaderc_compile_options_t,
    target  : shaderc_target_env,
    version : u32
) #foreign shaderc;

// The known versions of SPIR-V.
shaderc_spirv_version :: enum s32 #specified {
    // Use the values used for word 1 of a SPIR-V binary:
    // - bits 24 to 31: zero
    // - bits 16 to 23: major version number
    // - bits 8 to 15: minor version number
    // - bits 0 to 7: zero
    shaderc_spirv_version_1_0 :: 0x010000;
    shaderc_spirv_version_1_1 :: 0x010100;
    shaderc_spirv_version_1_2 :: 0x010200;
    shaderc_spirv_version_1_3 :: 0x010300;
    shaderc_spirv_version_1_4 :: 0x010400;
    shaderc_spirv_version_1_5 :: 0x010500;
    shaderc_spirv_version_1_6 :: 0x010600;
}

// Sets the target SPIR-V version. The generated module will use this version
// of SPIR-V.  Each target environment determines what versions of SPIR-V
// it can consume.  Defaults to the highest version of SPIR-V 1.0 which is
// required to be supported by the target environment.  E.g. Default to SPIR-V
// 1.0 for Vulkan 1.0 and SPIR-V 1.3 for Vulkan 1.1.
shaderc_compile_options_set_target_spirv :: (
    options : shaderc_compile_options_t,
    version : shaderc_spirv_version
) #foreign shaderc;

// Sets whether the compiler should automatically assign bindings to uniforms
// that aren't already explicitly bound in the shader source.
shaderc_compile_options_set_auto_bind_uniforms :: (
    options   : shaderc_compile_options_t,
    auto_bind : bool
) #foreign shaderc;

// Sets the base binding number used for for a uniform resource type when
// automatically assigning bindings.  For GLSL compilation, sets the lowest
// automatically assigned number.  For HLSL compilation, the regsiter number
// assigned to the resource is added to this specified base.
shaderc_compile_options_set_binding_base :: (
    options : shaderc_compile_options_t,
    kind    : shaderc_uniform_kind,
    base    : u32
) #foreign shaderc;

// Sets whether the compiler should automatically assign locations to
// uniform variables that don't have explicit locations in the shader source.
shaderc_compile_options_set_auto_map_locations :: (
    options  : shaderc_compile_options_t,
    auto_map : bool
) #foreign shaderc;

// Sets whether the compiler should invert position.Y output in vertex shader.
shaderc_compile_options_set_invert_y :: (
    options : shaderc_compile_options_t,
    enable  : bool
) #foreign shaderc;

// An opaque handle to the results of a call to any shaderc_compile_into_*()
// function.
shaderc_compilation_result   :: struct {}
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
shaderc_compile_into_spv :: (
    compiler           : shaderc_compiler_t,
    source_text        : *s8,
    source_text_size   : size_t,
    shader_kind        : shaderc_shader_kind,
    input_file_name    : *s8,
    entry_point_name   : *s8,
    additional_options : shaderc_compile_options_t
) -> shaderc_compilation_result_t #foreign shaderc;

// Like shaderc_compile_into_spv, but the result contains SPIR-V assembly text
// instead of a SPIR-V binary module.  The SPIR-V assembly syntax is as defined
// by the SPIRV-Tools open source project.
shaderc_compile_into_spv_assembly :: (
    compiler           : shaderc_compiler_t,
    source_text        : *s8,
    source_text_size   : size_t,
    shader_kind        : shaderc_shader_kind,
    input_file_name    : *s8,
    entry_point_name   : *s8,
    additional_options : shaderc_compile_options_t
) -> shaderc_compilation_result_t #foreign shaderc;

// Releases the resources held by the result object. It is invalid to use the
// result object for any further operations.
shaderc_result_release :: (
    result : shaderc_compilation_result_t
) #foreign shaderc;

// Returns the number of bytes of the compilation output data in a result
// object.
shaderc_result_get_length :: (
    result : shaderc_compilation_result_t
) -> size_t #foreign shaderc;

// Returns the number of warnings generated during the compilation.
shaderc_result_get_num_warnings :: (
    result : shaderc_compilation_result_t
) -> size_t #foreign shaderc;

// Returns the number of errors generated during the compilation.
shaderc_result_get_num_errors :: (
    result : shaderc_compilation_result_t
) -> size_t #foreign shaderc;

// Indicate the status of a compilation.
shaderc_compilation_status :: enum #specified {
    shaderc_compilation_status_success :: 0;
    shaderc_compilation_status_invalid_stage :: 1;  // error stage deduction
    shaderc_compilation_status_compilation_error :: 2;
    shaderc_compilation_status_internal_error :: 3;  // unexpected failure
    shaderc_compilation_status_null_result_object :: 4;
    shaderc_compilation_status_invalid_assembly :: 5;
    shaderc_compilation_status_validation_error :: 6;
    shaderc_compilation_status_transformation_error :: 7;
    shaderc_compilation_status_configuration_error :: 8;
}

// Returns the compilation status, indicating whether the compilation succeeded,
// or failed due to some reasons, like invalid shader stage or compilation
// errors.
shaderc_result_get_compilation_status :: (
    result : shaderc_compilation_result_t
) -> shaderc_compilation_status #foreign shaderc;

// Returns a pointer to the start of the compilation output data bytes, either
// SPIR-V binary or char string. When the source string is compiled into SPIR-V
// binary, this is guaranteed to be castable to a uint32_t*. If the result
// contains assembly text or preprocessed source text, the pointer will point to
// the resulting array of characters.
shaderc_result_get_bytes :: (
    result : shaderc_compilation_result_t
) -> *s8 #foreign shaderc;

// Returns a null-terminated string that contains any error messages generated
// during the compilation.
shaderc_result_get_error_message :: (
    result : shaderc_compilation_result_t
) -> *s8 #foreign shaderc;

#scope_file

#if DEBUG_BUILD {
    shaderc :: #system_library "shaderc_sharedd";
} else {
    shaderc :: #system_library "shaderc_shared";
}

size_t :: u64; // We target only 64-bit systems, so... whatever.
