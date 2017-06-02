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

	// read nodes from buffers
	//Node n = nodes[i];
	nodes[ni].ax = nodes[ni].ay = 0;
	nodes[ni].gx = 0;
	nodes[ni].gy = 0;
	if (nodes[ni].act && nodes[ni].m > 0) {
		//actives[i] = n;
		//nodes[ni].act = false;
		
		nodes[ni].u /= nodes[ni].m;
		nodes[ni].v /= nodes[ni].m;
		for (int j = 0; j < numMaterials; j++) {
			nodes[ni].gx += nodes[ni].cgx[j];
			nodes[ni].gy += nodes[ni].cgy[j];
		}
		for (int j = 0; j < numMaterials; j++) {
			nodes[ni].cgx[j] -= nodes[ni].gx - nodes[ni].cgx[j];
			nodes[ni].cgy[j] -= nodes[ni].gy - nodes[ni].cgy[j];
		}
	}
	//nodes[i] = n;
}
