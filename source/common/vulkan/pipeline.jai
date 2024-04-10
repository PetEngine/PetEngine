#scope_export

// Provided by VK_VERSION_1_0
VkPipelineCache :: *VkPipelineCache_T; VkPipelineCache_T :: struct {}

// Provided by VK_VERSION_1_0
VkPipelineLayout :: *VkPipelineLayout_T; VkPipelineLayout_T :: struct {}

// Provided by VK_VERSION_1_0
VkPipeline :: *VkPipeline_T; VkPipeline_T :: struct {}

// Provided by VK_VERSION_1_0
VkShaderModule :: *VkShaderModule_T; VkShaderModule_T :: struct {}

// Provided by VK_VERSION_1_0
VkSampleMask :: #type,distinct u32;

// Provided by VK_VERSION_1_0
VkVertexInputRate :: enum VkEnum #specified {
    VK_VERTEX_INPUT_RATE_VERTEX   :: 0;
    VK_VERTEX_INPUT_RATE_INSTANCE :: 1;
}

// Provided by VK_VERSION_1_0
VkPrimitiveTopology :: enum VkEnum #specified {
    VK_PRIMITIVE_TOPOLOGY_POINT_LIST                    :: 0;
    VK_PRIMITIVE_TOPOLOGY_LINE_LIST                     :: 1;
    VK_PRIMITIVE_TOPOLOGY_LINE_STRIP                    :: 2;
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST                 :: 3;
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP                :: 4;
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_FAN                  :: 5;
    VK_PRIMITIVE_TOPOLOGY_LINE_LIST_WITH_ADJACENCY      :: 6;
    VK_PRIMITIVE_TOPOLOGY_LINE_STRIP_WITH_ADJACENCY     :: 7;
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST_WITH_ADJACENCY  :: 8;
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP_WITH_ADJACENCY :: 9;
    VK_PRIMITIVE_TOPOLOGY_PATCH_LIST                    :: 10;
}

// Provided by VK_VERSION_1_0
VkPolygonMode :: enum VkEnum #specified {
    VK_POLYGON_MODE_FILL              :: 0;
    VK_POLYGON_MODE_LINE              :: 1;
    VK_POLYGON_MODE_POINT             :: 2;
    // Provided by VK_NV_fill_rectangle
    VK_POLYGON_MODE_FILL_RECTANGLE_NV :: 1000153000;
}

// Provided by VK_VERSION_1_0
VkFrontFace :: enum VkEnum #specified {
    VK_FRONT_FACE_COUNTER_CLOCKWISE :: 0;
    VK_FRONT_FACE_CLOCKWISE         :: 1;
}

// Provided by VK_VERSION_1_0
VkCompareOp :: enum VkEnum #specified {
    VK_COMPARE_OP_NEVER            :: 0;
    VK_COMPARE_OP_LESS             :: 1;
    VK_COMPARE_OP_EQUAL            :: 2;
    VK_COMPARE_OP_LESS_OR_EQUAL    :: 3;
    VK_COMPARE_OP_GREATER          :: 4;
    VK_COMPARE_OP_NOT_EQUAL        :: 5;
    VK_COMPARE_OP_GREATER_OR_EQUAL :: 6;
    VK_COMPARE_OP_ALWAYS           :: 7;
}

// Provided by VK_VERSION_1_0
VkStencilOp :: enum VkEnum #specified {
    VK_STENCIL_OP_KEEP                :: 0;
    VK_STENCIL_OP_ZERO                :: 1;
    VK_STENCIL_OP_REPLACE             :: 2;
    VK_STENCIL_OP_INCREMENT_AND_CLAMP :: 3;
    VK_STENCIL_OP_DECREMENT_AND_CLAMP :: 4;
    VK_STENCIL_OP_INVERT              :: 5;
    VK_STENCIL_OP_INCREMENT_AND_WRAP  :: 6;
    VK_STENCIL_OP_DECREMENT_AND_WRAP  :: 7;
}

// Provided by VK_VERSION_1_0
VkLogicOp :: enum VkEnum #specified {
    VK_LOGIC_OP_CLEAR         :: 0;
    VK_LOGIC_OP_AND           :: 1;
    VK_LOGIC_OP_AND_REVERSE   :: 2;
    VK_LOGIC_OP_COPY          :: 3;
    VK_LOGIC_OP_AND_INVERTED  :: 4;
    VK_LOGIC_OP_NO_OP         :: 5;
    VK_LOGIC_OP_XOR           :: 6;
    VK_LOGIC_OP_OR            :: 7;
    VK_LOGIC_OP_NOR           :: 8;
    VK_LOGIC_OP_EQUIVALENT    :: 9;
    VK_LOGIC_OP_INVERT        :: 10;
    VK_LOGIC_OP_OR_REVERSE    :: 11;
    VK_LOGIC_OP_COPY_INVERTED :: 12;
    VK_LOGIC_OP_OR_INVERTED   :: 13;
    VK_LOGIC_OP_NAND          :: 14;
    VK_LOGIC_OP_SET           :: 15;
}

