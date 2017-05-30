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

float uscip(float p00, float x00, float y00, float p01, float x01, float y01, float p10, float x10, float y10, float p11, float x11, float y11, float u, float v)
{
	float dx = x00 - x01;
	float dy = y00 - y10;
	float a = p01 - p00;
	float b = p11 - p10 - a;
	float c = p10 - p00;
	float d = y11 - y01;
	return ((((d - 2 * b - dy) * u - 2 * a + y00 + y01) * v +
		((3 * b + 2 * dy - d) * u + 3 * a - 2 * y00 - y01)) * v +
		((((2 * c - x00 - x10) * u + (3 * b + 2 * dx + x10 - x11)) * u - b - dy - dx) * u + y00)) * v +
		(((x11 - 2 * (p11 - p01 + c) + x10 + x00 + x01) * u +
		(3 * c - 2 * x00 - x10)) * u +
			x00) * u + p00;
}

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

	float fx = 0, fy = 0, dudx = 0, dudy = 0, dvdx = 0, dvdy = 0, sx = 0, sy = 0;
	n = nodes[p.gi];
	float ppx[3] = p.px;
	float pgx[3] = p.gx;
	float ppy[3] = p.py;
	float pgy[3] = p.gy;

	int materialId = mat.materialIndex;
	int ni = p.gi;
	for (int i = 0; i < 3; i++) {
		float pxi = ppx[i];
		float gxi = pgx[i];
		for (int j = 0; j < 3; j++) {
			if (ni < GRIDX * GRIDY) {
				n = nodes[ni];
				float pyj = ppy[j];
				float gyj = pgy[j];
				float phi = pxi * pyj;
				float gx = gxi * pyj;
				float gy = pxi * gyj;
				// Velocity gradient
				dudx += n.u * gx;
				dudy += n.u * gy;
				dvdx += n.v * gx;
				dvdy += n.v * gy;

				// Surface tension
				sx += phi * n.cgx[materialId];
				sy += phi * n.cgy[materialId];
				ni++;
			}
		}
		ni += (GRIDY - 3);
	}

	int cx = int(p.x);
	int cy = int(p.y);
	int gi = cx * GRIDY + cy;

	Node n1 = nodes[gi];
	Node n2 = nodes[gi + 1];
	Node n3 = nodes[gi + GRIDY];
	Node n4 = nodes[gi + GRIDY + 1];
	float density = uscip(n1.d, n1.gx, n1.gy, n2.d, n2.gx, n2.gy, n3.d, n3.gx, n3.gy, n4.d, n4.gx, n4.gy, p.x - cx, p.y - cy);

	float pressure = mat.stiffness / mat.restDensity * (density - mat.restDensity);
	if (pressure > 2) {
		pressure = 2;
	}

	// Update stress tensor
	float w1 = dudy - dvdx;
	float wT0 = .5f * w1 * (p.T01 + p.T01);
	float wT1 = .5f * w1 * (p.T00 - p.T11);
	float D00 = dudx;
	float D01 = .5f * (dudy + dvdx);
	float D11 = dvdy;
	float trace = .5f * (D00 + D11);
	D00 -= trace;
	D11 -= trace;
	p.T00 += .5f * (-wT0 + D00 - mat.meltRate * p.T00);
	p.T01 += .5f * (wT1 + D01 - mat.meltRate * p.T01);
	p.T11 += .5f * (wT0 + D11 - mat.meltRate * p.T11);

	// Stress tensor fracture
	float norm = p.T00 * p.T00 + 2 * p.T01 * p.T01 + p.T11 * p.T11;

	if (norm > mat.maxDeformation)
	{
		p.T00 = p.T01 = p.T11 = 0;
	}

	float T00 = mat.mass * (mat.kElastic * p.T00 + mat.viscosity * D00 + pressure + trace * mat.bulkViscosity);
	float T01 = mat.mass * (mat.kElastic * p.T01 + mat.viscosity * D01);
	float T11 = mat.mass * (mat.kElastic * p.T11 + mat.viscosity * D11 + pressure + trace * mat.bulkViscosity);

	// Surface tension
	float lenSq = sx * sx + sy * sy;
	if (lenSq > 0)
	{
		float len = sqrt(lenSq);
		float a = mat.mass * mat.surfaceTension / len;
		T00 -= a * (.5f * lenSq - sx * sx);
		T01 -= a * (-sx * sy);
		T11 -= a * (.5f * lenSq - sy * sy);
	}

	// Wall force
	if (p.x < 4) {
		fx += (4 - p.x);
	}
	else if (p.x > GRIDX - 5) {
		fx += (GRIDX - 5 - p.x);
	}
	if (p.y < 4) {
		fy += (4 - p.y);
	}
	else if (p.y > GRIDY - 5) {
		fy += (GRIDY - 5 - p.y);
	}


	// Add forces to grid
	ni = p.gi;
	for (int i = 0; i < 3; i++) {
		float pxi = ppx[i];
		float gxi = pgx[i];
		for (int j = 0; j < 3; j++) {
			if (ni < GRIDX * GRIDY) {
				n = nodes[ni];
				float pyj = ppy[j];
				float gyj = pgy[j];
				float phi = pxi * pyj;

				float gx = gxi * pyj;
				float gy = pxi * gyj;
				n.ax += -(gx * T00 + gy * T01) + fx * phi;
				n.ay += -(gx * T01 + gy * T11) + fy * phi;
				nodes[ni] = n;
				ni++;
			}
		}
		ni += (GRIDY - 3);
	}

	//Assign final particle Position
	p.posx = p.x * WINDOWX/GRIDX;
	p.posy = p.y * WINDOWY/GRIDY;
	//p.pu = (p.x - p.gu);
	//p.pv = (p.y - p.gv);

	// write new values
	particles[pi] = p;
}
