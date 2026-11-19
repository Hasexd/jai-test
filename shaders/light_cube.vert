#version 460 core

layout (location = 0) in vec3 inPos;

layout (std430, binding = 0) readonly buffer VPBuffer
{
	mat4 view;
	mat4 projection;
};

uniform mat4 model;

void main()
{
	gl_Position = projection * view * model * vec4(inPos, 1.0);
}
