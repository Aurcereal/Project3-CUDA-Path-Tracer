#include "volume.h"
#include "utilities.h"
#include "cuda-utilities.h"

__host__ __device__ float henyeyGreenstein(float cosTheta, float g) {
    float denom = 1.0f + g*g + 2.0f * g * cosTheta;
    return 0.25 * IPI * (1.0f - g*g) / (denom * max(1e-5, sqrt(denom)));
}

__host__ __device__ glm::vec3 sampleHenyeyGreenstein(glm::vec3 wo, float g, thrust::default_random_engine& rng, float& outPdf) {
      thrust::uniform_real_distribution u01(0.0f, 1.0f);
      glm::vec2 xi = glm::vec2(u01(rng), u01(rng));

       float cosTheta;
       if (glm::abs(g) < 1e-3f)
           cosTheta = 1.0f - 2.0f * xi.x;
       else
           cosTheta = -1.0f / (2.0f * g) *
                      (1.0f + SQR(g) - SQR((1 - SQR(g)) / (1.0f + g - 2.0f * g * xi.x)));

       float sinTheta = sqrt(max(1 - SQR(cosTheta), 1e-5));
       float phi = 2.0f * PI * xi.y;
       glm::mat3 wFrame = FrameFromZ(wo);
       glm::vec3 wi = wFrame * (SphericalDirection(cosTheta, sinTheta, phi));

       outPdf = henyeyGreenstein(cosTheta, g);
       return wi;
}


__host__ __device__ float sampleVolume(const Volume& volume, glm::vec3 p) {
    if (length(p) > 3.0f) return 0.0f;
    return glm::smoothstep(0.75f, 1.0f, glm::abs(glm::dot(cos(2.0f * p), sin(4.0f * glm::vec3(p.z, p.y, p.x))))) * 1.0f;// / max(0.5f, dot(p, p));
    // // Weird way to do this, makes more sense physically to do absorption (a), scattering (s), then extinction (e) = a + s, albedo = s/e, absorption = a/e
    // float extinction = 10.0f / max(0.5f, dot(p, p));
    
    // float albedo = 0.99f;
    

    // float absorption = (1.0f - albedo) * extinction;

    // return glm::vec3(extinction, albedo, absorption);
}

__host__ __device__ float volumeIntersectionTest(Ray ray, const Volume& volume, thrust::default_random_engine& rng, float tVolumeStart, float tMax) {
    thrust::uniform_real_distribution<float> u01(0, 1);

    float t = tVolumeStart;
    int iter = 0;
    while(t < tMax) {
        t += -log(max(1e-5, u01(rng))) / volume.extinctionMax;

        if(t >= tMax) {
            return -1.0f;
        }

        glm::vec3 newPoint = ray.origin + ray.direction * t;
        float extinction = sampleVolume(volume, newPoint);

        if(u01(rng) <= extinction / volume.extinctionMax) {
            return t;
            // Hit

            // store info in intersection struct (pass it in as out param or smth)
            // terminate if absorbed (maybe there's no point in doing this for me it doesn't effect actual render ithink actually mabe it does)
            // sample phase function bounce and multiply by albedo and phase function and then divide by pdf (which is also phase function so it cancels and WE ONLY MULT BY ALBEDO (only works for single wavelength))
            // do MIS sample random ligh tsame as before but use the volume pdfs in MIS
            // DONT FORGET TO SET LASTBSDFPDF to henyey pdf so we do still haveto sample it ig
        }
        if (iter++ > 50)
            return t;
    }

    return -1.0f;
}