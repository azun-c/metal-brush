//
//  shaders.metal
//  metal-brush
//
//  Created by azun on 21/02/2024.
//

#include <metal_stdlib>
using namespace metal;

#include "FreeDrawShaderTypes.h"


#pragma mark - Shaders for simple pipeline used to render triangle to renderable texture

// Vertex shader outputs and fragment shader inputs for simple pipeline
struct NormalRasterizerData
{
    float4 position [[position]];
    float2 texcoord;
};

// Vertex shader which passes position and color through to rasterizer.
vertex NormalRasterizerData
normalVertex(const uint vertexID [[ vertex_id ]],
             const device FreeDrawTextureVertex *vertices [[ buffer(FreeDrawVertexInputIndexVertices) ]])
{
    NormalRasterizerData out;

    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = vertices[vertexID].position.xy;

    out.texcoord = vertices[vertexID].texcoord;

    return out;
}

// Fragment shader that just outputs color passed from rasterizer.
fragment float4 
normalFragment(NormalRasterizerData in [[stage_in]],
               texture2d<float> texture [[texture(FreeDrawTextureInputIndexColor)]])
{
    sampler simpleSampler;

    // Sample data from the texture.
    float4 colorSample = texture.sample(simpleSampler, in.texcoord);

    // Return the color sample as the final color.
    return colorSample;
}

#pragma mark -

#pragma mark Shaders for pipeline used texture from renderable texture when rendering to the drawable.

// Vertex shader outputs and fragment shader inputs for texturing pipeline.
struct WhiteAsAlphaRasterizerData
{
    float4 position [[position]];
    float2 texcoord;
    float4 drawingColor;
};

// Vertex shader which adjusts positions by an aspect ratio and passes texture
// coordinates through to the rasterizer.
vertex WhiteAsAlphaRasterizerData
whiteAsAlphaVertex(const uint vertexID [[ vertex_id ]],
                   const device FreeDrawTextureVertex *vertices [[ buffer(FreeDrawVertexInputIndexVertices) ]],
                   constant float4 &drawColor [[ buffer(FreeDrawVertexInputIndexDrawColor) ]])
{
    WhiteAsAlphaRasterizerData out;

    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);

    out.position.x = vertices[vertexID].position.x;
    out.position.y = vertices[vertexID].position.y;

    out.texcoord = vertices[vertexID].texcoord;
    out.drawingColor = drawColor;

    return out;
}
// Fragment shader that samples a texture and outputs the sampled color.
fragment float4
whiteAsAlphaFragment(WhiteAsAlphaRasterizerData in [[stage_in]],
                     texture2d<float> texture [[texture(FreeDrawTextureInputIndexColor)]])
{
    sampler simpleSampler;

    // Sample data from the texture.
    float4 colorSample = texture.sample(simpleSampler, in.texcoord);

    float alphaFactor = colorSample.r; // alpha factor from Red component
    float4 finalColor = in.drawingColor;
    finalColor.a = finalColor.a * alphaFactor;
    return finalColor;
}