// Provided by VK_VERSION_1_0
VkBlendFactor :: enum VkEnum #specified {
    VK_BLEND_FACTOR_ZERO                     :: 0;
    VK_BLEND_FACTOR_ONE                      :: 1;
    VK_BLEND_FACTOR_SRC_COLOR                :: 2;
    VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR      :: 3;
    VK_BLEND_FACTOR_DST_COLOR                :: 4;
    VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR      :: 5;
    VK_BLEND_FACTOR_SRC_ALPHA                :: 6;
    VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA      :: 7;
    VK_BLEND_FACTOR_DST_ALPHA                :: 8;
    VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA      :: 9;
    VK_BLEND_FACTOR_CONSTANT_COLOR           :: 10;
    VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR :: 11;
    VK_BLEND_FACTOR_CONSTANT_ALPHA           :: 12;
    VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_ALPHA :: 13;
    VK_BLEND_FACTOR_SRC_ALPHA_SATURATE       :: 14;
    VK_BLEND_FACTOR_SRC1_COLOR               :: 15;
    VK_BLEND_FACTOR_ONE_MINUS_SRC1_COLOR     :: 16;
    VK_BLEND_FACTOR_SRC1_ALPHA               :: 17;
    VK_BLEND_FACTOR_ONE_MINUS_SRC1_ALPHA     :: 18;
}

// Provided by VK_VERSION_1_0
VkBlendOp :: enum VkEnum #specified {
    VK_BLEND_OP_ADD                    :: 0;
    VK_BLEND_OP_SUBTRACT               :: 1;
    VK_BLEND_OP_REVERSE_SUBTRACT       :: 2;
    VK_BLEND_OP_MIN                    :: 3;
    VK_BLEND_OP_MAX                    :: 4;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_ZERO_EXT               :: 1000148000;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_SRC_EXT                :: 1000148001;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_DST_EXT                :: 1000148002;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_SRC_OVER_EXT           :: 1000148003;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_DST_OVER_EXT           :: 1000148004;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_SRC_IN_EXT             :: 1000148005;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_DST_IN_EXT             :: 1000148006;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_SRC_OUT_EXT            :: 1000148007;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_DST_OUT_EXT            :: 1000148008;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_SRC_ATOP_EXT           :: 1000148009;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_DST_ATOP_EXT           :: 1000148010;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_XOR_EXT                :: 1000148011;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_MULTIPLY_EXT           :: 1000148012;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_SCREEN_EXT             :: 1000148013;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_OVERLAY_EXT            :: 1000148014;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_DARKEN_EXT             :: 1000148015;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_LIGHTEN_EXT            :: 1000148016;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_COLORDODGE_EXT         :: 1000148017;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_COLORBURN_EXT          :: 1000148018;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_HARDLIGHT_EXT          :: 1000148019;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_SOFTLIGHT_EXT          :: 1000148020;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_DIFFERENCE_EXT         :: 1000148021;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_EXCLUSION_EXT          :: 1000148022;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_INVERT_EXT             :: 1000148023;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_INVERT_RGB_EXT         :: 1000148024;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_LINEARDODGE_EXT        :: 1000148025;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_LINEARBURN_EXT         :: 1000148026;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_VIVIDLIGHT_EXT         :: 1000148027;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_LINEARLIGHT_EXT        :: 1000148028;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_PINLIGHT_EXT           :: 1000148029;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_HARDMIX_EXT            :: 1000148030;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_HSL_HUE_EXT            :: 1000148031;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_HSL_SATURATION_EXT     :: 1000148032;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_HSL_COLOR_EXT          :: 1000148033;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_HSL_LUMINOSITY_EXT     :: 1000148034;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_PLUS_EXT               :: 1000148035;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_PLUS_CLAMPED_EXT       :: 1000148036;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_PLUS_CLAMPED_ALPHA_EXT :: 1000148037;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_PLUS_DARKER_EXT        :: 1000148038;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_MINUS_EXT              :: 1000148039;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_MINUS_CLAMPED_EXT      :: 1000148040;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_CONTRAST_EXT           :: 1000148041;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_INVERT_OVG_EXT         :: 1000148042;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_RED_EXT                :: 1000148043;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_GREEN_EXT              :: 1000148044;
    // Provided by VK_EXT_blend_operation_advanced
    VK_BLEND_OP_BLUE_EXT               :: 1000148045;
}

