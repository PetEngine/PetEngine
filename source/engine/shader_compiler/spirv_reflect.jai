/*
 Copyright 2017-2022 Google Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

#load "spirv.jai";

/*! @enum SpvReflectResult

*/
SpvReflectResult :: enum s32 {
    SPV_REFLECT_RESULT_SUCCESS;
    SPV_REFLECT_RESULT_NOT_READY;
    SPV_REFLECT_RESULT_ERROR_PARSE_FAILED;
    SPV_REFLECT_RESULT_ERROR_ALLOC_FAILED;
    SPV_REFLECT_RESULT_ERROR_RANGE_EXCEEDED;
    SPV_REFLECT_RESULT_ERROR_NULL_POINTER;
    SPV_REFLECT_RESULT_ERROR_INTERNAL_ERROR;
    SPV_REFLECT_RESULT_ERROR_COUNT_MISMATCH;
    SPV_REFLECT_RESULT_ERROR_ELEMENT_NOT_FOUND;
    SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_CODE_SIZE;
    SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_MAGIC_NUMBER;
    SPV_REFLECT_RESULT_ERROR_SPIRV_UNEXPECTED_EOF;
    SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_ID_REFERENCE;
    SPV_REFLECT_RESULT_ERROR_SPIRV_SET_NUMBER_OVERFLOW;
    SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_STORAGE_CLASS;
    SPV_REFLECT_RESULT_ERROR_SPIRV_RECURSION;
    SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_INSTRUCTION;
    SPV_REFLECT_RESULT_ERROR_SPIRV_UNEXPECTED_BLOCK_DATA;
    SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_BLOCK_MEMBER_REFERENCE;
    SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_ENTRY_POINT;
    SPV_REFLECT_RESULT_ERROR_SPIRV_INVALID_EXECUTION_MODE;
    SPV_REFLECT_RESULT_ERROR_SPIRV_MAX_RECURSIVE_EXCEEDED;
}

/*! @enum SpvReflectModuleFlags

SPV_REFLECT_MODULE_FLAG_NO_COPY - Disables copying of SPIR-V code
  when a SPIRV-Reflect shader module is created. It is the
  responsibility of the calling program to ensure that the pointer
  remains valid and the memory it's pointing to is not freed while
  SPIRV-Reflect operations are taking place. Freeing the backing
  memory will cause undefined behavior or most likely a crash.
  This is flag is intended for cases where the memory overhead of
  storing the copied SPIR-V is undesirable.

*/
SpvReflectModuleFlags :: enum_flags u32 #specified {
    SPV_REFLECT_MODULE_FLAG_NONE    :: 0x00000000;
    SPV_REFLECT_MODULE_FLAG_NO_COPY :: 0x00000001;
}

/*! @enum SpvReflectTypeFlags

*/
SpvReflectTypeFlags :: enum_flags u32 #specified {
    SPV_REFLECT_TYPE_FLAG_UNDEFINED                       :: 0x00000000;
    SPV_REFLECT_TYPE_FLAG_VOID                            :: 0x00000001;
    SPV_REFLECT_TYPE_FLAG_BOOL                            :: 0x00000002;
    SPV_REFLECT_TYPE_FLAG_INT                             :: 0x00000004;
    SPV_REFLECT_TYPE_FLAG_FLOAT                           :: 0x00000008;
    SPV_REFLECT_TYPE_FLAG_VECTOR                          :: 0x00000100;
    SPV_REFLECT_TYPE_FLAG_MATRIX                          :: 0x00000200;
    SPV_REFLECT_TYPE_FLAG_EXTERNAL_IMAGE                  :: 0x00010000;
    SPV_REFLECT_TYPE_FLAG_EXTERNAL_SAMPLER                :: 0x00020000;
    SPV_REFLECT_TYPE_FLAG_EXTERNAL_SAMPLED_IMAGE          :: 0x00040000;
    SPV_REFLECT_TYPE_FLAG_EXTERNAL_BLOCK                  :: 0x00080000;
    SPV_REFLECT_TYPE_FLAG_EXTERNAL_ACCELERATION_STRUCTURE :: 0x00100000;
    SPV_REFLECT_TYPE_FLAG_EXTERNAL_MASK                   :: 0x00FF0000;
    SPV_REFLECT_TYPE_FLAG_STRUCT                          :: 0x10000000;
    SPV_REFLECT_TYPE_FLAG_ARRAY                           :: 0x20000000;
    SPV_REFLECT_TYPE_FLAG_REF                             :: 0x40000000;
}

