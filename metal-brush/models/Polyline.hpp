//
//  Polyline.hpp
//  i-Reporter
//
//  Created by 高津 洋一 on 12/11/20.
//  Copyright (c) 2012 CIMTOPS CORPORATION. All rights reserved.
//
#pragma once

#include <vector>
#include "Vector.hpp"

class Polyline {
    public:
    void addPoint(const vec2& pnt);
    void clear();
    float *ptr() const;
    unsigned int count() const;
    
    std::vector<vec2> m_points;
};

void InterpolateAsBezie(const Polyline& input, Polyline *pResult);
void InterpolateAsSNS(const Polyline& input, Polyline *pResult);

void GetPolylineOfEllipse(float centerX, float centerY, float width, float height, Polyline *pResult);
void GetPolylineOfBox(float centerX, float centerY, float width, float height, Polyline *pResult);
void GetPolylineOfTriangle(float centerX, float centerY, float width, float height, Polyline *pResult);
void GetPolylineOfCross(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult);
void GetPolylineOfLeftArrow(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult);
void GetPolylineOfRightArrow(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult);
void GetPolylineOfDownArrow(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult);
void GetPolylineOfUpArrow(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult);
