
#include "temperature.h"
#include <glm/glm.hpp>


// __device__ glm::vec3 kelvin_to_rgb_tanner(float temperature) {
//     float t = fmin(fmax(40000.0f, temperature/100.0f), 1000.0f);

//     float r, g, b;
    
//     if(t <= 66.0f) {
//         r = 1.0f;
//     } else {
//         r = __saturatef(1.29293f * powf(t - 60.0f, -0.1332047592f));
//     }
// }

// AI implemented this func using formula direct from https://tannerhelland.com/2012/09/18/convert-temperature-rgb-algorithm-code.html
__device__ glm::vec3 kelvin_to_rgb(float temperature) {
    // Clamp to valid range and scale down for the curve fit
    float t = fminf(temperature, 40000.0f) / 100.0f;
    
    float r, g, b;
    //t = fmaxf(10.0f, t);

    // Calculate Red
    if (t <= 66.0f) {
        r = 1.0f;
    } else {
        r = __saturatef(1.292936f * powf(t - 60.0f, -0.1332047f));
    }

    // Calculate Green
    if (t <= 66.0f) {
        g = __saturatef(0.3900815f * logf(t) - 0.6318414f);
    } else {
        g = __saturatef(1.12989f * powf(t - 60.0f, -0.0755148f));
    }
    
    if (t < 10.0f) {
        // Jank way to linearly go to 0
        g = fmaxf(g, 0.0f);
        return glm::smoothstep(3.0f, 10.0f, t) * glm::vec3(r, g, 0.0f);
    }

    // Calculate Blue
    if (t >= 66.0f) {
        b = 1.0f;
    } else if (t <= 19.0f) {
        b = 0.0f;
    } else {
        b = __saturatef(0.543206f * logf(t - 10.0f) - 1.19625f);
    }

    return glm::vec3(r, g, b);
}