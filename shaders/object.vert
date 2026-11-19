#version 460 core

layout (location = 0) in vec3 inPos;
layout (location = 1) in vec3 inNormal;
layout (location = 2) in vec2 inTexCoord;

layout (std430, binding = 0) readonly buffer VPBuffer
{
	mat4 view;
	mat4 projection;
};

uniform mat4 model;

out vec3 fragPos;
out vec3 normal;
out vec2 texCoord;

void main()
{
	vec4 worldPos = model * vec4(inPos, 1.0);

	fragPos = worldPos.xyz;
	// normal matrix - correct also for non-uniform scale (could be precomputed on the CPU)
	normal = mat3(transpose(inverse(model))) * inNormal;
	texCoord = inTexCoord;

	gl_Position = projection * view * worldPos;
}
