#pragma once

#include "sceneStructs.h"

#include <glm/glm.hpp>

#include <thrust/random.h>

// TODO: move phase functions to phase functions maybe? if not DELETE this
__host__ __device__ float henyeyGreenstein(float cosTheta, float g); // Is normalized and sample function matches exactly so also functions as pdf
__host__ __device__ glm::vec3 sampleHenyeyGreenstein(glm::vec3 wo, float g, thrust::default_random_engine& rng, float& outPdf);

__host__ __device__ float sampleVolume(const Volume& volume, glm::vec3 p);

// Look into implementing wavelength stuff, each ray is a very specific wavelength and each of my software 'rays' can store 4 rays in reality and they do their throughput calculations separately like wave[i].throughput *= f.calculateThroughput(wavelengths[i])
// Can probably get away with art directing it a bit though
__host__ __device__  float volumeIntersectionTest(Ray ray, const Volume& volume, thrust::default_random_engine& rng, float tVolumeStart, float tMax);