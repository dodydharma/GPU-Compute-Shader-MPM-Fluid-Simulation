#version 430 core
#extension GL_ARB_shader_storage_buffer_object : require

struct Material
{
	float mass, restDensity, stiffness, bulkViscosity, surfaceTension, kElastic, maxDeformation, meltRate, viscosity, damping, friction, stickiness, smoothing, gravity;
	int materialIndex;
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


layout( location = 0 ) in int particleId;

out gl_PerVertex {
    vec4 gl_Position;
};

out block {
     vec4 color;
} Out;

layout( std430, binding = 1 ) buffer Particles
{
    Particle particles[];
};

uniform mat4 ciModelViewProjection;


void main()
{
	gl_Position = ciModelViewProjection * vec4( particles[particleId].posx, particles[particleId].posy, 0, 1 );
	//Out.color = vec4(0.4, 0.8, 1.0, 1.0);
	if(particles[particleId].mat.materialIndex == 0) Out.color = vec4(1, 0.3, 0.3, 1);
	else if(particles[particleId].mat.materialIndex == 1) Out.color = vec4(0.3, 1, 0.3, 1);
	else  Out.color = vec4(0.3, 0.3, 1, 1);
}