// Provided by VK_VERSION_1_0
VkDynamicState :: enum VkEnum #specified {
    VK_DYNAMIC_STATE_VIEWPORT                                :: 0;
    VK_DYNAMIC_STATE_SCISSOR                                 :: 1;
    VK_DYNAMIC_STATE_LINE_WIDTH                              :: 2;
    VK_DYNAMIC_STATE_DEPTH_BIAS                              :: 3;
    VK_DYNAMIC_STATE_BLEND_CONSTANTS                         :: 4;
    VK_DYNAMIC_STATE_DEPTH_BOUNDS                            :: 5;
    VK_DYNAMIC_STATE_STENCIL_COMPARE_MASK                    :: 6;
    VK_DYNAMIC_STATE_STENCIL_WRITE_MASK                      :: 7;
    VK_DYNAMIC_STATE_STENCIL_REFERENCE                       :: 8;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_CULL_MODE                               :: 1000267000;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_FRONT_FACE                              :: 1000267001;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_PRIMITIVE_TOPOLOGY                      :: 1000267002;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_VIEWPORT_WITH_COUNT                     :: 1000267003;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_SCISSOR_WITH_COUNT                      :: 1000267004;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_VERTEX_INPUT_BINDING_STRIDE             :: 1000267005;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_DEPTH_TEST_ENABLE                       :: 1000267006;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_DEPTH_WRITE_ENABLE                      :: 1000267007;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_DEPTH_COMPARE_OP                        :: 1000267008;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_DEPTH_BOUNDS_TEST_ENABLE                :: 1000267009;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_STENCIL_TEST_ENABLE                     :: 1000267010;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_STENCIL_OP                              :: 1000267011;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_RASTERIZER_DISCARD_ENABLE               :: 1000377001;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_DEPTH_BIAS_ENABLE                       :: 1000377002;
    // Provided by VK_VERSION_1_3
    VK_DYNAMIC_STATE_PRIMITIVE_RESTART_ENABLE                :: 1000377004;
    // Provided by VK_NV_clip_space_w_scaling
    VK_DYNAMIC_STATE_VIEWPORT_W_SCALING_NV                   :: 1000087000;
    // Provided by VK_EXT_discard_rectangles
    VK_DYNAMIC_STATE_DISCARD_RECTANGLE_EXT                   :: 1000099000;
    // Provided by VK_EXT_discard_rectangles
    VK_DYNAMIC_STATE_DISCARD_RECTANGLE_ENABLE_EXT            :: 1000099001;
    // Provided by VK_EXT_discard_rectangles
    VK_DYNAMIC_STATE_DISCARD_RECTANGLE_MODE_EXT              :: 1000099002;
    // Provided by VK_EXT_sample_locations
    VK_DYNAMIC_STATE_SAMPLE_LOCATIONS_EXT                    :: 1000143000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_DYNAMIC_STATE_RAY_TRACING_PIPELINE_STACK_SIZE_KHR     :: 1000347000;
    // Provided by VK_NV_shading_rate_image
    VK_DYNAMIC_STATE_VIEWPORT_SHADING_RATE_PALETTE_NV        :: 1000164004;
    // Provided by VK_NV_shading_rate_image
    VK_DYNAMIC_STATE_VIEWPORT_COARSE_SAMPLE_ORDER_NV         :: 1000164006;
    // Provided by VK_NV_scissor_exclusive
    VK_DYNAMIC_STATE_EXCLUSIVE_SCISSOR_ENABLE_NV             :: 1000205000;
    // Provided by VK_NV_scissor_exclusive
    VK_DYNAMIC_STATE_EXCLUSIVE_SCISSOR_NV                    :: 1000205001;
    // Provided by VK_KHR_fragment_shading_rate
    VK_DYNAMIC_STATE_FRAGMENT_SHADING_RATE_KHR               :: 1000226000;
    // Provided by VK_EXT_line_rasterization
    VK_DYNAMIC_STATE_LINE_STIPPLE_EXT                        :: 1000259000;
    // Provided by VK_EXT_vertex_input_dynamic_state
    VK_DYNAMIC_STATE_VERTEX_INPUT_EXT                        :: 1000352000;
    // Provided by VK_EXT_extended_dynamic_state2
    VK_DYNAMIC_STATE_PATCH_CONTROL_POINTS_EXT                :: 1000377000;
    // Provided by VK_EXT_extended_dynamic_state2
    VK_DYNAMIC_STATE_LOGIC_OP_EXT                            :: 1000377003;
    // Provided by VK_EXT_color_write_enable
    VK_DYNAMIC_STATE_COLOR_WRITE_ENABLE_EXT                  :: 1000381000;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_TESSELLATION_DOMAIN_ORIGIN_EXT          :: 1000455002;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_DEPTH_CLAMP_ENABLE_EXT                  :: 1000455003;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_POLYGON_MODE_EXT                        :: 1000455004;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_RASTERIZATION_SAMPLES_EXT               :: 1000455005;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_SAMPLE_MASK_EXT                         :: 1000455006;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_ALPHA_TO_COVERAGE_ENABLE_EXT            :: 1000455007;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_ALPHA_TO_ONE_ENABLE_EXT                 :: 1000455008;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_LOGIC_OP_ENABLE_EXT                     :: 1000455009;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COLOR_BLEND_ENABLE_EXT                  :: 1000455010;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COLOR_BLEND_EQUATION_EXT                :: 1000455011;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COLOR_WRITE_MASK_EXT                    :: 1000455012;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_RASTERIZATION_STREAM_EXT                :: 1000455013;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_CONSERVATIVE_RASTERIZATION_MODE_EXT     :: 1000455014;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_EXTRA_PRIMITIVE_OVERESTIMATION_SIZE_EXT :: 1000455015;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_DEPTH_CLIP_ENABLE_EXT                   :: 1000455016;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_SAMPLE_LOCATIONS_ENABLE_EXT             :: 1000455017;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COLOR_BLEND_ADVANCED_EXT                :: 1000455018;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_PROVOKING_VERTEX_MODE_EXT               :: 1000455019;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_LINE_RASTERIZATION_MODE_EXT             :: 1000455020;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_LINE_STIPPLE_ENABLE_EXT                 :: 1000455021;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_DEPTH_CLIP_NEGATIVE_ONE_TO_ONE_EXT      :: 1000455022;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_VIEWPORT_W_SCALING_ENABLE_NV            :: 1000455023;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_VIEWPORT_SWIZZLE_NV                     :: 1000455024;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COVERAGE_TO_COLOR_ENABLE_NV             :: 1000455025;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COVERAGE_TO_COLOR_LOCATION_NV           :: 1000455026;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COVERAGE_MODULATION_MODE_NV             :: 1000455027;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COVERAGE_MODULATION_TABLE_ENABLE_NV     :: 1000455028;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COVERAGE_MODULATION_TABLE_NV            :: 1000455029;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_SHADING_RATE_IMAGE_ENABLE_NV            :: 1000455030;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_REPRESENTATIVE_FRAGMENT_TEST_ENABLE_NV  :: 1000455031;
    // Provided by VK_EXT_extended_dynamic_state3
    VK_DYNAMIC_STATE_COVERAGE_REDUCTION_MODE_NV              :: 1000455032;
    // Provided by VK_EXT_attachment_feedback_loop_dynamic_state
    VK_DYNAMIC_STATE_ATTACHMENT_FEEDBACK_LOOP_ENABLE_EXT     :: 1000524000;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_CULL_MODE_EXT                           :: VK_DYNAMIC_STATE_CULL_MODE;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_FRONT_FACE_EXT                          :: VK_DYNAMIC_STATE_FRONT_FACE;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_PRIMITIVE_TOPOLOGY_EXT                  :: VK_DYNAMIC_STATE_PRIMITIVE_TOPOLOGY;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_VIEWPORT_WITH_COUNT_EXT                 :: VK_DYNAMIC_STATE_VIEWPORT_WITH_COUNT;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_SCISSOR_WITH_COUNT_EXT                  :: VK_DYNAMIC_STATE_SCISSOR_WITH_COUNT;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_VERTEX_INPUT_BINDING_STRIDE_EXT         :: VK_DYNAMIC_STATE_VERTEX_INPUT_BINDING_STRIDE;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_DEPTH_TEST_ENABLE_EXT                   :: VK_DYNAMIC_STATE_DEPTH_TEST_ENABLE;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_DEPTH_WRITE_ENABLE_EXT                  :: VK_DYNAMIC_STATE_DEPTH_WRITE_ENABLE;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_DEPTH_COMPARE_OP_EXT                    :: VK_DYNAMIC_STATE_DEPTH_COMPARE_OP;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_DEPTH_BOUNDS_TEST_ENABLE_EXT            :: VK_DYNAMIC_STATE_DEPTH_BOUNDS_TEST_ENABLE;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_STENCIL_TEST_ENABLE_EXT                 :: VK_DYNAMIC_STATE_STENCIL_TEST_ENABLE;
    // Provided by VK_EXT_extended_dynamic_state
    VK_DYNAMIC_STATE_STENCIL_OP_EXT                          :: VK_DYNAMIC_STATE_STENCIL_OP;
    // Provided by VK_EXT_extended_dynamic_state2
    VK_DYNAMIC_STATE_RASTERIZER_DISCARD_ENABLE_EXT           :: VK_DYNAMIC_STATE_RASTERIZER_DISCARD_ENABLE;
    // Provided by VK_EXT_extended_dynamic_state2
    VK_DYNAMIC_STATE_DEPTH_BIAS_ENABLE_EXT                   :: VK_DYNAMIC_STATE_DEPTH_BIAS_ENABLE;
    // Provided by VK_EXT_extended_dynamic_state2
    VK_DYNAMIC_STATE_PRIMITIVE_RESTART_ENABLE_EXT            :: VK_DYNAMIC_STATE_PRIMITIVE_RESTART_ENABLE;
}

