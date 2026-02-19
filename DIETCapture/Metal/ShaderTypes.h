//
//  ShaderTypes.h
//  DIETCapture
//
//  Shared Metal type definitions used by both Swift and Metal shaders.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Uniforms for depth overlay shader
typedef struct {
    float minDepth;
    float maxDepth;
    float opacity;
    int mode;  // 0 = depth, 1 = confidence
} DepthOverlayUniforms;

#endif /* ShaderTypes_h */
