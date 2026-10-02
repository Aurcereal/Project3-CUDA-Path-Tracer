#include "vdb_usage.h"

#include <nanovdb/cuda/DeviceBuffer.h>
#include <nanovdb/io/IO.h>

#include "../intersections.h"

using namespace glm;

__host__ __device__ inline nanovdb::Coord toCoord(vec3 p) {
    return nanovdb::Coord(floor(p.x), floor(p.y), floor(p.z));
}
__host__ __device__ inline nanovdb::Coord getCoord(vec3 ro, vec3 rd, float t) {
    vec3 p = ro + rd * t;
    return toCoord(p);
}

#define VDBTRAVERSEEPS 1e-4f

__host__ __device__  float vdbIntersectionTest(void* vGrid, const Volume& volume, Ray ray, thrust::default_random_engine& rng, float tMax) {
    // BBX
    vec2 ts = bbxIntersectionTest(ray, volume.invTransform * volume.userInvTransform);
    if(ts.x >= ts.y || ts.y < 0.0f) return -1.0f;
    tMax = min(tMax, ts.y);

    //
    nanovdb::FloatGrid* grid = (nanovdb::FloatGrid*)vGrid;
    auto accessor = grid->getAccessor();

    vec3 lro = grid->worldToIndex(vec3(volume.userInvTransform * vec4(ray.origin, 1.0f)));
    vec3 lrd = grid->worldToIndexDir(vec3(volume.userInvTransform * vec4(ray.direction, 0.0f)));

    thrust::uniform_real_distribution<float> u01(0, 1);

    float t = max(0.0f, ts.x);
    int iter = 0;
    nanovdb::Coord ijk;
    glm::vec3 currPnt;

    while(t < tMax) {
        bool uniformMode = false;

        currPnt = lro + lrd * t;
        const nanovdb::NanoLower<float>* lowerNode = grid->tree().template get<nanovdb::GetLower<float>>(toCoord(currPnt));
        while ((lowerNode == nullptr || lowerNode->getMax() <= 0.0f) && t < tMax) {
            nanovdb::Coord coord = toCoord(currPnt);
            // Floor to nearest 8*16
            vec3 bbxMin = vec3(coord.x() & ~127, coord.y() & ~127, coord.z() & ~127);
            vec3 bbxMax = bbxMin + vec3(128);

            t += VDBTRAVERSEEPS + alignedBbxIntersectionTest(currPnt, lrd, bbxMin, bbxMax).y;
            currPnt = lro + lrd * t; // negative

            lowerNode = grid->tree().template get<nanovdb::GetLower<float>>(toCoord(currPnt));
        }

        const nanovdb::NanoLeaf<float>* leafNode = grid->tree().template get<nanovdb::GetLeaf<float>>(toCoord(currPnt));
        while (!uniformMode && (leafNode == nullptr || leafNode->getMax() <= 0.0f) && t < tMax) {
            nanovdb::Coord coord = toCoord(currPnt);
            // Floor to nearest 8
            vec3 bbxMin = vec3(coord.x() & ~7, coord.y() & ~7, coord.z() & ~7);
            vec3 bbxMax = bbxMin + vec3(8);

            t += VDBTRAVERSEEPS+alignedBbxIntersectionTest(currPnt, lrd, bbxMin, bbxMax).y;
            currPnt = lro + lrd * t; // negative

            leafNode = grid->tree().template get<nanovdb::GetLeaf<float>>(toCoord(currPnt));
            if (lowerNode->valueMask().isOn(lowerNode->CoordToOffset(coord)))
                uniformMode = true;
        }

        if (t >= tMax) return -1.0f;

        ijk = getCoord(lro, lrd, t); // just toCoord(currPnt)
        float currMax = uniformMode ? accessor.getValue(ijk) : leafNode->getMax();// grid->tree().template get<nanovdb::GetLower<float>>(ijk)->getMax();// node->getMax();
        float deltaT = -log(max(1e-5, u01(rng))) / (volume.extinctionMult * currMax);

        vec3 bbxMin = vec3(ijk.x() & ~7, ijk.y() & ~7, ijk.z() & ~7);
        vec3 bbxMax = bbxMin + vec3(8);
        float deltaTcap = alignedBbxIntersectionTest(currPnt, lrd, bbxMin, bbxMax).y;
        if (deltaT > deltaTcap) {
            t += deltaTcap + VDBTRAVERSEEPS;
            currPnt = lro + lrd * t; // unnecessary but accident waiting to happen
            continue;
        }
        t += deltaT;

        if(t >= tMax) {
            return -1.0f;
        }

        ijk = getCoord(lro, lrd, t);
        float extinction = uniformMode ? currMax : accessor.getValue(ijk);

        if(u01(rng) <= extinction / currMax)
            return t;

        // Iter cap
        if (iter++ > 500)
            return t;
    }

    return -1.0f;
}