// Provided by VK_VERSION_1_0
VkPipelineBindPoint :: enum VkEnum #specified {
    VK_PIPELINE_BIND_POINT_GRAPHICS               :: 0;
    VK_PIPELINE_BIND_POINT_COMPUTE                :: 1;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR        :: 1000165000;
    // Provided by VK_HUAWEI_subpass_shading
    VK_PIPELINE_BIND_POINT_SUBPASS_SHADING_HUAWEI :: 1000369003;
    // Provided by VK_NV_ray_tracing
    VK_PIPELINE_BIND_POINT_RAY_TRACING_NV         :: VK_PIPELINE_BIND_POINT_RAY_TRACING_KHR;
}

// Provided by VK_EXT_pipeline_creation_cache_control
VkPipelineCacheCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_VERSION_1_3
    VK_PIPELINE_CACHE_CREATE_EXTERNALLY_SYNCHRONIZED_BIT     :: 0x00000001;
    // Provided by VK_EXT_pipeline_creation_cache_control
    VK_PIPELINE_CACHE_CREATE_EXTERNALLY_SYNCHRONIZED_BIT_EXT :: VK_PIPELINE_CACHE_CREATE_EXTERNALLY_SYNCHRONIZED_BIT;
}

// Provided by VK_EXT_graphics_pipeline_library
VkPipelineLayoutCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_EXT_graphics_pipeline_library
    VK_PIPELINE_LAYOUT_CREATE_INDEPENDENT_SETS_BIT_EXT :: 0x00000002;
}

