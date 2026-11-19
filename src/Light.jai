
MAX_POINT_LIGHTS :: 4;

Material :: struct
{
	Ambient: Vector3;
	Diffuse: Vector3;
	Specular: Vector3;
	Shininess: float32;
}

// http://devernay.free.fr/cours/opengl/materials.html
MATERIAL_EMERALD   :: Material.{ Vector3.{ 0.0215, 0.1745, 0.0215 },  Vector3.{ 0.07568, 0.61424, 0.07568 },
	Vector3.{ 0.633, 0.727811, 0.633 }, 76.8 };

MATERIAL_GOLD      :: Material.{ Vector3.{ 0.24725, 0.1995, 0.0745 }, Vector3.{ 0.75164, 0.60648, 0.22648 },
	Vector3.{ 0.628281, 0.555802, 0.366065 }, 51.2 };

MATERIAL_CHROME    :: Material.{ Vector3.{ 0.25, 0.25, 0.25 },        Vector3.{ 0.4, 0.4, 0.4 },
	Vector3.{ 0.774597, 0.774597, 0.774597 }, 76.8 };

MATERIAL_COPPER    :: Material.{ Vector3.{ 0.19125, 0.0735, 0.0225 }, Vector3.{ 0.7038, 0.27048, 0.0828 },
	Vector3.{ 0.256777, 0.137622, 0.086014 }, 12.8 };

MATERIAL_RED_RUBBER :: Material.{ Vector3.{ 0.05, 0.0, 0.0 },         Vector3.{ 0.5, 0.4, 0.4 },
	Vector3.{ 0.7, 0.04, 0.04 },             10.0 };


DirLight :: struct
{
	Enabled: bool;
	Direction: Vector3;

	Ambient: Vector3;
	Diffuse: Vector3;
	Specular: Vector3;
}

PointLight :: struct
{
	Enabled: bool;
	Position: Vector3;

	Constant: float32;
	Linear: float32;
	Quadratic: float32;

	Ambient: Vector3;
	Diffuse: Vector3;
	Specular: Vector3;
}

SpotLight :: struct
{
	Enabled: bool;
	Position: Vector3;
	Direction: Vector3;
	CutOff: float32;
	OuterCutOff: float32;

	Constant: float32;
	Linear: float32;
	Quadratic: float32;

	Ambient: Vector3;
	Diffuse: Vector3;
	Specular: Vector3;
}

MakeDirLight :: (direction: Vector3, color: Vector3) -> DirLight
{
	light: DirLight;

	light.Enabled = true;
	light.Direction = direction;
	light.Ambient = color * 0.05;
	light.Diffuse = color * 0.4;
	light.Specular = color * 0.5;

	return light;
}

MakePointLight :: (position: Vector3, color: Vector3) -> PointLight
{
	light: PointLight;

	light.Enabled = true;
	light.Position = position;

	light.Constant = 1.0;
	light.Linear = 0.09;
	light.Quadratic = 0.032;

	light.Ambient = color * 0.05;
	light.Diffuse = color * 0.8;
	light.Specular = color;

	return light;
}

MakeSpotLight :: (innerDegrees: float32, outerDegrees: float32) -> SpotLight
{
	light: SpotLight;

	light.Enabled = true;

	light.CutOff = cos(innerDegrees * (PI / 180.0));
	light.OuterCutOff = cos(outerDegrees * (PI / 180.0));

	light.Constant = 1.0;
	light.Linear = 0.09;
	light.Quadratic = 0.032;

	light.Ambient = Vector3.{ 0.0, 0.0, 0.0 };
	light.Diffuse = Vector3.{ 1.0, 1.0, 1.0 };
	light.Specular = Vector3.{ 1.0, 1.0, 1.0 };

	return light;
}

ShaderSetMaterial :: (shader: *Shader, material: *Material)
{
	ShaderSetVec3(shader, "material.ambient", material.Ambient);
	ShaderSetVec3(shader, "material.diffuse", material.Diffuse);
	ShaderSetVec3(shader, "material.specular", material.Specular);
	ShaderSetFloat(shader, "material.shininess", material.Shininess);
}

ShaderSetDirLight :: (shader: *Shader, light: *DirLight)
{
	ShaderSetBool(shader, "dirLight.enabled", light.Enabled);
	ShaderSetVec3(shader, "dirLight.direction", light.Direction);
	ShaderSetVec3(shader, "dirLight.ambient", light.Ambient);
	ShaderSetVec3(shader, "dirLight.diffuse", light.Diffuse);
	ShaderSetVec3(shader, "dirLight.specular", light.Specular);
}

ShaderSetPointLights :: (shader: *Shader, lights: [] PointLight)
{
	count := lights.count;
	if count > MAX_POINT_LIGHTS count = MAX_POINT_LIGHTS;

	ShaderSetInt(shader, "pointLightCount", xx count);

	for i: 0..count - 1
	{
		light := *lights[i];

		ShaderSetBool (shader, tprint("pointLights[%].enabled", i), light.Enabled);
		ShaderSetVec3 (shader, tprint("pointLights[%].position", i), light.Position);
		ShaderSetFloat(shader, tprint("pointLights[%].constant", i), light.Constant);
		ShaderSetFloat(shader, tprint("pointLights[%].linear", i), light.Linear);
		ShaderSetFloat(shader, tprint("pointLights[%].quadratic", i), light.Quadratic);
		ShaderSetVec3 (shader, tprint("pointLights[%].ambient", i), light.Ambient);
		ShaderSetVec3 (shader, tprint("pointLights[%].diffuse", i), light.Diffuse);
		ShaderSetVec3 (shader, tprint("pointLights[%].specular", i), light.Specular);
	}
}

ShaderSetSpotLight :: (shader: *Shader, light: *SpotLight)
{
	ShaderSetBool (shader, "spotLight.enabled", light.Enabled);
	ShaderSetVec3 (shader, "spotLight.position", light.Position);
	ShaderSetVec3 (shader, "spotLight.direction", light.Direction);
	ShaderSetFloat(shader, "spotLight.cutOff", light.CutOff);
	ShaderSetFloat(shader, "spotLight.outerCutOff", light.OuterCutOff);
	ShaderSetFloat(shader, "spotLight.constant", light.Constant);
	ShaderSetFloat(shader, "spotLight.linear", light.Linear);
	ShaderSetFloat(shader, "spotLight.quadratic", light.Quadratic);
	ShaderSetVec3 (shader, "spotLight.ambient", light.Ambient);
	ShaderSetVec3 (shader, "spotLight.diffuse", light.Diffuse);
	ShaderSetVec3 (shader, "spotLight.specular", light.Specular);
}

#import, file "Shader.jai";

#import "Basic";
#import "Math";
