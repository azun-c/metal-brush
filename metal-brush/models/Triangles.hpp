//
//  Triangles.hpp
//  i-Reporter
//
//  Created by 高津 洋一 on 12/11/20.
//  Copyright (c) 2012 CIMTOPS CORPORATION. All rights reserved.
//

#pragma once

#include <vector>
#include "Vertex.hpp"
#include "Vector.hpp"
#include "Polyline.hpp"

struct Triangle {
    Triangle():p1(Vertex()), p2(Vertex()), p3(Vertex()) {};
    Triangle(Vertex p1, Vertex p2, Vertex p3):p1(p1), p2(p2), p3(p3) {};
    
    Vertex p1;
    Vertex p2;
    Vertex p3;
};

class Triangles {
public:
    Triangles();
    Triangles(size_t reserveSize);
    
    void addTriangle(const Triangle& tri);
    void addTriangles(const Triangles& triangles);
    float *ptrToPoints() const;
    float *ptrToTexCod() const;
    
    std::vector<Triangle> m_triangles;
};

void PolylineToTriangles(const Polyline& polyline, float width, Triangles *result);
void PolylineToTriangleStripVertices(const Polyline& polyline, float width, std::vector<Vertex>* pVertices);