// Provided by VK_VERSION_1_0
VkShaderStageFlags :: enum_flags VkFlags #specified {
    VK_SHADER_STAGE_VERTEX_BIT                  :: 0x00000001;
    VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT    :: 0x00000002;
    VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT :: 0x00000004;
    VK_SHADER_STAGE_GEOMETRY_BIT                :: 0x00000008;
    VK_SHADER_STAGE_FRAGMENT_BIT                :: 0x00000010;
    VK_SHADER_STAGE_COMPUTE_BIT                 :: 0x00000020;
    VK_SHADER_STAGE_ALL_GRAPHICS                :: 0x0000001F;
    VK_SHADER_STAGE_ALL                         :: 0x7FFFFFFF;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_SHADER_STAGE_RAYGEN_BIT_KHR              :: 0x00000100;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_SHADER_STAGE_ANY_HIT_BIT_KHR             :: 0x00000200;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR         :: 0x00000400;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_SHADER_STAGE_MISS_BIT_KHR                :: 0x00000800;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_SHADER_STAGE_INTERSECTION_BIT_KHR        :: 0x00001000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_SHADER_STAGE_CALLABLE_BIT_KHR            :: 0x00002000;
    // Provided by VK_EXT_mesh_shader
    VK_SHADER_STAGE_TASK_BIT_EXT                :: 0x00000040;
    // Provided by VK_EXT_mesh_shader
    VK_SHADER_STAGE_MESH_BIT_EXT                :: 0x00000080;
    // Provided by VK_HUAWEI_subpass_shading
    VK_SHADER_STAGE_SUBPASS_SHADING_BIT_HUAWEI  :: 0x00004000;
    // Provided by VK_HUAWEI_cluster_culling_shader
    VK_SHADER_STAGE_CLUSTER_CULLING_BIT_HUAWEI  :: 0x00080000;
    // Provided by VK_NV_ray_tracing
    VK_SHADER_STAGE_RAYGEN_BIT_NV               :: VK_SHADER_STAGE_RAYGEN_BIT_KHR;
    // Provided by VK_NV_ray_tracing
    VK_SHADER_STAGE_ANY_HIT_BIT_NV              :: VK_SHADER_STAGE_ANY_HIT_BIT_KHR;
    // Provided by VK_NV_ray_tracing
    VK_SHADER_STAGE_CLOSEST_HIT_BIT_NV          :: VK_SHADER_STAGE_CLOSEST_HIT_BIT_KHR;
    // Provided by VK_NV_ray_tracing
    VK_SHADER_STAGE_MISS_BIT_NV                 :: VK_SHADER_STAGE_MISS_BIT_KHR;
    // Provided by VK_NV_ray_tracing
    VK_SHADER_STAGE_INTERSECTION_BIT_NV         :: VK_SHADER_STAGE_INTERSECTION_BIT_KHR;
    // Provided by VK_NV_ray_tracing
    VK_SHADER_STAGE_CALLABLE_BIT_NV             :: VK_SHADER_STAGE_CALLABLE_BIT_KHR;
    // Provided by VK_NV_mesh_shader
    VK_SHADER_STAGE_TASK_BIT_NV                 :: VK_SHADER_STAGE_TASK_BIT_EXT;
    // Provided by VK_NV_mesh_shader
    VK_SHADER_STAGE_MESH_BIT_NV                 :: VK_SHADER_STAGE_MESH_BIT_EXT;
}

// Provided by VK_VERSION_1_0
VkPipelineCreateFlags :: enum_flags VkFlags #specified {
    VK_PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT                                     :: 0x00000001;
    VK_PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT                                        :: 0x00000002;
    VK_PIPELINE_CREATE_DERIVATIVE_BIT                                               :: 0x00000004;
    // Provided by VK_VERSION_1_1
    VK_PIPELINE_CREATE_VIEW_INDEX_FROM_DEVICE_INDEX_BIT                             :: 0x00000008;
    // Provided by VK_VERSION_1_1
    VK_PIPELINE_CREATE_DISPATCH_BASE_BIT                                            :: 0x00000010;
    // Provided by VK_VERSION_1_3
    VK_PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT                        :: 0x00000100;
    // Provided by VK_VERSION_1_3
    VK_PIPELINE_CREATE_EARLY_RETURN_ON_FAILURE_BIT                                  :: 0x00000200;
    // Provided by VK_KHR_dynamic_rendering with VK_KHR_fragment_shading_rate
    VK_PIPELINE_CREATE_RENDERING_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR           :: 0x00200000;
    // Provided by VK_KHR_dynamic_rendering with VK_EXT_fragment_density_map
    VK_PIPELINE_CREATE_RENDERING_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT            :: 0x00400000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_CREATE_RAY_TRACING_NO_NULL_ANY_HIT_SHADERS_BIT_KHR                  :: 0x00004000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_CREATE_RAY_TRACING_NO_NULL_CLOSEST_HIT_SHADERS_BIT_KHR              :: 0x00008000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_CREATE_RAY_TRACING_NO_NULL_MISS_SHADERS_BIT_KHR                     :: 0x00010000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_CREATE_RAY_TRACING_NO_NULL_INTERSECTION_SHADERS_BIT_KHR             :: 0x00020000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_CREATE_RAY_TRACING_SKIP_TRIANGLES_BIT_KHR                           :: 0x00001000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_CREATE_RAY_TRACING_SKIP_AABBS_BIT_KHR                               :: 0x00002000;
    // Provided by VK_KHR_ray_tracing_pipeline
    VK_PIPELINE_CREATE_RAY_TRACING_SHADER_GROUP_HANDLE_CAPTURE_REPLAY_BIT_KHR       :: 0x00080000;
    // Provided by VK_NV_ray_tracing
    VK_PIPELINE_CREATE_DEFER_COMPILE_BIT_NV                                         :: 0x00000020;
    // Provided by VK_KHR_pipeline_executable_properties
    VK_PIPELINE_CREATE_CAPTURE_STATISTICS_BIT_KHR                                   :: 0x00000040;
    // Provided by VK_KHR_pipeline_executable_properties
    VK_PIPELINE_CREATE_CAPTURE_INTERNAL_REPRESENTATIONS_BIT_KHR                     :: 0x00000080;
    // Provided by VK_NV_device_generated_commands
    VK_PIPELINE_CREATE_INDIRECT_BINDABLE_BIT_NV                                     :: 0x00040000;
    // Provided by VK_KHR_pipeline_library
    VK_PIPELINE_CREATE_LIBRARY_BIT_KHR                                              :: 0x00000800;
    // Provided by VK_EXT_descriptor_buffer
    VK_PIPELINE_CREATE_DESCRIPTOR_BUFFER_BIT_EXT                                    :: 0x20000000;
    // Provided by VK_EXT_graphics_pipeline_library
    VK_PIPELINE_CREATE_RETAIN_LINK_TIME_OPTIMIZATION_INFO_BIT_EXT                   :: 0x00800000;
    // Provided by VK_EXT_graphics_pipeline_library
    VK_PIPELINE_CREATE_LINK_TIME_OPTIMIZATION_BIT_EXT                               :: 0x00000400;
    // Provided by VK_NV_ray_tracing_motion_blur
    VK_PIPELINE_CREATE_RAY_TRACING_ALLOW_MOTION_BIT_NV                              :: 0x00100000;
    // Provided by VK_EXT_attachment_feedback_loop_layout
    VK_PIPELINE_CREATE_COLOR_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT                       :: 0x02000000;
    // Provided by VK_EXT_attachment_feedback_loop_layout
    VK_PIPELINE_CREATE_DEPTH_STENCIL_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT               :: 0x04000000;
    // Provided by VK_EXT_opacity_micromap
    VK_PIPELINE_CREATE_RAY_TRACING_OPACITY_MICROMAP_BIT_EXT                         :: 0x01000000;