/*! @enum SpvReflectDecorationFlags

NOTE: HLSL row_major and column_major decorations are reversed
      in SPIR-V. Meaning that matrices declrations with row_major
      will get reflected as column_major and vice versa. The
      row and column decorations get appied during the compilation.
      SPIRV-Reflect reads the data as is and does not make any
      attempt to correct it to match what's in the source.

      The Patch, PerVertex, and PerTask are used for Interface
      variables that can have array

*/
SpvReflectDecorationFlags :: enum_flags u32 #specified {
    SPV_REFLECT_DECORATION_NONE                :: 0x00000000;
    SPV_REFLECT_DECORATION_BLOCK               :: 0x00000001;
    SPV_REFLECT_DECORATION_BUFFER_BLOCK        :: 0x00000002;
    SPV_REFLECT_DECORATION_ROW_MAJOR           :: 0x00000004;
    SPV_REFLECT_DECORATION_COLUMN_MAJOR        :: 0x00000008;
    SPV_REFLECT_DECORATION_BUILT_IN            :: 0x00000010;
    SPV_REFLECT_DECORATION_NOPERSPECTIVE       :: 0x00000020;
    SPV_REFLECT_DECORATION_FLAT                :: 0x00000040;
    SPV_REFLECT_DECORATION_NON_WRITABLE        :: 0x00000080;
    SPV_REFLECT_DECORATION_RELAXED_PRECISION   :: 0x00000100;
    SPV_REFLECT_DECORATION_NON_READABLE        :: 0x00000200;
    SPV_REFLECT_DECORATION_PATCH               :: 0x00000400;
    SPV_REFLECT_DECORATION_PER_VERTEX          :: 0x00000800;
    SPV_REFLECT_DECORATION_PER_TASK            :: 0x00001000;
    SPV_REFLECT_DECORATION_WEIGHT_TEXTURE      :: 0x00002000;
    SPV_REFLECT_DECORATION_BLOCK_MATCH_TEXTURE :: 0x00004000;
}

