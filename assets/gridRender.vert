#version 430 core
#extension GL_ARB_shader_storage_buffer_object : require

struct Node
{
	float m, d, gx, gy, u, v, u2, v2, ax, ay;
	float cgx[4];
	float cgy[4];
	bool act;
};


layout( location = 4 ) in int gridId;

out gl_PerVertex {
    vec4 gl_Position;
};

out block {
     vec4 color;
} Out;

layout( std430, binding = 2 ) buffer Nodes
{
    Node nodes[];
};

uniform mat4 ciModelViewProjection;


void main()
{
	gl_Position = ciModelViewProjection * vec4( (gridId/120 + 1)*(800/160f), (gridId%120 + 1)*(600/120f), 0, 1 );
	gl_PointSize = gridId/(19200-120*6);
	Out.color = vec4(1.0, 0, 0, 1.0);
}