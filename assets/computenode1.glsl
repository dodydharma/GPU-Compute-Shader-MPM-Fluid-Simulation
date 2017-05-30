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

	// read nodes from buffers
	Node n = nodes[i];
	if (n.act && n.m > 0) {
		actives[i] = n;
		//n.act = false;
		n.ax = n.ay = 0;
		n.gx = 0;
		n.gy = 0;
		n.u /= n.m;
		n.v /= n.m;
		for (int j = 0; j < numMaterials; j++) {
			n.gx += n.cgx[j];
			n.gy += n.cgy[j];
		}
		for (int j = 0; j < numMaterials; j++) {
			n.cgx[j] -= n.gx - n.cgx[j];
			n.cgy[j] -= n.gy - n.cgy[j];
		}
	}
	nodes[i] = n;
}