// Based of SPV_GOOGLE_user_type
SpvReflectUserType :: enum s32 {
    SPV_REFLECT_USER_TYPE_INVALID :: 0;
    SPV_REFLECT_USER_TYPE_CBUFFER;
    SPV_REFLECT_USER_TYPE_TBUFFER;
    SPV_REFLECT_USER_TYPE_APPEND_STRUCTURED_BUFFER;
    SPV_REFLECT_USER_TYPE_BUFFER;
    SPV_REFLECT_USER_TYPE_BYTE_ADDRESS_BUFFER;
    SPV_REFLECT_USER_TYPE_CONSTANT_BUFFER;
    SPV_REFLECT_USER_TYPE_CONSUME_STRUCTURED_BUFFER;
    SPV_REFLECT_USER_TYPE_INPUT_PATCH;
    SPV_REFLECT_USER_TYPE_OUTPUT_PATCH;
    SPV_REFLECT_USER_TYPE_RASTERIZER_ORDERED_BUFFER;
    SPV_REFLECT_USER_TYPE_RASTERIZER_ORDERED_BYTE_ADDRESS_BUFFER;
    SPV_REFLECT_USER_TYPE_RASTERIZER_ORDERED_STRUCTURED_BUFFER;
    SPV_REFLECT_USER_TYPE_RASTERIZER_ORDERED_TEXTURE_1D;
    SPV_REFLECT_USER_TYPE_RASTERIZER_ORDERED_TEXTURE_1D_ARRAY;
    SPV_REFLECT_USER_TYPE_RASTERIZER_ORDERED_TEXTURE_2D;
    SPV_REFLECT_USER_TYPE_RASTERIZER_ORDERED_TEXTURE_2D_ARRAY;
    SPV_REFLECT_USER_TYPE_RASTERIZER_ORDERED_TEXTURE_3D;
    SPV_REFLECT_USER_TYPE_RAYTRACING_ACCELERATION_STRUCTURE;
    SPV_REFLECT_USER_TYPE_RW_BUFFER;
    SPV_REFLECT_USER_TYPE_RW_BYTE_ADDRESS_BUFFER;
    SPV_REFLECT_USER_TYPE_RW_STRUCTURED_BUFFER;
    SPV_REFLECT_USER_TYPE_RW_TEXTURE_1D;
    SPV_REFLECT_USER_TYPE_RW_TEXTURE_1D_ARRAY;
    SPV_REFLECT_USER_TYPE_RW_TEXTURE_2D;
    SPV_REFLECT_USER_TYPE_RW_TEXTURE_2D_ARRAY;
    SPV_REFLECT_USER_TYPE_RW_TEXTURE_3D;
    SPV_REFLECT_USER_TYPE_STRUCTURED_BUFFER;
    SPV_REFLECT_USER_TYPE_SUBPASS_INPUT;
    SPV_REFLECT_USER_TYPE_SUBPASS_INPUT_MS;
    SPV_REFLECT_USER_TYPE_TEXTURE_1D;
    SPV_REFLECT_USER_TYPE_TEXTURE_1D_ARRAY;
    SPV_REFLECT_USER_TYPE_TEXTURE_2D;
    SPV_REFLECT_USER_TYPE_TEXTURE_2D_ARRAY;
    SPV_REFLECT_USER_TYPE_TEXTURE_2DMS;
    SPV_REFLECT_USER_TYPE_TEXTURE_2DMS_ARRAY;
    SPV_REFLECT_USER_TYPE_TEXTURE_3D;
    SPV_REFLECT_USER_TYPE_TEXTURE_BUFFER;
    SPV_REFLECT_USER_TYPE_TEXTURE_CUBE;
    SPV_REFLECT_USER_TYPE_TEXTURE_CUBE_ARRAY;
}

/*! @enum SpvReflectResourceType

*/
SpvReflectResourceType :: enum s32 #specified {
    SPV_REFLECT_RESOURCE_FLAG_UNDEFINED :: 0x00000000;
    SPV_REFLECT_RESOURCE_FLAG_SAMPLER   :: 0x00000001;
    SPV_REFLECT_RESOURCE_FLAG_CBV       :: 0x00000002;
    SPV_REFLECT_RESOURCE_FLAG_SRV       :: 0x00000004;
    SPV_REFLECT_RESOURCE_FLAG_UAV       :: 0x00000008;
}

