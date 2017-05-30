#include "cinder/app/App.h"
#include "cinder/app/RendererGl.h"
#include "cinder/Rand.h"
#include "cinder/gl/gl.h"
#include "cinder/Utilities.h"
#include "cinder/gl/Ssbo.h"
#include "uniforms.h"


using namespace ci;
using namespace ci::app;
using namespace std;

extern "C"
{
	__declspec(dllexport) unsigned long NvOptimusEnablement = 0x00000001;
	__declspec(dllexport) int AmdPowerXpressRequestHighPerformance = 1;
}

static unsigned int mirand = 1;

class GPUMPMFluidApp : public App {
public:
	void setup() override;
	void update() override;
	void draw() override;

	float sfrand(void);
	string loadShaderWithUniform(string filename);

private:
	gl::GlslProgRef mRenderProg;
	gl::GlslProgRef mGridProg;
	gl::GlslProgRef mProgramPass1;
	gl::GlslProgRef mProgramNode1;
	gl::GlslProgRef mProgramPass2;
	gl::GlslProgRef mProgramNode2;
	gl::GlslProgRef mProgramPass3;
	gl::GlslProgRef mProgramNode3;
	gl::GlslProgRef mProgramPass4;

	// Buffers holding raw particle data on GPU.
	gl::SsboRef mParticleBuffer;
	gl::SsboRef mNodeBuffer;
	gl::SsboRef mActiveBuffer;
	gl::VboRef mIdsVbo;
	gl::VboRef mGridsVbo;
	gl::VaoRef mAttributes;
	gl::VaoRef mGridAttributes;

	Material material[numMaterials];

	// Mouse state suitable for passing as uniforms to update program
	bool			mMouseDown = false;
	float			mMouseForce = 0.0f;
	vec3			mMousePos = vec3(0);
};

float GPUMPMFluidApp::sfrand(void)
{
	unsigned int a;
	mirand *= 16807;
	a = (mirand & 0x007fffff) | 0x40000000;
	return((*((float*)&a) - 3.0f));
}

string GPUMPMFluidApp::loadShaderWithUniform(string filename) {
	// Read uniforms file
	string uniformsCode;
	ifstream uniformsStream("../include/uniforms.h", ios::in);
	if (uniformsStream.is_open()) {
		string Line = "";
		while (getline(uniformsStream, Line))
			uniformsCode += "\n" + Line;
		uniformsStream.close();
	}
	// Read shader file
	string shaderCode;
	ifstream shaderStream("../assets/" + filename, ios::in);
	if (shaderStream.is_open()) {
		string Line = "";
		while (getline(shaderStream, Line))
			shaderCode += "\n" + Line;
		shaderStream.close();
	}
	// Append uniforms code to shader code
	size_t uniformTagPos = shaderCode.find("#UNIFORMS");
	string dest = "";
	if (uniformTagPos != string::npos)
		dest += shaderCode.substr(0, uniformTagPos) + "\n" + uniformsCode + "\n" + shaderCode.substr(uniformTagPos + strlen("#UNIFORMS"), shaderCode.length() - uniformTagPos);
	else
		dest += shaderCode;
	shaderCode = dest;
	return shaderCode;
}

