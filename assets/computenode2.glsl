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
	uint ni = gl_GlobalInvocationID.x;

	if (ni >= GRIDX*GRIDY) return;
	
	//Node n = nodes[i];
	if (nodes[ni].act && nodes[ni].m > 0) {
		
		nodes[ni].ax /= nodes[ni].m;
		nodes[ni].ay /= nodes[ni].m;
	}
	nodes[ni].u2 = 0;
	nodes[ni].v2 = 0;

	// write new values
	//nodes[i] = n;
}