/*! @enum SpvReflectFormat

*/
SpvReflectFormat :: enum s32 #specified {
    SPV_REFLECT_FORMAT_UNDEFINED           ::   0; // = VK_FORMAT_UNDEFINED
    SPV_REFLECT_FORMAT_R16_UINT            ::  74; // = VK_FORMAT_R16_UINT
    SPV_REFLECT_FORMAT_R16_SINT            ::  75; // = VK_FORMAT_R16_SINT
    SPV_REFLECT_FORMAT_R16_SFLOAT          ::  76; // = VK_FORMAT_R16_SFLOAT
    SPV_REFLECT_FORMAT_R16G16_UINT         ::  81; // = VK_FORMAT_R16G16_UINT
    SPV_REFLECT_FORMAT_R16G16_SINT         ::  82; // = VK_FORMAT_R16G16_SINT
    SPV_REFLECT_FORMAT_R16G16_SFLOAT       ::  83; // = VK_FORMAT_R16G16_SFLOAT
    SPV_REFLECT_FORMAT_R16G16B16_UINT      ::  88; // = VK_FORMAT_R16G16B16_UINT
    SPV_REFLECT_FORMAT_R16G16B16_SINT      ::  89; // = VK_FORMAT_R16G16B16_SINT
    SPV_REFLECT_FORMAT_R16G16B16_SFLOAT    ::  90; // = VK_FORMAT_R16G16B16_SFLOAT
    SPV_REFLECT_FORMAT_R16G16B16A16_UINT   ::  95; // = VK_FORMAT_R16G16B16A16_UINT
    SPV_REFLECT_FORMAT_R16G16B16A16_SINT   ::  96; // = VK_FORMAT_R16G16B16A16_SINT
    SPV_REFLECT_FORMAT_R16G16B16A16_SFLOAT ::  97; // = VK_FORMAT_R16G16B16A16_SFLOAT
    SPV_REFLECT_FORMAT_R32_UINT            ::  98; // = VK_FORMAT_R32_UINT
    SPV_REFLECT_FORMAT_R32_SINT            ::  99; // = VK_FORMAT_R32_SINT
    SPV_REFLECT_FORMAT_R32_SFLOAT          :: 100; // = VK_FORMAT_R32_SFLOAT
    SPV_REFLECT_FORMAT_R32G32_UINT         :: 101; // = VK_FORMAT_R32G32_UINT
    SPV_REFLECT_FORMAT_R32G32_SINT         :: 102; // = VK_FORMAT_R32G32_SINT
    SPV_REFLECT_FORMAT_R32G32_SFLOAT       :: 103; // = VK_FORMAT_R32G32_SFLOAT
    SPV_REFLECT_FORMAT_R32G32B32_UINT      :: 104; // = VK_FORMAT_R32G32B32_UINT
    SPV_REFLECT_FORMAT_R32G32B32_SINT      :: 105; // = VK_FORMAT_R32G32B32_SINT
    SPV_REFLECT_FORMAT_R32G32B32_SFLOAT    :: 106; // = VK_FORMAT_R32G32B32_SFLOAT
    SPV_REFLECT_FORMAT_R32G32B32A32_UINT   :: 107; // = VK_FORMAT_R32G32B32A32_UINT
    SPV_REFLECT_FORMAT_R32G32B32A32_SINT   :: 108; // = VK_FORMAT_R32G32B32A32_SINT
    SPV_REFLECT_FORMAT_R32G32B32A32_SFLOAT :: 109; // = VK_FORMAT_R32G32B32A32_SFLOAT
    SPV_REFLECT_FORMAT_R64_UINT            :: 110; // = VK_FORMAT_R64_UINT
    SPV_REFLECT_FORMAT_R64_SINT            :: 111; // = VK_FORMAT_R64_SINT
    SPV_REFLECT_FORMAT_R64_SFLOAT          :: 112; // = VK_FORMAT_R64_SFLOAT
    SPV_REFLECT_FORMAT_R64G64_UINT         :: 113; // = VK_FORMAT_R64G64_UINT
    SPV_REFLECT_FORMAT_R64G64_SINT         :: 114; // = VK_FORMAT_R64G64_SINT
    SPV_REFLECT_FORMAT_R64G64_SFLOAT       :: 115; // = VK_FORMAT_R64G64_SFLOAT
    SPV_REFLECT_FORMAT_R64G64B64_UINT      :: 116; // = VK_FORMAT_R64G64B64_UINT
    SPV_REFLECT_FORMAT_R64G64B64_SINT      :: 117; // = VK_FORMAT_R64G64B64_SINT
    SPV_REFLECT_FORMAT_R64G64B64_SFLOAT    :: 118; // = VK_FORMAT_R64G64B64_SFLOAT
    SPV_REFLECT_FORMAT_R64G64B64A64_UINT   :: 119; // = VK_FORMAT_R64G64B64A64_UINT
    SPV_REFLECT_FORMAT_R64G64B64A64_SINT   :: 120; // = VK_FORMAT_R64G64B64A64_SINT
    SPV_REFLECT_FORMAT_R64G64B64A64_SFLOAT :: 121; // = VK_FORMAT_R64G64B64A64_SFLOAT
}

/*! @enum SpvReflectVariableFlags

*/
SpvReflectVariableFlags :: enum_flags u32 #specified {
    SPV_REFLECT_VARIABLE_FLAGS_NONE   :: 0x00000000;
    SPV_REFLECT_VARIABLE_FLAGS_UNUSED :: 0x00000001;
    // If variable points to a copy of the PhysicalStorageBuffer struct
    SPV_REFLECT_VARIABLE_FLAGS_PHYSICAL_POINTER_COPY :: 0x00000002;
}

