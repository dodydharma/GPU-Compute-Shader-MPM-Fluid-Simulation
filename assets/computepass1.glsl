#version 430 core
#extension GL_ARB_compute_shader : enable
#extension GL_ARB_shader_storage_buffer_object : enable
#extension GL_ARB_compute_variable_group_size : enable
#extension GL_NV_shader_atomic_float : enable


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

	//Begin Loop 1
	p = particles[pi];
	
	/*float px[3] = particles[pi].px;
	float py[3] = particles[pi].py;
	float gx[3] = particles[pi].gx;
	float gy[3] = particles[pi].gy;*/
	Material mat = p.mat;
	float gu = 0, gv = 0, dudx = 0, dudy = 0, dvdx = 0, dvdy = 0;
	int ni = p.gi;
	for (int i = 0; i < 3; i++) {
		float pxi = p.px[i];
		float gxi = p.gx[i];
		for (int j = 0; j < 3; j++) {
				//n = nodes[ni];
				float pyj = p.py[j];
				float gyj = p.gy[j];
				float phi = pxi * pyj;
				gu += phi * nodes[ni].u2;
				gv += phi * nodes[ni].v2;
				float gx = gxi * pyj;
				float gy = pxi * gyj;
				// Velocity gradient
				dudx += nodes[ni].u2 * gx;
				dudy += nodes[ni].u2 * gy;
				dvdx += nodes[ni].v2 * gx;
				dvdy += nodes[ni].v2 * gy;
				ni++;
		}
		ni += (GRIDY - 3);
	}

	// Update stress tensor
	float w1 = dudy - dvdx;
	float wT0 = .5f * w1 * (p.T01 + p.T01);
	float wT1 = .5f * w1 * (p.T00 - p.T11);
	float D00 = dudx;
	float D01 = .5f * (dudy + dvdx);
	float D11 = dvdy;
	float trace = .5f * (D00 + D11);
	p.T00 += .5f * (-wT0 + (D00 - trace) - mat.meltRate * p.T00);
	p.T01 += .5f * (wT1 + D01 - mat.meltRate * p.T01);
	p.T11 += .5f * (wT0 + (D11 - trace) - mat.meltRate * p.T11);

	float norm = p.T00 * p.T00 + 2 * p.T01 * p.T01 + p.T11 * p.T11;

	if (norm > mat.maxDeformation)
	{
		p.T00 = p.T01 = p.T11 = 0;
	}

	p.x += gu;
	p.y += gv;

	p.gu = gu;
	p.gv = gv;

	p.u += mat.smoothing*(gu - p.u);
	p.v += mat.smoothing*(gv - p.v);

	// Hard boundary correction
	if (p.x < 2) {
		p.x = 2 + .1f * pi/NPARTICLES;
	}
	else if (p.x > GRIDX - 3) {
		p.x = GRIDX - 3 - .1f * pi/NPARTICLES;
	}
	if (p.y < 2) {
		p.y = 2 + .1f * pi/NPARTICLES;
	}
	else if (p.y > GRIDY - 3) {
		p.y = GRIDY - 3 - .1f * pi/NPARTICLES;
	}
	
	// Update grid cell index and kernel weights
	int cx = p.cx = int(p.x - .5f);
	int cy = p.cy = int(p.y - .5f);
	p.gi = cx * GRIDY + cy;
	
	float x = cx - p.x;
	float y = cy - p.y;

	// Quadratic interpolation kernel weights - Not meant to be changed
	p.px[0] = .5f * x * x + 1.5f * x + 1.125f;
	p.gx[0] = x + 1.5f;
	x++;
	p.px[1] = -x * x + .75f;
	p.gx[1] = -2 * x;
	x++;
	p.px[2] = .5f * x * x - 1.5f * x + 1.125f;
	p.gx[2] = x - 1.5f;

	p.py[0] = .5f * y * y + 1.5f * y + 1.125f;
	p.gy[0] = y + 1.5f;
	y++;
	p.py[1] = -y * y + .75f;
	p.gy[1] = -2 * y;
	y++;
	p.py[2] = .5f * y * y - 1.5f * y + 1.125f;
	p.gy[2] = y - 1.5f;

	/*p.px = px;
	p.py = py;
	p.gx = gx;
	p.gy = gy;*/

	float m = p.mat.mass;
	float mu = m * p.u;
	float mv = m * p.v;
	int mi = p.mat.materialIndex;
	ni = p.gi;
	for (int i = 0; i < 3; i++) {
		float pxi = p.px[i];
		float gxi = p.gx[i];
		for (int j = 0; j < 3; j++) {
				//n = nodes[ni];
				float pyj = p.py[j];
				float gyj = p.gy[j];
				float phi = pxi * pyj;
				// Add particle mass, velocity and density gradient to grid
				//nodes[ni].m += phi * m;
				//nodes[ni].d += phi;
				//nodes[ni].u += phi * mu;
				//nodes[ni].v += phi * mv;
				//nodes[ni].cgx[mi] += gxi * pyj;
				//nodes[ni].cgy[mi] += pxi * gyj;
	
				atomicAdd(nodes[ni].m, phi * m);
				atomicAdd(nodes[ni].d, phi);
				atomicAdd(nodes[ni].u, phi * mu);
				atomicAdd(nodes[ni].v, phi * mv);
				atomicAdd(nodes[ni].cgx[mi], gxi * pyj);
				atomicAdd(nodes[ni].cgy[mi], pxi * gyj);


				nodes[ni].act = true;
				//nodes[ni] = n;
				ni++;
		}
		ni += (GRIDY - 3);
	}
	//p.x = 100f;
	particles[pi] = p;

}
