//
//  Polyline.cpp
//  i-Reporter
//
//  Created by 高津 洋一 on 12/11/20.
//  Copyright (c) 2012 CIMTOPS CORPORATION. All rights reserved.
//

#include <math.h>
#include "Polyline.hpp"
#include "NonuniformSpline.hpp"

void Polyline::addPoint(const vec2& pnt) {
    m_points.push_back(pnt);
}

void Polyline::clear() {
    m_points.clear();
}

float *Polyline::ptr() const {
    return (float *)&m_points.front().x;
}

unsigned int Polyline::count() const {
    return (unsigned int)m_points.size();
}

// 3次Bezieの通過点を計算
vec2 CalcPosition(const vec2& c0, const vec2& c1, const vec2& c2, const vec2& c3, float t) {
    float oneMinusT = (1.0f - t);
    
    return c0*oneMinusT*oneMinusT*oneMinusT + c1*3*oneMinusT*oneMinusT*t + c2*3*oneMinusT*t*t + c3*t*t*t;
}

// 3次Bezieとして補間
void InterpolateAsBezie(const Polyline& input, Polyline *pResult) {
    // 3点未満であればそのまま
    if (input.m_points.size() < 3) {
        *pResult = input;
        return;
    }
    
    // 折れ線の数(点数-1) * 2個の制御点 p0 c0 c1 p1 c2 c3 p2のc1...c3を求める
    std::vector<vec2> controls(2*(input.m_points.size() - 1));
    // 3点ずつ
    for (size_t i = 0; i < input.m_points.size() - 2; ++i) {
        vec2 p0 = input.m_points[i];
        vec2 p1 = input.m_points[i+1];
        vec2 p2 = input.m_points[i+2];
        
        // 最初のコントロールポイント
        controls[2*i] = (p0*7.0f + p1*6.0 - p2)/12.0;
        controls[2*i+1] = (p0 + p1*6.0 - p2)/6.0;
        
        // 最後のセグメントを追加
        if (i == input.m_points.size() - 3) {
            controls[2*i+2] = (-p0 + p1*6.0 + p2)/6.0;
            controls[2*i+3] = (-p0 + p1*6.0 + p2*7.0)/12.0;
        }
    }
    
    // 補間
    for (size_t i = 0; i < input.m_points.size() - 1; ++i) {
        // 開始点
        const vec2& c0 = input.m_points[i];
        const vec2& c1 = controls[2*i];
        const vec2& c2 = controls[2*i+1];
        const vec2& c3 = input.m_points[i+1];
        pResult->m_points.push_back(input.m_points[i]);
        pResult->m_points.push_back(CalcPosition(c0, c1, c2, c3, 0.2f));
        pResult->m_points.push_back(CalcPosition(c0, c1, c2, c3, 0.4f));
        pResult->m_points.push_back(CalcPosition(c0, c1, c2, c3, 0.6f));
        pResult->m_points.push_back(CalcPosition(c0, c1, c2, c3, 0.8f));
        if (i == input.m_points.size() - 2) {
            pResult->m_points.push_back(input.m_points[i+1]);
        }
    }
}

void InterpolateAsSNS(const Polyline& input, Polyline *pResult) {
    // 3点未満であればそのまま
    if (input.m_points.size() < 3) {
        *pResult = input;
        return;
    }
    
    RNS spline;
    for (size_t i = 0; i < input.m_points.size(); ++i) {
        spline.AddNode(input.m_points[i]);
    }
    spline.BuildSpline();
    
    const int DIVIDE_MAX = 10; // 最大１０分割
    const float DIVIDE_LENGTH = 5.0f; // 分割する目安長さ
    for (int i = 0; i < input.m_points.size() - 1; ++i) {
        int divideNum = (int)(spline.nodeArray[i].distance/DIVIDE_LENGTH);
        if (DIVIDE_MAX < divideNum) {
            divideNum = DIVIDE_MAX;
        }
        
        pResult->m_points.push_back(spline.GetPosition(i, 0.0f));
        
        for (int k = 1; k < divideNum; k++) {
            pResult->m_points.push_back(spline.GetPosition(i, (float)k/(float)divideNum));
        }
        
        if (i == input.m_points.size() - 2) {
            pResult->m_points.push_back(spline.GetPosition(i, 1.0f));
        }
    }
}

void GetPolylineOfEllipse(float centerX, float centerY, float width, float height, Polyline *pResult) {
    static const int division = 32;
    static const double deltaTheta = 2.0*M_PI/division;
    
    float halfWidth = 0.5*width;
    float halfHeight = 0.5*height;
    
    pResult->clear();
    for (int i = 0; i < division; ++i) {
        float theta = i*deltaTheta;
        float x = centerX + halfWidth*cos(theta);
        float y = centerY + halfHeight*sin(theta);
        
        pResult->addPoint(vec2(x, y));
    }
    pResult->addPoint(pResult->m_points.front());
}

