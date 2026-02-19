// DepthOverlay.metal
// DIETCapture
//
// Metal shader for real-time depth/confidence colormap overlay on camera feed.
// This shader converts a single-channel depth or confidence texture into a
// jet-colormap RGBA output composited at a given opacity.

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Shader (fullscreen quad)

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut depthOverlayVertex(
    uint vertexID [[vertex_id]]
) {
    // Fullscreen triangle strip
    float2 positions[4] = {
        float2(-1, -1),
        float2( 1, -1),
        float2(-1,  1),
        float2( 1,  1)
    };
    
    float2 texCoords[4] = {
        float2(0, 1),
        float2(1, 1),
        float2(0, 0),
        float2(1, 0)
    };
    
    VertexOut out;
    out.position = float4(positions[vertexID], 0, 1);
    out.texCoord = texCoords[vertexID];
    return out;
}

// MARK: - Jet Colormap Function

float3 jetColormap(float value) {
    float v = clamp(value, 0.0f, 1.0f);
    float3 color;
    
    if (v < 0.125) {
        color = float3(0, 0, 0.5 + v * 4.0);
    } else if (v < 0.375) {
        color = float3(0, (v - 0.125) * 4.0, 1.0);
    } else if (v < 0.625) {
        color = float3((v - 0.375) * 4.0, 1.0, 1.0 - (v - 0.375) * 4.0);
    } else if (v < 0.875) {
        color = float3(1.0, 1.0 - (v - 0.625) * 4.0, 0);
    } else {
        color = float3(1.0 - (v - 0.875) * 4.0, 0, 0);
    }
    
    return color;
}

// MARK: - Depth Overlay Fragment Shader

struct DepthOverlayUniforms {
    float minDepth;
    float maxDepth;
    float opacity;
    int mode;  // 0 = depth, 1 = confidence
};

fragment float4 depthOverlayFragment(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> depthTexture [[texture(0)]],
    texture2d<float, access::sample> cameraTexture [[texture(1)]],
    constant DepthOverlayUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );
    
    // Sample camera RGB
    float4 cameraColor = cameraTexture.sample(textureSampler, in.texCoord);
    
    // Sample depth/confidence
    float depthValue = depthTexture.sample(textureSampler, in.texCoord).r;
    
    if (depthValue <= 0.0) {
        // No depth data — show camera only
        return cameraColor;
    }
    
    float3 overlayColor;
    
    if (uniforms.mode == 0) {
        // Depth mode: normalize and apply jet colormap
        float normalized = (depthValue - uniforms.minDepth) / (uniforms.maxDepth - uniforms.minDepth);
        overlayColor = jetColormap(normalized);
    } else {
        // Confidence mode: 0=red, 1=yellow, 2=green
        if (depthValue < 0.5) {
            overlayColor = float3(1, 0.2, 0.2);  // Red
        } else if (depthValue < 1.5) {
            overlayColor = float3(1, 0.8, 0.2);  // Yellow
        } else {
            overlayColor = float3(0.2, 1, 0.2);  // Green
        }
    }
    
    // Composite overlay onto camera
    float4 result;
    result.rgb = mix(cameraColor.rgb, overlayColor, uniforms.opacity);
    result.a = 1.0;
    
    return result;
}

// MARK: - Depth-Only Fragment (no camera composite)

fragment float4 depthOnlyFragment(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> depthTexture [[texture(0)]],
    constant DepthOverlayUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );
    
    float depthValue = depthTexture.sample(textureSampler, in.texCoord).r;
    
    if (depthValue <= 0.0) {
        return float4(0, 0, 0, 0);
    }
    
    float normalized = (depthValue - uniforms.minDepth) / (uniforms.maxDepth - uniforms.minDepth);
    float3 color = jetColormap(normalized);
    
    return float4(color, uniforms.opacity);
}
