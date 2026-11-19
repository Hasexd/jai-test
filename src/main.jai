
main :: () {
	glfwInitResult := glfwInit();

	if !glfwInitResult 
		print("GLFW initialization failed!\n");
	
	defer glfwTerminate();
	
	app: App;
	app.Width = 1080;
	app.Height = 720;
	app.CursorDisabled = true;
	app.FlashlightOn = true;
	app.DirLightOn = true;
	app.PointLightsOn = true;

	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

	app.Window = glfwCreateWindow(xx app.Width, xx app.Height, "Window", null, null);
	defer glfwDestroyWindow(app.Window);

	glfwMakeContextCurrent(app.Window);

	gl_load(*gl, glfwGetProcAddress.(*void));

	glfwSetWindowUserPointer(app.Window, *app);
	glfwSetFramebufferSizeCallback(app.Window, _FramebufferCallback);
	glfwSetCursorPosCallback(app.Window, _CursorPosCallback);
	glfwSetKeyCallback(app.Window, _KeyCallback);
	glfwSetMouseButtonCallback(app.Window, _MouseButtonCallback);

	glViewport(0, 0, app.Width, app.Height);

	glEnable(GL_DEPTH_TEST);
	glfwSetInputMode(app.Window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

	objectShader: Shader;
	ShaderInit(*objectShader, "object.vert", "object.frag");

	lightCubeShader: Shader;
	ShaderInit(*lightCubeShader, "light_cube.vert", "light_cube.frag");

	CameraInit(*app.MainCamera, Vector3.{ 0.0, 0.0, 3.0 });

	vpBuffer := _CreateVPBuffer(0);
	vp := VP.{
		CameraGetViewMatrix(*app.MainCamera),
		CameraGetProjectionMatrix(*app.MainCamera, cast(float32) app.Width / cast(float32) app.Height)
	};

	lastX, lastY: float64;
	glfwGetCursorPos(app.Window, *lastX, *lastY);
	app.LastX = cast(float32) lastX;
	app.LastY = cast(float32) lastY;

	// to delete later
	vertices: [..]Vertex;

	array_add(*vertices, Vertex.{ Vector3.{ -0.5, -0.5, -0.5 }, Vector3.{ 0, 0, -1 }, Vector2.{ 1, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5,  0.5, -0.5 }, Vector3.{ 0, 0, -1 }, Vector2.{ 1, 1 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5,  0.5, -0.5 }, Vector3.{ 0, 0, -1 }, Vector2.{ 0, 1 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5, -0.5, -0.5 }, Vector3.{ 0, 0, -1 }, Vector2.{ 0, 0 } });

	array_add(*vertices, Vertex.{ Vector3.{ -0.5, -0.5,  0.5 }, Vector3.{ 0, 0, 1 }, Vector2.{ 0, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5, -0.5,  0.5 }, Vector3.{ 0, 0, 1 }, Vector2.{ 1, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5,  0.5,  0.5 }, Vector3.{ 0, 0, 1 }, Vector2.{ 1, 1 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5,  0.5,  0.5 }, Vector3.{ 0, 0, 1 }, Vector2.{ 0, 1 } });

	array_add(*vertices, Vertex.{ Vector3.{ -0.5, -0.5, -0.5 }, Vector3.{ -1, 0, 0 }, Vector2.{ 0, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5, -0.5,  0.5 }, Vector3.{ -1, 0, 0 }, Vector2.{ 1, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5,  0.5,  0.5 }, Vector3.{ -1, 0, 0 }, Vector2.{ 1, 1 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5,  0.5, -0.5 }, Vector3.{ -1, 0, 0 }, Vector2.{ 0, 1 } });

	array_add(*vertices, Vertex.{ Vector3.{  0.5, -0.5, -0.5 }, Vector3.{ 1, 0, 0 }, Vector2.{ 1, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5,  0.5, -0.5 }, Vector3.{ 1, 0, 0 }, Vector2.{ 1, 1 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5,  0.5,  0.5 }, Vector3.{ 1, 0, 0 }, Vector2.{ 0, 1 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5, -0.5,  0.5 }, Vector3.{ 1, 0, 0 }, Vector2.{ 0, 0 } });

	array_add(*vertices, Vertex.{ Vector3.{ -0.5, -0.5, -0.5 }, Vector3.{ 0, -1, 0 }, Vector2.{ 0, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5, -0.5, -0.5 }, Vector3.{ 0, -1, 0 }, Vector2.{ 1, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5, -0.5,  0.5 }, Vector3.{ 0, -1, 0 }, Vector2.{ 1, 1 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5, -0.5,  0.5 }, Vector3.{ 0, -1, 0 }, Vector2.{ 0, 1 } });

	array_add(*vertices, Vertex.{ Vector3.{ -0.5,  0.5,  0.5 }, Vector3.{ 0, 1, 0 }, Vector2.{ 0, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5,  0.5,  0.5 }, Vector3.{ 0, 1, 0 }, Vector2.{ 1, 0 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5,  0.5, -0.5 }, Vector3.{ 0, 1, 0 }, Vector2.{ 1, 1 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5,  0.5, -0.5 }, Vector3.{ 0, 1, 0 }, Vector2.{ 0, 1 } });
	
	indices: [..]u32;
	for face: 0..5 
	{
    	b := cast(u32) (face * 4);
    	array_add(*indices, b + 0); array_add(*indices, b + 1); array_add(*indices, b + 2);
    	array_add(*indices, b + 0); array_add(*indices, b + 2); array_add(*indices, b + 3);
	}
	
	textures: [..] Texture;

	diffuseMap, diffuseOk := TextureLoad("container2.png", "texture_diffuse");
	if !diffuseOk
	{
		diffuseMap = TextureCreateSolid(200, 200, 200, "texture_diffuse");
	}
	array_add(*textures, diffuseMap);

	specularMap, specularOk := TextureLoad("container2_specular.png", "texture_specular");
	if !specularOk
	{
		specularMap = TextureCreateSolid(128, 128, 128, "texture_specular");
	}
	array_add(*textures, specularMap);

	emissionMap, emissionOk := TextureLoad("matrix.jpg", "texture_emission");
	if emissionOk
	{
		array_add(*textures, emissionMap);
	}

	cubeMesh: Mesh;
	MeshInit(*cubeMesh, *vertices, *indices, *textures);

	noTextures: [..] Texture;
	plainMesh: Mesh;
	MeshInit(*plainMesh, *vertices, *indices, *noTextures);

	containerMaterial := Material.{ Vector3.{ 1.0, 1.0, 1.0 }, Vector3.{ 1.0, 1.0, 1.0 }, Vector3.{ 1.0, 1.0, 1.0 }, 32.0 };

	plainMaterials := Material.[ MATERIAL_EMERALD, MATERIAL_GOLD, MATERIAL_CHROME ];
	plainPositions := Vector3.[
		Vector3.{ -2.0,  0.0,  0.0 },
		Vector3.{  2.0,  0.0,  0.0 },
		Vector3.{  0.0, -1.5,  0.0 }
	];

	cubePositions := Vector3.[
		Vector3.{  0.0,  0.0,   0.0 },
		Vector3.{  2.0,  5.0, -15.0 },
		Vector3.{ -1.5, -2.2,  -2.5 },
		Vector3.{ -3.8, -2.0, -12.3 },
		Vector3.{  2.4, -0.4,  -3.5 },
		Vector3.{ -1.7,  3.0,  -7.5 },
		Vector3.{  1.3, -2.0,  -2.5 },
		Vector3.{  1.5,  2.0,  -2.5 },
		Vector3.{  1.5,  0.2,  -1.5 },
		Vector3.{ -1.3,  1.0,  -1.5 }
	];

	dirLight := MakeDirLight(Vector3.{ -0.2, -1.0, -0.3 }, Vector3.{ 1.0, 1.0, 1.0 });

	pointLightPositions := Vector3.[
		Vector3.{  0.7,  0.2,   2.0 },
		Vector3.{  2.3, -3.3,  -4.0 },
		Vector3.{ -4.0,  2.0, -12.0 },
		Vector3.{  0.0,  0.0,  -3.0 }
	];
	pointLightColors := Vector3.[
		Vector3.{ 1.0, 0.9, 0.8 },
		Vector3.{ 0.4, 0.6, 1.0 },
		Vector3.{ 1.0, 0.3, 0.2 },
		Vector3.{ 0.3, 1.0, 0.4 }
	];

	pointLights: [MAX_POINT_LIGHTS] PointLight;
	for i: 0..MAX_POINT_LIGHTS - 1
	{
		pointLights[i] = MakePointLight(pointLightPositions[i], pointLightColors[i]);
	}

	spotLight := MakeSpotLight(12.5, 15.0);

	now := glfwGetTime();
	last := glfwGetTime();
	deltaTime: float32 = 0.0;
	
	glClearColor(0.0, 0.0, 0.0, 1.0);
	while !glfwWindowShouldClose(app.Window) 
	{
		now = glfwGetTime();
		deltaTime = cast(float32) (now - last);
		last = now;

		glfwPollEvents();

		if glfwGetKey(app.Window, GLFW_KEY_W) == GLFW_PRESS CameraProcessKeyboard(*app.MainCamera, .FORWARD, deltaTime);
		if glfwGetKey(app.Window, GLFW_KEY_S) == GLFW_PRESS CameraProcessKeyboard(*app.MainCamera, .BACKWARD, deltaTime);
		if glfwGetKey(app.Window, GLFW_KEY_A) == GLFW_PRESS CameraProcessKeyboard(*app.MainCamera, .LEFT, deltaTime);
		if glfwGetKey(app.Window, GLFW_KEY_D) == GLFW_PRESS CameraProcessKeyboard(*app.MainCamera, .RIGHT, deltaTime);
		
		_UpdateCameraBuffers(*app, *vp, vpBuffer);
		
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		dirLight.Enabled = app.DirLightOn;

		for *pointLights
		{
			it.Enabled = app.PointLightsOn;
		}

		spotLight.Enabled = app.FlashlightOn;
		spotLight.Position = app.MainCamera.Position;
		spotLight.Direction = app.MainCamera.Front;

		ShaderUse(*objectShader);
		ShaderSetVec3(*objectShader, "viewPos", app.MainCamera.Position);

		ShaderSetDirLight(*objectShader, *dirLight);
		ShaderSetPointLights(*objectShader, pointLights);
		ShaderSetSpotLight(*objectShader, *spotLight);

		ShaderSetMaterial(*objectShader, *containerMaterial);
		for position, i: cubePositions
		{
			angle := 20.0 * cast(float32) i;
			model := MakeTranslation(position) * MakeRotation(Vector3.{ 1.0, 0.3, 0.5 }, _ToRadians(angle));

			ShaderSetMat4(*objectShader, "model", model);
			MeshDraw(*cubeMesh, *objectShader);
		}

		for *plainMaterials
		{
			model := MakeTranslation(plainPositions[it_index]) * MakeScale(Vector3.{ 0.8, 0.8, 0.8 });

			ShaderSetMaterial(*objectShader, it);
			ShaderSetMat4(*objectShader, "model", model);
			MeshDraw(*plainMesh, *objectShader);
		}

		ShaderUse(*lightCubeShader);
		for light: pointLights
		{
			if !light.Enabled continue;

			model := MakeTranslation(light.Position) * MakeScale(Vector3.{ 0.2, 0.2, 0.2 });

			ShaderSetMat4(*lightCubeShader, "model", model);
			ShaderSetVec3(*lightCubeShader, "lightColor", light.Specular);
			MeshDrawGeometry(*cubeMesh);
		}

		glfwSwapBuffers(app.Window);

		reset_temporary_storage();
	}
}

_UpdateCameraBuffers :: (app: *App, vp: *VP, vpBuffer: u32)
{
	aspect: float32 = 1.0;
	if app.Height > 0
		aspect = cast(float32) app.Width / cast(float32) app.Height;

	vp.View = CameraGetViewMatrix(*app.MainCamera);
	vp.Projection = CameraGetProjectionMatrix(*app.MainCamera, aspect);

	_UpdateVPBuffer(vpBuffer, vp);
}

_CreateVPBuffer :: (binding: u32) -> u32
{
	buffer: u32 = 0;

	glGenBuffers(1, *buffer);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, buffer);
	glBufferData(GL_SHADER_STORAGE_BUFFER, size_of(VP), null, GL_DYNAMIC_DRAW);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding, buffer);

	return buffer;
}

