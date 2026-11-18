
main :: () {
	glfwInitResult := glfwInit();

	if !glfwInitResult 
		print("GLFW initialization failed!\n");
	
	defer glfwTerminate();
	
	app: App;
	app.Width = 1080;
	app.Height = 720;

	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 6);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

	app.Window = glfwCreateWindow(xx app.Width, xx app.Height, "Window", null, null);
	defer glfwDestroyWindow(app.Window);

	glfwMakeContextCurrent(app.Window);

	gl_load(*gl, glfwGetProcAddress.(*void));

	glfwSetWindowUserPointer(app.Window, *app);
	glfwSetFramebufferSizeCallback(app.Window, FramebufferCallback);

	glViewport(0, 0, app.Width, app.Height);

	shader: Shader;
	ShaderInit(*shader, "object.vert", "object.frag");

	now := glfwGetTime();
	last := glfwGetTime();
	deltaTime: float32 = 0.0;

	while !glfwWindowShouldClose(app.Window) 
	{
		now = glfwGetTime();
		deltaTime = cast(float32) (now - last) / 1000.0;
		last = now;

		glfwPollEvents();

		glClear(GL_COLOR_BUFFER_BIT);
		glClearColor(0.0, 0.0, 0.0, 1.0);

		glfwSwapBuffers(app.Window);
	}
}

FramebufferCallback :: (window: *GLFWwindow, width: s32, height: s32) #c_call
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
}

Vertex :: struct
{
	Position: Vector3;
}

#import, file "Shader.jai";

#import, file "../libs/glfw/module.jai";

#import "Basic";
#import "GL";
#import "Math";
