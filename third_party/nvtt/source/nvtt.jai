NvttBoolean :: enum s32 {
    False;
    True;
}

nvttIsCudaSupported :: () -> NvttBoolean #foreign nvtt;

NvttError :: enum s32 {
	None;
	Unknown :: None;
	InvalidInput;
	UnsupportedFeature;
	CudaError;
	FileOpen;
	FileWrite;
    UnsupportedOutputFormat;
	Messaging;
	OutOfHostMemory;
	OutOfDeviceMemory;
	OutputWrite;
	Count;
}

NvttSeverity :: enum s32 {
	Info;
	Warning;
	Error;
	Count;
}

nvttMessageCallback :: #type (severity : NvttSeverity, error : NvttError, message : *u8, userData : *void) #c_call;

nvttSetMessageCallback :: (callback : nvttMessageCallback, userData : *void) -> NvttBoolean #foreign nvtt;

NvttContext :: struct {
    pimpl : *void;
}

nvttCreateContext :: () -> *NvttContext #foreign nvtt;
nvttDestroyContext :: (context_ : *NvttContext) #foreign nvtt;
nvttSetContextCudaAcceleration :: (context_ : *NvttContext, enable : NvttBoolean) #foreign nvtt;
nvttContextIsCudaAccelerationEnabled :: (context_ : *NvttContext) -> NvttBoolean #foreign nvtt;
nvttContextCompress :: (
    context_           : *NvttContext,
    img                : *NvttSurface,
    face               : s32,
    mipmap             : s32,
    compressionOptions : *NvttCompressionOptions,
    outputOptions      : *NvttOutputOptions
) -> NvttBoolean #foreign nvtt;

NvttTimingContext :: struct {
    pimpl : *void;
}

NvttSurface :: struct {
    pimpl : *void;
}

NvttTextureType :: enum s32 {
	_2D;
	_Cube;
	_3D;
}

/// @brief Mipmap downsampling filters. Each of these can be customized using
/// `filterWidth` and `params` when calling nvttSurfaceBuildNextMipmap().
NvttMipmapFilter :: enum s32 {
	/// Box filter is quite good and very fast. It has some special paths
	/// for downsampling by exactly a factor of 2.
	/// `filterWidth` defaults to 0.5; `box(x)` is equal to 1 when
	/// `|x| < filterWidth` and 0 otherwise.
	Box;
	/// Triangle filter blurs the results too much, but that might be what you want.
	/// `filterWidth` defaults to 1.0; `triangle(x)` is equal to
	/// `filterWidth - |x|` when `|x| < filterWidth` and 0 otherwise.
	Triangle;
	/// Kaiser-windowed Sinc filter is the best downsampling filter, and
	/// close to a mathematically ideal windowing filter. If the window
	/// size is too large, it can introduce ringing.
	///
	/// `filterWidth` controls the width of the Kaiser window. Larger
	/// values take longer to compute and include more oscillations of the
	/// sinc filter.
	///
	/// `param[0]` (default: 4.0f) sets `alpha`, the sharpness of the
	/// Kaiser window. Higher values make the main lobe wider, but reduce
	/// sideband energy.
	///
	/// `param[1]` (default: 1.0f) controls the frequency of the sinc
	/// filter. Higher values include higher frequencies.
	///
	/// @see https://en.wikipedia.org/wiki/Kaiser_window
	Kaiser;
	/// Mitchell & Netravali's two parameter cubic filter.
	/// @see NvttMipmapFilter.Mitchell
	///
	/// `filterWidth` (default: 2.0f) can truncate the filter, but should
	/// usually be left at the default.
	///
	/// `param[0]` (default: 1/3) sets B.
	///
	/// `param[1]` (default: 2/3) sets C.
	///
	/// @see "Reconstruction Filters in Computer Graphics", SIGGRAPH 1988
	///
	/// @see https://en.wikipedia.org/wiki/Mitchell%E2%80%93Netravali_filters
	Mitchell;
	/// Takes the minimum over all input texels that contribute to each
	/// output texel.
	///
	/// This is especially useful for generating mipmaps for parallax
	/// occlusion mapping, or for structures like hierarchical Z-buffers.
	///
	/// Specifically, this acts as if for an X x Y x Z image, the texel
	/// at (i, j, k) covers the open box
	/// (i/X, (i+1)/X) x (j/Y, (j+1)/Y) x (k/Z, (k+1)/Z).
	///
	/// Then for each output texel, the set of contributing texels is the
	/// set of input texels whose boxes intersect the output texel's box.
	Min;
	/// Like Min, but takes the maximum over all contributing
	/// texels instead of the minimum.
	Max;
}