/*! @enum SpvReflectDescriptorType

*/
SpvReflectDescriptorType :: enum s32 #specified {
    SPV_REFLECT_DESCRIPTOR_TYPE_SAMPLER                    ::  0;         // = VK_DESCRIPTOR_TYPE_SAMPLER
    SPV_REFLECT_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER     ::  1;         // = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
    SPV_REFLECT_DESCRIPTOR_TYPE_SAMPLED_IMAGE              ::  2;         // = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE
    SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_IMAGE              ::  3;         // = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE
    SPV_REFLECT_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER       ::  4;         // = VK_DESCRIPTOR_TYPE_UNIFORM_TEXEL_BUFFER
    SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER       ::  5;         // = VK_DESCRIPTOR_TYPE_STORAGE_TEXEL_BUFFER
    SPV_REFLECT_DESCRIPTOR_TYPE_UNIFORM_BUFFER             ::  6;         // = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
    SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_BUFFER             ::  7;         // = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER
    SPV_REFLECT_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC     ::  8;         // = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC
    SPV_REFLECT_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC     ::  9;         // = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC
    SPV_REFLECT_DESCRIPTOR_TYPE_INPUT_ATTACHMENT           :: 10;         // = VK_DESCRIPTOR_TYPE_INPUT_ATTACHMENT
    SPV_REFLECT_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR :: 1000150000; // = VK_DESCRIPTOR_TYPE_ACCELERATION_STRUCTURE_KHR
}

/*! @enum SpvReflectShaderStageFlags

*/
SpvReflectShaderStageFlags :: enum_flags u32 #specified {
    SPV_REFLECT_SHADER_STAGE_VERTEX_BIT                  :: 0x00000001; // = VK_SHADER_STAGE_VERTEX_BIT
    SPV_REFLECT_SHADER_STAGE_TESSELLATION_CONTROL_BIT    :: 0x00000002; // = VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT
    SPV_REFLECT_SHADER_STAGE_TESSELLATION_EVALUATION_BIT :: 0x00000004; // = VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT
    SPV_REFLECT_SHADER_STAGE_GEOMETRY_BIT                :: 0x00000008; // = VK_SHADER_STAGE_GEOMETRY_BIT
    SPV_REFLECT_SHADER_STAGE_FRAGMENT_BIT                :: 0x00000010; // = VK_SHADER_STAGE_FRAGMENT_BIT
    SPV_REFLECT_SHADER_STAGE_COMPUTE_BIT                 :: 0x00000020; // = VK_SHADER_STAGE_COMPUTE_BIT
    SPV_REFLECT_SHADER_STAGE_TASK_BIT_NV                 :: 0x00000040; // = VK_SHADER_STAGE_TASK_BIT_NV
    SPV_REFLECT_SHADER_STAGE_TASK_BIT_EXT                :: SPV_REFLECT_SHADER_STAGE_TASK_BIT_NV; // = VK_SHADER_STAGE_CALLABLE_BIT_EXT
    SPV_REFLECT_SHADER_STAGE_MESH_BIT_NV                 :: 0x00000080; // = VK_SHADER_STAGE_MESH_BIT_NV
    SPV_REFLECT_SHADER_STAGE_MESH_BIT_EXT                :: SPV_REFLECT_SHADER_STAGE_MESH_BIT_NV; // = VK_SHADER_STAGE_CALLABLE_BIT_EXT
    SPV_REFLECT_SHADER_STAGE_RAYGEN_BIT_KHR              :: 0x00000100; // = VK_SHADER_STAGE_RAYGEN_BIT_KHR
    SPV_REFLECT_SHADER_STAGE_ANY_HIT_BIT_KHR             :: 0x00000200; // = VK_SHADER_STAGE_ANY_HIT_BIT_KHR
    SPV_REFLECT_SHADER_STAGE_CLOSEST_HIT_BIT_KHR         :: 0x00000400; // = VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR
    SPV_REFLECT_SHADER_STAGE_MISS_BIT_KHR                :: 0x00000800; // = VK_SHADER_STAGE_MISS_BIT_KHR
    SPV_REFLECT_SHADER_STAGE_INTERSECTION_BIT_KHR        :: 0x00001000; // = VK_SHADER_STAGE_INTERSECTION_BIT_KHR
    SPV_REFLECT_SHADER_STAGE_CALLABLE_BIT_KHR            :: 0x00002000; // = VK_SHADER_STAGE_CALLABLE_BIT_KHR
}

