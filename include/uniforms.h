#ifndef UNIFORM_H 
#define UNIFORM_H

#ifndef __cplusplus
#define sdk_bool bool
// Standard SDK defines
#define SDK_BOOL  bool
#define SDK_VEC2  vec2
#define SDK_VEC3  vec3
#define SDK_VEC4  vec4
#define SDK_MAT4  mat4

#endif

#define WINDOWX 1280
#define WINDOWY 720
#define GRIDX 160
#define GRIDY 120
#define COMPUTESIZE 512
#define NPARTICLES 1000
#define numMaterials 4

struct Material
{
	float mass, restDensity, stiffness, bulkViscosity, surfaceTension, kElastic, maxDeformation, meltRate, viscosity, damping, friction, stickiness, smoothing, gravity;
	int materialIndex;
#ifdef __cplusplus
	Material() : mass(1), 
		restDensity(2), 
		stiffness(1), 
		bulkViscosity(1), 
		surfaceTension(0), 
		kElastic(0), 
		maxDeformation(0), 
		meltRate(0), 
		viscosity(.02), 
		damping(.001), 
		friction(0),
		stickiness(0), 
		smoothing(.02), 
		gravity(.03) {};
#endif
};

struct Node
{
	float m, d, gx, gy, u, v, u2, v2, ax, ay;
	float cgx[numMaterials];
	float cgy[numMaterials];
	bool act;
};

struct Particle
{
	float x, y, u, v, gu, gv, T00, T01, T11;
	float posx, posy;

	int cx, cy, gi;

	float px[3];
	float py[3];
	float gx[3];
	float gy[3];
	Material mat;
};



#endif