void GPUMPMFluidApp::setup()
{
	// Initialize materials
	material[0].materialIndex = 0;
	material[0].mass = 1.0f;
	material[0].viscosity = 0.04f;

	material[1].materialIndex = 1;
	material[1].mass = 1.0f;
	material[1].restDensity = 10.0f;
	material[1].viscosity = 1.0f;
	material[1].bulkViscosity = 3.0f;
	material[1].stiffness = 1.0f;
	material[1].meltRate = 1.0f;
	material[1].kElastic = 1.0f;

	material[2].materialIndex = 2;
	material[2].mass = 0.7f;
	material[2].viscosity = 0.03f;

	material[3].materialIndex = 3;


	// Create initial particle layout.
	vector<Particle> particles;
	particles.assign(NPARTICLES, Particle());
	vec3 center = vec3(getWindowCenter(), 0.0f);
	for (int i = 0; i < particles.size(); ++i)
	{
		float x = i%GRIDX;
		float y = i / GRIDX;

		auto &particle = particles.at(i);
		particle.x = x;
		particle.y = y;
		particle.u = particle.v = particle.gu = particle.gv = particle.T00 = particle.T01 = particle.T11 = 0;

		// Initialize weights
		particle.cx = (int)(particle.x - .5f);
		particle.cy = (int)(particle.y - .5f);
		particle.gi = particle.cx * GRIDY + particle.cy;

		float x1 = particle.cx - particle.x;
		float y1 = particle.cy - particle.y;

		particle.px[0] = (0.5F * x1 * x1 + 1.5F * x1) + 1.125f;
		particle.gx[0] = x1 + 1.5F;
		x1++;
		particle.px[1] = -x1 * x1 + 0.75F;
		particle.gx[1] = -2.0F * x1;
		x1++;
		particle.px[2] = (0.5F * x1 * x1 - 1.5F * x1) + 1.125f;
		particle.gx[2] = x1 - 1.5F;

		particle.py[0] = (0.5F * y1 * y1 + 1.5F * y1) + 1.125f;
		particle.gy[0] = y1 + 1.5F;
		y1++;
		particle.py[1] = -y1 * y1 + 0.75F;
		particle.gy[1] = -2.0F * y1;
		y1++;
		particle.py[2] = (0.5F * y1 * y1 - 1.5F * y1) + 1.125f;
		particle.gy[2] = y1 - 1.5F;

		particle.mat = material[1];
		//console() << particle.x << endl;
	}
	vector<Node> nodes;
	nodes.assign(GRIDX * GRIDY, Node());
	for (int i = 0; i < nodes.size(); ++i)
	{
		auto &node = nodes.at(i);
		node.ax = node.ay = node.d = node.gx = node.gy = node.m = node.u = node.v = node.u2 = node.v2 = 0;
		node.act = false;
		memset(node.cgx, 0, 2 * numMaterials * sizeof(float));
	}
	vector<Node> activeNodes;
	activeNodes.assign(GRIDX * GRIDY, Node());
	for (int i = 0; i < nodes.size(); ++i)
	{
		auto &node = nodes.at(i);
		node.ax = node.ay = node.d = node.gx = node.gy = node.m = node.u = node.v = node.u2 = node.v2 = 0;
		node.act = false;
		memset(node.cgx, 0, 2 * numMaterials * sizeof(float));
	}


	ivec3 count = gl::getMaxComputeWorkGroupCount();
	CI_ASSERT(count.x >= (NPARTICLES / COMPUTESIZE) + 1);

	mActiveBuffer = gl::Ssbo::create(activeNodes.size() * sizeof(Node), activeNodes.data(), GL_STATIC_DRAW);
	gl::ScopedBuffer scopedActiveSsbo(mActiveBuffer);
	mActiveBuffer->bindBase(3);
	mNodeBuffer = gl::Ssbo::create(nodes.size() * sizeof(Node), nodes.data(), GL_STATIC_DRAW);
	gl::ScopedBuffer scopedNodeSsbo(mNodeBuffer);
	mNodeBuffer->bindBase(2);
	// Create particle buffers on GPU and copy data into the first buffer.
	// Mark as static since we only write from the CPU once.
	mParticleBuffer = gl::Ssbo::create(particles.size() * sizeof(Particle), particles.data(), GL_STATIC_DRAW);
	gl::ScopedBuffer scopedParticleSsbo(mParticleBuffer);
	mParticleBuffer->bindBase(1);


	// Create a default color shader.
	try {
		mRenderProg = gl::GlslProg::create(gl::GlslProg::Format().vertex(loadAsset("particleRender.vert"))
			.fragment(loadAsset("particleRender.frag"))
			.attribLocation("particleId", 0));
		mGridProg = gl::GlslProg::create(gl::GlslProg::Format().vertex(loadAsset("gridRender.vert"))
			.fragment(loadAsset("gridRender.frag"))
			.attribLocation("gridId", 4));
	}
	catch (gl::GlslProgCompileExc e) {
		ci::app::console() << e.what() << std::endl;
		quit();
	}

	std::vector<GLuint> ids(NPARTICLES);
	GLuint currId = 0;
	std::generate(ids.begin(), ids.end(), [&currId]() -> GLuint { return currId++; });

	mIdsVbo = gl::Vbo::create<GLuint>(GL_ARRAY_BUFFER, ids, GL_STATIC_DRAW);
	mAttributes = gl::Vao::create();
	gl::ScopedVao vao(mAttributes);
	gl::ScopedBuffer scopedIds(mIdsVbo);
	gl::enableVertexAttribArray(0);
	gl::vertexAttribIPointer(0, 1, GL_UNSIGNED_INT, sizeof(GLuint), 0);

	std::vector<GLuint> gridids(GRIDX * GRIDY);
	currId = 0;
	std::generate(gridids.begin(), gridids.end(), [&currId]() -> GLuint { return currId++; });

	mGridsVbo = gl::Vbo::create<GLuint>(GL_ARRAY_BUFFER, gridids, GL_STATIC_DRAW);
	mGridAttributes = gl::Vao::create();
	gl::ScopedVao gridvao(mGridAttributes);
	gl::ScopedBuffer scopedGrids(mGridsVbo);
	gl::enableVertexAttribArray(4);
	gl::vertexAttribIPointer(4, 1, GL_UNSIGNED_INT, sizeof(GLuint), 0);

	try {
		//// Load our update program.
		const string pass1 = loadShaderWithUniform("../assets/computepass1.glsl");
		const string node1 = loadShaderWithUniform("../assets/computenode1.glsl");
		const string pass2 = loadShaderWithUniform("../assets/computepass2.glsl");
		const string node2 = loadShaderWithUniform("../assets/computenode2.glsl");
		const string pass3 = loadShaderWithUniform("../assets/computepass3.glsl");
		const string node3 = loadShaderWithUniform("../assets/computenode3.glsl");

		mProgramPass1 = gl::GlslProg::
			create(gl::GlslProg::Format().compute(pass1));
		mProgramNode1 = gl::GlslProg::
			create(gl::GlslProg::Format().compute(node1));
		mProgramPass2 = gl::GlslProg::
			create(gl::GlslProg::Format().compute(pass2));
		mProgramNode2 = gl::GlslProg::
			create(gl::GlslProg::Format().compute(node2));
		mProgramPass3 = gl::GlslProg::
			create(gl::GlslProg::Format().compute(pass3));
		mProgramNode3 = gl::GlslProg::
			create(gl::GlslProg::Format().compute(node3));
	}
	catch (gl::GlslProgCompileExc e) {
		ci::app::console() << e.what() << std::endl;
		quit();
	}

	// Listen to mouse events so we can send data as uniforms.
	getWindow()->getSignalMouseDown().connect([this](MouseEvent event)
	{
		mMouseDown = true;
		mMouseForce = 500.0f;
		mMousePos = vec3(event.getX(), event.getY(), 0.0f);
	});
	getWindow()->getSignalMouseDrag().connect([this](MouseEvent event)
	{
		mMousePos = vec3(event.getX(), event.getY(), 0.0f);
	});
	getWindow()->getSignalMouseUp().connect([this](MouseEvent event)
	{
		mMouseForce = 0.0f;
		mMouseDown = false;
	});
}

