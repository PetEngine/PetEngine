//
// This file was auto-generated using the following command:
//
// jai build.jai - nvtt
//



NVTT_SHARED :: 1;
NVTT_VERSION :: 30205;

/// Check if CUDA is supported by the run-time environment
isCudaSupported :: () -> bool #foreign nvtt "?isCudaSupported@nvtt@@YA_NXZ";

/// @brief Tells NVTT to always use an application-set device rather
/// than selecting its own.
///
/// By default, NVTT functions such as nvtt::isCudaSupported() and
/// nvtt::Context() can choose a device and call cudaSetDevice().
/// Calling this function will prevent NVTT from calling cudaSetDevice(),
/// and will make it use the currently set device instead.
/// The application must then call cudaSetDevice() before calling NVTT
/// functions, and whenever it wants to change the device subsequent
/// NVTT functions will use.
///
/// For instance, this may be useful when managing devices on multi-GPU
/// systems.
useCurrentDevice :: () -> void #foreign nvtt "?useCurrentDevice@nvtt@@YAXXZ";

/// Value type of the input images.
/// The input buffer will use the same value type as the input images
ValueType :: enum s32 {
    UINT8   :: 0;
    SINT8   :: 1;
    FLOAT32 :: 2;
    FLOAT16 :: 3;
}

/// Name of channels for defining a swizzling
ChannelOrder :: enum s32 {
    Red   :: 0;
    Green :: 1;
    Blue  :: 2;
    Alpha :: 3;
    Zero  :: 4;
    One   :: 5;
}

/// Use this structure to reference each of the input images
RefImage :: struct {
    data:               *void; ///< For CPUInputBuffer, this should point to host memory; for GPUInputBuffer, this should point to device memory.
    width:              s32 = 0; ///< Width of the image. This can be arbitrary, up to 65535.
    height:             s32 = 0; ///< Height of the image. This can be arbitrary, up to 65535.
    depth:              s32 = 1; ///< Z-dimension of the images, usually 1
    num_channels:       s32 = 4; ///< Number of channels the image has
    channel_swizzle:    [4] ChannelOrder; ///< Channels order how the image is stored
    channel_interleave  := true; ///< Whether the rgba channels are interleaved (r0, g0, b0, a0, r1, g1, b1, a1, ...)
}

/// @brief Structure containing all the input images from host memory.
/// The image data is reordered by tiles.
CPUInputBuffer :: struct {
    /// @brief Construct a CPUInputBuffer from 1 or more RefImage structs.
    ///
    /// The input images should use the same value type.
    /// `images[i].data` should point to host memory here.
    /// `num_tiles` can be an array of numImages elements used to return the number of tiles of each input image after reordering.
    Constructor :: (this: *CPUInputBuffer, images: *RefImage, value_type: ValueType, numImages: s32 = 1, tile_w: s32 = 4, tile_h: s32 = 4, WeightR: float = 1.0, WeightG: float = 1.0, WeightB: float = 1.0, WeightA: float = 1.0, tc: *TimingContext = null, num_tiles: *u32 = null) -> void #cpp_method #foreign nvtt "??0CPUInputBuffer@nvtt@@QEAA@PEBURefImage@1@W4ValueType@1@HHHMMMMPEAUTimingContext@1@PEAI@Z";

    /// Destructor
    Destructor :: (this: *CPUInputBuffer) -> void #cpp_method #foreign nvtt "??1CPUInputBuffer@nvtt@@QEAA@XZ";

    /// The total number of tiles of the input buffer
    NumTiles :: (this: *CPUInputBuffer) -> s32 #cpp_method #foreign nvtt "?NumTiles@CPUInputBuffer@nvtt@@QEBAHXZ";

    /// Tile Size
    TileSize :: (this: *CPUInputBuffer, tile_w: *s32, tile_h: *s32) -> void #cpp_method #foreign nvtt "?TileSize@CPUInputBuffer@nvtt@@QEBAXAEAH0@Z";

    /// Value type. The same as the input images used for creating this object
    Type :: (this: *CPUInputBuffer) -> ValueType #cpp_method #foreign nvtt "?Type@CPUInputBuffer@nvtt@@QEBA?AW4ValueType@2@XZ";

    /// Get a pointer to the i-th tile. Mainly used internally.
    GetTile :: (this: *CPUInputBuffer, i: s32, vw: *s32, vh: *s32) -> *void #cpp_method #foreign nvtt "?GetTile@CPUInputBuffer@nvtt@@QEBAPEAXHAEAH0@Z";

    Private :: struct {}
    m: *Private;
}

/// @brief Structure containing all the input images from device memory.
/// The image data is reordered by tiles.
GPUInputBuffer :: struct {
    /// @brief Construct a GPUInputBuffer from 1 or more RefImage structs.
    ///
    /// The input images should use the same value type.
    /// `images[i].data` should point to GPU global memory here (more specifically, a CUDA device pointer).
    /// `num_tiles` can be used to return the number of tiles of each input image after reordering.
    Constructor :: (this: *GPUInputBuffer, images: *RefImage, value_type: ValueType, numImages: s32 = 1, tile_w: s32 = 4, tile_h: s32 = 4, WeightR: float = 1.0, WeightG: float = 1.0, WeightB: float = 1.0, WeightA: float = 1.0, tc: *TimingContext = null, num_tiles: *u32 = null) -> void #cpp_method #foreign nvtt "??0GPUInputBuffer@nvtt@@QEAA@PEBURefImage@1@W4ValueType@1@HHHMMMMPEAUTimingContext@1@PEAI@Z";

    /// @brief Construct a GPUInputBuffer from a CPUInputBuffer.
    ///
    /// `begin`/`end` can be used to sepcify a range of tiles to copy from the CPUInputBuffer.
    /// `end = -1` means the end of the input buffer.
    Constructor :: (this: *GPUInputBuffer, cpu_buf: *CPUInputBuffer, begin: s32 = 0, end: s32 = -1, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "??0GPUInputBuffer@nvtt@@QEAA@AEBUCPUInputBuffer@1@HHPEAUTimingContext@1@@Z";
    Constructor :: (this: *GPUInputBuffer, cpu_buf: CPUInputBuffer, begin: s32 = 0, end: s32 = -1, tc: *TimingContext = null) #no_context {
        Constructor(this, *cpu_buf, begin, end, tc);
    }

    /// Destructor
    Destructor :: (this: *GPUInputBuffer) -> void #cpp_method #foreign nvtt "??1GPUInputBuffer@nvtt@@QEAA@XZ";

    /// The total number of tiles of the input buffer
    NumTiles :: (this: *GPUInputBuffer) -> s32 #cpp_method #foreign nvtt "?NumTiles@GPUInputBuffer@nvtt@@QEBAHXZ";

    /// Tile Size
    TileSize :: (this: *GPUInputBuffer, tile_w: *s32, tile_h: *s32) -> void #cpp_method #foreign nvtt "?TileSize@GPUInputBuffer@nvtt@@QEBAXAEAH0@Z";

    /// @brief Value type. The same as the input images of the CPUInputBuffer used for creating this object
    Type :: (this: *GPUInputBuffer) -> ValueType #cpp_method #foreign nvtt "?Type@GPUInputBuffer@nvtt@@QEBA?AW4ValueType@2@XZ";

    Private :: struct {}
    m: *Private;
}

/// Supported block-compression formats, including compressor variants.
// @@ I wish I had distinguished between "formats" and compressors.
/// That is:
/// - 'DXT1' is a format, 'DXT1a' and 'DXT1n' are DXT1 compressors.
/// - 'DXT3' is a format, 'DXT3n' is a DXT3 compressor.
///
// @@ Having multiple enums for the same ids only creates confusion. Clean this up.
Format :: enum s32 {
    RGB            :: 0;
    RGBA           :: 0;

    DXT1           :: 1;
    DXT1a          :: 2;
    DXT3           :: 3;
    DXT5           :: 4;
    DXT5n          :: 5;

    BC1            :: 1;
    BC1a           :: 2;
    BC2            :: 3;
    BC3            :: 4;
    BC3n           :: 5;
    BC4            :: 6;
    BC4S           :: 7;
    ATI2           :: 8;
    BC5            :: 9;
    BC5S           :: 10;

    DXT1n          :: 11;
    CTX1           :: 12;

    BC6U           :: 13;
    BC6S           :: 14;

    BC7            :: 15;

    BC3_RGBM       :: 16;

    ASTC_LDR_4x4   :: 17;
    ASTC_LDR_5x4   :: 18;
    ASTC_LDR_5x5   :: 19;
    ASTC_LDR_6x5   :: 20;
    ASTC_LDR_6x6   :: 21;
    ASTC_LDR_8x5   :: 22;
    ASTC_LDR_8x6   :: 23;
    ASTC_LDR_8x8   :: 24;
    ASTC_LDR_10x5  :: 25;
    ASTC_LDR_10x6  :: 26;
    ASTC_LDR_10x8  :: 27;
    ASTC_LDR_10x10 :: 28;
    ASTC_LDR_12x10 :: 29;
    ASTC_LDR_12x12 :: 30;

    Count          :: 31;

    Unset          :: 255;
}

/// @brief Pixel value types.
///
/// These are used for Format_RGB: they indicate how the output should be
/// interpreted, but do not have any influence over the input. They are
/// ignored for other compression modes.
PixelType :: enum s32 {
    UnsignedNorm  :: 0;
    SignedNorm    :: 1;
    UnsignedInt   :: 2;
    SignedInt     :: 3;
    Float         :: 4;
    UnsignedFloat :: 5;
    SharedExp     :: 6;
}

/// @brief Quality modes.
///
/// These can be used to trade off speed of compression for lower error,
/// and often selects the specific compression algorithm that will be used.
/// Here's a table showing which (format, quality) combinations support
/// CUDA acceleration:
///
/// Quality    | BC1 | BC1a | BC2 | BC3 | BC3n | RGBM | BC4 | BC5 | BC6 | BC7       | ASTC |
/// -----------|-----|------|-----|-----|------|------|-----|-----|-----|-----------|------|
/// Fastest    | Yes | No   | No  | No  | No   | No   | Yes | Yes | Yes | Yes       | Yes  |
/// Normal     | Yes | Yes  | Yes | Yes | Yes  | No   | Yes | Yes | Yes | Yes       | Yes  |
/// Production | Yes | Yes  | Yes | Yes | Yes  | No   | No  | No  | No  | No (slow) | Yes  |
/// Highest    | Yes | Yes  | Yes | Yes | Yes  | No   | No  | No  | No  | No (slow) | Yes  |
///
/// See the documentation of the different compression functions in
/// nvtt_lowlevel.h for more information.
Quality :: enum s32 {
    Fastest    :: 0;
    Normal     :: 1;
    Production :: 2;
    Highest    :: 3;
}

/// Declares that EncodeSettings uses the structure layout used in
/// NVTT 3.2.
EncodeSettings_Version_1: u32 : 1;

/// Encode flags for EncodeSettings.
EncodeFlags :: enum_flags u32 {
    None           :: 0x0;

    UseGPU         :: 0x1;

    OutputToGPUMem :: 0x2;

    Opaque         :: 0x4;
}

/// Low-level settings including the compression format, where compressed
/// data should be written, and how to encode the data.
/// This can be used in the low-level compression API (@see nvtt_encode)
/// for any format NVTT supports.
///
/// Most new apps will only need to use `format` and `SetOutputToGPUMem()`.
/// EncodeSettings' functions provide concise ways to change individual
/// properties. For instance, here's one way to configure it to encode
/// data to ASTC 4x4 at Production quality, attach a timing context, and
/// output data on the GPU:
///
/// ```cpp
/// using namespace nvtt;
/// TimingContext tc = TimingContext();
/// const auto settings = EncodeSettings().SetFormat(Format_ASTC_LDR_4x4)
/// 	.SetQuality(Quality_Production)
/// 	.SetTimingContext(&tc)
/// 	.SetOutputToGPUMem(true)
/// ```
///
/// If your compiler supports C++20 aggregate initialization, it can also
/// be used (and the C wrapper supports C99's designated initialization):
/// ```cpp
/// const EncodeSettings settings{
///		.format = Format_ASTC_LDR_4x4,
///		.quality = Quality_Production,
///		.timing_context = &tc,
///		.encode_flags = EncodeFlags_UseGPU | EncodeFlags_OutputToGPUMem };
/// ```
///
/// @since NVTT 3.2
EncodeSettings :: struct {
    /// The structure type and version. This is here to allow this struct
    /// to be identified from its first 32 bits, and to allow future NVTT
    /// versions to add new members to this struct without breaking
    /// backwards compatibility. It should not be changed from the default.
    sType:          u32 = EncodeSettings_Version_1;

    /// The desired compression format. @see Format
    format:         Format = .Unset;

    /// The desired compression quality. @see Quality
    quality:        Quality = .Normal;

    /// When `format` is Format_RGB, this defines the type of the
    /// output data.
    rgb_pixel_type: PixelType = .UnsignedNorm;

    /// @see nvtt::TimingContext.
    timing_context: *TimingContext = null;

    /// A bitmask of EncodeFlags. This can be set using bit operations,
    /// like `encode_flags = EncodeFlags_UseGPU | EncodeFlags_Opaque`,
    /// or using EncodeSettings' functions for individual flags.
    encode_flags:   u32 = xx EncodeFlags.UseGPU;

    /// Functions that set this object's fields and return this object.
    /// These allows setters to be chained.
    SetFormat :: (this: *EncodeSettings, _format: Format) -> *EncodeSettings #cpp_method #foreign nvtt "?SetFormat@EncodeSettings@nvtt@@QEAAAEAU12@W4Format@2@@Z";
    SetQuality :: (this: *EncodeSettings, _quality: Quality) -> *EncodeSettings #cpp_method #foreign nvtt "?SetQuality@EncodeSettings@nvtt@@QEAAAEAU12@W4Quality@2@@Z";
    SetRGBPixelType :: (this: *EncodeSettings, _rgb_pixel_type: PixelType) -> *EncodeSettings #cpp_method #foreign nvtt "?SetRGBPixelType@EncodeSettings@nvtt@@QEAAAEAU12@W4PixelType@2@@Z";
    SetTimingContext :: (this: *EncodeSettings, _timing_context: *TimingContext) -> *EncodeSettings #cpp_method #foreign nvtt "?SetTimingContext@EncodeSettings@nvtt@@QEAAAEAU12@PEAUTimingContext@2@@Z";

    /// @see EncodeFlags_UseGPU
    SetUseGPU :: (this: *EncodeSettings, _use_gpu: bool) -> *EncodeSettings #cpp_method #foreign nvtt "?SetUseGPU@EncodeSettings@nvtt@@QEAAAEAU12@_N@Z";

    /// @see EncodeFlags_OutputToGPUMem
    SetOutputToGPUMem :: (this: *EncodeSettings, _to_device_mem: bool) -> *EncodeSettings #cpp_method #foreign nvtt "?SetOutputToGPUMem@EncodeSettings@nvtt@@QEAAAEAU12@_N@Z";

    /// @see EncodeFlags_Opaque
    SetIsOpaque :: (this: *EncodeSettings, _is_opaque: bool) -> *EncodeSettings #cpp_method #foreign nvtt "?SetIsOpaque@EncodeSettings@nvtt@@QEAAAEAU12@_N@Z";
}

