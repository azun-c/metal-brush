//
//  FreeDrawShaderTypes.h
//  metal-brush
//
//  Created by azun on 27/02/2024.
//

#ifndef FreeDrawShaderTypes_h
#define FreeDrawShaderTypes_h

#include <simd/simd.h>

typedef enum FreeDrawVertexInputIndex
{
    FreeDrawVertexInputIndexVertices    = 0,
    FreeDrawVertexInputIndexDrawColor   = 1,
} FreeDrawVertexInputIndex;

typedef enum FreeDrawTextureInputIndex
{
    FreeDrawTextureInputIndexColor = 0
} FreeDrawTextureInputIndex;

typedef enum FreeDrawSamplerInputIndex
{
    FreeDrawSamplerInputIndexSampler = 0
} FreeDrawSamplerInputIndex;

typedef struct
{
    vector_float2 position;
    vector_float2 texcoord;
} FreeDrawTextureVertex;

#endif /* FreeDrawShaderTypes_h */