_UpdateVPBuffer :: (buffer: u32, vp: *VP)
{
	view := transpose(vp.View);
	projection := transpose(vp.Projection);

	transposedVP := VP.{
		view,
		projection
	};

	glBindBuffer(GL_SHADER_STORAGE_BUFFER, buffer);
	glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, size_of(VP), *transposedVP);
}

_MouseButtonCallback :: (window: *GLFWwindow, button: s32, action: s32, mods: s32) #c_call
{
	app := cast(*App) glfwGetWindowUserPointer(window);

	if button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS
	{
		if !app.CursorDisabled
		{
			glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
			app.CursorDisabled = true;
		}
	}
}

_KeyCallback :: (window: *GLFWwindow, key: s32, scancode: s32, action: s32, mods: s32) #c_call
{
	app := cast(*App) glfwGetWindowUserPointer(window);

	if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS
	{
		if app.CursorDisabled
		{
			glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
			app.CursorDisabled = false;
		}
	}

	if key == GLFW_KEY_F && action == GLFW_PRESS app.FlashlightOn = !app.FlashlightOn;
	if key == GLFW_KEY_G && action == GLFW_PRESS app.DirLightOn = !app.DirLightOn;
	if key == GLFW_KEY_H && action == GLFW_PRESS app.PointLightsOn = !app.PointLightsOn;
}