void GPUMPMFluidApp::update()
{
	// Update particles on the GPU
	gl::ScopedGlslProg pass1(mProgramPass1);

	//mProgramPass1->uniform( "uMouseForce", mMouseForce );
	//mProgramPass1->uniform( "uMousePos", mMousePos );
	gl::ScopedBuffer scopedParticleSsbo(mParticleBuffer);
	gl::ScopedBuffer scopedNodeSsbo(mNodeBuffer);
	gl::ScopedBuffer scopedActiveSsbo(mActiveBuffer);

	gl::dispatchCompute(NPARTICLES / COMPUTESIZE + 1, 1, 1);
	gl::memoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

	gl::ScopedGlslProg node1(mProgramNode1);

	//mProgramPass1->uniform( "uMouseForce", mMouseForce );
	//mProgramPass1->uniform( "uMousePos", mMousePos );

	gl::dispatchCompute((GRIDX*GRIDY) / COMPUTESIZE, 1, 1);
	gl::memoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

	gl::ScopedGlslProg pass2(mProgramPass2);

	//mProgramPass1->uniform( "uMouseForce", mMouseForce );
	//mProgramPass1->uniform( "uMousePos", mMousePos );

	gl::dispatchCompute(NPARTICLES / COMPUTESIZE + 1, 1, 1);
	gl::memoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

	gl::ScopedGlslProg node2(mProgramNode2);

	//mProgramPass1->uniform( "uMouseForce", mMouseForce );
	//mProgramPass1->uniform( "uMousePos", mMousePos );

	gl::dispatchCompute((GRIDX*GRIDY) / COMPUTESIZE + 1, 1, 1);
	gl::memoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

	gl::ScopedGlslProg pass3(mProgramPass3);

	//mProgramPass1->uniform( "uMouseForce", mMouseForce );
	//mProgramPass1->uniform( "uMousePos", mMousePos );

	gl::dispatchCompute(NPARTICLES / COMPUTESIZE + 1, 1, 1);
	gl::memoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

	gl::ScopedGlslProg node3(mProgramNode3);

	//mProgramPass1->uniform( "uMouseForce", mMouseForce );
	//mProgramPass1->uniform( "uMousePos", mMousePos );

	gl::dispatchCompute((GRIDX*GRIDY) / COMPUTESIZE + 1, 1, 1);
	gl::memoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);

	// Update mouse force.
	if (mMouseDown) {
		mMouseForce = 150.0f;
	}
}

void GPUMPMFluidApp::draw()
{
	gl::clear(Color(0, 0, 0));
	gl::setMatricesWindowPersp(getWindowSize());
	gl::enableDepthRead();
	gl::enableDepthWrite();
	gl::enable(GL_VERTEX_PROGRAM_POINT_SIZE);

	gl::ScopedGlslProg gridRender(mGridProg);
	gl::ScopedBuffer scopedNodeSsbo(mNodeBuffer);
	gl::ScopedVao gridvao(mGridAttributes);

	gl::context()->setDefaultShaderVars();
	gl::drawArrays(GL_POINTS, 0, GRIDX*GRIDY);

	gl::ScopedGlslProg render(mRenderProg);
	gl::ScopedBuffer scopedParticleSsbo(mParticleBuffer);
	gl::ScopedVao vao(mAttributes);

	gl::context()->setDefaultShaderVars();

	gl::pointSize(3.0f);
	gl::drawArrays(GL_POINTS, 0, NPARTICLES);

	gl::setMatricesWindow(app::getWindowSize());
	gl::drawString(toString(static_cast<int>(getAverageFps())) + " fps", vec2(32.0f, 52.0f));
}

CINDER_APP(GPUMPMFluidApp, RendererGl, [](App::Settings *settings) {
	settings->setWindowSize(WINDOWX, WINDOWY);
	settings->setMultiTouchEnabled(false);
})
