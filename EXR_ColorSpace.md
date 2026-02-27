# EXR Color Space in ReScan

When "EXR Sequence" is enabled in the ReScan settings, the application captures individual frames as 16-bit half-float OpenEXR (`.exr`) files.

## Color Pipeline

ARKit natively delivers camera frames in YCbCr format (usually 8-bit or 10-bit YUV). To save these frames as EXR without losing data and ensuring compatibility with standard VFX/compositing pipelines, the following conversion happens:

1. **YCbCr to RGB Conversion:** CoreImage (`CIImage`) converts the native ARKit YUV pixel buffers into RGB.
2. **Linearization:** The RGB data is mapped to the **Extended Linear sRGB** color space (`CGColorSpace.extendedLinearSRGB`).
3. **Float Conversion:** The color values are encoded as 16-bit half-floats (`.RGBAh`).

## Extended Linear sRGB

The **Extended Linear sRGB** space differs from standard sRGB in two major ways:
- **Linear Transfer Function:** It does NOT have the standard sRGB gamma curve (approx 2.2). The values are scene-linear, meaning a pixel value of 1.0 is exactly twice as bright as 0.5.
- **Extended Range:** Values can drop below 0.0 or go above 1.0. This allows it to hold HDR (High Dynamic Range) information captured by the camera without clipping the highlights.

## Best Practices for Post-Processing

When importing these EXR sequences into compositing or processing software (like Nuke, DaVinci Resolve, Blender, or COLMAP pipelines):

- Ensure your software interprets the incoming files as **Linear sRGB** (or simply "Linear").
- Do **not** apply an sRGB to Linear conversion on import, as the files are already linear.
- Because `extendedLinearSRGB` shares the same color primaries as standard sRGB (Rec. 709 primaries), no gamut mapping is necessary if your working space is Linear sRGB/Rec. 709.
- If your working space is ACEScg, apply a color space transform from **Linear sRGB** to **ACEScg**. 

## Storage & Performance

- **Precision:** 16-bit half-floats provide massive dynamic range while keeping file sizes smaller than 32-bit floats.
- **Size:** Expect EXR sequences to be significantly heavier than HEVC or ProRes videos. Use this mode only when the highest precision linear data is required for photogrammetry or rendering.