#if VK_ENABLE_BETA_EXTENSIONS {
    // Provided by VK_NV_displacement_micromap
    VK_PIPELINE_CREATE_RAY_TRACING_DISPLACEMENT_MICROMAP_BIT_NV                     :: 0x10000000;
}
    // Provided by VK_EXT_pipeline_protected_access
    VK_PIPELINE_CREATE_NO_PROTECTED_ACCESS_BIT_EXT                                  :: 0x08000000;
    // Provided by VK_EXT_pipeline_protected_access
    VK_PIPELINE_CREATE_PROTECTED_ACCESS_ONLY_BIT_EXT                                :: 0x40000000;
    // Provided by VK_VERSION_1_1
    VK_PIPELINE_CREATE_DISPATCH_BASE                                                :: VK_PIPELINE_CREATE_DISPATCH_BASE_BIT;
    // Provided by VK_KHR_dynamic_rendering with VK_KHR_fragment_shading_rate
    VK_PIPELINE_RASTERIZATION_STATE_CREATE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR :: VK_PIPELINE_CREATE_RENDERING_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR;
    // Provided by VK_KHR_dynamic_rendering with VK_EXT_fragment_density_map
    VK_PIPELINE_RASTERIZATION_STATE_CREATE_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT  :: VK_PIPELINE_CREATE_RENDERING_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT;
    // Provided by VK_KHR_device_group
    VK_PIPELINE_CREATE_VIEW_INDEX_FROM_DEVICE_INDEX_BIT_KHR                         :: VK_PIPELINE_CREATE_VIEW_INDEX_FROM_DEVICE_INDEX_BIT;
    // Provided by VK_KHR_device_group
    VK_PIPELINE_CREATE_DISPATCH_BASE_KHR                                            :: VK_PIPELINE_CREATE_DISPATCH_BASE;
    // Provided by VK_EXT_pipeline_creation_cache_control
    VK_PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT_EXT                    :: VK_PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT;
    // Provided by VK_EXT_pipeline_creation_cache_control
    VK_PIPELINE_CREATE_EARLY_RETURN_ON_FAILURE_BIT_EXT                              :: VK_PIPELINE_CREATE_EARLY_RETURN_ON_FAILURE_BIT;
}

// Provided by VK_VERSION_1_0
VkPipelineShaderStageCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_VERSION_1_3
    VK_PIPELINE_SHADER_STAGE_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT     :: 0x00000001;
    // Provided by VK_VERSION_1_3
    VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT          :: 0x00000002;
    // Provided by VK_EXT_subgroup_size_control
    VK_PIPELINE_SHADER_STAGE_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT_EXT :: VK_PIPELINE_SHADER_STAGE_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT;
    // Provided by VK_EXT_subgroup_size_control
    VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT_EXT      :: VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT;
}

// Provided by VK_VERSION_1_0
VkPipelineVertexInputStateCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_0
VkPipelineInputAssemblyStateCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_0
VkPipelineTessellationStateCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_0
VkPipelineViewportStateCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_0
VkPipelineRasterizationStateCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_0
VkCullModeFlags :: enum_flags VkFlags #specified {
    VK_CULL_MODE_NONE           :: 0;
    VK_CULL_MODE_FRONT_BIT      :: 0x00000001;
    VK_CULL_MODE_BACK_BIT       :: 0x00000002;
    VK_CULL_MODE_FRONT_AND_BACK :: 0x00000003;
}

// Provided by VK_VERSION_1_0
VkPipelineMultisampleStateCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_EXT_rasterization_order_attachment_access
VkPipelineDepthStencilStateCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_EXT_rasterization_order_attachment_access
    VK_PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_EXT   :: 0x00000001;
    // Provided by VK_EXT_rasterization_order_attachment_access
    VK_PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_EXT :: 0x00000002;
    // Provided by VK_ARM_rasterization_order_attachment_access
    VK_PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_ARM   :: VK_PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_EXT;
    // Provided by VK_ARM_rasterization_order_attachment_access
    VK_PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_ARM :: VK_PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_EXT;
}

// Provided by VK_EXT_rasterization_order_attachment_access
VkPipelineColorBlendStateCreateFlags :: enum_flags VkFlags #specified {
    // Provided by VK_EXT_rasterization_order_attachment_access
    VK_PIPELINE_COLOR_BLEND_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_ACCESS_BIT_EXT :: 0x00000001;
    // Provided by VK_ARM_rasterization_order_attachment_access
    VK_PIPELINE_COLOR_BLEND_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_ACCESS_BIT_ARM :: VK_PIPELINE_COLOR_BLEND_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_ACCESS_BIT_EXT;
}

