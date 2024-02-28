//
//  Triangles.cpp
//  i-Reporter
//
//  Created by 高津 洋一 on 12/11/20.
//  Copyright (c) 2012 CIMTOPS CORPORATION. All rights reserved.
//

#include "Triangles.hpp"

Triangles::Triangles() {
}

Triangles::Triangles(size_t reserveSize) {
    m_triangles.resize(reserveSize);
}

void Triangles::addTriangle(const Triangle &tri) {
    m_triangles.push_back(tri);
}

void Triangles::addTriangles(const Triangles &triangles) {
    size_t originalSize = m_triangles.size();
    m_triangles.resize(originalSize + triangles.m_triangles.size());
    for (size_t i = 0; i < triangles.m_triangles.size(); ++i) {
        m_triangles[originalSize + i] = triangles.m_triangles[i];
    }
}

float *Triangles::ptrToPoints() const {
    return (float *)&m_triangles.front().p1.position.x;
}

float *Triangles::ptrToTexCod() const {
    return (float *)&m_triangles.front().p1.texPos.x;
}

void PolylineToTriangles(const Polyline& polyline, float width, Triangles *result) {
    float halfWidth = 0.5*width;
    
    size_t lineCount = polyline.m_points.size() - 1;
    size_t triangleCount = 6*lineCount;
    result->m_triangles.resize(triangleCount);
    
    vec2 SWTex = vec2(0, 0);
    vec2 NWTex = vec2(0, 1);
    vec2 STex = vec2(0.5, 0);
    vec2 NTex = vec2(0.5, 1);
    vec2 NETex = vec2(1, 1);
    vec2 SETex = vec2(1, 0);
    
    for (size_t i = 0; i < lineCount; ++i) {
        vec2 v1 = polyline.m_points[i];
        vec2 v2 = polyline.m_points[i+1];
        vec2 e = (v2 - v1).Normalized()*halfWidth;
        
        vec2 N = vec2(-e.y, e.x);
        vec2 S = -N;
        vec2 NE = N + e;
        vec2 NW = N - e;
        vec2 SW = -NE;
        vec2 SE = -NW;
        
        result->m_triangles[6*i+0].p1.position = v1 + SW;
        result->m_triangles[6*i+0].p2.position = v1 + NW;
        result->m_triangles[6*i+0].p3.position = v1 + S;
        
        result->m_triangles[6*i+1].p1.position = v1 + NW;
        result->m_triangles[6*i+1].p2.position = v1 + S;
        result->m_triangles[6*i+1].p3.position = v1 + N;
        
        result->m_triangles[6*i+2].p1.position = v1 + S;
        result->m_triangles[6*i+2].p2.position = v1 + N;
        result->m_triangles[6*i+2].p3.position = v2 + S;
        
        result->m_triangles[6*i+3].p1.position = v1 + N;
        result->m_triangles[6*i+3].p2.position = v2 + S;
        result->m_triangles[6*i+3].p3.position = v2 + N;
        
        result->m_triangles[6*i+4].p1.position = v2 + S;
        result->m_triangles[6*i+4].p2.position = v2 + N;
        result->m_triangles[6*i+4].p3.position = v2 + SE;
        
        result->m_triangles[6*i+5].p1.position = v2 + N;
        result->m_triangles[6*i+5].p2.position = v2 + SE;
        result->m_triangles[6*i+5].p3.position = v2 + NE;
        
        //// texture座標
        result->m_triangles[6*i+0].p1.texPos = SWTex;
        result->m_triangles[6*i+0].p2.texPos = NWTex;
        result->m_triangles[6*i+0].p3.texPos = STex;
        
        result->m_triangles[6*i+1].p1.texPos = NWTex;
        result->m_triangles[6*i+1].p2.texPos = STex;
        result->m_triangles[6*i+1].p3.texPos = NTex;
        
        result->m_triangles[6*i+2].p1.texPos = STex;
        result->m_triangles[6*i+2].p2.texPos = NTex;
        result->m_triangles[6*i+2].p3.texPos = STex;
        
        result->m_triangles[6*i+3].p1.texPos = NTex;
        result->m_triangles[6*i+3].p2.texPos = STex;
        result->m_triangles[6*i+3].p3.texPos = NTex;
        
        result->m_triangles[6*i+4].p1.texPos = STex;
        result->m_triangles[6*i+4].p2.texPos = NTex;
        result->m_triangles[6*i+4].p3.texPos = SETex;
        
        result->m_triangles[6*i+5].p1.texPos = NTex;
        result->m_triangles[6*i+5].p2.texPos = SETex;
        result->m_triangles[6*i+5].p3.texPos = NETex;
    }
}

void PolylineToTriangleStripVertices(const Polyline& polyline, float width, std::vector<Vertex>* pVertices) {
    float halfWidth = 0.5*width;
    
    size_t lineCount = polyline.m_points.size() - 1;
    
    std::vector<Vertex> vertices;
    
    for (size_t i = 0; i < lineCount; ++i) {
        vec2 v1 = polyline.m_points[i];
        vec2 v2 = polyline.m_points[i+1];
        vec2 e = (v2 - v1).Normalized()*halfWidth; // 方向ベクトル
        
        vec2 N = vec2(-e.y, e.x); // 方向ベクトルを左に90度回転
        vec2 S = -N;
        vec2 NE = N + e;
        vec2 NW = N - e;
        vec2 SW = -NE;
        vec2 SE = -NW;
        
        if (i == 0) {
            Vertex appendStart0;
            appendStart0.position = v1 + SW;
            appendStart0.texPos = vec2(0, 0);
            vertices.push_back(appendStart0);
            
            Vertex appendStart1;
            appendStart1.position = v1 + NW;
            appendStart1.texPos = vec2(0, 1);
            vertices.push_back(appendStart1);
        }
        
        Vertex vert0, vert1, vert2, vert3;
        vert0.position = v1 + S;
        vert0.texPos = vec2(0.5, 0);
        vertices.push_back(vert0);
        
        vert1.position = v1 + N;
        vert1.texPos = vec2(0.5, 1);
        vertices.push_back(vert1);
        
        vert2.position = v2 + S;
        vert2.texPos = vec2(0.5, 0);
        vertices.push_back(vert2);
        
        vert3.position = v2 + N;
        vert3.texPos = vec2(0.5, 1);
        vertices.push_back(vert3);
        
        if (i == lineCount - 1) {
            Vertex appendEnd0;
            appendEnd0.position = v2 + SE;
            appendEnd0.texPos = vec2(1.0, 0.0);
            vertices.push_back(appendEnd0);
            
            Vertex appendEnd1;
            appendEnd1.position = v2 + NE;
            appendEnd1.texPos = vec2(1.0, 1.0);
            vertices.push_back(appendEnd1);
        }
    }
    *pVertices = vertices;
}
