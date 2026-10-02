#pragma once

#include <thrust/random.h>

#include "../sceneStructs.h"

#include <glm/glm.hpp>

#define EXTINCTION_DECAY 0.75f

__host__ __device__  float vdbIntersectionTest(void* grid, int depth, const Volume& volume, Ray ray, thrust::default_random_engine& rng, float tMax);
