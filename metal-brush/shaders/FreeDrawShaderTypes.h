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
    FreeDrawVertexInputIndexAspectRatio = 1,
} FreeDrawVertexInputIndex;

typedef enum FreeDrawTextureInputIndex
{
    FreeDrawTextureInputIndexColor = 0,
} FreeDrawTextureInputIndex;

typedef struct
{
    vector_float2 position;
    vector_float4 color;
} FreeDrawSimpleVertex;

typedef struct
{
    vector_float2 position;
    vector_float2 texcoord;
} FreeDrawTextureVertex;

#endif /* FreeDrawShaderTypes_h */
