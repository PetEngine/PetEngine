## 1. Shader file structure

Shader file consists of several GLSL shaders and pipeline state description.

Each shader begins with `#<stage>_shader` keyword. `<stage>` can be only `vertex` or `fragment` for now. Code before first `#<stage>_shader` is visible to all shaders in the file.

Pipeline state description begins with `#pipeline_state` keyword.

## 2. Graphics pipeline state

Pipeline state description is just a set of parameters for pipeline creation.
Syntax is super trivial: `<parameter name> = <parameter value>;`.

### 2.1. PrimitiveTopology

Possible values:
- POINT_LIST
- LINE_LIST
- LINE_STRIP
- TRIANGLE_LIST
- TRIANGLE_STRIP

Default value:
- TRIANGLE_LIST

### 2.2. FillMode

[Points](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap28.html#primsrast-points) are not supported yet

Possible values:
- FILL
- LINE

Default value:
- FILL

### 2.3. CullMode

Possible values:
- NONE
- FRONT_FACE
- BACK_FACE

Default value:
- NONE

### 2.4. FrontFace

Possible values:
- CLOCKWISE
- COUNTER_CLOCKWISE

Default value:
- CLOCKWISE

### 2.5. DepthBiasEnable

Possible values:
- false
- true

Default value:
- false

### 2.7. DepthBiasClamp

Possible values:
- floating point value

Default value:
- 0

### 2.6. DepthBiasConstantFactor

Possible values:
- floating point value

Default value:
- 0

### 2.8. DepthBiasSlopeFactor

Possible values:
- floating point value

Default value:
- 0

### 2.9. DepthTestEnable

Possible values:
- false
- true

Default value:
- false

### 2.10. DepthWriteEnable

Possible values:
- false
- true

Default value:
- false

### 2.11. DepthCompareOp

Possible values:
- NEVER
- ALWAYS
- NOT_EQUAL
- EQUAL
- LESS
- LESS_OR_EQUAL
- GREATER
- GREATER_OR_EQUAL

Default value:
- GREATER

### 2.12. BlendLogicOpEnable

Only for signed, unsigned and normalized integer framebuffers.

Possible values:
- false
- true

Default value:
- false

### 2.13. BlendLogicOp

[Description of all operations](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap30.html#framebuffer-logicop).

Possible values:
- ZERO
- ONE
- COPY
- COPY_INVERTED
- NO_OP
- INVERT
- AND
- AND_REVERSE
- AND_INVERTED
- NAND
- OR
- OR_REVERSE
- OR_INVERTED
- NOR
- XOR
- EQUIVALENT

Default value:
- COPY

### 2.14. ColorTarget[`<index>`]
`<index>` must be less than number of out variables in fragment shader.
ColorTarget[`<index>`] is followed by dot followed by any name below e.g. `ColorTarget[0].WriteMask`.

**2.14.1. WriteMask**

Possible values:
- Any combination of `R` `G` `B` `A` without repetitions.

Default value:
- RGBA

**2.14.2. BlendEnable**

Possible values:
- false
- true

Default value:
- false

**2.14.3. SrcColorBlendFactor**

[Dual-source blending](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap30.html#framebuffer-dsb) is not supported yet.

Possible values:
- ZERO
- ONE
- SRC_COLOR
- ONE_MINUS_SRC_COLOR
- DST_COLOR
- ONE_MINUS_DST_COLOR
- SRC_ALPHA
- ONE_MINUS_SRC_ALPHA
- DST_ALPHA
- ONE_MINUS_DST_ALPHA
- CONSTANT_COLOR
- ONE_MINUS_CONSTANT_COLOR
- CONSTANT_ALPHA
- ONE_MINUS_CONSTANT_ALPHA
- SRC_ALPHA_SATURATE

Default value:
- SRC_COLOR

**2.14.4. DstColorBlendFactor**

[Dual-source blending](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap30.html#framebuffer-dsb) is not supported yet.

Possible values:
- ZERO
- ONE
- SRC_COLOR
- ONE_MINUS_SRC_COLOR
- DST_COLOR
- ONE_MINUS_DST_COLOR
- SRC_ALPHA
- ONE_MINUS_SRC_ALPHA
- DST_ALPHA
- ONE_MINUS_DST_ALPHA
- CONSTANT_COLOR
- ONE_MINUS_CONSTANT_COLOR
- CONSTANT_ALPHA
- ONE_MINUS_CONSTANT_ALPHA
- SRC_ALPHA_SATURATE

Default value:
- ZERO

**2.14.5. ColorBlendOp**

[VK_EXT_blend_operation_advanced](https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/VK_EXT_blend_operation_advanced.html) is not supported yet.

Possible values:
- ADD
- SUBTRACT
- REVERSE_SUBTRACT
- MIN
- MAX

Default value:
- ADD

**2.14.6. SrcAlphaBlendFactor**

[Dual-source blending](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap30.html#framebuffer-dsb) is not supported yet.

Possible values:
- ZERO
- ONE
- SRC_COLOR
- ONE_MINUS_SRC_COLOR
- DST_COLOR
- ONE_MINUS_DST_COLOR
- SRC_ALPHA
- ONE_MINUS_SRC_ALPHA
- DST_ALPHA
- ONE_MINUS_DST_ALPHA
- CONSTANT_COLOR
- ONE_MINUS_CONSTANT_COLOR
- CONSTANT_ALPHA
- ONE_MINUS_CONSTANT_ALPHA
- SRC_ALPHA_SATURATE

Default value:
- SRC_ALPHA

**2.14.7. DstAlphaBlendFactor**

[Dual-source blending](https://registry.khronos.org/vulkan/specs/1.3-extensions/html/chap30.html#framebuffer-dsb) is not supported yet.

Possible values:
- ZERO
- ONE
- SRC_COLOR
- ONE_MINUS_SRC_COLOR
- DST_COLOR
- ONE_MINUS_DST_COLOR
- SRC_ALPHA
- ONE_MINUS_SRC_ALPHA
- DST_ALPHA
- ONE_MINUS_DST_ALPHA
- CONSTANT_COLOR
- ONE_MINUS_CONSTANT_COLOR
- CONSTANT_ALPHA
- ONE_MINUS_CONSTANT_ALPHA
- SRC_ALPHA_SATURATE

Default value:
- ZERO

**2.14.8. AlphaBlendOp**

[VK_EXT_blend_operation_advanced](https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/VK_EXT_blend_operation_advanced.html) is not supported yet.

Possible values:
- ADD
- SUBTRACT
- REVERSE_SUBTRACT
- MIN
- MAX

Default value:
- ADD