_CursorPosCallback :: (window: *GLFWwindow, xOffset: float64, yOffset: float64) #c_call
{
	app := cast(*App) glfwGetWindowUserPointer(window);

	if (!app.CursorDisabled)
	{
		app.LastX = cast(float32) xOffset;
		app.LastY = cast(float32) yOffset;

		return;
	}
	
	push_context 
	{
		CameraProcessMouse(*app.MainCamera, cast(float32) (xOffset - app.LastX), cast(float32) (app.LastY - yOffset));
	}

	app.LastX = cast(float32) xOffset;
	app.LastY = cast(float32) yOffset;
}

_FramebufferCallback :: (window: *GLFWwindow, width: s32, height: s32) #c_call
{
	app := cast(*App) glfwGetWindowUserPointer(window);

	glViewport(0, 0, xx width, xx height);

	app.Width = xx width;
	app.Height = xx height;
}


App :: struct 
{
	Width: u32;
	Height: u32;
	Window: *GLFWwindow;
	MainCamera: Camera;
	LastX: float32;
	LastY: float32;
	CursorDisabled: bool;
	FlashlightOn: bool;
	DirLightOn: bool;
	PointLightsOn: bool;
}

VP :: struct
{
	View: Matrix4;
	Projection: Matrix4;
}

#import, file "Mesh.jai";
#import, file "Shader.jai";
#import, file "Camera.jai";
#import, file "Assimp.jai";
#import, file "Light.jai";
#import, file "Texture.jai";
#import, file "Transform.jai";

#import, file "../libs/glfw/module.jai";

#import "Basic";
#import "GL";
#import "Math";
