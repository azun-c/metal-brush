//
//  NonuniformSpline.cpp
//  i-Reporter
//
//  Created by 高津 洋一 on 12/11/20.
//  Copyright (c) 2012 CIMTOPS CORPORATION. All rights reserved.
//

#include "NonuniformSpline.hpp"

// cubic curve defined by 2 positions and 2 velocities
vec2 GetPositionOnCubic(const vec2 &startPos, const vec2 &startVel, const vec2 &endPos, const vec2 &endVel, float time) {
    vec4 timeVector = vec4(time*time*time, time*time, time, 1.f);
    
    vec4 hermite0 = vec4(2.f,-2.f, 1.f, 1.f);
    vec4 hermite1 = vec4(-3.f, 3.f,-2.f,-1.f);
    vec4 hermite2 = vec4(0.f, 0.f, 1.f, 0.f);
    vec4 hermite3 = vec4(1.f, 0.f, 0.f, 0.f);
    
    vec4 mX = vec4(startPos.x, endPos.x, startVel.x, endVel.x);
    vec4 mY = vec4(startPos.y, endPos.y, startVel.y, endVel.y);
    
    float x = timeVector.Dot(vec4(hermite0.Dot(mX), hermite1.Dot(mX), hermite2.Dot(mX), hermite3.Dot(mX)));
    float y = timeVector.Dot(vec4(hermite0.Dot(mY), hermite1.Dot(mY), hermite2.Dot(mY), hermite3.Dot(mY)));
    
    return vec2(x,y);
}

/*********************************** R N S **************************************************/

// adds node and updates segment length
void RNS::AddNode(const vec2 &pos) {
    if (nodeArray.size() > 0) {
        nodeArray.back().distance = (nodeArray.back().position - pos).Length();
    }
    
    splineData data;
    data.position = pos;
    nodeArray.push_back(data);
}

// called after all nodes added. This function calculates the node velocities
void RNS::BuildSpline() {
    for (int i = 1; i<nodeArray.size()-1; i++) {        vec2 v1 = nodeArray[i+1].position - nodeArray[i].position;
        v1.Normalize();
        vec2 v0 = nodeArray[i-1].position - nodeArray[i].position;
        v0.Normalize();
        nodeArray[i].velocity = v1 - v0;
        nodeArray[i].velocity.Normalize();
    }
    // calculate start and end velocities
    nodeArray[0].velocity = GetStartVelocity(0);
    nodeArray.back().velocity = GetEndVelocity((int)nodeArray.size()-1);
}

// time is 0 -> 1
vec2 RNS::GetPosition(int i, float time) {
    vec2 startVel = nodeArray[i].velocity *nodeArray[i].distance;
    vec2 endVel = nodeArray[i+1].velocity *nodeArray[i].distance;
    return GetPositionOnCubic(nodeArray[i].position, startVel,
                              nodeArray[i+1].position, endVel, time);
}

// internal. Based on Equation 14
vec2 RNS::GetStartVelocity(int index) {
    vec2 temp = (nodeArray[index+1].position - nodeArray[index].position)*3.f/nodeArray[index].distance;
    return (temp - nodeArray[index+1].velocity)*0.5f;
}

// internal. Based on Equation 15
vec2 RNS::GetEndVelocity(int index) {
    vec2 temp = (nodeArray[index].position - nodeArray[index-1].position)*3.f/nodeArray[index-1].distance;
    return (temp - nodeArray[index-1].velocity)*0.5f;
}

/*********************************** S N S **************************************************/

// smoothing filter.
void SNS::Smooth() {
    vec2 newVel;
    vec2 oldVel = GetStartVelocity(0);
    for (int i = 1; i<nodeArray.size()-1; i++) {        // Equation 12
        newVel = GetEndVelocity(i)*nodeArray[i].distance +
        GetStartVelocity(i)*nodeArray[i-1].distance;
        newVel /= (nodeArray[i-1].distance + nodeArray[i].distance);
        nodeArray[i-1].velocity = oldVel;
        oldVel = newVel;
    }
    nodeArray[nodeArray.size()-1].velocity = GetEndVelocity((int)nodeArray.size()-1);
    nodeArray[nodeArray.size()-2].velocity = oldVel;
}

/*********************************** T N S **************************************************/

// as with RNS but use timePeriod in place of actual node spacing
// ie time period is time from last node to this node
void TNS::AddNode(const vec2 &pos, float timePeriod) {
    if (nodeArray.size() > 0) {
        nodeArray.back().distance = timePeriod;
    }
    
    splineData data;
    data.position = pos;
    nodeArray.push_back(data);
}

// stabilised version of TNS
void TNS::Constrain() {
    for (int i = 1; i<nodeArray.size()-1; i++) {        // Equation 13
        float r0 = (nodeArray[i].position-nodeArray[i-1].position).Length()/nodeArray[i-1].distance;
        float r1 = (nodeArray[i+1].position-nodeArray[i].position).Length()/nodeArray[i].distance;
        nodeArray[i].velocity *= 4.f*r0*r1/((r0+r1)*(r0+r1));
    }
}
