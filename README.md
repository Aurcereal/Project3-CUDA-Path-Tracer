CUDA Path Tracer
================

**University of Pennsylvania, CIS 565: GPU Programming and Architecture, Project 3**

* Aidan
* [Personal Website](aidanmgideon.com) 
* Tested on: Windows 11, i7-1360P @ 2.20GHz 16GB, RTX 4060 128MB

## Renders

## Features

This is a GPU renderer built in C++ and CUDA.  It uses path-tracing to render scenes and the light that bounces around in them realistically.  It features

- Wavefront Pathtracing used to improve warp coherence
- Multiple Importance Sampling
- Depth of Field
- Volumes using Woodcock Tracking
- VDB Loading and Fast Ray Traversal
- Emissive Volumes that use temperature from VDB

## Overview

### Wavefront Pathtracing

In order to improve warp coherence, we ues wavefront pathtracing.  We split the normal pathtracing operatins (ray-scene intersect, shade, bounce..) into multiple steps.  While adding overhead, it allows us to have optimizations like **removing paths that don't contribute light early** and **sorting intersections by material so warps are doing similar instructions**.

(wavefront pathtracing diagram with reference)

### Diffuse Surfaces

To simulate diffuse surfaces, when the ray bounces, we can sample a random direction in the hemisphere aligned with the normal.  We assume diffuse surfaces are completely rough; **every photon that bounces on it goes in a random direction with equal probability**.

(cornell box)

### Multiple Importance Sampling

This project features Multiple Importance Sampling (MIS).  MIS is an addition to importance sampling, the idea of sampling certain directions on ray bounce more often.  For example, if you know one direction will be particularly bright, you can sample that direction more (and then divide by the probability of doing so to normalize).  It's most important to sample directions with lots of light often since they contribute the most, we want them to be the most accurate.

MIS builds upon this idea.  We don't always know what direction will give us the most light, but we can approximate it based on different models.  We can approximate it based on the **material** of the object and the **lights** in the scene.  So we have two sampling methods, material (or BSDF sampling) and direct light sampling.  MIS is how we combine these two methods.  We basically take a BSDF sample and a direct light sample and add them and divide each one by the total probability that that direction was sampled overall (to normalize).  (Though sometimes we add a power to it).

Running MIS on every bounce allows us to accumulate light per bounce, which means we can converge much faster.  Here's a comparison of a render with and without MIS after 500 iterations.

### Depth of Field

To simulate depth of field, we can offset the starting positions of rays a bit (cylindrically) to simulate the fact that camera lenses aren't infinitely small.  We then have them go directly to a focal plane.  Here's what it looks like.

### Volumes

To render volumes, I used woodcock pathtracing, which basically models the probability of photons colliding with clouds.  We do a probability roll to see how long a ray will take to collide within a cloud, bounce it (or absorb it) and if the ray wasn't absorbed, we collide the ray with the cloud again.  The ray will keep bouncing within the cloud until it escapes or gets absorbed.  A dense cloud will have the ray bounce short distances since it collides within short distances while a low-density cloud will allow the ray to escape much faster. 

We also do a direct light sample at each bounce in the cloud to converge faster.

(show the ball and some bright blooper)

PDF was off..

Sphere looks correct now

### VDB Loading & Traversal

To render cloud volumes, I wanted to load in VDB files

(density was too high..)

### Emissive Volumes

### Performance Analysis

