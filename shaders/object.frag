#version 460 core

#define MAX_POINT_LIGHTS 4

struct Material
{
	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
	float shininess;

	sampler2D diffuseMap;
	sampler2D specularMap;
	sampler2D emissionMap;

	bool hasDiffuseMap;
	bool hasSpecularMap;
	bool hasEmissionMap;
};

struct DirLight
{
	bool enabled;
	vec3 direction;

	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
};

struct PointLight
{
	bool enabled;
	vec3 position;

	float constant;
	float linear;
	float quadratic;

	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
};

struct SpotLight
{
	bool enabled;
	vec3 position;
	vec3 direction;
	float cutOff;
	float outerCutOff;

	float constant;
	float linear;
	float quadratic;

	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
};

in vec3 fragPos;
in vec3 normal;
in vec2 texCoord;

out vec4 fragColor;

uniform vec3 viewPos;
uniform Material material;

uniform DirLight dirLight;
uniform int pointLightCount;
uniform PointLight pointLights[MAX_POINT_LIGHTS];
uniform SpotLight spotLight;

vec3 CalcDirLight(DirLight light, vec3 norm, vec3 viewDir, vec3 mAmbient, vec3 mDiffuse, vec3 mSpecular)
{
	vec3 lightDir = normalize(-light.direction);

	float diff = max(dot(norm, lightDir), 0.0);

	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);

	vec3 ambient  = light.ambient  * mAmbient;
	vec3 diffuse  = light.diffuse  * diff * mDiffuse;
	vec3 specular = light.specular * spec * mSpecular;

	return ambient + diffuse + specular;
}

vec3 CalcPointLight(PointLight light, vec3 norm, vec3 viewDir, vec3 mAmbient, vec3 mDiffuse, vec3 mSpecular)
{
	vec3 lightDir = normalize(light.position - fragPos);

	float diff = max(dot(norm, lightDir), 0.0);

	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);

	float dist = length(light.position - fragPos);
	float attenuation = 1.0 / (light.constant + light.linear * dist + light.quadratic * dist * dist);

	vec3 ambient  = light.ambient  * mAmbient;
	vec3 diffuse  = light.diffuse  * diff * mDiffuse;
	vec3 specular = light.specular * spec * mSpecular;

	return (ambient + diffuse + specular) * attenuation;
}

vec3 CalcSpotLight(SpotLight light, vec3 norm, vec3 viewDir, vec3 mAmbient, vec3 mDiffuse, vec3 mSpecular)
{
	vec3 lightDir = normalize(light.position - fragPos);

	float diff = max(dot(norm, lightDir), 0.0);

	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);

	float dist = length(light.position - fragPos);
	float attenuation = 1.0 / (light.constant + light.linear * dist + light.quadratic * dist * dist);

	float theta = dot(lightDir, normalize(-light.direction));
	float epsilon = light.cutOff - light.outerCutOff;
	float intensity = clamp((theta - light.outerCutOff) / epsilon, 0.0, 1.0);

	vec3 ambient  = light.ambient  * mAmbient;
	vec3 diffuse  = light.diffuse  * diff * mDiffuse;
	vec3 specular = light.specular * spec * mSpecular;

	return (ambient + diffuse + specular) * attenuation * intensity;
}

void main()
{
	vec3 norm = normalize(normal);
	vec3 viewDir = normalize(viewPos - fragPos);

	vec3 mDiffuse  = material.hasDiffuseMap  ? texture(material.diffuseMap, texCoord).rgb  : material.diffuse;
	vec3 mAmbient  = material.hasDiffuseMap  ? mDiffuse                                    : material.ambient;
	vec3 mSpecular = material.hasSpecularMap ? texture(material.specularMap, texCoord).rgb : material.specular;
	vec3 mEmission = material.hasEmissionMap ? texture(material.emissionMap, texCoord).rgb : vec3(0.0);

	vec3 result = vec3(0.0);

	if (dirLight.enabled)
		result += CalcDirLight(dirLight, norm, viewDir, mAmbient, mDiffuse, mSpecular);

	for (int i = 0; i < pointLightCount; i++)
	{
		if (pointLights[i].enabled)
			result += CalcPointLight(pointLights[i], norm, viewDir, mAmbient, mDiffuse, mSpecular);
	}

	if (spotLight.enabled)
		result += CalcSpotLight(spotLight, norm, viewDir, mAmbient, mDiffuse, mSpecular);

	fragColor = vec4(result + mEmission, 1.0);
}