/// Low-level interface for compressing to any of NVTT's formats from a
/// CPUInputBuffer. If encoding succeeded, returns true. On failure, logs
/// at least one error (@see nvtt::setMessageCallback()) and returns false.
///
/// Here's an example of how to encode data in CPU memory to BC7 format
/// on the GPU, writing the output to CUDA device memory:
///
/// ```cpp
/// // Given void* d_outputData, a pointer to where the compressed data
/// // should be written on the GPU, and a CPUInputBuffer cpuInput:
/// using namespace nvtt;
/// const auto settings = EncodeSettings().SetFormat(Format_BC7)
///                                       .SetOutputToGPUMem(true);
/// if (nvtt_encode(cpuInput, d_outputData, settings))
/// {
///   // Encoding succeeded! Do something with the data here.
/// }
/// ```
///
/// @param input Constant reference to input in CPU memory.
///
/// @param output Pointer to output: CUDA device pointer if
/// `settings.encode_flags` includes ENCODE_USE_GPU, and a pointer to CPU
/// memory otherwise.
///
/// @param settings Encoder settings, including the compression format
/// and quality.
///
/// @since NVTT 3.2
nvtt_encode :: (input: *CPUInputBuffer, output: *void, settings: *EncodeSettings) -> bool #foreign nvtt "?nvtt_encode@nvtt@@YA_NAEBUCPUInputBuffer@1@PEAXAEBUEncodeSettings@1@@Z";
nvtt_encode :: (input: CPUInputBuffer, output: *void, settings: EncodeSettings) -> bool #no_context {
    return nvtt_encode(*input, output, *settings);
}

/// Low-level interface for compressing to any of NVTT's formats from a
/// GPUInputBuffer. If encoding succeeded, returns true. On failure, logs
/// at least one error (@see nvtt::setMessageCallback()) and returns false.
///
/// Here's an example of how to encode data in GPU memory to BC7 format
/// on the GPU, writing the output to CUDA device memory:
///
/// ```cpp
/// // Given void* d_outputData, a pointer to where the compressed data
/// // should be written on the GPU, and a GPUInputBuffer gpuInput:
/// using namespace nvtt;
/// const auto settings = EncodeSettings().SetFormat(Format_BC7)
///                                       .SetOutputToGPUMem(true);
/// if (nvtt_encode(gpuInput, d_outputData, settings))
/// {
///   // Encoding succeeded! Do something with the data here.
/// }
/// ```
///
/// @param input Constant reference to input in GPU memory.
///
/// @param output Pointer to output: CUDA device pointer if
/// `settings.encode_flags` includes ENCODE_USE_GPU, and a pointer to CPU
/// memory otherwise.
///
/// @param settings Encoder settings, including the compression format
/// and quality.
///
/// @note Clearing `settings` flag ENCODE_USE_GPU is ignored; data
/// compressed using this function is currently always compressed on
/// the GPU.
///
/// @since NVTT 3.2
nvtt_encode :: (input: *GPUInputBuffer, output: *void, settings: *EncodeSettings) -> bool #foreign nvtt "?nvtt_encode@nvtt@@YA_NAEBUGPUInputBuffer@1@PEAXAEBUEncodeSettings@1@@Z";
nvtt_encode :: (input: GPUInputBuffer, output: *void, settings: EncodeSettings) -> bool #no_context {
    return nvtt_encode(*input, output, *settings);
}

/// Return the NVTT version number, as 10000*fork + 100*major + minor.
version :: () -> u32 #foreign nvtt "?version@nvtt@@YAIXZ";

/// Compression options. This class describes the desired compression format and other compression settings.
CompressionOptions :: struct {
    Private :: struct {}
    m: *Private;

    /// Constructor. Sets compression options to the default values.
    Constructor :: (this: *CompressionOptions) -> void #cpp_method #foreign nvtt "??0CompressionOptions@nvtt@@QEAA@XZ";

    /// Destructor.
    Destructor :: (this: *CompressionOptions) -> void #cpp_method #foreign nvtt "??1CompressionOptions@nvtt@@QEAA@XZ";

    /// Set default compression options.
    reset :: (this: *CompressionOptions) -> void #cpp_method #foreign nvtt "?reset@CompressionOptions@nvtt@@QEAAXXZ";

    /// Set desired compression format.
    setFormat :: (this: *CompressionOptions, format: Format) -> void #cpp_method #foreign nvtt "?setFormat@CompressionOptions@nvtt@@QEAAXW4Format@2@@Z";

    /// Set compression quality settings.
    setQuality :: (this: *CompressionOptions, quality: Quality) -> void #cpp_method #foreign nvtt "?setQuality@CompressionOptions@nvtt@@QEAAXW4Quality@2@@Z";

    /// @brief Set the weights of each color channel used to measure compression error.
    ///
    /// The choice for these values is subjective. In most cases uniform color weights
    /// (1.0, 1.0, 1.0) work very well. A popular choice is to use the NTSC luma encoding
    /// weights (0.2126, 0.7152, 0.0722), but I think that blue contributes to our
    /// perception more than 7%. A better choice in my opinion is (3, 4, 2).
    setColorWeights :: (this: *CompressionOptions, red: float, green: float, blue: float, alpha: float = 1.0) -> void #cpp_method #foreign nvtt "?setColorWeights@CompressionOptions@nvtt@@QEAAXMMMM@Z";

    /// @brief Describes an RGB/RGBA format using 32-bit masks per channel.
    ///
    /// Note that this sets the number of bits per channel to 0.
    setPixelFormat :: (this: *CompressionOptions, bitcount: u32, rmask: u32, gmask: u32, bmask: u32, amask: u32) -> void #cpp_method #foreign nvtt "?setPixelFormat@CompressionOptions@nvtt@@QEAAXIIIII@Z";

    /// @brief Describes an RGB/RGBA format using the number of bits per channel.
    ///
    /// Note that this sets the masks per channel to 0.
    setPixelFormat :: (this: *CompressionOptions, rsize: u8, gsize: u8, bsize: u8, asize: u8) -> void #cpp_method #foreign nvtt "?setPixelFormat@CompressionOptions@nvtt@@QEAAXEEEE@Z";

    /// @brief Set pixel type.
    ///
    /// These are used for Format_RGB: they indicate how the
    /// output should be interpreted, but do not have any influence over
    /// the input. They are ignored for other compression modes.
    setPixelType :: (this: *CompressionOptions, pixelType: PixelType) -> void #cpp_method #foreign nvtt "?setPixelType@CompressionOptions@nvtt@@QEAAXW4PixelType@2@@Z";

    /// Set pitch alignment in bytes.
    setPitchAlignment :: (this: *CompressionOptions, pitchAlignment: s32) -> void #cpp_method #foreign nvtt "?setPitchAlignment@CompressionOptions@nvtt@@QEAAXH@Z";

    /// @brief Set quantization options.
    ///
    /// @warning Do not enable dithering unless you know what you are doing. Quantization
    /// introduces errors. It's better to let the compressor quantize the result to
    /// minimize the error, instead of quantizing the data before handling it to
    /// the compressor.
    setQuantization :: (this: *CompressionOptions, colorDithering: bool, alphaDithering: bool, binaryAlpha: bool, alphaThreshold: s32 = 127) -> void #cpp_method #foreign nvtt "?setQuantization@CompressionOptions@nvtt@@QEAAX_N00H@Z";

    /// @brief Translates to a D3D format.
    ///
    /// Returns 0 if no corresponding format could be found.
    ///
    /// For Format_RGB, this looks at the pixel type and pixel format to
    /// determine the corresponding D3D format.
    /// For BC6, BC7, and ASTC, this returns a FourCC code: 'BC6H' for
    /// both unsigned and signed BC6, 'BC7L' for BC7, and 'ASTC' for all
    /// ASTC formats.
    d3d9Format :: (this: *CompressionOptions) -> u32 #cpp_method #foreign nvtt "?d3d9Format@CompressionOptions@nvtt@@QEBAIXZ";
}

/// Wrap modes. Specifies how to handle coordinates outside the typical image range.
WrapMode :: enum s32 {
    Clamp  :: 0;

    Repeat :: 1;

    Mirror :: 2;
}

/// Texture types. Specifies the dimensionality of a texture.
TextureType :: enum s32 {
    _2D  :: 0;
    Cube :: 1;
    _3D  :: 2;
}

/// @brief Input formats. Used when creating an nvtt::Surface from an RGB/RGBA array.
InputFormat :: enum s32 {
    BGRA_8UB :: 0;
    BGRA_8SB :: 1;
    RGBA_16F :: 2;
    RGBA_32F :: 3;
    R_32F    :: 4;
}

/// @brief Mipmap downsampling filters. Each of these can be customized using
/// `filterWidth` and `params` when calling Surface::buildNextMipmap().
MipmapFilter :: enum s32 {
    Box      :: 0;

    Triangle :: 1;

    Kaiser   :: 2;

    Mitchell :: 3;

    Min      :: 4;

    Max      :: 5;
}

/// Texture resizing filters.
ResizeFilter :: enum s32 {
    Box      :: 0;

    Triangle :: 1;

    Kaiser   :: 2;

    Mitchell :: 3;

    Min      :: 4;

    Max      :: 5;
}

/// @brief Extents rounding mode.
///
/// Determines how to round sizes to different sets when shrinking an image.
///
/// For each of the PowerOfTwo modes, `maxExtent` is first rounded to the
/// previous power of two.
///
/// Then all extents are scaled and truncated without changing the aspect
/// ratio, using `s = max((s * maxExtent) / m, 1)`, where `m` is the
/// maximum width, height, or depth.
///
/// If the texture is a cube map, the width and height are then averaged
/// to make the resulting texture square.
///
/// Finally, extents are rounded to a set of possible sizes depending on
/// this enum.
///
/// @see getTargetExtent()
RoundMode :: enum s32 {
    None                 :: 0;
    ToNextPowerOfTwo     :: 1;
    ToNearestPowerOfTwo  :: 2;
    ToPreviousPowerOfTwo :: 3;
}

/// Alpha mode.
AlphaMode :: enum s32 {
    None          :: 0;

    Transparency  :: 1;

    Premultiplied :: 2;
}

/// @brief Inheritable interface for outputting data.
///
/// For instance, one can inherit from this to write to a stream, a buffer
/// in memory, or a custom data structure.
OutputHandler :: struct {
    vtable: *OutputHandler_VTable;
}
OutputHandler_VTable :: struct #type_info_none {
    Destructor: #type (this: *OutputHandler, flags: Msvc_Destructor_Flags = .NONE) -> void #cpp_method;

    beginImage: #type (this: *OutputHandler, size: s32, width: s32, height: s32, depth: s32, face: s32, miplevel: s32) -> void #cpp_method;

    writeData:  #type (this: *OutputHandler, data: *void, size: s32) -> bool #cpp_method;

    endImage:   #type (this: *OutputHandler) -> void #cpp_method;
}
OutputHandler_Destructor :: inline (this: *OutputHandler, flags: Msvc_Destructor_Flags = .NONE) { this.vtable.Destructor(this, flags); }

OutputHandler_beginImage :: inline (this: *OutputHandler, size: s32, width: s32, height: s32, depth: s32, face: s32, miplevel: s32) { this.vtable.beginImage(this, size, width, height, depth, face, miplevel); }

OutputHandler_writeData :: inline (this: *OutputHandler, data: *void, size: s32) -> bool { return this.vtable.writeData(this, data, size); }

OutputHandler_endImage :: inline (this: *OutputHandler) { this.vtable.endImage(this); }

vtable :: (obj: *OutputHandler) -> *OutputHandler_VTable { return obj.vtable; }


/// @brief Error codes.
///
/// @see nvtt::ErrorHandler
/// @see errorString()
Error :: enum s32 {
    None                    :: 0;
    Unknown                 :: 0;
    InvalidInput            :: 1;
    UnsupportedFeature      :: 2;
    CudaError               :: 3;
    FileOpen                :: 4;
    FileWrite               :: 5;
    UnsupportedOutputFormat :: 6;
    Messaging               :: 7;
    OutOfHostMemory         :: 8;
    OutOfDeviceMemory       :: 9;
    OutputWrite             :: 10;
    Count                   :: 11;
}

/// Return string for the given error code.
errorString :: (e: Error) -> *u8 #foreign nvtt "?errorString@nvtt@@YAPEBDW4Error@1@@Z";

/// Inheritable interface for handling errors.
ErrorHandler :: struct {
    vtable: *ErrorHandler_VTable;
}
ErrorHandler_VTable :: struct #type_info_none {
    Destructor: #type (this: *ErrorHandler, flags: Msvc_Destructor_Flags = .NONE) -> void #cpp_method;

    error:      #type (this: *ErrorHandler, e: Error) -> void #cpp_method;
}
ErrorHandler_Destructor :: inline (this: *ErrorHandler, flags: Msvc_Destructor_Flags = .NONE) { this.vtable.Destructor(this, flags); }

ErrorHandler_error :: inline (this: *ErrorHandler, e: Error) { this.vtable.error(this, e); }

vtable :: (obj: *ErrorHandler) -> *ErrorHandler_VTable { return obj.vtable; }


/// @brief Message severity.
/// @since NVTT 3.2
Severity :: enum s32 {
    Info    :: 0;

    Warning :: 1;

    Error   :: 2;
    Count   :: 3;
}

/// A MessageCallback is a function that takes a message `Severity`,
/// an error enumeration (only nonzero for error messages),
/// a null-terminated description of the message (usually with useful
/// information for debugging; no newline at end), and a custom
/// user pointer set when calling `nvtt::SetMessageCallback()`.
/// @since NVTT 3.2
MessageCallback :: #type (severity: Severity, error: Error, message: *u8, userData: *void) -> void #c_call;

/// Sets the current thread's NVTT `MessageCallback`.
/// NVTT calls this function whenever it encounters an error or performance
/// warning, or has useful information. Here's an example showing how to
/// use a message callback to detect and print errors:
/// ```cpp
/// thread_local bool caughtError = false;
/// void customCallback(nvtt::Severity severity, nvtt::Error error,
///                     const char* message, const void* userData)
/// {
///     if (severity == nvtt::Severity_Error)
///     {
///         printf("ERROR: %s\n", message);
///         caughtError = true;
///     }
/// }
///
/// // Example processing function; returns true on success
/// bool exampleProcessing(...)
/// {
///     nvtt::setMessageCallback(customCallback, nullptr);
///     GPUInputBuffer input(...);
///     nvtt_encode_bc7(input, ...);
///     return !caughtError;
/// }
/// ```
/// Since each thread has its own callback pointer, a custom callback
/// should be set whenever an app creates a new thread. If no callback has
/// been set, the default callback prints the severity and the message,
/// followed by a newline, to stdout. If a callback has been set, setting
/// the callback to nullptr will make NVTT switch to the default callback.
/// Returns true if setting the message callback succeeded.
/// @since NVTT 3.2
setMessageCallback :: (callback: MessageCallback, userData: *void) -> bool #foreign nvtt "?setMessageCallback@nvtt@@YA_NP6AXW4Severity@1@W4Error@1@PEBDPEBX@Z3@Z";

/// @brief Container type for encoded data.
///
/// @note For DDS containers, NVTT stores some additional data in the
/// `reserved[]` fields to allow consumers to detect writer versions.
/// - `reserved[7]` is the FourCC code "UVER", and `reserved[8]` stores a
/// version number that can be set by the user.
/// - `reserved[9]` is the FourCC code "NVTT", and `reserved[10]` is the
/// NVTT writer version (which isn't necessarily the same as `nvtt::version()`).
///
/// @note For DDS containers, NVTT also extends the `dwFlags` field with two
/// more flags.
/// - `DDPF_SRGB` (`0x40000000U`) indicates that the texture uses an sRGB
/// transfer function. Note that most readers will ignore this and instead
/// guess the transfer function from the format.
/// - `DDPF_NORMAL` (`0x80000000U`) indicates that the texture is a normal map.
Container :: enum s32 {
    DDS   :: 0;
    DDS10 :: 1;
}

