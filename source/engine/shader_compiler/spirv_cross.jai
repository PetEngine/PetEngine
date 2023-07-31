/*
 * Copyright 2019-2021 Hans-Kristian Arntzen
 * SPDX-License-Identifier: Apache-2.0 OR MIT
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * At your option, you may choose to accept this material under either:
 *  1. The Apache License, Version 2.0, found at <http://www.apache.org/licenses/LICENSE-2.0>, or
 *  2. The MIT License, found at <http://opensource.org/licenses/MIT>.
 */

#load "spirv.jai";

/* These types are opaque to the user. */
spvc_context   :: *spvc_context_s;   spvc_context_s   :: struct {}
spvc_parsed_ir :: *spvc_parsed_ir_s; spvc_parsed_ir_s :: struct {}
spvc_compiler  :: *spvc_compiler_s;  spvc_compiler_s  :: struct {}
spvc_resources :: *spvc_resources_s; spvc_resources_s :: struct {}
spvc_set       :: *spvc_set_s;       spvc_set_s       :: struct {}

/*
 * Shallow typedefs. All SPIR-V IDs are plain 32-bit numbers, but this helps communicate which data is used.
 * Maps to a SPIRType.
 */
spvc_type_id :: SpvId;
/* Maps to a SPIRVariable. */
spvc_variable_id :: SpvId;
/* Maps to a SPIRConstant. */
spvc_constant_id :: SpvId;

/* See C++ API. */
spvc_reflected_resource :: struct {
    id           : spvc_variable_id;
    base_type_id : spvc_type_id;
    type_id      : spvc_type_id;
    name         : *s8;
}

spvc_result :: enum s32 {
    /* Success. */
    SPVC_SUCCESS :: 0;

    /* The SPIR-V is invalid. Should have been caught by validation ideally. */
    SPVC_ERROR_INVALID_SPIRV :: -1;

    /* The SPIR-V might be valid or invalid, but SPIRV-Cross currently cannot correctly translate this to your target language. */
    SPVC_ERROR_UNSUPPORTED_SPIRV :: -2;

    /* If for some reason we hit this, new or malloc failed. */
    SPVC_ERROR_OUT_OF_MEMORY :: -3;

    /* Invalid API argument. */
    SPVC_ERROR_INVALID_ARGUMENT :: -4;

    SPVC_ERROR_INT_MAX :: 0x7fffffff;
}

spvc_capture_mode :: enum s32 {
    /* The Parsed IR payload will be copied, and the handle can be reused to create other compiler instances. */
    SPVC_CAPTURE_MODE_COPY :: 0;

    /*
     * The payload will now be owned by the compiler.
     * parsed_ir should now be considered a dead blob and must not be used further.
     * This is optimal for performance and should be the go-to option.
     */
    SPVC_CAPTURE_MODE_TAKE_OWNERSHIP :: 1;

    SPVC_CAPTURE_MODE_INT_MAX :: 0x7fffffff;
}

spvc_backend :: enum s32 {
    /* This backend can only perform reflection, no compiler options are supported. Maps to spirv_cross::Compiler. */
    SPVC_BACKEND_NONE :: 0;
    SPVC_BACKEND_GLSL :: 1; /* spirv_cross::CompilerGLSL */
    SPVC_BACKEND_HLSL :: 2; /* CompilerHLSL */
    SPVC_BACKEND_MSL :: 3; /* CompilerMSL */
    SPVC_BACKEND_CPP :: 4; /* CompilerCPP */
    SPVC_BACKEND_JSON :: 5; /* CompilerReflection w/ JSON backend */
    SPVC_BACKEND_INT_MAX :: 0x7fffffff;
}

