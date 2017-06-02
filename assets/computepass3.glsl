#version 430 core
#extension GL_ARB_compute_shader : enable
#extension GL_ARB_shader_storage_buffer_object : enable
#extension GL_ARB_compute_variable_group_size : enable

#UNIFORMS

layout( std430, binding=1 ) buffer Particles {
    Particle particles[];
};

layout( std430, binding=2 ) buffer Nodes {
    Node nodes[];
};

layout(std430, binding = 3) buffer ActiveNodes {
	Node actives[];
};

layout(local_size_x = COMPUTESIZE, local_size_y = 1, local_size_z = 1) in;

// compute shader to update particles
void main() {
	uint pi = gl_GlobalInvocationID.x;

	// thread block size may not be exact multiple of number of particles
	if (pi >= NPARTICLES) return;

	// read particles from buffers
	Particle p;
	Node n;
	
	p = particles[pi];
	Material mat = p.mat;
	// Update particle velocities
	int ni = p.gi;
	float px[3] = p.px;
	float py[3] = p.py;
	for (int i = 0; i < 3; i++) {
		float pxi = p.px[i];
		for (int j = 0; j < 3; j++) {
				//n = nodes[ni];
				float pyj = p.py[j];
				float phi = pxi * pyj;
				p.u += phi * nodes[ni].ax;
				p.v += phi * nodes[ni].ay;
				ni++;
		}
		ni += (GRIDY - 3);
	}

	p.v += mat.gravity;
	p.u *= 1 - mat.damping;
	p.v *= 1 - mat.damping;

	float m = p.mat.mass;
	float mu = m * p.u;
	float mv = m * p.v;

	// Add particle velocities back to the grid
	ni = p.gi;
	for (int i = 0; i < 3; i++) {
		float pxi = px[i];
		for (int j = 0; j < 3; j++) {
				//n = nodes[ni];
				float pyj = py[j];
				float phi = pxi * pyj;
				nodes[ni].u2 += phi * mu;
				nodes[ni].v2 += phi * mv;
				//nodes[ni] = n;
				ni++;
		}
		ni += (GRIDY - 3);
	}

	// write new values
	particles[pi] = p;
}