/// @brief Output Options.
///
/// This class holds pointers to the interfaces that are used to report
/// the output of the compressor to the app, as well as the container type
/// and options specific to the container.
OutputOptions :: struct {
    Private :: struct {}
    m: *Private;

    Constructor :: (this: *OutputOptions) -> void #cpp_method #foreign nvtt "??0OutputOptions@nvtt@@QEAA@XZ";
    Destructor :: (this: *OutputOptions) -> void #cpp_method #foreign nvtt "??1OutputOptions@nvtt@@QEAA@XZ";

    /// Set default options.
    reset :: (this: *OutputOptions) -> void #cpp_method #foreign nvtt "?reset@OutputOptions@nvtt@@QEAAXXZ";

    /// Set output file name. This uses the same character encoding as the
    /// `filename` argument of `fopen()`.
    setFileName :: (this: *OutputOptions, fileName: *u8) -> void #cpp_method #foreign nvtt "?setFileName@OutputOptions@nvtt@@QEAAXPEBD@Z";

    /// Set output file handle.
    setFileHandle :: (this: *OutputOptions, fp: *void) -> void #cpp_method #foreign nvtt "?setFileHandle@OutputOptions@nvtt@@QEAAXPEAX@Z";

    /// Set output handler.
    setOutputHandler :: (this: *OutputOptions, outputHandler: *OutputHandler) -> void #cpp_method #foreign nvtt "?setOutputHandler@OutputOptions@nvtt@@QEAAXPEAUOutputHandler@2@@Z";

    /// Set error handler.
    setErrorHandler :: (this: *OutputOptions, errorHandler: *ErrorHandler) -> void #cpp_method #foreign nvtt "?setErrorHandler@OutputOptions@nvtt@@QEAAXPEAUErrorHandler@2@@Z";

    /// Set output header. Defaults to true.
    setOutputHeader :: (this: *OutputOptions, outputHeader: bool) -> void #cpp_method #foreign nvtt "?setOutputHeader@OutputOptions@nvtt@@QEAAX_N@Z";

    /// Set container. Defaults to Container_DDS.
    setContainer :: (this: *OutputOptions, container: Container) -> void #cpp_method #foreign nvtt "?setContainer@OutputOptions@nvtt@@QEAAXW4Container@2@@Z";

    /// Set user version.
    ///
    /// @see #Container
    setUserVersion :: (this: *OutputOptions, version: s32) -> void #cpp_method #foreign nvtt "?setUserVersion@OutputOptions@nvtt@@QEAAXH@Z";

    /// Set the sRGB flag, indicating whether this file stores data with
    /// an sRGB transfer function (true) or a linear transfer function
    /// (false). Defaults to false.
    ///
    /// @see #Container
    setSrgbFlag :: (this: *OutputOptions, b: bool) -> void #cpp_method #foreign nvtt "?setSrgbFlag@OutputOptions@nvtt@@QEAAX_N@Z";
}

/// Compression context.
Context :: struct {
    Private :: struct {}
    m: *Private;

    /// @brief Create a compression context.
    /// @param enableCuda If true, enables CUDA acceleration (same as calling `enableCudaAcceleration()`).
    Constructor :: (this: *Context, enableCuda := true) -> void #cpp_method #foreign nvtt "??0Context@nvtt@@QEAA@_N@Z";
    Destructor :: (this: *Context) -> void #cpp_method #foreign nvtt "??1Context@nvtt@@QEAA@XZ";

    /// Enable CUDA acceleration; initializes CUDA if not already initialized.
    enableCudaAcceleration :: (this: *Context, enable: bool) -> void #cpp_method #foreign nvtt "?enableCudaAcceleration@Context@nvtt@@QEAAX_N@Z";

    /// Check if CUDA acceleration is enabled
    isCudaAccelerationEnabled :: (this: *Context) -> bool #cpp_method #foreign nvtt "?isCudaAccelerationEnabled@Context@nvtt@@QEBA_NXZ";

    /// @brief Write the #Container's header to the output.
    /// @param mipmapCount The number of mipmaps in the container.
    /// @since NVTT 2.1
    outputHeader :: (this: *Context, img: *Surface, mipmapCount: s32, compressionOptions: *CompressionOptions, outputOptions: *OutputOptions) -> bool #cpp_method #foreign nvtt "?outputHeader@Context@nvtt@@QEBA_NAEBUSurface@2@HAEBUCompressionOptions@2@AEBUOutputOptions@2@@Z";
    outputHeader :: (this: *Context, img: Surface, mipmapCount: s32, compressionOptions: CompressionOptions, outputOptions: OutputOptions) -> bool #no_context {
        return outputHeader(this, *img, mipmapCount, *compressionOptions, *outputOptions);
    }

    /// @brief Compress the Surface and write the compressed data to the output.
    /// @param img The Surface.
    /// @param face Ignored.
    /// @param mipmap Ignored.
    /// @param compressionOptions Specifies the compression format.
    /// @param outputOptions Specifies how to output the data.
    /// @since NVTT 2.1
    compress :: (this: *Context, img: *Surface, face: s32, mipmap: s32, compressionOptions: *CompressionOptions, outputOptions: *OutputOptions) -> bool #cpp_method #foreign nvtt "?compress@Context@nvtt@@QEBA_NAEBUSurface@2@HHAEBUCompressionOptions@2@AEBUOutputOptions@2@@Z";
    compress :: (this: *Context, img: Surface, face: s32, mipmap: s32, compressionOptions: CompressionOptions, outputOptions: OutputOptions) -> bool #no_context {
        return compress(this, *img, face, mipmap, *compressionOptions, *outputOptions);
    }

    /// @brief Returns the total compressed size of mips 0...`mipmapCount-1`,
    /// without compressing the image.
    ///
    /// Note that this does not include the container header, and mips are
    /// assumed to be tightly packed.
    ///
    /// For instance, call this with `mipmapCount = img.countMipmaps()` and
    /// add the size of the DDS header to get the size of a DDS file with
    /// a surface and a full mip chain.
    ///
    /// @param img The Surface.
    /// @param mipmapCount The number of mips (each with size `max(1, s/2)` of the previous) in the mip chain to be compressed.
    /// @param compressionOptions Specifies the compression format.
    /// @since NVTT 2.1
    estimateSize :: (this: *Context, img: *Surface, mipmapCount: s32, compressionOptions: *CompressionOptions) -> s32 #cpp_method #foreign nvtt "?estimateSize@Context@nvtt@@QEBAHAEBUSurface@2@HAEBUCompressionOptions@2@@Z";
    estimateSize :: (this: *Context, img: Surface, mipmapCount: s32, compressionOptions: CompressionOptions) -> s32 #no_context {
        return estimateSize(this, *img, mipmapCount, *compressionOptions);
    }

    /// @brief Quantize a Surface to the number of bits per channel of the given format.
    ///
    /// This shouldn't be called unless you're confident you want to do
    /// this. Compressors quantize automatically, and calling this will
    /// cause compression to minimize error with respect to the quantized
    /// values, rather than the original image.
    ///
    /// @see nvtt::Surface::quantize()
    /// @see nvtt::Surface::binarize()
    /// @since NVTT 3.0
    quantize :: (this: *Context, tex: *Surface, compressionOptions: *CompressionOptions) -> void #cpp_method #foreign nvtt "?quantize@Context@nvtt@@QEBAXAEAUSurface@2@AEBUCompressionOptions@2@@Z";
    quantize :: (this: *Context, tex: *Surface, compressionOptions: CompressionOptions) #no_context {
        quantize(this, tex, *compressionOptions);
    }

    /// @brief Write the #Container's header to the output.
    /// @param cube The CubeSurface to read sizes from.
    /// @param mipmapCount The number of mipmaps in the container.
    /// @since NVTT 2.1
    outputHeader :: (this: *Context, cube: *CubeSurface, mipmapCount: s32, compressionOptions: *CompressionOptions, outputOptions: *OutputOptions) -> bool #cpp_method #foreign nvtt "?outputHeader@Context@nvtt@@QEBA_NAEBUCubeSurface@2@HAEBUCompressionOptions@2@AEBUOutputOptions@2@@Z";
    outputHeader :: (this: *Context, cube: CubeSurface, mipmapCount: s32, compressionOptions: CompressionOptions, outputOptions: OutputOptions) -> bool #no_context {
        return outputHeader(this, *cube, mipmapCount, *compressionOptions, *outputOptions);
    }

    /// @brief Compress the CubeSurface and write the compressed data to the output.
    /// @param cube The CubeSurface.
    /// @param mipmap Ignored.
    /// @param compressionOptions Specifies the compression format.
    /// @param outputOptions Specifies how to output the data.
    /// @since NVTT 2.1
    compress :: (this: *Context, cube: *CubeSurface, mipmap: s32, compressionOptions: *CompressionOptions, outputOptions: *OutputOptions) -> bool #cpp_method #foreign nvtt "?compress@Context@nvtt@@QEBA_NAEBUCubeSurface@2@HAEBUCompressionOptions@2@AEBUOutputOptions@2@@Z";
    compress :: (this: *Context, cube: CubeSurface, mipmap: s32, compressionOptions: CompressionOptions, outputOptions: OutputOptions) -> bool #no_context {
        return compress(this, *cube, mipmap, *compressionOptions, *outputOptions);
    }

    /// @brief Returns the total compressed size of mips 0...`mipmapCount-1`,
    /// without compressing the image.
    ///
    /// Note that this does not include the container header, and mips are
    /// assumed to be tightly packed.
    ///
    /// For instance, call this with `mipmapCount = cube.countMipmaps()` and
    /// add the size of the DDS header to get the size of a DDS file with
    /// a CubeSurface and a full mip chain.
    ///
    /// @param cube The CubeSurface.
    /// @param mipmapCount The number of mips (each with size `max(1, s/2)` of the previous) in the mip chain to be compressed.
    /// @param compressionOptions Specifies the compression format.
    /// @since NVTT 2.1
    estimateSize :: (this: *Context, cube: *CubeSurface, mipmapCount: s32, compressionOptions: *CompressionOptions) -> s32 #cpp_method #foreign nvtt "?estimateSize@Context@nvtt@@QEBAHAEBUCubeSurface@2@HAEBUCompressionOptions@2@@Z";
    estimateSize :: (this: *Context, cube: CubeSurface, mipmapCount: s32, compressionOptions: CompressionOptions) -> s32 #no_context {
        return estimateSize(this, *cube, mipmapCount, *compressionOptions);
    }

    /// @brief Write the #Container's header to the output.
    /// @param mipmapCount The number of mipmaps in the container.
    /// @since NVTT 2.1
    outputHeader :: (this: *Context, type: TextureType, w: s32, h: s32, d: s32, mipmapCount: s32, isNormalMap: bool, compressionOptions: *CompressionOptions, outputOptions: *OutputOptions) -> bool #cpp_method #foreign nvtt "?outputHeader@Context@nvtt@@QEBA_NW4TextureType@2@HHHH_NAEBUCompressionOptions@2@AEBUOutputOptions@2@@Z";
    outputHeader :: (this: *Context, type: TextureType, w: s32, h: s32, d: s32, mipmapCount: s32, isNormalMap: bool, compressionOptions: CompressionOptions, outputOptions: OutputOptions) -> bool #no_context {
        return outputHeader(this, type, w, h, d, mipmapCount, isNormalMap, *compressionOptions, *outputOptions);
    }

    /// @brief Compress raw data and write the compressed data to the output.
    ///
    /// Note that this only supports CPU compression. For GPU support and
    /// more options, please see nvtt_lowlevel.h.
    /// @param face Ignored.
    /// @param mipmap Ignored.
    /// @param rgba Color data. Assumed to be non-interleaved; i.e. the value of channel c, pixel (x, y, z) is `rgba[((c*d + z)*h + y)*w + x]`.
    /// @param compressionOptions Specifies the compression format.
    /// @param outputOptions Specifies how to output the data.
    /// @since NVTT 2.1
    compress :: (this: *Context, w: s32, h: s32, d: s32, face: s32, mipmap: s32, rgba: *float, compressionOptions: *CompressionOptions, outputOptions: *OutputOptions) -> bool #cpp_method #foreign nvtt "?compress@Context@nvtt@@QEBA_NHHHHHPEBMAEBUCompressionOptions@2@AEBUOutputOptions@2@@Z";
    compress :: (this: *Context, w: s32, h: s32, d: s32, face: s32, mipmap: s32, rgba: *float, compressionOptions: CompressionOptions, outputOptions: OutputOptions) -> bool #no_context {
        return compress(this, w, h, d, face, mipmap, rgba, *compressionOptions, *outputOptions);
    }

    /// @brief Returns the total compressed size of mips 0...`mipmapCount-1`,
    /// without compressing the image.
    ///
    /// Note that this does not include the container header, and mips are
    /// assumed to be tightly packed.
    ///
    /// For instance, call this with `mipmapCount = nvtt::countMipmaps()` and
    /// add the size of the DDS header to get the size of a DDS file with
    /// a CubeSurface and a full mip chain.
    ///
    /// @param w Width.
    /// @param h Height.
    /// @param d Depth.
    /// @param mipmapCount The number of mips (each with size `max(1, s/2)` of the previous) in the mip chain to be compressed.
    /// @param compressionOptions Specifies the compression format.
    /// @since NVTT 2.1
    estimateSize :: (this: *Context, w: s32, h: s32, d: s32, mipmapCount: s32, compressionOptions: *CompressionOptions) -> s32 #cpp_method #foreign nvtt "?estimateSize@Context@nvtt@@QEBAHHHHHAEBUCompressionOptions@2@@Z";
    estimateSize :: (this: *Context, w: s32, h: s32, d: s32, mipmapCount: s32, compressionOptions: CompressionOptions) -> s32 #no_context {
        return estimateSize(this, w, h, d, mipmapCount, *compressionOptions);
    }

    /// @brief Batch processing compression interface.
    ///
    /// Compresses multiple inputs in a row, improving performance.
    /// Outputs data to each item's `OutputHandler`.
    ///
    /// @see BatchList
    /// @since NVTT 3.0
    compress :: (this: *Context, lst: *BatchList, compressionOptions: *CompressionOptions) -> bool #cpp_method #foreign nvtt "?compress@Context@nvtt@@QEBA_NAEBUBatchList@2@AEBUCompressionOptions@2@@Z";
    compress :: (this: *Context, lst: BatchList, compressionOptions: CompressionOptions) -> bool #no_context {
        return compress(this, *lst, *compressionOptions);
    }

    /// @brief Enables performance measurement. May introduce additional synchronization.
    /// @see TimingContext
    /// @since NVTT 3.0
    enableTiming :: (this: *Context, enable: bool, detailLevel: s32 = 1) -> void #cpp_method #foreign nvtt "?enableTiming@Context@nvtt@@QEAAX_NH@Z";

    /// @brief Returns a TimingContext containing recorded compression performance information.
    /// @since NVTT 3.0
    getTimingContext :: (this: *Context) -> *TimingContext #cpp_method #foreign nvtt "?getTimingContext@Context@nvtt@@QEAAPEAUTimingContext@2@XZ";
}

/// @brief Specifies a normal transformation, used to store 3D (x, y, z) normals in 2D (x, y).
///
/// We define these in terms of their 2D -> 3D reconstructions, since their
/// transformations are the inverse of the reconstructions. Most require
/// z >= 0.0f.
///
/// @see Surface::transformNormals()
/// @see Surface::reconstructNormals()
/// @since NVTT 2.1
NormalTransform :: enum s32 {
    Orthographic  :: 0;

    Stereographic :: 1;

    Paraboloid    :: 2;

    Quartic       :: 3;
}

