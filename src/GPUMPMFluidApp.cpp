#include "cinder/app/App.h"
#include "cinder/app/RendererGl.h"
#include "cinder/gl/gl.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class GPUMPMFluidApp : public App {
  public:
	void setup() override;
	void mouseDown( MouseEvent event ) override;
	void update() override;
	void draw() override;
};

void GPUMPMFluidApp::setup()
{
}

void GPUMPMFluidApp::mouseDown( MouseEvent event )
{
}

void GPUMPMFluidApp::update()
{
}

void GPUMPMFluidApp::draw()
{
	gl::clear( Color( 0, 0, 0 ) ); 
}

CINDER_APP( GPUMPMFluidApp, RendererGl )
