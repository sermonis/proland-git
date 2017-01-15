/*
 * Proland: a procedural landscape rendering library.
 * Copyright (c) 2008-2011 INRIA
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Proland is distributed under a dual-license scheme.
 * You can obtain a specific license from Inria: proland-licensing@inria.fr.
 */

/*
 * Authors: Eric Bruneton, Antoine Begault, Guillaume Piolat.
 */

struct samplerTile {
    sampler2DArray tilePool; // tile cache
    vec3 tileCoords; // coords of currently selected tile in tile cache (u,v,layer; u,v in [0,1]^2)
    vec3 tileSize; // size of currently selected tile in tile cache (du,dv,d; du,dv in [0,1]^2, d in pixels)
};

// returns content of currently selected tile, at uv coordinates (in [0,1]^2; relatively to this tile)
vec4 textureTile(samplerTile tex, vec2 uv) {
    vec3 uvl = tex.tileCoords + vec3(uv * tex.tileSize.xy, 0.0);
    return texture(tex.tilePool, uvl);
}

uniform struct {
    vec4 offset;
    vec4 camera;
    vec2 blending;
    mat4 localToScreen;
} deformation;

uniform samplerTile elevationSampler;
uniform samplerTile fragmentNormalSampler;

#ifdef _VERTEX_

layout(location=0) in vec3 vertex;
out vec2 uv;
out vec3 p;

void main() {
    vec4 zfc = textureTile(elevationSampler, vertex.xy);

    vec2 v = abs(deformation.camera.xy - vertex.xy);
    float d = max(max(v.x, v.y), deformation.camera.z);
    float blend = clamp((d - deformation.blending.x) / deformation.blending.y, 0.0, 1.0);

    float h = zfc.z * (1.0 - blend) + zfc.y * blend;
    p = vec3(vertex.xy * deformation.offset.z + deformation.offset.xy, h);

    gl_Position = deformation.localToScreen * vec4(p, 1.0);
    uv = vertex.xy;
}

#endif

#ifdef _FRAGMENT_

uniform vec4 pencil;
uniform vec4 pencilColor;

in vec3 p;
in vec2 uv;
layout(location=0) out vec4 data;

void main() {
    float h = textureTile(elevationSampler, uv).x;
    if (h < 0.1) {
        data = vec4(0.0, 0.0, 0.5, 1.0);
    } else {
        data = vec4(0.0, 0.5, 0.0, 1.0);
    }

    vec3 n = vec3(textureTile(fragmentNormalSampler, uv).xy * 2.0 - 1.0, 0.0);
    n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));

    float light = dot(n, normalize(vec3(1.0)));
    data.rgb *= 0.5 + 0.75 * light;

    if (length(p.xy - pencil.xy) < pencil.w) {
        data += pencilColor;
    }
}

#endif
