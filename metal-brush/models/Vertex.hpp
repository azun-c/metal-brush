//
//  Vertex.hpp
//  i-Reporter
//
//  Created by 高津 洋一 on 12/11/20.
//  Copyright (c) 2012 CIMTOPS CORPORATION. All rights reserved.
//

#pragma once

#include "Vector.hpp"

struct Vertex {
    Vertex():position(0, 0), texPos(0, 0) {}
    Vertex(float x, float y):position(x,y), texPos(0, 0) {}
    Vertex(float x, float y, float texX, float texY):position(x,y), texPos(texX, texY) {}
    vec2 position;
    vec2 texPos;
};
