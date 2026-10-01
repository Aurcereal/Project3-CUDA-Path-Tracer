#include "vdb_usage.h"

#include <nanovdb/cuda/DeviceBuffer.h>
#include <nanovdb/io/IO.h>

#include "../intersections.h"

using namespace glm;

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
        currPnt = lro + lrd * t;
        ijk = nanovdb::Coord(floor(currPnt.x), floor(currPnt.y), floor(currPnt.z));
        auto node = grid->tree().template get<nanovdb::GetUpper<float>>(ijk);
        float currMax = node->getMax();
        t += -log(max(1e-5, u01(rng))) / (volume.extinctionMult * currMax);

        if(t >= tMax) {
            return -1.0f;
        }

        currPnt = lro + lrd * t;
        ijk = nanovdb::Coord(floor(currPnt.x), floor(currPnt.y), floor(currPnt.z));
        float extinction = accessor.getValue(ijk);

        if(u01(rng) <= extinction / currMax) {
            return t;
        }

        // Iter cap
        if (iter++ > 500)
            return t;
    }

    return -1.0f;
}