// Provided by VK_VERSION_1_0
VkColorComponentFlags :: enum_flags VkFlags #specified {
    VK_COLOR_COMPONENT_R_BIT :: 0x00000001;
    VK_COLOR_COMPONENT_G_BIT :: 0x00000002;
    VK_COLOR_COMPONENT_B_BIT :: 0x00000004;
    VK_COLOR_COMPONENT_A_BIT :: 0x00000008;
}

// Provided by VK_VERSION_1_0
VkPipelineDynamicStateCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_0
VkShaderModuleCreateFlags :: enum_flags VkFlags #specified {
}

// Provided by VK_VERSION_1_0
VkPipelineCacheCreateInfo :: struct {
    sType           : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO;
    pNext           : *void;
    flags           : VkPipelineCacheCreateFlags;
    initialDataSize : size_t;
    pInitialData    : *void;
}

// Provided by VK_VERSION_1_0
VkPushConstantRange :: struct {
    stageFlags : VkShaderStageFlags;
    offset     : u32;
    size       : u32;
}

// Provided by VK_VERSION_1_0
VkPipelineLayoutCreateInfo :: struct {
    sType                  : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pNext                  : *void;
    flags                  : VkPipelineLayoutCreateFlags;
    setLayoutCount         : u32;
    pSetLayouts            : *VkDescriptorSetLayout;
    pushConstantRangeCount : u32;
    pPushConstantRanges    : *VkPushConstantRange;
}

// Provided by VK_VERSION_1_0
VkSpecializationMapEntry :: struct {
    constantID : u32;
    offset     : u32;
    size       : size_t;
}

// Provided by VK_VERSION_1_0
VkSpecializationInfo :: struct {
    mapEntryCount : u32;
    pMapEntries   : *VkSpecializationMapEntry;
    dataSize      : size_t;
    pData         : *void;
}

// Provided by VK_VERSION_1_0
VkPipelineShaderStageCreateInfo :: struct {
    sType               : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    pNext               : *void;
    flags               : VkPipelineShaderStageCreateFlags;
    stage               : VkShaderStageFlags;
    module              : VkShaderModule;
    pName               : *s8;
    pSpecializationInfo : *VkSpecializationInfo;
}

// Provided by VK_VERSION_1_0
VkVertexInputBindingDescription :: struct {
    binding   : u32;
    stride    : u32;
    inputRate : VkVertexInputRate;
}

// Provided by VK_VERSION_1_0
VkVertexInputAttributeDescription :: struct {
    location : u32;
    binding  : u32;
    format   : VkFormat;
    offset   : u32;
}

// Provided by VK_VERSION_1_0
VkPipelineVertexInputStateCreateInfo :: struct {
    sType                           : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    pNext                           : *void;
    flags                           : VkPipelineVertexInputStateCreateFlags;
    vertexBindingDescriptionCount   : u32;
    pVertexBindingDescriptions      : *VkVertexInputBindingDescription;
    vertexAttributeDescriptionCount : u32;
    pVertexAttributeDescriptions    : *VkVertexInputAttributeDescription;
}

// Provided by VK_VERSION_1_0
VkPipelineInputAssemblyStateCreateInfo :: struct {
    sType                  : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    pNext                  : *void;
    flags                  : VkPipelineInputAssemblyStateCreateFlags;
    topology               : VkPrimitiveTopology;
    primitiveRestartEnable : VkBool32;
}

// Provided by VK_VERSION_1_0
VkPipelineTessellationStateCreateInfo :: struct {
    sType              : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_TESSELLATION_STATE_CREATE_INFO;
    pNext              : *void;
    flags              : VkPipelineTessellationStateCreateFlags;
    patchControlPoints : u32;
}

// Provided by VK_VERSION_1_0
VkViewport :: struct {
    x        : f32;
    y        : f32;
    width    : f32;
    height   : f32;
    minDepth : f32;
    maxDepth : f32;
}

// Provided by VK_VERSION_1_0
VkPipelineViewportStateCreateInfo :: struct {
    sType         : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    pNext         : *void;
    flags         : VkPipelineViewportStateCreateFlags;
    viewportCount : u32;
    pViewports    : *VkViewport;
    scissorCount  : u32;
    pScissors     : *VkRect2D;
}

// Provided by VK_VERSION_1_0
VkPipelineRasterizationStateCreateInfo :: struct {
    sType                   : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    pNext                   : *void;
    flags                   : VkPipelineRasterizationStateCreateFlags;
    depthClampEnable        : VkBool32;
    rasterizerDiscardEnable : VkBool32;
    polygonMode             : VkPolygonMode;
    cullMode                : VkCullModeFlags;
    frontFace               : VkFrontFace;
    depthBiasEnable         : VkBool32;
    depthBiasConstantFactor : f32;
    depthBiasClamp          : f32;
    depthBiasSlopeFactor    : f32;
    lineWidth               : f32;
}

// Provided by VK_VERSION_1_0
VkPipelineMultisampleStateCreateInfo :: struct {
    sType                 : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    pNext                 : *void;
    flags                 : VkPipelineMultisampleStateCreateFlags;
    rasterizationSamples  : VkSampleCountFlags;
    sampleShadingEnable   : VkBool32;
    minSampleShading      : f32;
    pSampleMask           : *VkSampleMask;
    alphaToCoverageEnable : VkBool32;
    alphaToOneEnable      : VkBool32;
}

// Provided by VK_VERSION_1_0
VkStencilOpState :: struct {
    failOp      : VkStencilOp;
    passOp      : VkStencilOp;
    depthFailOp : VkStencilOp;
    compareOp   : VkCompareOp;
    compareMask : u32;
    writeMask   : u32;
    reference   : u32;
}