void GetPolylineOfBox(float centerX, float centerY, float width, float height, Polyline *pResult) {
    float halfWidth = 0.5*width;
    float halfHeight = 0.5*height;
    vec2 topLeft(centerX - halfWidth, centerY - halfHeight);
    vec2 bottomLeft(centerX - halfWidth, centerY + halfHeight);
    vec2 bottomRight(centerX + halfWidth, centerY + halfHeight);
    vec2 topRight(centerX + halfWidth, centerY - halfHeight);
    
    pResult->clear();
    pResult->addPoint(topLeft);
    pResult->addPoint(bottomLeft);
    pResult->addPoint(bottomRight);
    pResult->addPoint(topRight);
    pResult->addPoint(topLeft);
}

void GetPolylineOfTriangle(float centerX, float centerY, float width, float height, Polyline *pResult) {
    float halfWidth = 0.5*width;
    float halfHeight = 0.5*height;
    vec2 top(centerX, centerY - halfHeight);
    vec2 bottomLeft(centerX - halfWidth, centerY + halfHeight);
    vec2 bottomRight(centerX + halfWidth, centerY + halfHeight);
    
    pResult->clear();
    pResult->addPoint(top);
    pResult->addPoint(bottomLeft);
    pResult->addPoint(bottomRight);
    pResult->addPoint(top);
}

void GetPolylineOfCross(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult) {
    float halfWidth = 0.5*width;
    float halfHeight = 0.5*height;
    vec2 topLeft(centerX - halfWidth, centerY - halfHeight);
    vec2 bottomLeft(centerX - halfWidth, centerY + halfHeight);
    vec2 bottomRight(centerX + halfWidth, centerY + halfHeight);
    vec2 topRight(centerX + halfWidth, centerY - halfHeight);
    
    Polyline polyline1;
    polyline1.addPoint(topLeft);
    polyline1.addPoint(bottomRight);
    Polyline polyline2;
    polyline2.addPoint(topRight);
    polyline2.addPoint(bottomLeft);
    
    pResult->clear();
    pResult->push_back(polyline1);
    pResult->push_back(polyline2);
}

void GetPolylineOfLeftArrow(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult) {
    float halfWidth = 0.5*width;
    float halfHeight = 0.5*height;
    vec2 left(centerX - halfWidth, centerY);
    vec2 right(centerX + halfWidth, centerY);
    vec2 top(centerX, centerY - halfHeight);
    vec2 bottom(centerX, centerY + halfHeight);
    
    Polyline polyline1;
    polyline1.addPoint(left);
    polyline1.addPoint(right);
    Polyline polyline2;
    polyline2.addPoint(top);
    polyline2.addPoint(left);
    polyline2.addPoint(bottom);
    
    pResult->clear();
    pResult->push_back(polyline1);
    pResult->push_back(polyline2);    
}

void GetPolylineOfRightArrow(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult) {
    float halfWidth = 0.5*width;
    float halfHeight = 0.5*height;
    vec2 left(centerX - halfWidth, centerY);
    vec2 right(centerX + halfWidth, centerY);
    vec2 top(centerX, centerY - halfHeight);
    vec2 bottom(centerX, centerY + halfHeight);
    
    Polyline polyline1;
    polyline1.addPoint(left);
    polyline1.addPoint(right);
    Polyline polyline2;
    polyline2.addPoint(top);
    polyline2.addPoint(right);
    polyline2.addPoint(bottom);
    
    pResult->clear();
    pResult->push_back(polyline1);
    pResult->push_back(polyline2);    
}

void GetPolylineOfDownArrow(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult) {
    float halfWidth = 0.5*width;
    float halfHeight = 0.5*height;
    vec2 left(centerX - halfWidth, centerY);
    vec2 right(centerX + halfWidth, centerY);
    vec2 top(centerX, centerY - halfHeight);
    vec2 bottom(centerX, centerY + halfHeight);
    
    Polyline polyline1;
    polyline1.addPoint(top);
    polyline1.addPoint(bottom);
    Polyline polyline2;
    polyline2.addPoint(left);
    polyline2.addPoint(bottom);
    polyline2.addPoint(right);
    
    pResult->clear();
    pResult->push_back(polyline1);
    pResult->push_back(polyline2);
}

void GetPolylineOfUpArrow(float centerX, float centerY, float width, float height, std::vector<Polyline>* pResult) {
    float halfWidth = 0.5*width;
    float halfHeight = 0.5*height;
    vec2 left(centerX - halfWidth, centerY);
    vec2 right(centerX + halfWidth, centerY);
    vec2 top(centerX, centerY - halfHeight);
    vec2 bottom(centerX, centerY + halfHeight);
    
    Polyline polyline1;
    polyline1.addPoint(top);
    polyline1.addPoint(bottom);
    Polyline polyline2;
    polyline2.addPoint(left);
    polyline2.addPoint(top);
    polyline2.addPoint(right);
    
    pResult->clear();
    pResult->push_back(polyline1);
    pResult->push_back(polyline2);
}