nvttCreateSurface :: () -> *NvttSurface #foreign nvtt;
nvttDestroySurface :: (surface : *NvttSurface) #foreign nvtt;
nvttSurfaceClone :: (surface : *NvttSurface) -> *NvttSurface #foreign nvtt;
nvttSurfaceWidth :: (surface : *NvttSurface) -> s32 #foreign nvtt;
nvttSurfaceHeight :: (surface : *NvttSurface) -> s32 #foreign nvtt;
nvttSurfaceDepth :: (surface : *NvttSurface) -> s32 #foreign nvtt;
nvttSurfaceType :: (surface : *NvttSurface) -> NvttTextureType #foreign nvtt;
nvttSurfaceLoadFromMemory :: (
    surface      : *NvttSurface,
    data         : *void,
    sizeInBytes  : u64,
    hasAlpha     : *NvttBoolean       = null,
    expectSigned : NvttBoolean        = .False,
    tc           : *NvttTimingContext = null
) -> NvttBoolean #foreign nvtt;
nvttSurfaceToGPU :: (surface : *NvttSurface, performCopy : NvttBoolean = .True, tc : *NvttTimingContext = null) #foreign nvtt;
nvttSurfaceCountMipmaps :: (surface : *NvttSurface, min_size : s32) -> s32 #foreign nvtt;
nvttSurfaceBuildNextMipmapDefaults :: (
    surface  : *NvttSurface,
    filter   : NvttMipmapFilter,
    min_size : s32                = 1,
    tc       : *NvttTimingContext = null
) -> NvttBoolean #foreign nvtt;
nvttSurfaceToSrgb :: (surface : *NvttSurface, tc : *NvttTimingContext = null) #foreign nvtt;
nvttSurfacePremultiplyAlpha :: (surface : *NvttSurface, tc : *NvttTimingContext = null) #foreign nvtt;
nvttSurfaceDemultiplyAlpha :: (surface : *NvttSurface, epsilon : float32 = 1.0e-12, tc : *NvttTimingContext = null) #foreign nvtt;
nvttSurfacePackNormals :: (surface : *NvttSurface, scale : float32 = 0.5, bias : float32 = 0.5, tc : *NvttTimingContext = null) #foreign nvtt;
nvttSurfaceNormalizeNormalMap :: (surface : *NvttSurface, tc : *NvttTimingContext = null) #foreign nvtt;

NvttCompressionOptions :: struct {
    pimpl : *void;
}

NvttFormat :: enum s32 {
	// No block-compression (linear).
	RGB;  ///< Linear RGB format
	RGBA :: RGB; ///< Linear RGBA format

	// DX9 formats.
	DXT1;    ///< DX9 - DXT1 format
	DXT1a;   ///< DX9 - DXT1 with binary alpha.
	DXT3;    ///< DX9 - DXT3 format
	DXT5;    ///< DX9 - DXT5 format
	DXT5n;   ///< DX9 - DXT5 normal format. Stores a normal (x, y, z) as (R, G, B, A) = (1, y, 0, x).

	// DX10 formats.
	BC1 :: DXT1; ///< DX10 - BC1 (DXT1) format
	BC1a :: DXT1a; ///< DX10 - BC1 (DXT1) format
	BC2 :: DXT3; ///< DX10 - BC2 (DXT3) format
	BC3 :: DXT5; ///< DX10 - BC3 (DXT5) format
	BC3n :: DXT5n; ///< DX10 - BC3 (DXT5) normal format for improved compression, storing a normal (x, y, z) as (1, y, 0, x).
	BC4;     ///< DX10 - BC4U (ATI1) format (one channel, unsigned)
	BC4S;     ///< DX10 - BC4S format (one channel, signed)
	ATI2;     ///< DX10 - ATI2 format, similar to BC5U, channel order GR instead of RG
	BC5;     ///< DX10 - BC5U format (two channels, unsigned)
	BC5S;     ///< DX10 - BC5S format (two channels, signed)

	DXT1n;   ///< Not supported.
	CTX1;    ///< Not supported.

	BC6U;     ///< DX10 - BC6 format (three-channel HDR, unsigned)
	BC6S;     ///< DX10 - BC6 format (three-channel HDR, signed)

	BC7;     ///< DX10 - BC7 format (four channels, UNORM)

	//BC5_Luma,    // Two DXT alpha blocks encoding a single float.
	/// DX10 - BC3(DXT5) - using a magnitude encoding to approximate
	/// three-channel HDR data in four UNORM channels. The input should be
	/// in the range [0,1], and this should give more accurate values
	/// closer to 0. On most devices, consider using BC6 instead.
	///
	/// To decompress this format, decompress it like a standard BC3 texture,
	/// then compute `(R, G, B)` from `(r, g, b, m)` using `fromRGBM()` with
	/// `range = 1` and `threshold = 0.25`:
	///
	/// `M = m * 0.75 + 0.25`;
	///
	/// `(R, G, B) = (r, g, b) * M`
	///
	/// The idea is that since BC3 uses separate compression for the RGB
	/// and alpha blocks, the RGB and M signals can be independent.
	/// Additionally, the compressor can account for the RGB compression
	/// error.
	/// This will print warnings if any of the computed m values were
	/// greater than 1.0.
	BC3_RGBM;

	// 14 ASTC LDR Formats
	// Added by Fei Yang
	ASTC_LDR_4x4; ///< ASTC - LDR - format, tile size 4x4
	ASTC_LDR_5x4; ///< ASTC - LDR - format, tile size 5x4
	ASTC_LDR_5x5; ///< ASTC - LDR - format, tile size 5x5
	ASTC_LDR_6x5; ///< ASTC - LDR - format, tile size 6x5
	ASTC_LDR_6x6; ///< ASTC - LDR - format, tile size 6x6
	ASTC_LDR_8x5; ///< ASTC - LDR - format, tile size 8x5
	ASTC_LDR_8x6; ///< ASTC - LDR - format, tile size 8x6
	ASTC_LDR_8x8; ///< ASTC - LDR - format, tile size 8x8
	ASTC_LDR_10x5; ///< ASTC - LDR - format, tile size 10x5
	ASTC_LDR_10x6; ///< ASTC - LDR - format, tile size 10x6
	ASTC_LDR_10x8; ///< ASTC - LDR - format, tile size 10x8
	ASTC_LDR_10x10; ///< ASTC - LDR - format, tile size 10x10
	ASTC_LDR_12x10; ///< ASTC - LDR - format, tile size 12x10
	ASTC_LDR_12x12; ///< ASTC - LDR - format, tile size 12x12

	Count;

	/// Placeholder in structs to produce errors if a format is not
	/// explicitly set, since format 0 is RGB.
	Unset :: 255;
}

