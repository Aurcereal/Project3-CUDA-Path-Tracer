#include "interactions.h"

#include "utilities.h"

#include <thrust/random.h>

__host__ __device__ glm::vec3 calculateRandomDirectionInHemisphere(
    glm::vec3 normal,
    thrust::default_random_engine &rng)
{
    thrust::uniform_real_distribution<float> u01(0, 1);

    float up = sqrt(u01(rng)); // cos(theta)
    float over = sqrt(1 - up * up); // sin(theta)
    float around = u01(rng) * TWO_PI;

    // Find a direction that is not the normal based off of whether or not the
    // normal's components are all equal to sqrt(1/3) or whether or not at
    // least one component is less than sqrt(1/3). Learned this trick from
    // Peter Kutz.

    glm::vec3 directionNotNormal;
    if (abs(normal.x) < SQRT_OF_ONE_THIRD)
    {
        directionNotNormal = glm::vec3(1, 0, 0);
    }
    else if (abs(normal.y) < SQRT_OF_ONE_THIRD)
    {
        directionNotNormal = glm::vec3(0, 1, 0);
    }
    else
    {
        directionNotNormal = glm::vec3(0, 0, 1);
    }

    // Use not-normal direction to generate two perpendicular directions
    glm::vec3 perpendicularDirection1 =
        glm::normalize(glm::cross(normal, directionNotNormal));
    glm::vec3 perpendicularDirection2 =
        glm::normalize(glm::cross(normal, perpendicularDirection1));

    return up * normal
        + cos(around) * over * perpendicularDirection1
        + sin(around) * over * perpendicularDirection2;
}

__host__ __device__ glm::vec2 calculateRandomPositionOnDisk(thrust::default_random_engine &rng) 
{
    thrust::uniform_real_distribution<float> u01(0, 1);
    glm::vec2 xi = glm::vec2(u01(rng), u01(rng));
    xi = xi*2.0f-1.0f;
    if(xi.x == 0 && xi.y == 0)
        return glm::vec2(0.0f);

    glm::vec2 polar;
    if(abs(xi.y) > abs(xi.x)) {
        polar.x = xi.y;
        polar.y = PI*0.5 - PI*0.25 * xi.x/xi.y;
    } else {
        polar.x = xi.x;
        polar.y = PI*0.25 * xi.y/xi.x;
    }
    return polar.x * glm::vec2(cos(polar.y), sin(polar.y));

}

__host__ __device__ void scatterRay(
    PathSegment & pathSegment,
    glm::vec3 intersect,
    glm::vec3 normal,
    const Material &m,
    thrust::default_random_engine &rng, float& outPdf)
{
    pathSegment.ray.origin = intersect + normal * 0.005f;
    if(m.hasReflective) {
        // Just use perfect reflection
        pathSegment.ray.direction -= normal * 2.0f * glm::dot(pathSegment.ray.direction, normal);
        outPdf = 1.0f;
    } else {
        pathSegment.ray.direction = calculateRandomDirectionInHemisphere(normal, rng);
        outPdf = dot(pathSegment.ray.direction, normal)*IPI;
    }
}
