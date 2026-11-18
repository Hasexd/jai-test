
main :: () {
	glfwInitResult := glfwInit();

	if !glfwInitResult 
		print("GLFW initialization failed!\n");
	
	defer glfwTerminate();
	
	app: App;
	app.Width = 1080;
	app.Height = 720;
	app.CursorDisabled = true;

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

	shader: Shader;
	ShaderInit(*shader, "object.vert", "object.frag");

	CameraInit(*app.MainCamera, Vector3.{ 0.0, 0.0, 3.0 });

	vpBuffer := _CreateVPBuffer(0);
	vp := VP.{
		CameraGetViewMatrix(*app.MainCamera),
		CameraGetProjectionMatrix(*app.MainCamera, cast(float32) app.Width / cast(float32) app.Height)
	};

	model := Matrix4_Identity;

	lastX, lastY: float64;
	glfwGetCursorPos(app.Window, *lastX, *lastY);
	app.LastX = cast(float32) lastX;
	app.LastY = cast(float32) lastY;

	// to delete later
	vertices : [..]Vertex;
	array_add(*vertices, Vertex.{ Vector3.{ -0.5, -0.5, -0.5 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5, -0.5, -0.5 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5,  0.5, -0.5 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5,  0.5, -0.5 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5, -0.5,  0.5 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5, -0.5,  0.5 } });
	array_add(*vertices, Vertex.{ Vector3.{  0.5,  0.5,  0.5 } });
	array_add(*vertices, Vertex.{ Vector3.{ -0.5,  0.5,  0.5 } });

	cubeIndices := u32.[
		4, 5, 6,  4, 6, 7,
		1, 0, 3,  1, 3, 2,
		0, 4, 7,  0, 7, 3,
		5, 1, 2,  5, 2, 6,
		7, 6, 2,  7, 2, 3,
		0, 1, 5,  0, 5, 4
	];

	indices: [..]u32;
	for cubeIndices  array_add(*indices, it);

	vao: u32 = 0;
	glGenVertexArrays(1, *vao);
	glBindVertexArray(vao);

	vbo: u32 = 0;
	glGenBuffers(1, *vbo);

	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Vertex), vertices.data, GL_STATIC_DRAW);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), xx 0);
	glEnableVertexAttribArray(0);

	ebo: u32 = 0;
	glGenBuffers(1, *ebo);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.count * size_of(u32), indices.data, GL_STATIC_DRAW);

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

		// render (to delete later)
		ShaderUse(*shader);
		ShaderSetMat4(*shader, "model", model);
		glBindVertexArray(vao);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glDrawElements(GL_TRIANGLES, cast(u32) indices.count, GL_UNSIGNED_INT, xx 0);

		glfwSwapBuffers(app.Window);
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
}

Vertex :: struct
{
	Position: Vector3;
}

VP :: struct
{
	View: Matrix4;
	Projection: Matrix4;
}

#import, file "Shader.jai";
#import, file "Camera.jai";

#import, file "../libs/glfw/module.jai";

#import "Basic";
#import "GL";
#import "Math";