/// Here's a table showing which (format, quality) combinations support
/// CUDA acceleration:
///
/// Quality    | BC1 | BC1a | BC2 | BC3 | BC3n | RGBM | BC4 | BC5 | BC6 | BC7       | ASTC |
/// -----------|-----|------|-----|-----|------|------|-----|-----|-----|-----------|------|
/// Fastest    | Yes | No   | No  | No  | No   | No   | Yes | Yes | Yes | Yes       | Yes  |
/// Normal     | Yes | Yes  | Yes | Yes | Yes  | No   | Yes | Yes | Yes | Yes       | Yes  |
/// Production | Yes | Yes  | Yes | Yes | Yes  | No   | No  | No  | No  | No (slow) | Yes  |
/// Highest    | Yes | Yes  | Yes | Yes | Yes  | No   | No  | No  | No  | No (slow) | Yes  |
NvttQuality :: enum s32 {
	Fastest;
	Normal;
	Production;
	Highest;
}

nvttCreateCompressionOptions :: () -> *NvttCompressionOptions #foreign nvtt;
nvttDestroyCompressionOptions :: (compressionOptions : *NvttCompressionOptions) #foreign nvtt;
nvttSetCompressionOptionsFormat :: (compressionOptions : *NvttCompressionOptions, format : NvttFormat) #foreign nvtt;
nvttSetCompressionOptionsQuality :: (compressionOptions : *NvttCompressionOptions, quality : NvttQuality) #foreign nvtt;

NvttOutputOptions :: struct {
    pimpl : *void;
}

nvttBeginImageHandler :: #type (size : s32, width : s32, height : s32, depth : s32, face : s32, miplevel : s32) #c_call;
nvttOutputHandler     :: #type (data : *void, size : s32) -> NvttBoolean #c_call;
nvttEndImageHandler   :: #type () #c_call;

nvttCreateOutputOptions :: () -> *NvttOutputOptions #foreign nvtt;
nvttDestroyOutputOptions :: (outputOptions : *NvttOutputOptions) #foreign nvtt;
nvttSetOutputOptionsOutputHandler :: (
    outputOptions     : *NvttOutputOptions,
    beginImageHandler : nvttBeginImageHandler,
    outputHandler     : nvttOutputHandler,
    endImageHandler   : nvttEndImageHandler
) #foreign nvtt;
nvttSetOutputOptionsOutputHeader :: (outputOptions : *NvttOutputOptions, b : NvttBoolean) #foreign nvtt;
