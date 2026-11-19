
main :: () {
	glfwInitResult := glfwInit();

	if !glfwInitResult 
		print("GLFW initialization failed!\n");
	
	defer glfwTerminate();
	
	app: App;
	app.Width = 1080;
	app.Height = 720;
	app.CursorDisabled = true;
	app.DirLightOn = true;

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

	// sun
	dirLight := MakeDirLight(Vector3.{ -0.2, -1.0, -0.3 }, Vector3.{ 1.0, 1.0, 1.0 });

	model: Model;
	ModelInit(*model, "assasin.fbx");

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

		ShaderUse(*objectShader);
		ShaderSetMat4(*objectShader, "model", Matrix4_Identity);
		ShaderSetVec3(*objectShader, "viewPos", app.MainCamera.Position);
		ShaderSetDirLight(*objectShader, *dirLight);
		
		ModelDraw(*model, *objectShader);

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

	if key == GLFW_KEY_G && action == GLFW_PRESS app.DirLightOn = !app.DirLightOn;
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
	DirLightOn: bool;
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
#import, file "Model.jai";

#import, file "../libs/glfw/module.jai";

#import "Basic";
#import "GL";
#import "Math";
