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
	uint i = gl_GlobalInvocationID.x;

	if (i >= GRIDX*GRIDY) return;

	Node n = nodes[i];
	if (n.act && n.m > 0) {
		n.act = false;
		n.u2 /= n.m;
		n.v2 /= n.m;

		/*n.m = 0;
		n.d = 0;
		n.u = 0;
		n.v = 0;
		float cgx1[numMaterials];
		for (int id = 0; id < numMaterials; id++)
			cgx1[id] = 0;
		n.cgx = cgx1;
		n.cgy = cgx1;*/
	}
	//actives[i] = n;
	nodes[i] = n;
}