// Provided by VK_VERSION_1_0
VkPipelineDepthStencilStateCreateInfo :: struct {
    sType                 : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
    pNext                 : *void;
    flags                 : VkPipelineDepthStencilStateCreateFlags;
    depthTestEnable       : VkBool32;
    depthWriteEnable      : VkBool32;
    depthCompareOp        : VkCompareOp;
    depthBoundsTestEnable : VkBool32;
    stencilTestEnable     : VkBool32;
    front                 : VkStencilOpState;
    back                  : VkStencilOpState;
    minDepthBounds        : f32;
    maxDepthBounds        : f32;
}

// Provided by VK_VERSION_1_0
VkPipelineColorBlendAttachmentState :: struct {
    blendEnable         : VkBool32;
    srcColorBlendFactor : VkBlendFactor;
    dstColorBlendFactor : VkBlendFactor;
    colorBlendOp        : VkBlendOp;
    srcAlphaBlendFactor : VkBlendFactor;
    dstAlphaBlendFactor : VkBlendFactor;
    alphaBlendOp        : VkBlendOp;
    colorWriteMask      : VkColorComponentFlags;
}

// Provided by VK_VERSION_1_0
VkPipelineColorBlendStateCreateInfo :: struct {
    sType           : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    pNext           : *void;
    flags           : VkPipelineColorBlendStateCreateFlags;
    logicOpEnable   : VkBool32;
    logicOp         : VkLogicOp;
    attachmentCount : u32;
    pAttachments    : *VkPipelineColorBlendAttachmentState;
    blendConstants  : [4] f32;
}

// Provided by VK_VERSION_1_0
VkPipelineDynamicStateCreateInfo :: struct {
    sType             : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    pNext             : *void;
    flags             : VkPipelineDynamicStateCreateFlags;
    dynamicStateCount : u32;
    pDynamicStates    : *VkDynamicState;
}

// Provided by VK_VERSION_1_0
VkGraphicsPipelineCreateInfo :: struct {
    sType               : VkStructureType = .VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pNext               : *void;
    flags               : VkPipelineCreateFlags;
    stageCount          : u32;
    pStages             : *VkPipelineShaderStageCreateInfo;
    pVertexInputState   : *VkPipelineVertexInputStateCreateInfo;
    pInputAssemblyState : *VkPipelineInputAssemblyStateCreateInfo;
    pTessellationState  : *VkPipelineTessellationStateCreateInfo;
    pViewportState      : *VkPipelineViewportStateCreateInfo;
    pRasterizationState : *VkPipelineRasterizationStateCreateInfo;
    pMultisampleState   : *VkPipelineMultisampleStateCreateInfo;
    pDepthStencilState  : *VkPipelineDepthStencilStateCreateInfo;
    pColorBlendState    : *VkPipelineColorBlendStateCreateInfo;
    pDynamicState       : *VkPipelineDynamicStateCreateInfo;
    layout              : VkPipelineLayout;
    renderPass          : VkRenderPass;
    subpass             : u32;
    basePipelineHandle  : VkPipeline;
    basePipelineIndex   : s32;
}

// Provided by VK_VERSION_1_3
VkPipelineRenderingCreateInfo :: struct {
    sType                   : VkStructureType = .VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
    pNext                   : *void;
    viewMask                : u32;
    colorAttachmentCount    : u32;
    pColorAttachmentFormats : *VkFormat;
    depthAttachmentFormat   : VkFormat;
    stencilAttachmentFormat : VkFormat;
}

// Provided by VK_VERSION_1_0
VkShaderModuleCreateInfo :: struct {
    sType    : VkStructureType = .VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    pNext    : *void;
    flags    : VkShaderModuleCreateFlags;
    codeSize : size_t;
    pCode    : *u32;
}

// Provided by VK_VERSION_1_0
vkCreatePipelineCache :: (
    device         : VkDevice,
    pCreateInfo    : *VkPipelineCacheCreateInfo,
    pAllocator     : *VkAllocationCallbacks,
    pPipelineCache : *VkPipelineCache
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyPipelineCache :: (
    device        : VkDevice,
    pipelineCache : VkPipelineCache,
    pAllocator    : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCreatePipelineLayout :: (
    device          : VkDevice,
    pCreateInfo     : *VkPipelineLayoutCreateInfo,
    pAllocator      : *VkAllocationCallbacks,
    pPipelineLayout : *VkPipelineLayout
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyPipelineLayout :: (
    device         : VkDevice,
    pipelineLayout : VkPipelineLayout,
    pAllocator     : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCreateGraphicsPipelines :: (
    device          : VkDevice,
    pipelineCache   : VkPipelineCache,
    createInfoCount : u32,
    pCreateInfos    : *VkGraphicsPipelineCreateInfo,
    pAllocator      : *VkAllocationCallbacks,
    pPipelines      : *VkPipeline
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyPipeline :: (
    device     : VkDevice,
    pipeline   : VkPipeline,
    pAllocator : *VkAllocationCallbacks
) #foreign vulkan;

// Provided by VK_VERSION_1_0
vkCreateShaderModule :: (
    device        : VkDevice,
    pCreateInfo   : *VkShaderModuleCreateInfo,
    pAllocator    : *VkAllocationCallbacks,
    pShaderModule : *VkShaderModule
) -> VkResult #foreign vulkan;

// Provided by VK_VERSION_1_0
vkDestroyShaderModule :: (
    device       : VkDevice,
    shaderModule : VkShaderModule,
    pAllocator   : *VkAllocationCallbacks
) #foreign vulkan;