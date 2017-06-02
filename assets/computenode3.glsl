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
		nodes[ni].act = false;
		nodes[ni].u2 /= nodes[ni].m;
		nodes[ni].v2 /= nodes[ni].m;
	}

		nodes[ni].m = 0;
		nodes[ni].d = 0;
		nodes[ni].u = 0;
		nodes[ni].v = 0;
		float cgx1[numMaterials];
		for (int id = 0; id < numMaterials; id++)
			cgx1[id] = 0;
		nodes[ni].cgx = cgx1;
		nodes[ni].cgy = cgx1;
	
	//actives[i] = n;
	//nodes[i] = n;
}