/*! @enum SpvReflectGenerator

*/
SpvReflectGenerator :: enum s32 #specified {
    SPV_REFLECT_GENERATOR_KHRONOS_LLVM_SPIRV_TRANSLATOR         :: 6;
    SPV_REFLECT_GENERATOR_KHRONOS_SPIRV_TOOLS_ASSEMBLER         :: 7;
    SPV_REFLECT_GENERATOR_KHRONOS_GLSLANG_REFERENCE_FRONT_END   :: 8;
    SPV_REFLECT_GENERATOR_GOOGLE_SHADERC_OVER_GLSLANG           :: 13;
    SPV_REFLECT_GENERATOR_GOOGLE_SPIREGG                        :: 14;
    SPV_REFLECT_GENERATOR_GOOGLE_RSPIRV                         :: 15;
    SPV_REFLECT_GENERATOR_X_LEGEND_MESA_MESAIR_SPIRV_TRANSLATOR :: 16;
    SPV_REFLECT_GENERATOR_KHRONOS_SPIRV_TOOLS_LINKER            :: 17;
    SPV_REFLECT_GENERATOR_WINE_VKD3D_SHADER_COMPILER            :: 18;
    SPV_REFLECT_GENERATOR_CLAY_CLAY_SHADER_COMPILER             :: 19;
}

SPV_REFLECT_MAX_ARRAY_DIMS             :: 32;
SPV_REFLECT_MAX_DESCRIPTOR_SETS        :: 64;
SPV_REFLECT_BINDING_NUMBER_DONT_CHANGE : u32 : 0xFFFFFFFF;
SPV_REFLECT_SET_NUMBER_DONT_CHANGE     : u32 : 0xFFFFFFFF;

SpvReflectNumericTraits :: struct {
    Scalar :: struct {
        width           : u32;
        signedness      : u32;
    }

    Vector :: struct {
        component_count : u32;
    }

    Matrix :: struct {
        column_count    : u32;
        row_count       : u32;
        stride          : u32; // Measured in bytes
    }

    scalar              : Scalar;
    vector              : Vector;
    matrix              : Matrix;
}

SpvReflectImageTraits :: struct {
    dim          : SpvDim;
    depth        : u32;
    arrayed      : u32;
    ms           : u32; // 0: single-sampled; 1: multisampled
    sampled      : u32;
    image_format : SpvImageFormat;
}

SpvReflectArrayDimType :: enum u32 #specified {
    SPV_REFLECT_ARRAY_DIM_RUNTIME :: 0; // OpTypeRuntimeArray
}

SpvReflectArrayTraits :: struct {
    dims_count           : u32;
    // Each entry is either:
    // - specialization constant dimension
    // - OpTypeRuntimeArray
    // - the array length otherwise
    dims                 : [SPV_REFLECT_MAX_ARRAY_DIMS] u32;
    // Stores Ids for dimensions that are specialization constants
    spec_constant_op_ids : [SPV_REFLECT_MAX_ARRAY_DIMS] u32;
    stride               : u32; // Measured in bytes
}

SpvReflectBindingArrayTraits :: struct {
    dims_count : u32;
    dims       : [SPV_REFLECT_MAX_ARRAY_DIMS] u32;
}

/*! @struct SpvReflectTypeDescription
    @brief Information about an OpType* instruction
*/
SpvReflectTypeDescription :: struct {
    id                      : u32;
    op                      : SpvOp;
    type_name               : *u8;
    // Non-NULL if type is member of a struct
    struct_member_name      : *u8;
    storage_class           : SpvStorageClass;
    type_flags              : SpvReflectTypeFlags;
    decoration_flags        : SpvReflectDecorationFlags;

    Traits :: struct {
        numeric             : SpvReflectNumericTraits;
        image               : SpvReflectImageTraits;
        array               : SpvReflectArrayTraits;
    }
    traits                  : Traits;

    // If underlying type is a struct (ex. array of structs)
    // this gives access to the OpTypeStruct
    struct_type_description : *SpvReflectTypeDescription;

    // Some pointers to SpvReflectTypeDescription are really
    // just copies of another reference to the same OpType
    copied                  : u32;

    // @deprecated use struct_type_description instead
    member_count            : u32;
    // @deprecated use struct_type_description instead
    members                 : *SpvReflectTypeDescription;
}

