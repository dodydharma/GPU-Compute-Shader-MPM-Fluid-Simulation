#version 430 core

in block {
    vec4 color;
} In;

layout(location=0) out vec4 fragColor;

void main()
{
    fragColor = vec4(In.color.rgb, 1.0);
}