/// @brief Tone mapping functions.
/// @since NVTT 2.1
ToneMapper :: enum s32 {
    Linear    :: 0;

    Reinhard  :: 1;

    Reindhart :: 1;

    Halo      :: 2;

    Lightmap  :: 3;
}

// Forward declarations.
Surface :: struct {
    /// @brief Creates an empty surface. All data will be null until a
    /// setImage() function is called.
    Constructor :: (this: *Surface) -> void #cpp_method #foreign nvtt "??0Surface@nvtt@@QEAA@XZ";

    /// Copy constructor.
    CopyConstructor :: (this: *Surface, img: *Surface) -> void #cpp_method #foreign nvtt "??0Surface@nvtt@@QEAA@AEBU01@@Z";
    CopyConstructor :: (this: *Surface, img: Surface) #no_context {
        CopyConstructor(this, *img);
    }

    /// Destructor.
    Destructor :: (this: *Surface) -> void #cpp_method #foreign nvtt "??1Surface@nvtt@@QEAA@XZ";

    /// Creates a deep copy of this Surface, with its own internal data. (New in NVTT 3.1)
    clone :: (this: *Surface) -> Surface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?clone@Surface@nvtt@@QEBA?AU12@XZ";

    /// @brief Set the Surface's wrap mode. See #WrapMode for details.
    setWrapMode :: (this: *Surface, mode: WrapMode) -> void #cpp_method #foreign nvtt "?setWrapMode@Surface@nvtt@@QEAAXW4WrapMode@2@@Z";

    /// @brief Set the Surface's alpha mode. See #AlphaMode for details.
    setAlphaMode :: (this: *Surface, alphaMode: AlphaMode) -> void #cpp_method #foreign nvtt "?setAlphaMode@Surface@nvtt@@QEAAXW4AlphaMode@2@@Z";

    /// @brief Set whether the Surface represents a normal map. This can
    /// be accessed using isNormalMap(), and e.g. affects whether DDS
    /// files are written with the normal map flag.
    setNormalMap :: (this: *Surface, isNormalMap: bool) -> void #cpp_method #foreign nvtt "?setNormalMap@Surface@nvtt@@QEAAX_N@Z";

    /// @brief Returns if the surface is null (i.e. refers to nothing, such
    /// as if it was just created using Surface()).
    isNull :: (this: *Surface) -> bool #cpp_method #foreign nvtt "?isNull@Surface@nvtt@@QEBA_NXZ";

    /// Returns the width (X size) of the surface.
    width :: (this: *Surface) -> s32 #cpp_method #foreign nvtt "?width@Surface@nvtt@@QEBAHXZ";

    /// Returns the height (Y size) of the surface.
    height :: (this: *Surface) -> s32 #cpp_method #foreign nvtt "?height@Surface@nvtt@@QEBAHXZ";

    /// Returns the depth (Z size) of the surface. 1 for 2D surfaces.
    depth :: (this: *Surface) -> s32 #cpp_method #foreign nvtt "?depth@Surface@nvtt@@QEBAHXZ";

    /// @brief Returns the dimensionality of the surface. This is set for
    /// instance by setImage().
    type :: (this: *Surface) -> TextureType #cpp_method #foreign nvtt "?type@Surface@nvtt@@QEBA?AW4TextureType@2@XZ";

    /// @brief Returns the wrap mode of the surface. See setWrapMode()
    wrapMode :: (this: *Surface) -> WrapMode #cpp_method #foreign nvtt "?wrapMode@Surface@nvtt@@QEBA?AW4WrapMode@2@XZ";

    /// @brief Returns the alpha mode of the surface. See setAlphaMode()
    alphaMode :: (this: *Surface) -> AlphaMode #cpp_method #foreign nvtt "?alphaMode@Surface@nvtt@@QEBA?AW4AlphaMode@2@XZ";

    /// @brief Returns whether the image represents a normal map. See setNormalMap()
    isNormalMap :: (this: *Surface) -> bool #cpp_method #foreign nvtt "?isNormalMap@Surface@nvtt@@QEBA_NXZ";

    /// @brief Returns the number of mipmaps in a full mipmap chain.
    /// Each mip is half the size of the previous, rounding down, until and
    /// including a 1x1 mip.
    ///
    /// For instance, a 8x5 surface has mipmaps of size 8x5 (mip 0),
    /// 4x2 (mip 1), 2x1 (mip 2), and 1x1 (mip 3), so countMipmaps()
    /// returns 4. A 7x3 surface has mipmaps of size 7x3, 3x1, and 1x1, so
    /// countMipmaps() returns 3.
    countMipmaps :: (this: *Surface) -> s32 #cpp_method #foreign nvtt "?countMipmaps@Surface@nvtt@@QEBAHXZ";

    /// @brief Returns the number of mipmaps in a mipmap chain, stopping
    /// when canMakeNextMipmap() returns false.
    ///
    /// That is, it stops when a 1x1x1 mip is reached if `min_size == 1`
    /// (in which case it is the same as countMipmaps()), or stops when
    /// the width and height are less than `min_size` and the depth is 1.
    ///
    /// @see canMakeNextMipmap().
    countMipmaps :: (this: *Surface, min_size: s32) -> s32 #cpp_method #foreign nvtt "?countMipmaps@Surface@nvtt@@QEBAHH@Z";

    /// @brief Returns the approximate fraction (0 to 1) of the image with
    /// an alpha value greater than `alphaRef`.
    ///
    /// This function uses 8 x 8 subsampling together with
    /// linear interpolation.
    ///
    /// @note `alphaRef` is clamped to the range [1/256, 255/256].
    alphaTestCoverage :: (this: *Surface, alphaRef: float = 0.5, alpha_channel: s32 = 3) -> float #cpp_method #foreign nvtt "?alphaTestCoverage@Surface@nvtt@@QEBAMMH@Z";

    /// @brief Computes the average of a channel, possibly with alpha or
    /// with a gamma transfer function.
    ///
    /// If `alpha_channel` is -1, this function computes
    ///
    /// `(sum(c[i]^gamma, i=0...numPixels)/numPixels)^(1/gamma)`
    ///
    /// where `c` is the channel's data.
    ///
    /// Otherwise, this computes
    ///
    /// `(sum((c[i]^gamma) * a[i], i=0...numPixels)/sum(a[i], i=0...numPixels))^(1/gamma)`
    ///
    /// where `a` is the alpha channel's data.
    ///
    /// @param channel The channel to average.
    /// @param alpha_channel If not equal to -1, weights each texel's value
    /// after gamma correction by this channel.
    /// @param gamma Gamma for the transfer function to apply. A value of
    /// 2.2f roughly corresponds to averaging an sRGB image in linear space,
    /// then converting back to sRGB.
    average :: (this: *Surface, channel: s32, alpha_channel: s32 = -1, gamma: float = 2.2) -> float #cpp_method #foreign nvtt "?average@Surface@nvtt@@QEBAMHHM@Z";

    /// @brief Returns a `const` pointer to the surface's CPU data.
    ///
    /// Data is stored in [c, z, y, x] order; that is, all channel 0's data
    /// comes first, followed by all channel 1's data, and so on.
    /// More specifically, the value of channel c of the texel at (x, y, z)
    /// is at index
    ///
    /// `((c * depth() + z) * height() + y) * width() + x`.
    ///
    /// @note If the image has GPU data (see ToGPU()), this performs a
    /// GPU-to-CPU copy.
    data :: (this: /*const*/ *Surface) -> *float #cpp_method #foreign nvtt "?data@Surface@nvtt@@QEBAPEBMXZ";

    /// @brief Returns a `const` pointer to channel i's CPU data.
    ///
    /// Data is stored in [z, y, x] order; that is, all channel 0's data
    /// comes first, followed by all channel 1's data, and so on.
    /// More specifically, the value of channel c of the texel at (x, y, z)
    /// is at index
    ///
    /// `(z * height() + y) * width() + x`
    ///
    /// of channel(c).
    ///
    /// @note If the image has GPU data (see ToGPU()), this performs a
    /// GPU-to-CPU copy.
    channel :: (this: /*const*/ *Surface, i: s32) -> *float #cpp_method #foreign nvtt "?channel@Surface@nvtt@@QEBAPEBMH@Z";

    /// @brief Returns a pointer that can be used to modify the surface's CPU data. See data() const.
    data_1 :: (this: *Surface) -> *float #cpp_method #foreign nvtt "?data@Surface@nvtt@@QEAAPEAMXZ";

    /// @brief Returns a pointer that can be used to modify channel i's CPU data. See channel(int) const.
    channel_1 :: (this: *Surface, i: s32) -> *float #cpp_method #foreign nvtt "?channel@Surface@nvtt@@QEAAPEAMH@Z";

    /// @brief Stores a histogram of channel values between `rangeMin` and
    /// `rangeMax` into `binPtr[0...binCount-1]`.
    ///
    /// `binPtr` must be an array of at least `binCount` integers.
    /// This function does not clear `binPtr`'s values, in case we want to
    /// accumulate multiple histograms.
    ///
    /// Each texel's value is linearly mapped to a bin, using floor
    /// rounding. Values below `rangeMin` are clamped to bin 0, values
    /// above `rangeMax` are clamped to bin `binCount-1`. Then the bin's
    /// value is incremented.
    histogram :: (this: *Surface, channel: s32, rangeMin: float, rangeMax: float, binCount: s32, binPtr: *s32, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?histogram@Surface@nvtt@@QEBAXHMMHPEAHPEAUTimingContext@2@@Z";

    /// @brief Sets `*rangeMin` and `*rangeMax` to the range of values in
    /// the channel, possibly using alpha testing.
    ///
    /// If `alpha_channel` is -1, this sets `*rangeMin` to the smallest
    /// value in the entire channel, and `*rangeMax` to the largest value
    /// in the entire channel. Otherwise, this only includes texels for
    /// which the alpha value is greater than `alpha_ref`.
    ///
    /// If the image is null or if an alpha channel is selected and all
    /// texels fail the alpha test, this sets `*rangeMin` to `FLT_MAX` and
    /// `*rangeMax` to `FLT_MIN`, i.e. one will have `*rangeMin > *rangeMax`.
    range :: (this: *Surface, channel: s32, rangeMin: *float, rangeMax: *float, alpha_channel: s32 = -1, alpha_ref: float = 0.0, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?range@Surface@nvtt@@QEBAXHPEAM0HMPEAUTimingContext@2@@Z";

    /// @brief Loads texture data from a file.
    ///
    /// @returns `true` if loading succeeded and `false` if it failed.
    ///
    /// @param fileName Path to the file to load. This uses the same
    /// character encoding as the `filename` argument of `fopen()`.
    /// @param hasAlpha If this is non-null, then `*hasAlpha` will be set
    /// to whether the reader reported that the file included
    /// an alpha channel.
    /// @param expectSigned If this is true, then some forms of unsigned
    /// data will be converted to signed using the mapping x |-> 2x-1.
    load :: (this: *Surface, fileName: *u8, hasAlpha: *bool = null, expectSigned := false, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?load@Surface@nvtt@@QEAA_NPEBDPEA_N_NPEAUTimingContext@2@@Z";

    /// @brief Variant of load() that reads from memory instead of a file.
    ///
    /// @returns `true` if loading succeeded and `false` if it failed.
    ///
    /// @param data Pointer to the start of the file's data in memory.
    /// @param sizeInBytes Length of the file's data.
    /// @param hasAlpha If this is non-null, then `*hasAlpha` will be set
    /// to whether the reader reported that the file included
    /// an alpha channel.
    /// @param expectSigned If this is true, then some forms of unsigned
    /// data will be converted to signed using the mapping x |-> 2x-1.
    loadFromMemory :: (this: *Surface, data: *void, sizeInBytes: u64, hasAlpha: *bool = null, expectSigned := false, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?loadFromMemory@Surface@nvtt@@QEAA_NPEBX_KPEA_N_NPEAUTimingContext@2@@Z";

    /// @brief Saves texture data to file.
    ///
    /// @returns `true` if saving succeeded and `false` if it failed.
    ///
    /// @param fileName Path to the file to load. This uses the same
    /// character encoding as the `filename` argument of `fopen()`.
    /// @param hasAlpha If true, then TGA images will be saved with an alpha channel.
    /// @param hdr If true, then this will attempt to use a writer that supports
    /// an HDR format before attempting to use an LDR format writer.
    save :: (this: *Surface, fileName: *u8, hasAlpha := false, hdr := false, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?save@Surface@nvtt@@QEBA_NPEBD_N1PEAUTimingContext@2@@Z";

    /// @brief Sets this surface to a new w x h x d uninitialized image.
    ///
    /// Surfaces are not GPU-enabled by default. The surface's texture type
    /// will be set to TextureType_2D if `d == 1`, and TextureType_3D
    /// otherwise.
    /// @returns `true`
    setImage :: (this: *Surface, w: s32, h: s32, d: s32, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?setImage@Surface@nvtt@@QEAA_NHHHPEAUTimingContext@2@@Z";

    /// @brief Sets this surface given uncompressed input data.
    ///
    /// The type of values in `data` should match `format`.
    ///
    /// If `unsignedToSigned` is true, #InputFormat_BGRA_8UB unsigned input
    /// will be converted to signed values between -1 and 1, mapping 0 to
    /// -1, and 1...255 linearly to -1...1.
    ///
    /// Returns whether setting the image succeeded.
    ///
    /// @see setImage(int, int, int, TimingContext*)
    setImage :: (this: *Surface, format: InputFormat, w: s32, h: s32, d: s32, data: *void, unsignedToSigned := false, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?setImage@Surface@nvtt@@QEAA_NW4InputFormat@2@HHHPEBX_NPEAUTimingContext@2@@Z";

    /// @brief Sets this surface given uncompressed input data, with different pointers for each channel.
    ///
    /// The type of values in `data` should match `format`.
    ///
    /// Returns whether setting the image succeeded.
    ///
    /// @see setImage(int, int, int, TimingContext*)
    setImage :: (this: *Surface, format: InputFormat, w: s32, h: s32, d: s32, r: *void, g: *void, b: *void, a: *void, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?setImage@Surface@nvtt@@QEAA_NW4InputFormat@2@HHHPEBX111PEAUTimingContext@2@@Z";

    /// @brief Set 2D surface values from an encoded data source. Same as setImage3D() with `d=1`.
    setImage2D :: (this: *Surface, format: Format, w: s32, h: s32, data: *void, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?setImage2D@Surface@nvtt@@QEAA_NW4Format@2@HHPEBXPEAUTimingContext@2@@Z";

    /// @brief Set surface values from an encoded data source.
    ///
    /// For instance, this can be used to decompress BC1-BC7 or ASTC data.
    ///
    /// Returns whether setting the image succeeded.
    setImage3D :: (this: *Surface, format: Format, w: s32, h: s32, d: s32, data: *void, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?setImage3D@Surface@nvtt@@QEAA_NW4Format@2@HHHPEBXPEAUTimingContext@2@@Z";

    /// Resizes this surface to have size w x h x d using a given filter.
    resize :: (this: *Surface, w: s32, h: s32, d: s32, filter: ResizeFilter, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?resize@Surface@nvtt@@QEAAXHHHW4ResizeFilter@2@PEAUTimingContext@2@@Z";

    /// Resizes this surface using customizable filter parameters.
    ///
    /// @see #ResizeFilter for filter-specific parameters.
    resize :: (this: *Surface, w: s32, h: s32, d: s32, filter: ResizeFilter, filterWidth: float, params: *float = null, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?resize@Surface@nvtt@@QEAAXHHHW4ResizeFilter@2@MPEBMPEAUTimingContext@2@@Z";

    /// @brief Resizes this surface so that its largest side has length `maxExtent`, subject to a rounding mode.
    /// @see getTargetExtent()
    resize :: (this: *Surface, maxExtent: s32, mode: RoundMode, filter: ResizeFilter, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?resize@Surface@nvtt@@QEAAXHW4RoundMode@2@W4ResizeFilter@2@PEAUTimingContext@2@@Z";

    /// @brief Resizes this surface so that its largest side has length `maxExtent`, subject to a rounding mode, using customizable filter parameters.
    /// @see getTargetExtent()
    resize :: (this: *Surface, maxExtent: s32, mode: RoundMode, filter: ResizeFilter, filterWidth: float, params: *float = null, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?resize@Surface@nvtt@@QEAAXHW4RoundMode@2@W4ResizeFilter@2@MPEBMPEAUTimingContext@2@@Z";

    /// @brief Resizes this surface so that its longest side has length `maxExtent` and the result is square or cubical.
    ///
    /// For 2D surfaces, the size is determined using getTargetExtent(),
    /// then using the minimum of the width and height. For 3D surfaces,
    /// the size is similarly determined using getTargetExtent(), then
    /// using the minimum of the width, height, or depth.
    resize_make_square :: (this: *Surface, maxExtent: s32, roundMode: RoundMode, filter: ResizeFilter, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?resize_make_square@Surface@nvtt@@QEAAXHW4RoundMode@2@W4ResizeFilter@2@PEAUTimingContext@2@@Z";

    /// @brief Resizes this surface to create the next mip in a mipmap chain.
    ///
    /// Returns false iff the next mip would have been smaller than
    /// `min_size` (signaling the end of the mipmap chain).
    buildNextMipmap :: (this: *Surface, filter: MipmapFilter, min_size: s32 = 1, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?buildNextMipmap@Surface@nvtt@@QEAA_NW4MipmapFilter@2@HPEAUTimingContext@2@@Z";

    /// @brief Version of buildNextMipmap(MipmapFilter, int, TimingContext*) with customizable parameters.
    ///
    /// @see #MipmapFilter for the effects of different parameters.
    buildNextMipmap :: (this: *Surface, filter: MipmapFilter, filterWidth: float, params: *float = null, min_size: s32 = 1, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?buildNextMipmap@Surface@nvtt@@QEAA_NW4MipmapFilter@2@MPEBMHPEAUTimingContext@2@@Z";

    /// @brief Replaces this surface with a surface the size of the next
    /// mip in a mip chain (half the width and height), but with each
    /// channel cleared to a constant value.
    ///
    /// @param color_components is an array of the value for each channel;
    /// it must be at least as long as the number of channels in the surface.
    buildNextMipmapSolidColor :: (this: *Surface, color_components: *float, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?buildNextMipmapSolidColor@Surface@nvtt@@QEAA_NQEBMPEAUTimingContext@2@@Z";

    /// Crops or expands this surface from the (0,0,0) corner, with any new values cleared to 0.
    canvasSize :: (this: *Surface, w: s32, h: s32, d: s32, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?canvasSize@Surface@nvtt@@QEAAXHHHPEAUTimingContext@2@@Z";

    /// @brief Returns whether a the surface would have a next mip in a mip
    /// chain with minimum size `min_size.
    ///
    /// That is, it returns false if this surface has size 1x1x1, or if
    /// the width and height are less than `min_size` and the depth is 1.
    canMakeNextMipmap :: (this: *Surface, min_size: s32 = 1) -> bool #cpp_method #foreign nvtt "?canMakeNextMipmap@Surface@nvtt@@QEAA_NH@Z";

    /// @brief Raises channels 0...2 to the power `gamma`.
    ///
    /// `gamma=2.2` approximates sRGB-to-linear conversion.
    ///
    /// @see toGamma()
    /// @see toLinearFromSrgb()
    toLinear :: (this: *Surface, gamma: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toLinear@Surface@nvtt@@QEAAXMPEAUTimingContext@2@@Z";

    /// @brief Raises channels 0...2 to the power `1/gamma`.
    ///
    /// `gamma=2.2` approximates linear-to-sRGB conversion.
    ///
    /// @see toLinear()
    /// @see toSrgb()
    toGamma :: (this: *Surface, gamma: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toGamma@Surface@nvtt@@QEAAXMPEAUTimingContext@2@@Z";

    /// @brief Raises the given channel to the power `gamma`.
    /// @see toLinear(float, TimingContext*)
    toLinear :: (this: *Surface, channel: s32, gamma: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toLinear@Surface@nvtt@@QEAAXHMPEAUTimingContext@2@@Z";

    /// @brief Raises the given channel to the power `1/gamma`.
    /// @see toGamma(float, TimingContext*)
    toGamma :: (this: *Surface, channel: s32, gamma: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toGamma@Surface@nvtt@@QEAAXHMPEAUTimingContext@2@@Z";

    /// @brief Applies the linear-to-sRGB transfer function to channels 0...2.
    ///
    /// This transfer function replaces each value `x` with
    /// ```text
    /// if x is NaN or x <= 0.0f, 0.0f
    /// if x <= 0.0031308f, 12.92f * x
    /// if x <  1.0f, powf(x, 1.0f/2.4f) * 1.055f - 0.055f
    /// otherwise, 1.0f
    /// ```
    ///
    /// @see toLinearFromSrgb()
    toSrgb :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toSrgb@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Applies the linear-to-sRGB transfer function to channels 0...2, but does not clamp output to [0,1].
    ///
    /// The motivation for this function is that it can approximately
    /// preserve HDR values through sRGB conversion and back; that is,
    /// s.toSrgbUnclamped().toLinearFromSrgbUnclamped() is close to s.
    ///
    /// This transfer function replaces each value `x` with
    /// ```text
    /// if x is NaN or x <= 0.0f, x
    /// if x <= 0.0031308f, 12.92f * x
    /// otherwise, powf(x, 1.0f/2.4f) * 1.055f - 0.055f
    /// ```
    ///
    /// @since NVTT 3.2
    /// @see toLinearFromSrgbUnclamped()
    toSrgbUnclamped :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toSrgbUnclamped@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Applies the sRGB-to-linear transfer function to channels 0...2.
    ///
    /// This transfer function replaces each value `x` with
    /// ```text
    /// if x < 0.0f, 0.0f
    /// if x < 0.04045f, x / 12.92f
    /// if x < 1.0f, powf((x + 0.055f)/1.055f, 2.4f)
    /// otherwise, 1.0f
    /// ```
    ///
    /// @see toSrgb()
    toLinearFromSrgb :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toLinearFromSrgb@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Applies the sRGB-to-linear transfer function to channels 0...2, but does not clamp output to [0,1].
    ///
    /// The motivation for this function is that it can approximately
    /// preserve HDR values through sRGB conversion and back; that is,
    /// s.toSrgbUnclamped().toLinearFromSrgbUnclamped() is close to s.
    ///
    /// This transfer function replaces each value `x` with
    /// ```text
    /// if x is NaN or x <= 0.0f, x
    /// if x < 0.04045f, x / 12.92f
    /// otherwise, powf((x + 0.055f)/1.055f, 2.4f)
    /// ```
    ///
    /// @since NVTT 3.2
    /// @see toSrgbUnclamped()
    toLinearFromSrgbUnclamped :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toLinearFromSrgbUnclamped@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Converts colors in channels 0...2 from linear to a
    /// piecewise linear sRGB approximation.
    ///
    /// This transfer function replaces each value `x` with
    /// ```text
    /// if x < 0,    0.0f
    /// if x < 1/16, 4.0f * x
    /// if x < 1/8,  2.0f * x + 0.125f
    /// if x < 1/2,         x + 0.25f
    /// if x < 1,    0.5f * x + 0.5f
    /// otherwise, 1.0f
    /// ```
    ///
    /// @see Alex Vlachos, Post Processing in The Orange Box, GDC 2008
    /// @see toLinearFromXenonSrgb()
    toXenonSrgb :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toXenonSrgb@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Converts colors in channels 0...2 from the Xenon sRGB
    /// piecewise linear sRGB approximation to linear.
    ///
    /// This transfer function replaces each value `x` with
    /// ```text
    /// if x < 0,    0.0f
    /// if x < 1/4,  x/4.0f
    /// if x < 3/8, (x - 0.125f) / 2.0f
    /// if x < 3/4,  x - 0.25f
    /// if x < 1,   (x - 0.5f) / 0.5f
    /// otherwise, 1.0f
    /// ```
    ///
    /// @since NVTT 3.2
    /// @see Alex Vlachos, Post Processing in The Orange Box, GDC 2008
    /// @see toXenonSrgb()
    toLinearFromXenonSrgb :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toLinearFromXenonSrgb@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Applies a 4x4 affine transformation to the values in channels 0...3.
    ///
    /// `w0`...`w3` are the columns of the matrix. `offset` is added after
    /// the matrix-vector multiplication.
    ///
    /// In other words, all (r, g, b, a) values are replaced with
    /// ```text
    /// (r)   (w0[0], w1[0], w2[0], w3[0]) (r)   (offset[0])
    /// (g) = (w0[1], w1[1], w2[1], w3[1]) (g) + (offset[1])
    /// (b)   (w0[2], w1[2], w2[2], w3[2]) (b)   (offset[2])
    /// (a)   (w0[3], w1[3], w2[3], w3[3]) (a)   (offset[3])
    /// ```
    transform :: (this: *Surface, w0: *[4] float, w1: *[4] float, w2: *[4] float, w3: *[4] float, offset: *[4] float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?transform@Surface@nvtt@@QEAAXQEBM0000PEAUTimingContext@2@@Z";

    /// @brief Swizzles the channels of the surface.
    ///
    /// Each argument specifies where the corresponding channel should come
    /// from. For instance, setting r to 2 would mean that the red (0)
    /// channel would be set to the current 2nd channel.
    ///
    /// In addition, the special values 4, 5, and 6 represent setting the
    /// channel to a constant value of 1.0f, 0.0f, or -1.0f, respectively.
    swizzle :: (this: *Surface, r: s32, g: s32, b: s32, a: s32, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?swizzle@Surface@nvtt@@QEAAXHHHHPEAUTimingContext@2@@Z";

    /// @brief Applies a scale and bias to the given channel. Each value x is replaced by x * scale + bias.
    scaleBias :: (this: *Surface, channel: s32, scale: float, bias: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?scaleBias@Surface@nvtt@@QEAAXHMMPEAUTimingContext@2@@Z";

    /// @brief Clamps all values in the channel to the range [low, high].
    clamp :: (this: *Surface, channel: s32, low: float = 0.0, high: float = 1.0, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?clamp@Surface@nvtt@@QEAAXHMMPEAUTimingContext@2@@Z";

    /// @brief Interpolates all texels between their current color and a constant color `(r, g, b, a)`.
    ///
    /// `t` is the value used for linearly interpolating between the
    /// surface's current colors and the constant color. For instance, a
    /// value of `t=0` has no effect to the surface's colors, and a value
    /// of `t=1` replaces the surface's colors entirely with (r, g, b, a).
    blend :: (this: *Surface, r: float, g: float, b: float, a: float, t: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?blend@Surface@nvtt@@QEAAXMMMMMPEAUTimingContext@2@@Z";

    /// @brief Converts to premultiplied alpha, replacing `(r, g, b, a)` with `(ar, ag, ab, a)`.
    premultiplyAlpha :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?premultiplyAlpha@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Converts from premultiplied to unpremultiplied alpha, with special handling around zero alpha values.
    ///
    /// When `abs(a) >= epsilon`, the result is the same as dividing the
    /// RGB channels by the alpha channel. Otherwise, this function divides
    /// the RGB channels by `epsilon * sign(a)`, since the result of
    /// unpremultiplying a fully transparent color is undefined.
    demultiplyAlpha :: (this: *Surface, epsilon: float = 0.0, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?demultiplyAlpha@Surface@nvtt@@QEAAXMPEAUTimingContext@2@@Z";

    /// @brief Sets channels 0...3 to the result of converting to grayscale, with customizable channel weights.
    ///
    /// For instance, this can be used to give green a higher weight than
    /// red or blue when computing luminance. This function will normalize
    /// the different scales so they sum to 1, so e.g. (2, 4, 1, 0) are
    /// valid scales. The greyscale value is then computed using
    /// ```c
    /// grey = r * redScale + g * greenScale + b * blueScale + a * alphaScale
    /// ```
    /// and then all channels (including alpha) are set to `grey`.
    toGreyScale :: (this: *Surface, redScale: float, greenScale: float, blueScale: float, alphaScale: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toGreyScale@Surface@nvtt@@QEAAXMMMMPEAUTimingContext@2@@Z";

    /// @brief Sets all texels on the border of the surface to a solid color.
    setBorder :: (this: *Surface, r: float, g: float, b: float, a: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?setBorder@Surface@nvtt@@QEAAXMMMMPEAUTimingContext@2@@Z";

    /// @brief Sets all texels in the surface to a solid color.
    fill :: (this: *Surface, r: float, g: float, b: float, a: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?fill@Surface@nvtt@@QEAAXMMMMPEAUTimingContext@2@@Z";

    /// @brief Attempts to scale the alpha channel so that a fraction
    /// `coverage` (between 0 and 1) of the surface has an alpha greater
    /// than `alphaRef`.
    ///
    /// @see alphaTestCoverage() for the method used to determine what fraction passes the alpha test.
    /// @see Ignacio Casta&ntilde;o, "Computing Alpha Mipmaps" (2010)
    scaleAlphaToCoverage :: (this: *Surface, coverage: float, alphaRef: float = 0.5, alpha_channel: s32 = 3, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?scaleAlphaToCoverage@Surface@nvtt@@QEAAXMMHPEAUTimingContext@2@@Z";

    /// @brief Produces an LDR Red, Green, Blue, Magnitude encoding of the HDR RGB channels.
    ///
    /// See fromRGBM() for the storage method. This uses an iterative
    /// compression approach to reduce the error with regard to decoding.
    toRGBM :: (this: *Surface, range: float = 1.0, threshold: float = 0.25, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toRGBM@Surface@nvtt@@QEAAXMMPEAUTimingContext@2@@Z";

    /// @brief Produces HDR `(r, g, b, 1)` values from an LDR `(red, green, blue, magnitude)` storage method.
    ///
    /// HDR values are reconstructed as follows: First, the magnitude `M`
    /// is reconstructed from the alpha channel using
    /// `M = a * (range - threshold) + threshold`. Then the red, green,
    /// and blue channels are multiplied by `M`.
    fromRGBM :: (this: *Surface, range: float = 1.0, threshold: float = 0.25, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?fromRGBM@Surface@nvtt@@QEAAXMMPEAUTimingContext@2@@Z";

    /// @brief Stores luminance-only values in a two-channel way. Maybe consider BC4 compression instead.
    ///
    /// Luminance `L` is computed by averaging the red, green, and blue
    /// values, while `M` stores the max of these values and `threshold`.
    /// The red, green, and blue channels then store `L/M`, and the alpha
    /// channel stores `(M - threshold)/(1 - threshold)`.
    toLM :: (this: *Surface, range: float = 1.0, threshold: float = 0.0, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toLM@Surface@nvtt@@QEAAXMMPEAUTimingContext@2@@Z";

    /// @brief Produces a shared-exponent Red, Green, Blue, Exponent encoding of the HDR RGB channels, such as R9G9B9E5.
    ///
    /// `mantissaBits` and `exponentBits` must be in the range 1...31.
    ///
    /// See fromRGBE() for the storage method. This uses an iterative
    /// compression approach to reduce the error with regard to decoding.
    toRGBE :: (this: *Surface, mantissaBits: s32, exponentBits: s32, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toRGBE@Surface@nvtt@@QEAAXHHPEAUTimingContext@2@@Z";

    /// @brief Produces HDR `(r, g, b, 1)` values from an LDR `(red, green, blue, exponent)` storage method.
    ///
    /// HDR values are reconstructed as follows:
    /// R, G, B, and E are first converted from UNORM floats to integers by
    /// multiplying RGB by `(1 << mantissaBits) - 1` and
    /// E by `(1 << exponentBits) - 1`. E stores a scaling factor as a
    /// power of 2, which is reconstructed using
    /// `scale = 2^(E - ((1 << (exponentBits - 1)) - 1) - mantissaBits)`.
    /// R, G, and B are then multiplied by `scale`.
    ///
    /// `mantissaBits` and `exponentBits` must be in the range 1...31.
    fromRGBE :: (this: *Surface, mantissaBits: s32, exponentBits: s32, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?fromRGBE@Surface@nvtt@@QEAAXHHPEAUTimingContext@2@@Z";

    /// @brief Converts from `(r, g, b, -)` colors to `(Co, Cg, 1, Y)` colors.
    ///
    /// This is useful for formats that use chroma subsampling.
    ///
    /// Y is in the range [0, 1], while Co and Cg are in the range [-1, 1].
    ///
    /// The RGB-to-YCoCg formula used is
    /// ```c
    /// Y  = (2g + r + b)/4
    /// Co = r - b
    /// Cg = (2g - r - b)/2
    /// ```
    toYCoCg :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toYCoCg@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Stores per-block YCoCg scaling information for potentially better 4-channel compression of YCoCg data.
    ///
    /// For each 4x4 block, this computes the maximum absolute Co and Cg
    /// values, stores the result in the blue channel, and multiplies the
    /// Co and Cg channels (0 and 1) by its reciprocal. The original Co
    /// and Cg values can then be reconstructed by multiplying by the
    /// blue channel.
    ///
    /// The scaling information is quantized to the given number of bits.
    ///
    /// `threshold` is ignored.
    ///
    /// @note This assumes that your texture compression format uses 4x4
    /// blocks. This is true for all BC1-BC7 formats, but ASTC can use
    /// other block sizes.
    blockScaleCoCg :: (this: *Surface, bits: s32 = 5, threshold: float = 0.0, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?blockScaleCoCg@Surface@nvtt@@QEAAXHMPEAUTimingContext@2@@Z";

    /// @brief Converts from `(Co, Cg, scale, Y)` colors to `(r, g, b, 1)` colors.
    ///
    /// This is useful for formats that use chroma subsampling.
    ///
    /// Y is in the range [0, 1], while Co and Cg are in the range [-1, 1].
    /// Co and Cg are multiplied by channel 2 (scale) to reverse the
    /// effects of optionally calling blockScaleCoCg().
    ///
    /// The YCoCg-to-RGB formula used is
    /// ```c
    /// r = Y + Co - Cg
    /// g = Y + Cg
    /// b = Y - Co - Cg
    /// ```
    fromYCoCg :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?fromYCoCg@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Converts from RGB colors to a (U, V, W, L) color space, much like RGBM.
    ///
    /// All values are clamped to [0, 1]. Then a luminance-like value
    /// `L` is computed from RGB using
    ///
    /// `L = max(sqrtf(R^2 + G^2 + B^2), 1e-6f)`.
    ///
    /// This then stores the value `(R/L, G/L, B/L, L/sqrt(3))`.
    toLUVW :: (this: *Surface, range: float = 1.0, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toLUVW@Surface@nvtt@@QEAAXMPEAUTimingContext@2@@Z";

    /// @brief Converts from toLUVW()'s color space to RGB colors.
    ///
    /// This is the same as fromRGBM(range * sqrt(3)).
    fromLUVW :: (this: *Surface, range: float = 1.0, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?fromLUVW@Surface@nvtt@@QEAAXMPEAUTimingContext@2@@Z";

    /// @brief Replaces all colors by their absolute value.
    abs :: (this: *Surface, channel: s32, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?abs@Surface@nvtt@@QEAAXHPEAUTimingContext@2@@Z";

    /// @brief Convolves a channel with a kernel.
    ///
    /// This uses a 2D kernelSize x kernelSize kernel, with values in
    /// `kernelData` specified in row-major order. The behavior around
    /// image borders is determined by the image's wrap mode.
    convolve :: (this: *Surface, channel: s32, kernelSize: s32, kernelData: *float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?convolve@Surface@nvtt@@QEAAXHHPEAMPEAUTimingContext@2@@Z";

    /// @brief Replaces all values with their log with the given base.
    toLogScale :: (this: *Surface, channel: s32, base: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toLogScale@Surface@nvtt@@QEAAXHMPEAUTimingContext@2@@Z";

    /// @brief Inverts toLogScale() by replacing all values `x` with `base^x`.
    fromLogScale :: (this: *Surface, channel: s32, base: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?fromLogScale@Surface@nvtt@@QEAAXHMPEAUTimingContext@2@@Z";

    /// @brief Draws borders of a given color around each w x h tile
    /// contained within the surface, starting from the (0, 0) corner.
    ///
    /// In case the surface size is not divisible by the tile size, borders
    /// are not drawn for tiles crossing the surface boundary.
    setAtlasBorder :: (this: *Surface, w: s32, h: s32, r: float, g: float, b: float, a: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?setAtlasBorder@Surface@nvtt@@QEAAXHHMMMMPEAUTimingContext@2@@Z";

    /// @brief Applies an HDR-to-LDR tone mapper.
    /// @see #ToneMapper for definitions of the tone mappers.
    toneMap :: (this: *Surface, tm: ToneMapper, parameters: *float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toneMap@Surface@nvtt@@QEAAXW4ToneMapper@2@PEAMPEAUTimingContext@2@@Z";

    /// @brief Sets values in the given channel to either 1 or 0 depending on if they're greater than the threshold, with optional dithering.
    /// @param dither If true, uses Floyd-Steinberg dithering on the CPU. Not supported for 3D surfaces.
    binarize :: (this: *Surface, channel: s32, threshold: float, dither: bool, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?binarize@Surface@nvtt@@QEAAXHM_NPEAUTimingContext@2@@Z";

    /// @brief Quantizes this channel to a particular number of bits, with optional dithering.
    /// @param channel The index of the channel to quantize.
    /// @param bits The number of bits to quantize to, yielding `2^bits` possible values.
    /// Must be nonnegative, and must not be 0 if exactEndPoints is true.
    /// @param exactEndPoints If true, the set of quantized values will be
    /// `0, 1/(2^bits-1), ..., 1`, rather than `0, 1/(2^bits), ..., (2^bits-1)/(2^bits)`.
    /// @param dither If true, uses Floyd-Steinberg dithering on the CPU. Not supported for 3D surfaces.
    quantize :: (this: *Surface, channel: s32, bits: s32, exactEndPoints: bool, dither: bool, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?quantize@Surface@nvtt@@QEAAXHH_N0PEAUTimingContext@2@@Z";

    /// @brief Sets the RGB channels to a normal map generated by interpreting the alpha channel as a heightmap,
    /// using a blend of four small-scale to large-scale Sobel kernels.
    ///
    /// This uses a 9x9 kernel which is a weighted sum of a 3x3 (small),
    /// 5x5 (medium), 7x7 (big), and 9x9 (large) differentiation kernels.
    /// Each of the weights can be greater than 1, or even negative.
    /// However, the kernel will be normalized so that its elements sum to
    /// 1, so scaling should be done on the alpha channel beforehand.
    /// The smallest kernel focuses on the highest-frequency details, and
    /// larger kernels attenuate higher frequencies.
    ///
    /// The source alpha channel, which is used as a height map to
    /// differentiate, is copied to the output.
    ///
    /// The output RGB channels will be in the ranges [-1, 1], [-1, 1], and [0, 1].
    ///
    /// @see convolve()
    toNormalMap :: (this: *Surface, sm: float, medium: float, big: float, large: float, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toNormalMap@Surface@nvtt@@QEAAXMMMMPEAUTimingContext@2@@Z";

    /// @brief Renormalizes the elements of a signed normal map, replacing `(r, g, b)` with `normalize(r, g, b)`.
    ///
    /// This function is safe to call even for zero vectors.
    normalizeNormalMap :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?normalizeNormalMap@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Applies a 3D->2D normal transformation, setting the z (blue) channel to 0.
    ///
    /// @see #NormalTransform for definitions of each of the normal transformations.
    transformNormals :: (this: *Surface, xform: NormalTransform, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?transformNormals@Surface@nvtt@@QEAAXW4NormalTransform@2@PEAUTimingContext@2@@Z";

    /// @brief Reconstructs 3D normals from 2D transformed normals.
    ///
    /// @see #NormalTransform for definitions of each of the normal transformations.
    reconstructNormals :: (this: *Surface, xform: NormalTransform, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?reconstructNormals@Surface@nvtt@@QEAAXW4NormalTransform@2@PEAUTimingContext@2@@Z";

    /// @brief Sets the z (blue) channel to x^2 + y^2.
    ///
    /// If the x and y channels represent slopes, instead of normals, then
    /// this represents a CLEAN map. The important thing about this is that
    /// it can be mipmapped, and the difference between the sum of the
    /// square of the first and second mipmapped channels and the third
    /// mipmapped channel can be used to determine how rough the normal
    /// map is in a given area.
    ///
    /// This is a lower-memory and lower-bandwidth version of LEAN mapping,
    /// but it has the drawback that it can only represent
    /// isotropic roughness.
    ///
    /// @see Olano and Baker, "LEAN Mapping", https://www.csee.umbc.edu/~olano/papers/lean/
    /// @see Hill, "Specular Showdown in the Wild West", http://blog.selfshadow.com/2011/07/22/specular-showdown/
    /// @see http://gaim.umbc.edu/2011/07/24/shiny-and-clean/
    /// @see http://gaim.umbc.edu/2011/07/26/on-error/
    toCleanNormalMap :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?toCleanNormalMap@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Packs signed normals in [-1, 1] to an unsigned range [0, 1], using (r, g, b, a) |-> (r/2+1/2, g/2+1/2, b/2+1/2, a).
    packNormals :: (this: *Surface, scale: float = 0.5, bias: float = 0.5, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?packNormals@Surface@nvtt@@QEAAXMMPEAUTimingContext@2@@Z";

    /// @brief Expands packed normals in [0, 1] to signed normals in [-1, 1] using (r, g, b, a) |-> (2r-1, 2g-1, 2b-1, a).
    expandNormals :: (this: *Surface, scale: float = 2.0, bias: float = -1.0, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?expandNormals@Surface@nvtt@@QEAAXMMPEAUTimingContext@2@@Z";

    /// @brief Unimplemented. This would equivalent to mipmapping a normal map and then measuring how much
    /// mipmapping shortens the normals. Currently returns a null surface.
    /// @see Hill, "Specular Showdown in the Wild West", http://blog.selfshadow.com/2011/07/22/specular-showdown/
    createToksvigMap :: (this: *Surface, power: float, tc: *TimingContext = null) -> Surface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?createToksvigMap@Surface@nvtt@@QEBA?AU12@MPEAUTimingContext@2@@Z";

    /// @brief Unimplemented. Currently returns a null surface.
    /// @see toCleanNormalMap()
    createCleanMap :: (this: *Surface, tc: *TimingContext = null) -> Surface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?createCleanMap@Surface@nvtt@@QEBA?AU12@PEAUTimingContext@2@@Z";

    /// @brief Flips the surface along the X axis.
    flipX :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?flipX@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Flips the surface along the Y axis.
    flipY :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?flipY@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Flips the surface along the Z axis.
    flipZ :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?flipZ@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Creates a new surface from the range of pixels from x = x0 to x1, y = y0 to y1, and z = z0 to z1.
    ///
    /// If any of the parameters are out of bounds or creation fails, returns a null surface.
    ///
    /// A valid surface created will have size (x1 - x0 + 1) x (y1 - y0 + 1) x (z1 - z0 + 1).
    createSubImage :: (this: *Surface, x0: s32, x1: s32, y0: s32, y1: s32, z0: s32, z1: s32, tc: *TimingContext = null) -> Surface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?createSubImage@Surface@nvtt@@QEBA?AU12@HHHHHHPEAUTimingContext@2@@Z";

    /// @brief Copies channel `srcChannel` from `srcImage` to `srcChannel` of this surface.
    ///
    /// Returns whether the operation succeeded (for instance, it can fail
    /// if the surfaces have different sizes).
    ///
    /// `srcChannel` must be in the range [0, 3].
    ///
    /// The surfaces need not have the same GPU mode.
    copyChannel :: (this: *Surface, srcImage: *Surface, srcChannel: s32, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?copyChannel@Surface@nvtt@@QEAA_NAEBU12@HPEAUTimingContext@2@@Z";
    copyChannel :: (this: *Surface, srcImage: Surface, srcChannel: s32, tc: *TimingContext = null) -> bool #no_context {
        return copyChannel(this, *srcImage, srcChannel, tc);
    }

    /// @brief Copies channel `srcChannel` from `srcImage` to `dstChannel` of this surface.
    ///
    /// Returns whether the operation succeeded (for instance, it can fail
    /// if the surfaces have different sizes).
    ///
    /// Both `srcChannel` and `dstChannel` must be in the range [0, 3].
    ///
    /// The surfaces need not have the same GPU mode.
    copyChannel :: (this: *Surface, srcImage: *Surface, srcChannel: s32, dstChannel: s32, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?copyChannel@Surface@nvtt@@QEAA_NAEBU12@HHPEAUTimingContext@2@@Z";
    copyChannel :: (this: *Surface, srcImage: Surface, srcChannel: s32, dstChannel: s32, tc: *TimingContext = null) -> bool #no_context {
        return copyChannel(this, *srcImage, srcChannel, dstChannel, tc);
    }

    /// @brief Add channel `srcChannel` of `img`, multiplied by `scale`, to `dstChannel` of this surface.
    ///
    /// Returns whether the operation succeeded (for instance, it can fail
    /// if the surfaces have different sizes).
    ///
    /// Both `srcChannel` and `dstChannel` must be in the range [0, 3].
    ///
    /// The surfaces need not have the same GPU mode.
    addChannel :: (this: *Surface, img: *Surface, srcChannel: s32, dstChannel: s32, scale: float, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?addChannel@Surface@nvtt@@QEAA_NAEBU12@HHMPEAUTimingContext@2@@Z";
    addChannel :: (this: *Surface, img: Surface, srcChannel: s32, dstChannel: s32, scale: float, tc: *TimingContext = null) -> bool #no_context {
        return addChannel(this, *img, srcChannel, dstChannel, scale, tc);
    }

    /// @brief Copies all channels of a rectangle from `src` to this surface.
    ///
    /// More specifically, this copies the rectangle
    ///
    /// `[xsrc, xsrc + xsize - 1] x [ysrc, ysrc + ysize - 1] x [zsrc, zsrc + zsize - 1]`
    ///
    /// to the rectangle
    ///
    /// `[xdst, xdst + xsize - 1] x [ydst, ydst + ysize - 1] x [zdst, zdst + zsize - 1]`.
    ///
    /// Returns whether the operation succeeded (for instance, invalid
    /// parameters return false).
    copy :: (this: *Surface, src: *Surface, xsrc: s32, ysrc: s32, zsrc: s32, xsize: s32, ysize: s32, zsize: s32, xdst: s32, ydst: s32, zdst: s32, tc: *TimingContext = null) -> bool #cpp_method #foreign nvtt "?copy@Surface@nvtt@@QEAA_NAEBU12@HHHHHHHHHPEAUTimingContext@2@@Z";
    copy :: (this: *Surface, src: Surface, xsrc: s32, ysrc: s32, zsrc: s32, xsize: s32, ysize: s32, zsize: s32, xdst: s32, ydst: s32, zdst: s32, tc: *TimingContext = null) -> bool #no_context {
        return copy(this, *src, xsrc, ysrc, zsrc, xsize, ysize, zsize, xdst, ydst, zdst, tc);
    }

    /// @brief Makes succeeding operations work on the GPU buffer.
    ///
    /// This also copies the surface's CPU data to a new or recreated GPU buffer.
    ///
    /// @since NVTT 3.0
    ToGPU :: (this: *Surface, tc: *TimingContext = null, performCopy := true) -> void #cpp_method #foreign nvtt "?ToGPU@Surface@nvtt@@QEAAXPEAUTimingContext@2@_N@Z";

    /// @brief Makes succeeding operations work on the CPU buffer.
    ///
    /// This copies the surface's GPU buffer to the CPU buffer, then destroys the GPU buffer.
    ///
    /// @since NVTT 3.0
    ToCPU :: (this: *Surface, tc: *TimingContext = null) -> void #cpp_method #foreign nvtt "?ToCPU@Surface@nvtt@@QEAAXPEAUTimingContext@2@@Z";

    /// @brief Get a CUDA pointer to const image data on the GPU, using the same layout as data().
    /// If GPU data does not exist, returns `nullptr`.
    gpuData :: (this: *Surface) -> *float #cpp_method #foreign nvtt "?gpuData@Surface@nvtt@@QEBAPEBMXZ";

    /// @brief Get a CUDA pointer to non-const image data on the GPU, using the same layout as data().
    /// If GPU data does not exist, returns `nullptr`.
    /// This can be used to modify NVTT Surface data on the GPU, outside of
    /// the functions NVTT provides.
    /// @since NVTT 3.2
    gpuDataMutable :: (this: *Surface) -> *float #cpp_method #foreign nvtt "?gpuDataMutable@Surface@nvtt@@QEAAPEAMXZ";

    Private :: struct {}
    m: *Private;
}

/// Assignment operator.
operator_assign :: (this: *Surface, img: *Surface) -> void #cpp_method #foreign nvtt "??4Surface@nvtt@@QEAAXAEBU01@@Z";
operator_assign :: (this: *Surface, img: Surface) #no_context {
    operator_assign(this, *img);
}

/// @brief Surface-set struct for convenience of handling multi-level texture files such as DDS, currently only supporting reading.
/// @since NVTT 3.0
SurfaceSet :: struct {
    Private :: struct {}
    m: *Private;

    /// Constructor
    Constructor :: (this: *SurfaceSet) -> void #cpp_method #foreign nvtt "??0SurfaceSet@nvtt@@QEAA@XZ";

    /// Destructor
    Destructor :: (this: *SurfaceSet) -> void #cpp_method #foreign nvtt "??1SurfaceSet@nvtt@@QEAA@XZ";

    /// Texture type: 2D, 3D, or Cube
    GetTextureType :: (this: *SurfaceSet) -> TextureType #cpp_method #foreign nvtt "?GetTextureType@SurfaceSet@nvtt@@QEAA?AW4TextureType@2@XZ";

    /// Number of faces
    GetFaceCount :: (this: *SurfaceSet) -> s32 #cpp_method #foreign nvtt "?GetFaceCount@SurfaceSet@nvtt@@QEAAHXZ";

    /// Number of mip-map levels
    GetMipmapCount :: (this: *SurfaceSet) -> s32 #cpp_method #foreign nvtt "?GetMipmapCount@SurfaceSet@nvtt@@QEAAHXZ";

    /// Image width (level 0)
    GetWidth :: (this: *SurfaceSet) -> s32 #cpp_method #foreign nvtt "?GetWidth@SurfaceSet@nvtt@@QEAAHXZ";

    /// Image height (level 0)
    GetHeight :: (this: *SurfaceSet) -> s32 #cpp_method #foreign nvtt "?GetHeight@SurfaceSet@nvtt@@QEAAHXZ";

    /// Image depth (level 0)
    GetDepth :: (this: *SurfaceSet) -> s32 #cpp_method #foreign nvtt "?GetDepth@SurfaceSet@nvtt@@QEAAHXZ";

    /// Get a surface at specified face and mip level
    GetSurface :: (this: *SurfaceSet, faceId: s32, mipId: s32, expectSigned := false) -> Surface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?GetSurface@SurfaceSet@nvtt@@QEAA?AUSurface@2@HH_N@Z";

    /// Get a surface at specified face and mip level
    GetSurface :: (this: *SurfaceSet, faceId: s32, mipId: s32, surface: *Surface, expectSigned := false) -> void #cpp_method #foreign nvtt "?GetSurface@SurfaceSet@nvtt@@QEAAXHHAEAUSurface@2@_N@Z";

    /// Release data
    reset :: (this: *SurfaceSet) -> void #cpp_method #foreign nvtt "?reset@SurfaceSet@nvtt@@QEAAXXZ";

    /// @brief Load a surface set from a DDS file.
    /// @returns `true` if loading succeeded and `false` if it failed.
    ///
    /// @param fileName Path to the file to load. This uses the same
    /// character encoding as the `filename` argument of `fopen()`.
    /// @param forcenormal If true, builds a normal map from the red and
    /// green components of BC5U data, or the alpha and green components of
    /// BC3 data.
    loadDDS :: (this: *SurfaceSet, fileName: *u8, forcenormal := false) -> bool #cpp_method #foreign nvtt "?loadDDS@SurfaceSet@nvtt@@QEAA_NPEBD_N@Z";

    /// @brief Load a surface set from an in-memory DDS file.
    /// @returns `true` if loading succeeded and `false` if it failed.
    ///
    /// @param data Pointer to the start of the file's data in memory.
    /// @param sizeInBytes Length of the file's data.
    /// @param forcenormal If true, builds a normal map from the red and
    /// green components of BC5U data, or the alpha and green components of
    /// BC3 data.
    loadDDSFromMemory :: (this: *SurfaceSet, data: *void, sizeInBytes: u64, forcenormal := false) -> bool #cpp_method #foreign nvtt "?loadDDSFromMemory@SurfaceSet@nvtt@@QEAA_NPEBX_K_N@Z";

    /// Save an image at specified face and mip level (for decompression)
    saveImage :: (this: *SurfaceSet, fileName: *u8, faceId: s32, mipId: s32) -> bool #cpp_method #foreign nvtt "?saveImage@SurfaceSet@nvtt@@QEAA_NPEBDHH@Z";
}

/// @brief Specifies how to fold or unfold a cube map from or to a 2D texture.
/// @since NVTT 2.1
CubeLayout :: enum s32 {
    VerticalCross     :: 0;

    HorizontalCross   :: 1;

    Column            :: 2;

    Row               :: 3;

    LatitudeLongitude :: 4;
}

/// @brief Use EdgeFixup_None if unsure; this affects how certain cube surface processing algorithms work.
EdgeFixup :: enum s32 {
    None    :: 0;
    Stretch :: 1;
    Warp    :: 2;
    Average :: 3;
}

/// @brief A CubeSurface is one level of a cube map texture.
///
/// CubeSurfaces are either null, or contain six square Surfaces numbered
/// 0 through 5, all with the same size (referred to as the edge length).
/// By convention, these are the +x, -x, +y, -y, +z, and -z faces, in that
/// order, of a cube map in a right-handed coordinate system.
///
/// These objects are reference-counted like nvtt::Surface.
///
/// @since NVTT 2.1
CubeSurface :: struct {
    /// Creates a null CubeSurface.
    Constructor :: (this: *CubeSurface) -> void #cpp_method #foreign nvtt "??0CubeSurface@nvtt@@QEAA@XZ";

    /// Copy constructor.
    CopyConstructor :: (this: *CubeSurface, img: *CubeSurface) -> void #cpp_method #foreign nvtt "??0CubeSurface@nvtt@@QEAA@AEBU01@@Z";
    CopyConstructor :: (this: *CubeSurface, img: CubeSurface) #no_context {
        CopyConstructor(this, *img);
    }

    /// Destructor.
    Destructor :: (this: *CubeSurface) -> void #cpp_method #foreign nvtt "??1CubeSurface@nvtt@@QEAA@XZ";

    /// @brief Returns if this CubeSurface is null (i.e. has no underlying
    /// data, or all faces have size 0x0).
    isNull :: (this: *CubeSurface) -> bool #cpp_method #foreign nvtt "?isNull@CubeSurface@nvtt@@QEBA_NXZ";

    /// Returns the edge length of any of the faces.
    edgeLength :: (this: *CubeSurface) -> s32 #cpp_method #foreign nvtt "?edgeLength@CubeSurface@nvtt@@QEBAHXZ";

    /// @brief Returns the number of mips that would be in a full mipmap
    /// chain starting with this CubeSurface.
    ///
    /// For instance, a full mip chain for a cube map with 10x10 faces
    /// would consist of cube maps with sizes 10x10, 5x5, 2x2, and 1x1, and
    /// this function would return 4.
    countMipmaps :: (this: *CubeSurface) -> s32 #cpp_method #foreign nvtt "?countMipmaps@CubeSurface@nvtt@@QEBAHXZ";

    /// @brief Load a cube map from a DDS file.
    ///
    /// @param fileName Path to the file to load. This uses the same
    /// character encoding as the `filename` argument of `fopen()`.
    /// @param mipmap The mip to read. If `mipmap` is negative, then this
    /// reads the `abs(mipmap)`'th smallest mipmap.
    ///
    /// If the DDS file has multiple array elements, this always loads the first one.
    ///
    /// Returns whether the operation succeeded (for instance, this can
    /// fail if the file does not exist or if the mipmap was out of range).
    load :: (this: *CubeSurface, fileName: *u8, mipmap: s32) -> bool #cpp_method #foreign nvtt "?load@CubeSurface@nvtt@@QEAA_NPEBDH@Z";

    /// @brief Load a cube map from a DDS file in memory.
    ///
    /// @param data Pointer to the start of the file's data in memory.
    /// @param sizeInBytes Length of the file's data.
    /// @param mipmap The mip to read. If `mipmap` is negative, then this
    /// reads the `abs(mipmap)`'th smallest mipmap.
    ///
    /// If the DDS file has multiple array elements, this always loads the first one.
    ///
    /// Returns whether the operation succeeded (for instance, this can
    /// fail if the file does not exist or if the mipmap was out of range).
    loadFromMemory :: (this: *CubeSurface, data: *void, sizeInBytes: u64, mipmap: s32) -> bool #cpp_method #foreign nvtt "?loadFromMemory@CubeSurface@nvtt@@QEAA_NPEBX_KH@Z";

    /// @brief Save a cube map to a DDS file in memory.
    ///
    /// Unimplemented - iterate over faces and save them instead.
    save :: (this: *CubeSurface, fileName: *u8) -> bool #cpp_method #foreign nvtt "?save@CubeSurface@nvtt@@QEBA_NPEBD@Z";

    /// @brief Get a non-const reference to the surface for the given face.
    ///
    /// `face` must be in the range [0, 5].
    face :: (this: *CubeSurface, face: s32) -> *Surface #cpp_method #foreign nvtt "?face@CubeSurface@nvtt@@QEAAAEAUSurface@2@H@Z";

    /// @brief Get a const reference to the surface for the given face.
    ///
    /// `face` must be in the range [0, 5].
    face_1 :: (this: /*const*/ *CubeSurface, face: s32) -> *Surface #cpp_method #foreign nvtt "?face@CubeSurface@nvtt@@QEBAAEBUSurface@2@H@Z";

    /// @brief Sets this CubeSurface from a 2D unfolded surface in `img`.
    ///
    /// @see #CubeLayout for allowed folding layouts.
    fold :: (this: *CubeSurface, img: *Surface, layout: CubeLayout) -> void #cpp_method #foreign nvtt "?fold@CubeSurface@nvtt@@QEAAXAEBUSurface@2@W4CubeLayout@2@@Z";
    fold :: (this: *CubeSurface, img: Surface, layout: CubeLayout) #no_context {
        fold(this, *img, layout);
    }

    /// @brief Creates a Surface containing an unfolded/flattened representation of the cube surface.
    ///
    /// @see #CubeLayout for allowed folding layouts.
    unfold :: (this: *CubeSurface, layout: CubeLayout) -> Surface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?unfold@CubeSurface@nvtt@@QEBA?AUSurface@2@W4CubeLayout@2@@Z";

    /// @brief Computes an average value for the given channel over the entire sphere.
    ///
    /// This takes solid angles into account when producing an average per
    /// steradian, so texels near face edges are weighted less than texels
    /// near face edges.
    ///
    /// No gamma correction is performed, unlike nvtt::Surface::average().
    average :: (this: *CubeSurface, channel: s32) -> float #cpp_method #foreign nvtt "?average@CubeSurface@nvtt@@QEBAMH@Z";

    /// @brief Sets `*minimum_ptr` and `*maximum_ptr` to the minimum and
    /// maximum values in the given channel.
    ///
    /// If all faces have size 0 x 0 (in which case the cube surface isNull()),
    /// this will set `*minimum_ptr` to `FLT_MAX` and `*maximum_ptr` to 0.0f.
    range :: (this: *CubeSurface, channel: s32, minimum_ptr: *float, maximum_ptr: *float) -> void #cpp_method #foreign nvtt "?range@CubeSurface@nvtt@@QEBAXHPEAM0@Z";

    /// Clamps values in the given channel to the range [low, high].
    clamp :: (this: *CubeSurface, channel: s32, low: float = 0.0, high: float = 1.0) -> void #cpp_method #foreign nvtt "?clamp@CubeSurface@nvtt@@QEAAXHMM@Z";

    /// Unimplemented; returns a null CubeSurface.
    irradianceFilter :: (this: *CubeSurface, size: s32, fixupMethod: EdgeFixup) -> CubeSurface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?irradianceFilter@CubeSurface@nvtt@@QEBA?AU12@HW4EdgeFixup@2@@Z";

    /// @brief Spherically convolves this CubeSurface with a
    /// `max(0.0f, cos(theta))^cosinePower` kernel, returning a CubeSurface
    /// with faces with dimension size x size.
    ///
    /// This is useful for generating prefiltered cube maps, as this
    /// corresponds to the cosine power used in the Phong reflection model
    /// (with energy conservation).
    ///
    /// This handles how each cube map texel can have a different solid angle.
    /// It also only considers texels for which the value of the kernel
    /// (without normalization) is at least 0.001.
    cosinePowerFilter :: (this: *CubeSurface, size: s32, cosinePower: float, fixupMethod: EdgeFixup) -> CubeSurface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?cosinePowerFilter@CubeSurface@nvtt@@QEBA?AU12@HMW4EdgeFixup@2@@Z";

    /// Produces a resized version of this CubeSurface using nearest-neighbor sampling.
    fastResample :: (this: *CubeSurface, size: s32, fixupMethod: EdgeFixup) -> CubeSurface #cpp_method #cpp_return_type_is_non_pod #foreign nvtt "?fastResample@CubeSurface@nvtt@@QEBA?AU12@HW4EdgeFixup@2@@Z";

    /// @brief Raises channels 0...2 to the power `gamma`.
    ///
    /// Using a `gamma` of 2.2 approximates sRGB-to-linear conversion.
    ///
    /// @see nvtt::Surface::toLinear()
    toLinear :: (this: *CubeSurface, gamma: float) -> void #cpp_method #foreign nvtt "?toLinear@CubeSurface@nvtt@@QEAAXM@Z";

    /// @brief Raises channels 0...2 to the power `1/gamma`.
    ///
    /// Using a `gamma` of 2.2 approximates linear-to-sRGB conversion.
    ///
    /// @see nvtt::Surface::toGamma()
    toGamma :: (this: *CubeSurface, gamma: float) -> void #cpp_method #foreign nvtt "?toGamma@CubeSurface@nvtt@@QEAAXM@Z";

    Private :: struct {}
    m: *Private;
}

/// Assignment operator.
operator_assign :: (this: *CubeSurface, img: *CubeSurface) -> void #cpp_method #foreign nvtt "??4CubeSurface@nvtt@@QEAAXAEBU01@@Z";
operator_assign :: (this: *CubeSurface, img: CubeSurface) #no_context {
    operator_assign(this, *img);
}

/// @brief Structure defining a list of inputs to be compressed.
///
/// Inputs will be combined for parallel GPU processing.
/// Better performance expected comparing to the Surface-only API, which compresses each image one by one, especially when the images are small.
///
/// @since NVTT 3.0
BatchList :: struct {
    Private :: struct {}
    m: *Private;

    /// Creates an empty BatchList.
    Constructor :: (this: *BatchList) -> void #cpp_method #foreign nvtt "??0BatchList@nvtt@@QEAA@XZ";

    /// Destructor.
    Destructor :: (this: *BatchList) -> void #cpp_method #foreign nvtt "??1BatchList@nvtt@@QEAA@XZ";

    /// Clears the list of inputs in this BatchList.
    Clear :: (this: *BatchList) -> void #cpp_method #foreign nvtt "?Clear@BatchList@nvtt@@QEAAXXZ";

    /// Adds a pointer to the surface, its face and mipmap index, and a pointer to the output method to the input list.
    Append :: (this: *BatchList, pImg: *Surface, face: s32, mipmap: s32, outputOptions: *OutputOptions) -> void #cpp_method #foreign nvtt "?Append@BatchList@nvtt@@QEAAXPEBUSurface@2@HHPEBUOutputOptions@2@@Z";

    /// Returns the size of the input list.
    GetSize :: (this: *BatchList) -> u32 #cpp_method #foreign nvtt "?GetSize@BatchList@nvtt@@QEBAIXZ";

    /// Gets the `i`th item in the input list.
    GetItem :: (this: *BatchList, i: u32, pImg: **Surface, face: *s32, mipmap: *s32, outputOptions: **OutputOptions) -> void #cpp_method #foreign nvtt "?GetItem@BatchList@nvtt@@QEBAXIAEAPEBUSurface@2@AEAH1AEAPEBUOutputOptions@2@@Z";
}

/// Image comparison and error measurement functions. (New in NVTT 2.1)
rmsError :: (reference: *Surface, img: *Surface, tc: *TimingContext = null) -> float #foreign nvtt "?rmsError@nvtt@@YAMAEBUSurface@1@0PEAUTimingContext@1@@Z";
rmsError :: (reference: Surface, img: Surface, tc: *TimingContext = null) -> float #no_context {
    return rmsError(*reference, *img, tc);
}

/// Image comparison and error measurement functions. (New in NVTT 2.1)
rmsAlphaError :: (reference: *Surface, img: *Surface, tc: *TimingContext = null) -> float #foreign nvtt "?rmsAlphaError@nvtt@@YAMAEBUSurface@1@0PEAUTimingContext@1@@Z";
rmsAlphaError :: (reference: Surface, img: Surface, tc: *TimingContext = null) -> float #no_context {
    return rmsAlphaError(*reference, *img, tc);
}

/// Image comparison and error measurement functions. (New in NVTT 2.1)
cieLabError :: (reference: *Surface, img: *Surface, tc: *TimingContext = null) -> float #foreign nvtt "?cieLabError@nvtt@@YAMAEBUSurface@1@0PEAUTimingContext@1@@Z";
cieLabError :: (reference: Surface, img: Surface, tc: *TimingContext = null) -> float #no_context {
    return cieLabError(*reference, *img, tc);
}

/// Image comparison and error measurement functions. (New in NVTT 2.1)
angularError :: (reference: *Surface, img: *Surface, tc: *TimingContext = null) -> float #foreign nvtt "?angularError@nvtt@@YAMAEBUSurface@1@0PEAUTimingContext@1@@Z";
angularError :: (reference: Surface, img: Surface, tc: *TimingContext = null) -> float #no_context {
    return angularError(*reference, *img, tc);
}

/// Image comparison and error measurement functions. (New in NVTT 2.1)
diff :: (reference: *Surface, img: *Surface, scale: float, tc: *TimingContext = null) -> Surface #cpp_return_type_is_non_pod #foreign nvtt "?diff@nvtt@@YA?AUSurface@1@AEBU21@0MPEAUTimingContext@1@@Z";
diff :: (reference: Surface, img: Surface, scale: float, tc: *TimingContext = null) -> Surface #no_context {
    return diff(*reference, *img, scale, tc);
}

/// Image comparison and error measurement functions. (New in NVTT 2.1)
rmsToneMappedError :: (reference: *Surface, img: *Surface, exposure: float, tc: *TimingContext = null) -> float #foreign nvtt "?rmsToneMappedError@nvtt@@YAMAEBUSurface@1@0MPEAUTimingContext@1@@Z";
rmsToneMappedError :: (reference: Surface, img: Surface, exposure: float, tc: *TimingContext = null) -> float #no_context {
    return rmsToneMappedError(*reference, *img, exposure, tc);
}

/// Generate histogram from surface
histogram :: (img: *Surface, width: s32, height: s32, tc: *TimingContext = null) -> Surface #cpp_return_type_is_non_pod #foreign nvtt "?histogram@nvtt@@YA?AUSurface@1@AEBU21@HHPEAUTimingContext@1@@Z";
histogram :: (img: Surface, width: s32, height: s32, tc: *TimingContext = null) -> Surface #no_context {
    return histogram(*img, width, height, tc);
}

/// Generate histogram from surface
histogram :: (img: *Surface, minRange: float, maxRange: float, width: s32, height: s32, tc: *TimingContext = null) -> Surface #cpp_return_type_is_non_pod #foreign nvtt "?histogram@nvtt@@YA?AUSurface@1@AEBU21@MMHHPEAUTimingContext@1@@Z";
histogram :: (img: Surface, minRange: float, maxRange: float, width: s32, height: s32, tc: *TimingContext = null) -> Surface #no_context {
    return histogram(*img, minRange, maxRange, width, height, tc);
}

/// Geting the target extent for round-mode and texture-type. (New in NVTT 3.0)
getTargetExtent :: (width: *s32, height: *s32, depth: *s32, maxExtent: s32, roundMode: RoundMode, textureType: TextureType, tc: *TimingContext = null) -> void #foreign nvtt "?getTargetExtent@nvtt@@YAXPEAH00HW4RoundMode@1@W4TextureType@1@PEAUTimingContext@1@@Z";

/// Calculate the count of mipmaps given width, height, depth. (New in NVTT 3.0)
countMipmaps :: (w: s32, h: s32, d: s32, tc: *TimingContext = null) -> s32 #foreign nvtt "?countMipmaps@nvtt@@YAHHHHPEAUTimingContext@1@@Z";

/// @brief A TimingContext is a way to collect timing data from a number of
/// functions, and report how much time each function took.
///
/// Since NVTT 3.0, many functions will take an optional TimingContext
/// pointer. If the `detailLevel` of the TimingContext is high enough,
/// the function will record the function name and how much CPU time the
/// function took, synchronizing with the CPU if necessary. One can then
/// get individual records using GetRecord(), or print all statistics
/// using PrintRecords().
///
/// @since NVTT 3.0
TimingContext :: struct {
    /// @brief Creates a TimingContext with the given `detailLevel`.
    ///
    /// Functions will only collect timing data if their detail level
    /// (usually 2 or 3) is less than or equal to the TimingContext's
    /// `detailLevel`.
    Constructor :: (this: *TimingContext, detailLevel: s32 = 1) -> void #cpp_method #foreign nvtt "??0TimingContext@nvtt@@QEAA@H@Z";

    /// Destructor.
    Destructor :: (this: *TimingContext) -> void #cpp_method #foreign nvtt "??1TimingContext@nvtt@@QEAA@XZ";

    /// @brief Sets this TimingContext's detail level.
    ///
    /// Functions will only collect timing data if their detail level
    /// (usually 2 or 3) is less than or equal to the TimingContext's
    /// `detailLevel`.
    SetDetailLevel :: (this: *TimingContext, detailLevel: s32) -> void #cpp_method #foreign nvtt "?SetDetailLevel@TimingContext@nvtt@@QEAAXH@Z";

    /// Returns the number of timing records stored.
    GetRecordCount :: (this: *TimingContext) -> s32 #cpp_method #foreign nvtt "?GetRecordCount@TimingContext@nvtt@@QEAAHXZ";

    /// @brief Returns the description and length in seconds of the `i`th record.
    ///
    /// `outDescriptionSize` is the size in bytes of the buffer pointed to
    /// by `outDescription`. GetRecord() truncates (if necessary) the
    /// record's description to `outDescriptionSize-1` bytes, and always
    /// writes a null terminator.
    ///
    /// Returns the number of bytes written,
    /// not including the null terminator.
    /// If `outDescription` is null, returns the number of bytes in the
    /// record's description.
    /// If `i` is out of bounds, returns 0.
    GetRecord :: (this: *TimingContext, i: s32, outDescription: *u8, outDescriptionSize: u64, outSeconds: *float64) -> u64 #cpp_method #foreign nvtt "?GetRecord@TimingContext@nvtt@@QEAA_KHPEAD_KAEAN@Z";

    /// @brief Prints all records including their levels of nesting.
    ///
    /// NVTT keeps track of how deeply timers are nested, so this will
    /// print out each description and length with an indentation
    /// corresponding to its nesting depth.
    PrintRecords :: (this: *TimingContext) -> void #cpp_method #foreign nvtt "?PrintRecords@TimingContext@nvtt@@QEAAXXZ";

    Private :: struct {}
    m: *Private;
}

#scope_file

#import "Basic"; // For assert

nvtt :: #library "bin/nvtt30205";

#run {
    {
        info := type_info(RefImage);
        for info.members {
            if it.name == {
                case "data";
                    assert(it.offset_in_bytes == 0, "RefImage.data has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "RefImage.data has unexpected size % instead of 8", it.type.runtime_size);
                case "width";
                    assert(it.offset_in_bytes == 8, "RefImage.width has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "RefImage.width has unexpected size % instead of 4", it.type.runtime_size);
                case "height";
                    assert(it.offset_in_bytes == 12, "RefImage.height has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "RefImage.height has unexpected size % instead of 4", it.type.runtime_size);
                case "depth";
                    assert(it.offset_in_bytes == 16, "RefImage.depth has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "RefImage.depth has unexpected size % instead of 4", it.type.runtime_size);
                case "num_channels";
                    assert(it.offset_in_bytes == 20, "RefImage.num_channels has unexpected offset % instead of 20", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "RefImage.num_channels has unexpected size % instead of 4", it.type.runtime_size);
                case "channel_swizzle";
                    assert(it.offset_in_bytes == 24, "RefImage.channel_swizzle has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 16, "RefImage.channel_swizzle has unexpected size % instead of 16", it.type.runtime_size);
                case "channel_interleave";
                    assert(it.offset_in_bytes == 40, "RefImage.channel_interleave has unexpected offset % instead of 40", it.offset_in_bytes);
                    assert(it.type.runtime_size == 1, "RefImage.channel_interleave has unexpected size % instead of 1", it.type.runtime_size);
            }
        }
        assert(size_of(RefImage) == 48, "RefImage has size % instead of 48", size_of(RefImage));
    }

    {
        info := type_info(CPUInputBuffer);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "CPUInputBuffer.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "CPUInputBuffer.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(CPUInputBuffer) == 8, "CPUInputBuffer has size % instead of 8", size_of(CPUInputBuffer));
    }

    {
        info := type_info(GPUInputBuffer);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "GPUInputBuffer.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "GPUInputBuffer.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(GPUInputBuffer) == 8, "GPUInputBuffer has size % instead of 8", size_of(GPUInputBuffer));
    }

    {
        info := type_info(EncodeSettings);
        for info.members {
            if it.name == {
                case "sType";
                    assert(it.offset_in_bytes == 0, "EncodeSettings.sType has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "EncodeSettings.sType has unexpected size % instead of 4", it.type.runtime_size);
                case "format";
                    assert(it.offset_in_bytes == 4, "EncodeSettings.format has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "EncodeSettings.format has unexpected size % instead of 4", it.type.runtime_size);
                case "quality";
                    assert(it.offset_in_bytes == 8, "EncodeSettings.quality has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "EncodeSettings.quality has unexpected size % instead of 4", it.type.runtime_size);
                case "rgb_pixel_type";
                    assert(it.offset_in_bytes == 12, "EncodeSettings.rgb_pixel_type has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "EncodeSettings.rgb_pixel_type has unexpected size % instead of 4", it.type.runtime_size);
                case "timing_context";
                    assert(it.offset_in_bytes == 16, "EncodeSettings.timing_context has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "EncodeSettings.timing_context has unexpected size % instead of 8", it.type.runtime_size);
                case "encode_flags";
                    assert(it.offset_in_bytes == 24, "EncodeSettings.encode_flags has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "EncodeSettings.encode_flags has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(EncodeSettings) == 32, "EncodeSettings has size % instead of 32", size_of(EncodeSettings));
    }

    {
        info := type_info(CompressionOptions);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "CompressionOptions.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "CompressionOptions.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(CompressionOptions) == 8, "CompressionOptions has size % instead of 8", size_of(CompressionOptions));
    }

    assert(size_of(OutputHandler) == 8, "OutputHandler has size % instead of 8", size_of(OutputHandler));

    assert(size_of(ErrorHandler) == 8, "ErrorHandler has size % instead of 8", size_of(ErrorHandler));

    {
        info := type_info(OutputOptions);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "OutputOptions.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "OutputOptions.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(OutputOptions) == 8, "OutputOptions has size % instead of 8", size_of(OutputOptions));
    }

    {
        info := type_info(Context);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "Context.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Context.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(Context) == 8, "Context has size % instead of 8", size_of(Context));
    }

    {
        info := type_info(Surface);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "Surface.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Surface.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(Surface) == 8, "Surface has size % instead of 8", size_of(Surface));
    }

    {
        info := type_info(SurfaceSet);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "SurfaceSet.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "SurfaceSet.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(SurfaceSet) == 8, "SurfaceSet has size % instead of 8", size_of(SurfaceSet));
    }

    {
        info := type_info(CubeSurface);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "CubeSurface.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "CubeSurface.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(CubeSurface) == 8, "CubeSurface has size % instead of 8", size_of(CubeSurface));
    }

    {
        info := type_info(BatchList);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "BatchList.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "BatchList.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(BatchList) == 8, "BatchList has size % instead of 8", size_of(BatchList));
    }

    {
        info := type_info(TimingContext);
        for info.members {
            if it.name == {
                case "m";
                    assert(it.offset_in_bytes == 0, "TimingContext.m has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "TimingContext.m has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(TimingContext) == 8, "TimingContext has size % instead of 8", size_of(TimingContext));
    }
}

using,only(Msvc_Destructor_Flags) Windows :: #import "Windows";