/*! @struct SpvReflectInterfaceVariable
    @brief The OpVariable that is either an Input or Output to the module
*/
SpvReflectInterfaceVariable :: struct {
    spirv_id         : u32;
    name             : *u8;
    location         : u32;
    component        : u32;
    storage_class    : SpvStorageClass;
    semantic         : *u8;
    decoration_flags : SpvReflectDecorationFlags;
    built_in         : SpvBuiltIn;
    numeric          : SpvReflectNumericTraits;
    array            : SpvReflectArrayTraits;

    member_count     : u32;
    members          : *SpvReflectInterfaceVariable;

    format           : SpvReflectFormat;

    // NOTE: SPIR-V shares type references for variables
    //       that have the same underlying type. This means
    //       that the same type name will appear for multiple
    //       variables.
    type_description : *SpvReflectTypeDescription;

    word_offset : struct {
        location     : u32;
    };
}

/*! @struct SpvReflectBlockVariable

*/
SpvReflectBlockVariable :: struct {
    spirv_id         : u32;
    name             : *u8;
    // For Push Constants, this is the lowest offset of all memebers
    offset           : u32; // Measured in bytes
    absolute_offset  : u32; // Measured in bytes
    size             : u32; // Measured in bytes
    padded_size      : u32; // Measured in bytes
    decoration_flags : SpvReflectDecorationFlags;
    numeric          : SpvReflectNumericTraits;
    array            : SpvReflectArrayTraits;
    flags            : SpvReflectVariableFlags;

    member_count     : u32;
    members          : *SpvReflectBlockVariable;

    type_description : *SpvReflectTypeDescription;

    word_offset      : struct {
        offset       : u32;
    };
}

/*! @struct SpvReflectDescriptorBinding

*/
SpvReflectDescriptorBinding :: struct {
    spirv_id                         : u32;
    name                             : *u8;
    binding                          : u32;
    input_attachment_index           : u32;
    set                              : u32;
    descriptor_type                  : SpvReflectDescriptorType;
    resource_type                    : SpvReflectResourceType;
    image                            : SpvReflectImageTraits;
    block                            : SpvReflectBlockVariable;
    array                            : SpvReflectBindingArrayTraits;
    count                            : u32;
    accessed                         : u32;
    uav_counter_id                   : u32;
    uav_counter_binding              : *SpvReflectDescriptorBinding;
    byte_address_buffer_offset_count : u32;
    byte_address_buffer_offsets      : *u32;

    type_description                 : *SpvReflectTypeDescription;

    word_offset                      : struct {
        binding                      : u32;
        set                          : u32;
    };

    decoration_flags                 : SpvReflectDecorationFlags;
    // Requires SPV_GOOGLE_user_type
    user_type                        : SpvReflectUserType;
}

/*! @struct SpvReflectDescriptorSet

*/
SpvReflectDescriptorSet :: struct {
    set           : u32;
    binding_count : u32;
    bindings      : **SpvReflectDescriptorBinding;
}

/*! @struct SpvReflectEntryPoint

 */
SpvReflectEntryPoint :: struct {
    name                     : *u8;
    id                       : u32;

    spirv_execution_model    : SpvExecutionModel;
    shader_stage             : SpvReflectShaderStageFlags;

    input_variable_count     : u32;
    input_variables          : **SpvReflectInterfaceVariable;
    output_variable_count    : u32;
    output_variables         : **SpvReflectInterfaceVariable;
    interface_variable_count : u32;
    interface_variables      : *SpvReflectInterfaceVariable;

    descriptor_set_count     : u32;
    descriptor_sets          : *SpvReflectDescriptorSet;

    used_uniform_count       : u32;
    used_uniforms            : *u32;
    used_push_constant_count : u32;
    used_push_constants      : *u32;

    execution_mode_count     : u32;
    execution_modes          : *SpvExecutionMode;

    LocalSize :: struct {
        x                    : u32;
        y                    : u32;
        z                    : u32;
    }
    local_size               : LocalSize;

    invocations              : u32; // valid for geometry
    output_vertices          : u32; // valid for geometry, tesselation
}