/* Maps to C++ API. */
spvc_resource_type :: enum s32 #specified {
    SPVC_RESOURCE_TYPE_UNKNOWN :: 0;
    SPVC_RESOURCE_TYPE_UNIFORM_BUFFER :: 1;
    SPVC_RESOURCE_TYPE_STORAGE_BUFFER :: 2;
    SPVC_RESOURCE_TYPE_STAGE_INPUT :: 3;
    SPVC_RESOURCE_TYPE_STAGE_OUTPUT :: 4;
    SPVC_RESOURCE_TYPE_SUBPASS_INPUT :: 5;
    SPVC_RESOURCE_TYPE_STORAGE_IMAGE :: 6;
    SPVC_RESOURCE_TYPE_SAMPLED_IMAGE :: 7;
    SPVC_RESOURCE_TYPE_ATOMIC_COUNTER :: 8;
    SPVC_RESOURCE_TYPE_PUSH_CONSTANT :: 9;
    SPVC_RESOURCE_TYPE_SEPARATE_IMAGE :: 10;
    SPVC_RESOURCE_TYPE_SEPARATE_SAMPLERS :: 11;
    SPVC_RESOURCE_TYPE_ACCELERATION_STRUCTURE :: 12;
    SPVC_RESOURCE_TYPE_RAY_QUERY :: 13;
    SPVC_RESOURCE_TYPE_SHADER_RECORD_BUFFER :: 14;
    SPVC_RESOURCE_TYPE_INT_MAX :: 0x7fffffff;
}

/*
 * Context is the highest-level API construct.
 * The context owns all memory allocations made by its child object hierarchy, including various non-opaque structs and strings.
 * This means that the API user only has to care about one "destroy" call ever when using the C API.
 * All pointers handed out by the APIs are only valid as long as the context
 * is alive and spvc_context_release_allocations has not been called.
 */
spvc_context_create :: (
    context_ : *spvc_context
) -> spvc_result #foreign spirv_cross;

/* Frees all memory allocations and objects associated with the context and its child objects. */
spvc_context_destroy :: (
    context_ : spvc_context
) #foreign spirv_cross;

/* Frees all memory allocations and objects associated with the context and its child objects, but keeps the context alive. */
spvc_context_release_allocations :: (
    context_ : spvc_context
) #foreign spirv_cross;

/* Get the string for the last error which was logged. */
spvc_context_get_last_error_string :: (
    context_ : spvc_context
) -> *s8 #foreign spirv_cross;

/* Get notified in a callback when an error triggers. Useful for debugging. */
spvc_error_callback :: #type (userdata : *void, error : *s8) #c_call;
spvc_context_set_error_callback :: (
    context_ : spvc_context,
    cb       : spvc_error_callback,
    userdata : *void
) #foreign spirv_cross;

/* SPIR-V parsing interface. Maps to Parser which then creates a ParsedIR, and that IR is extracted into the handle. */
spvc_context_parse_spirv :: (
    context_   : spvc_context,
    spirv      : *SpvId,
    word_count : size_t,
    parsed_ir  : *spvc_parsed_ir
) -> spvc_result #foreign spirv_cross;

/*
 * Create a compiler backend. Capture mode controls if we construct by copy or move semantics.
 * It is always recommended to use SPVC_CAPTURE_MODE_TAKE_OWNERSHIP if you only intend to cross-compile the IR once.
 */
spvc_context_create_compiler :: (
    context_  : spvc_context,
    backend   : spvc_backend,
    parsed_ir : spvc_parsed_ir,
    mode      : spvc_capture_mode,
    compiler  : *spvc_compiler
) -> spvc_result #foreign spirv_cross;

/*
 * Reflect resources.
 * Maps almost 1:1 to C++ API.
 */
spvc_compiler_get_active_interface_variables :: (
    compiler : spvc_compiler,
    set      : *spvc_set
) -> spvc_result #foreign spirv_cross;

spvc_resources_get_resource_list_for_type :: (
    resources     : spvc_resources,
    type          : spvc_resource_type,
    resource_list : **spvc_reflected_resource,
    resource_size : *size_t
) -> spvc_result #foreign spirv_cross;

#scope_file

#if DEBUG_BUILD {
    spirv_cross :: #system_library "spirv-cross-c-sharedd";
} else {
    spirv_cross :: #system_library "spirv-cross-c-shared";
}

size_t :: u64; // We target only 64-bit systems, so... whatever.
