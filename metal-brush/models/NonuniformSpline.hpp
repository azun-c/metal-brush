//
//  NonuniformSpline.hpp
//  i-Reporter
//
//  Created by 高津 洋一 on 12/11/20.
//  Copyright (c) 2012 CIMTOPS CORPORATION. All rights reserved.
//

#pragma once

#include <vector>
#include "Vector.hpp"

class RNS {
public:
    void Init() {}
    void AddNode(const vec2 &pos);
    void BuildSpline();
    vec2 GetPosition(int i, float time);
    struct splineData {        vec2 position;
        vec2 velocity;
        float distance;
    };
    
    // splineData
    std::vector<splineData> nodeArray;
    
protected:
    vec2 GetStartVelocity(int index);
    vec2 GetEndVelocity(int index);
};

class SNS : public RNS {
public:
    void BuildSpline() { RNS::BuildSpline(); Smooth(); Smooth(); Smooth();}
    void Smooth();
};

class TNS : public SNS {
public:
    void AddNode(const vec2 &pos, float timePeriod);
    void BuildSpline() { RNS::BuildSpline(); Smooth(); Smooth(); Smooth(); }
    void Smooth() { SNS::Smooth(); Constrain(); }
    void Constrain();
};
