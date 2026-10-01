#include "vdb_usage.h"

#include <nanovdb/cuda/DeviceBuffer.h>
#include <nanovdb/io/IO.h>

#include "../intersections.h"

using namespace glm;

__host__ __device__  float vdbIntersectionTest(void* vGrid, const Volume& volume, Ray ray, thrust::default_random_engine& rng, float tMax) {
    // BBX
    vec2 ts = bbxIntersectionTest(ray, volume.invTransform);
    if(ts.x >= ts.y || ts.y < 0.0f) return -1.0f;

    //
    nanovdb::FloatGrid* grid = (nanovdb::FloatGrid*)vGrid;
    auto accessor = grid->getAccessor();

    // grid->worldBBox

    // nanovdb::Coord ijk(10,24,30);

    // grid->tree().template get<nanovdb::GetUpper<float>>(ijk);
    thrust::uniform_real_distribution<float> u01(0, 1);

    float t = max(0.0f, ts.x);
    int iter = 0;
    nanovdb::Coord ijk;
    glm::vec3 newPoint;
    while(t < tMax) {
        {
            newPoint = ray.origin + ray.direction * t;
            // <->
            newPoint *= 1.0f / TEMP_SCALE;
            // <->
            vec3 localPoint = grid->worldToIndex(newPoint);
            ijk = nanovdb::Coord(floor(localPoint.x), floor(localPoint.y), floor(localPoint.z));
        }

        float currMax = grid->tree().template get<nanovdb::GetUpper<float>>(ijk)->getMax();
        t += -log(max(1e-5, u01(rng))) / (volume.extinctionMult * currMax);// volume.extinctionMax;

        if(t >= tMax) {
            return -1.0f;
        }

        newPoint = ray.origin + ray.direction * t;
        // <->
        newPoint *= 1.0f / TEMP_SCALE;
        // <->
        vec3 localPoint = grid->worldToIndex(newPoint);
        ijk = nanovdb::Coord(floor(localPoint.x), floor(localPoint.y), floor(localPoint.z));
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