/*! @struct SpvReflectCapability

*/
SpvReflectCapability :: struct {
    value       : SpvCapability;
    word_offset : u32;
}

/*! @struct SpvReflectSpecId

*/
SpvReflectSpecializationConstant :: struct {
    spirv_id    : u32;
    constant_id : u32;
    name        : *u8;
}

/*! @struct SpvReflectShaderModule

*/
SpvReflectShaderModule :: struct {
    generator                 : SpvReflectGenerator;
    entry_point_name          : *u8;
    entry_point_id            : u32;
    entry_point_count         : u32;
    entry_points              : *SpvReflectEntryPoint;
    source_language           : SpvSourceLanguage;
    source_language_version   : u32;
    source_file               : *u8;
    source_source             : *u8;
    capability_count          : u32;
    capabilities              : *SpvReflectCapability;
    spirv_execution_model     : SpvExecutionModel;                                         // Uses value(s) from first entry point
    shader_stage              : SpvReflectShaderStageFlags;                                // Uses value(s) from first entry point
    descriptor_binding_count  : u32;                                                       // Uses value(s) from first entry point
    descriptor_bindings       : *SpvReflectDescriptorBinding;                              // Uses value(s) from first entry point
    descriptor_set_count      : u32;                                                       // Uses value(s) from first entry point
    descriptor_sets           : [SPV_REFLECT_MAX_DESCRIPTOR_SETS] SpvReflectDescriptorSet; // Uses value(s) from first entry point
    input_variable_count      : u32;                                                       // Uses value(s) from first entry point
    input_variables           : **SpvReflectInterfaceVariable;                             // Uses value(s) from first entry point
    output_variable_count     : u32;                                                       // Uses value(s) from first entry point
    output_variables          : **SpvReflectInterfaceVariable;                             // Uses value(s) from first entry point
    interface_variable_count  : u32;                                                       // Uses value(s) from first entry point
    interface_variables       : *SpvReflectInterfaceVariable;                              // Uses value(s) from first entry point
    push_constant_block_count : u32;                                                       // Uses value(s) from first entry point
    push_constant_blocks      : *SpvReflectBlockVariable;                                  // Uses value(s) from first entry point
    spec_constant_count       : u32;                                                       // Uses value(s) from first entry point
    spec_constants            : *SpvReflectSpecializationConstant;                         // Uses value(s) from first entry point

    Internal :: struct {
        module_flags     : SpvReflectModuleFlags;
        spirv_size       : size_t;
        spirv_code       : *u32;
        spirv_word_count : u32;

        type_description_count : size_t;
        type_descriptions      : *SpvReflectTypeDescription;
    }

    _internal : *Internal;
}

/*! @fn spvReflectCreateShaderModule2

 @param  flags     Flags for module creations.
 @param  size      Size in bytes of SPIR-V code.
 @param  p_code    Pointer to SPIR-V code.
 @param  p_module  Pointer to an instance of SpvReflectShaderModule.
 @return           SPV_REFLECT_RESULT_SUCCESS on success.

*/
spvReflectCreateShaderModule2 :: (
  flags    : SpvReflectModuleFlags,
  size     : size_t,
  p_code   : *void,
  p_module : *SpvReflectShaderModule
) -> SpvReflectResult #foreign spirv_reflect;

/*! @fn spvReflectDestroyShaderModule

 @param  p_module  Pointer to an instance of SpvReflectShaderModule.

*/
spvReflectDestroyShaderModule :: (
    p_module : *SpvReflectShaderModule
) #foreign spirv_reflect;

#scope_file

#if DEBUG_BUILD {
    spirv_reflect :: #library,system,no_dll "spirv-reflectd";
} else {
    spirv_reflect :: #library,system,no_dll "spirv-reflect";
}

size_t :: u64; // We target only 64-bit systems, so... whatever.
