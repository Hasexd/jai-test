
// Dear ImGui backend for GLFW + OpenGL 3.3+ (core profile) - based on imgui_sdl_gl.jai.
//
// Usage (same shape as imgui_test.jai):
//     #load "imgui_glfw_gl.jai";          // GLFW must already be imported in your program
//
//     imgui_context := ImGui.CreateContext();
//     ImGui_ImplGlfw_Init(window);        // call AFTER you installed your own glfwSet*Callback functions,
//                                         // they are chained (see install_callbacks)
//     ImGui.StyleColorsClassic();
//
//     // every frame
//     ImGui_ImplGlfw_NewFrame(window);
//     ImGui.NewFrame();
//     ... widgets ...
//     ImGui.Render();
//     ... draw your scene ...
//     ImGui_ImplGlfw_RenderDrawLists(ImGui.GetDrawData());
//     glfwSwapBuffers(window);
//
//     // cleanup
//     ImGui_ImplGlfw_Shutdown();
//     ImGui.DestroyContext(imgui_context);
//
// io.WantCaptureMouse / io.WantCaptureKeyboard tell you when ImGui wants the input
// (e.g. skip your camera movement while they are true).

#import "Basic";
ImGui :: #import "ImGui";
#import "Math";
#import "GL";

// Data
g_Window: *GLFWwindow;
g_Time: float64 = 0.0;
g_MousePressed := bool.[false, false, false];
g_MouseWheel: float = 0.0;
g_FontTexture: GLuint = 0;
g_ShaderHandle: GLuint = 0;
g_VertHandle: GLuint = 0;
g_FragHandle: GLuint = 0;
g_AttribLocationTex: GLint = 0;
g_AttribLocationProjMtx: GLint = 0;
g_AttribLocationPosition: GLuint = 0;
g_AttribLocationUV: GLuint = 0;
g_AttribLocationColor: GLuint = 0;
g_VboHandle: GLuint = 0;
g_VaoHandle: GLuint = 0;
g_ElementsHandle: GLuint = 0;

g_CursorArrow: *GLFWcursor;
g_CursorTextInput: *GLFWcursor;
g_CursorHand: *GLFWcursor;
g_CursorResizeNS: *GLFWcursor;
g_CursorResizeEW: *GLFWcursor;
g_CursorResizeNESW: *GLFWcursor;
g_CursorResizeNWSE: *GLFWcursor;

// Callbacks that were installed before ImGui_ImplGlfw_Init (we call them first, then handle the event).
g_CallbacksInstalled := false;
g_PrevMouseButtonCallback: GLFWmousebuttonfun;
g_PrevScrollCallback: GLFWscrollfun;
g_PrevKeyCallback: GLFWkeyfun;
g_PrevCharCallback: GLFWcharfun;


// This is the main rendering function: call it after ImGui.Render().
// It saves / sets up / restores the OpenGL state, so it can run inside any OpenGL engine.
ImGui_ImplGlfw_RenderDrawLists :: (draw_data: *ImGui.ImDrawData) {
    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    io := ImGui.GetIO();
    fb_width := (io.DisplaySize.x * io.DisplayFramebufferScale.x);
    fb_height := (io.DisplaySize.y * io.DisplayFramebufferScale.y);
    if fb_width == 0 || fb_height == 0 return;
    draw_data.ScaleClipRects(draw_data, *io.DisplayFramebufferScale);

    // Backup GL state
    last_active_texture: GLenum;        glGetIntegerv(GL_ACTIVE_TEXTURE, xx *last_active_texture);
    last_program: GLuint;               glGetIntegerv(GL_CURRENT_PROGRAM, xx *last_program);
    last_texture: GLuint;               glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    last_sampler: GLuint;               glGetIntegerv(GL_SAMPLER_BINDING, xx *last_sampler);
    last_array_buffer: GLuint;          glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    last_element_array_buffer: GLuint;  glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, xx *last_element_array_buffer);
    last_vertex_array: GLuint;          glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);
    last_polygon_mode: [2]GLuint;       glGetIntegerv(GL_POLYGON_MODE, xx last_polygon_mode.data);
    last_viewport: [4]GLint;            glGetIntegerv(GL_VIEWPORT, last_viewport.data);
    last_scissor_box : [4]GLint;        glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box.data);
    last_blend_src_rgb: GLenum;         glGetIntegerv(GL_BLEND_SRC_RGB, xx *last_blend_src_rgb);
    last_blend_dst_rgb: GLenum;         glGetIntegerv(GL_BLEND_DST_RGB, xx *last_blend_dst_rgb);
    last_blend_src_alpha: GLenum;       glGetIntegerv(GL_BLEND_SRC_ALPHA, xx *last_blend_src_alpha);
    last_blend_dst_alpha: GLenum;       glGetIntegerv(GL_BLEND_DST_ALPHA, xx *last_blend_dst_alpha);
    last_blend_equation_rgb: GLenum;    glGetIntegerv(GL_BLEND_EQUATION_RGB, xx *last_blend_equation_rgb);
    last_blend_equation_alpha: GLenum;  glGetIntegerv(GL_BLEND_EQUATION_ALPHA, xx *last_blend_equation_alpha);
    last_enable_blend :=                glIsEnabled(GL_BLEND);
    last_enable_cull_face :=            glIsEnabled(GL_CULL_FACE);
    last_enable_depth_test :=           glIsEnabled(GL_DEPTH_TEST);
    last_enable_scissor_test :=         glIsEnabled(GL_SCISSOR_TEST);

    // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled, polygon fill
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_SCISSOR_TEST);
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    // Setup viewport, orthographic projection matrix
    glViewport(0, 0, xx fb_width, xx fb_height);

    ortho_projection := orthographic_projection_matrix(0, io.DisplaySize.x, io.DisplaySize.y, 0, 0, 1);
    ortho_projection = transpose(ortho_projection);

    glUseProgram(g_ShaderHandle);
    glUniform1i(g_AttribLocationTex, 0);
    glUniformMatrix4fv(g_AttribLocationProjMtx, 1, GL_FALSE, xx *ortho_projection);
    glBindVertexArray(g_VaoHandle);
    glBindSampler(0, 0); // Rely on combined texture/sampler state.

    // Render command lists
    for n: 0..draw_data.CmdListsCount-1 {
        cmd_list := draw_data.CmdLists[n];
        idx_buffer_offset : *ImGui.ImDrawIdx;

        glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
        glBufferData(GL_ARRAY_BUFFER, cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert), cmd_list.VtxBuffer.Data, GL_STREAM_DRAW);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ElementsHandle);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx), cmd_list.IdxBuffer.Data, GL_STREAM_DRAW);

        for cmd_i: 0..cmd_list.CmdBuffer.Size-1 {
            pcmd := *cmd_list.CmdBuffer.Data[cmd_i];
            if pcmd.UserCallback {
                pcmd.UserCallback(cmd_list, pcmd);
            }
            else {
                glBindTexture(GL_TEXTURE_2D, xx pcmd.TextureId);
                glScissor(xx pcmd.ClipRect.x, xx (fb_height - pcmd.ClipRect.w), xx (pcmd.ClipRect.z - pcmd.ClipRect.x), xx (pcmd.ClipRect.w - pcmd.ClipRect.y));

                glDrawElements(GL_TRIANGLES, pcmd.ElemCount, GL_UNSIGNED_SHORT, idx_buffer_offset);
            }
            idx_buffer_offset += pcmd.ElemCount;
        }
    }

    // Restore modified GL state
    glUseProgram(last_program);
    glBindTexture(GL_TEXTURE_2D, last_texture);
    glBindSampler(0, last_sampler);
    glActiveTexture(last_active_texture);
    glBindVertexArray(last_vertex_array);
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, last_element_array_buffer);
    glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
    glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
    if last_enable_blend        glEnable(GL_BLEND);         else glDisable(GL_BLEND);
    if last_enable_cull_face    glEnable(GL_CULL_FACE);     else glDisable(GL_CULL_FACE);
    if last_enable_depth_test   glEnable(GL_DEPTH_TEST);    else glDisable(GL_DEPTH_TEST);
    if last_enable_scissor_test glEnable(GL_SCISSOR_TEST);  else glDisable(GL_SCISSOR_TEST);
    glPolygonMode(GL_FRONT_AND_BACK, last_polygon_mode[0]);
    glViewport(last_viewport[0], last_viewport[1], xx last_viewport[2], xx last_viewport[3]);
    glScissor(last_scissor_box[0], last_scissor_box[1], xx last_scissor_box[2], xx last_scissor_box[3]);
}

ImGui_ImplGlfw_GetClipboardText :: (data: *void) -> *u8 #c_call {
    return xx glfwGetClipboardString(xx data);
}

ImGui_ImplGlfw_SetClipboardText :: (data: *void, text: *u8) #c_call {
    glfwSetClipboardString(xx data, xx text);
}

// GLFW callbacks. ImGui_ImplGlfw_Init installs them (and chains to the callbacks you had before),
// or call them yourself from your own callbacks if you pass install_callbacks = false.
ImGui_ImplGlfw_MouseButtonCallback :: (window: *GLFWwindow, button: s32, action: s32, mods: s32) #c_call {
    if g_PrevMouseButtonCallback g_PrevMouseButtonCallback(window, button, action, mods);

    if action == GLFW_PRESS && button >= 0 && button < 3  g_MousePressed[button] = true;
}

ImGui_ImplGlfw_ScrollCallback :: (window: *GLFWwindow, xoffset: float64, yoffset: float64) #c_call {
    if g_PrevScrollCallback g_PrevScrollCallback(window, xoffset, yoffset);

    g_MouseWheel += cast(float) yoffset;
}

ImGui_ImplGlfw_KeyCallback :: (window: *GLFWwindow, key: s32, scancode: s32, action: s32, mods: s32) #c_call {
    if g_PrevKeyCallback g_PrevKeyCallback(window, key, scancode, action, mods);

    io := ImGui.GetIO();

    if key >= 0 && key < io.KeysDown.count {
        if action == GLFW_PRESS   io.KeysDown[key] = true;
        if action == GLFW_RELEASE io.KeysDown[key] = false;
    }

    // Modifiers are not reliable across the window boundary, so derive them from the key state.
    io.KeyCtrl  = io.KeysDown[GLFW_KEY_LEFT_CONTROL] || io.KeysDown[GLFW_KEY_RIGHT_CONTROL];
    io.KeyShift = io.KeysDown[GLFW_KEY_LEFT_SHIFT]   || io.KeysDown[GLFW_KEY_RIGHT_SHIFT];
    io.KeyAlt   = io.KeysDown[GLFW_KEY_LEFT_ALT]     || io.KeysDown[GLFW_KEY_RIGHT_ALT];
    io.KeySuper = io.KeysDown[GLFW_KEY_LEFT_SUPER]   || io.KeysDown[GLFW_KEY_RIGHT_SUPER];
}

ImGui_ImplGlfw_CharCallback :: (window: *GLFWwindow, c: u32) #c_call {
    if g_PrevCharCallback g_PrevCharCallback(window, c);

    // GLFW gives a Unicode code point, ImGui wants UTF-8
    buffer: [5] u8;
    if c < 0x80 {
        buffer[0] = xx c;
    }
    else if c < 0x800 {
        buffer[0] = xx (0xC0 | (c >> 6));
        buffer[1] = xx (0x80 | (c & 0x3F));
    }
    else if c < 0x10000 {
        buffer[0] = xx (0xE0 | (c >> 12));
        buffer[1] = xx (0x80 | ((c >> 6) & 0x3F));
        buffer[2] = xx (0x80 | (c & 0x3F));
    }
    else {
        buffer[0] = xx (0xF0 | (c >> 18));
        buffer[1] = xx (0x80 | ((c >> 12) & 0x3F));
        buffer[2] = xx (0x80 | ((c >> 6) & 0x3F));
        buffer[3] = xx (0x80 | (c & 0x3F));
    }

    io := ImGui.GetIO();
    io.AddInputCharactersUTF8(io, xx *buffer[0]);
}

ImGui_ImplGlfw_CreateFontsTexture :: () -> bool {
    // Build texture atlas
    io := ImGui.GetIO();
    pixels: *u8;
    width, height: s32;
    bpp: s32;
    io.Fonts.GetTexDataAsAlpha8(io.Fonts, *pixels, *width, *height, *bpp);

    // Upload texture to graphics system
    last_texture: GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);

    glGenTextures(1, *g_FontTexture);
    glBindTexture(GL_TEXTURE_2D, g_FontTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1); // single channel rows are not 4-byte aligned in general
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, xx width, xx height, 0, GL_RED, GL_UNSIGNED_BYTE, pixels);

    // Store our identifier
    io.Fonts.TexID = xx g_FontTexture;

    // Restore state
    glBindTexture(GL_TEXTURE_2D, last_texture);

    return true;
}

_ImGui_CheckShader :: (handle: GLuint, what: string) {
    success: GLint;
    glGetShaderiv(handle, GL_COMPILE_STATUS, *success);
    if success return;

    log: [512] u8;
    length: GLsizei;
    glGetShaderInfoLog(handle, 512, *length, xx *log[0]);

    message: string;
    message.count = length;
    message.data = *log[0];
    print("ImGui % shader error: %\n", what, message);
}

ImGui_ImplGlfw_CreateDeviceObjects :: () -> bool {
    // Backup GL state
    last_texture, last_array_buffer, last_vertex_array: GLuint;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *last_texture);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, xx *last_array_buffer);
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, xx *last_vertex_array);

    vertex_shader := #string END
        #version 330
        uniform mat4 ProjMtx;
        in vec2 Position;
        in vec2 UV;
        in vec4 Color;
        out vec2 Frag_UV;
        out vec4 Frag_Color;
        void main() {
           Frag_UV = UV;
           Frag_Color = Color;
           gl_Position = ProjMtx * vec4(Position.xy,0,1);
        }
    END

    fragment_shader := #string END
        #version 330
        uniform sampler2D Texture;
        in vec2 Frag_UV;
        in vec4 Frag_Color;
        out vec4 Out_Color;
        void main() {
           Out_Color = Frag_Color * texture( Texture, Frag_UV.st).r;
        }
    END

    g_ShaderHandle = glCreateProgram();
    g_VertHandle = glCreateShader(GL_VERTEX_SHADER);
    g_FragHandle = glCreateShader(GL_FRAGMENT_SHADER);
    _glShaderSource(g_VertHandle, vertex_shader);
    _glShaderSource(g_FragHandle, fragment_shader);
    glCompileShader(g_VertHandle);
    _ImGui_CheckShader(g_VertHandle, "vertex");
    glCompileShader(g_FragHandle);
    _ImGui_CheckShader(g_FragHandle, "fragment");
    glAttachShader(g_ShaderHandle, g_VertHandle);
    glAttachShader(g_ShaderHandle, g_FragHandle);
    glLinkProgram(g_ShaderHandle);

    g_AttribLocationTex = glGetUniformLocation(g_ShaderHandle, "Texture");
    g_AttribLocationProjMtx = glGetUniformLocation(g_ShaderHandle, "ProjMtx");
    g_AttribLocationPosition = xx glGetAttribLocation(g_ShaderHandle, "Position");
    g_AttribLocationUV = xx glGetAttribLocation(g_ShaderHandle, "UV");
    g_AttribLocationColor = xx glGetAttribLocation(g_ShaderHandle, "Color");

    glGenBuffers(1, *g_VboHandle);
    glGenBuffers(1, *g_ElementsHandle);

    glGenVertexArrays(1, *g_VaoHandle);
    glBindVertexArray(g_VaoHandle);
    glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
    glEnableVertexAttribArray(g_AttribLocationPosition);
    glEnableVertexAttribArray(xx g_AttribLocationUV);
    glEnableVertexAttribArray(xx g_AttribLocationColor);

    // ImDrawVert :: struct {
    //    pos: ImVec2;       // 0
    //    uv: ImVec2;        // 8
    //    col: s32;          // 16
    // }
    glVertexAttribPointer(g_AttribLocationPosition, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 0);
    glVertexAttribPointer(g_AttribLocationUV, 2, GL_FLOAT, GL_FALSE, size_of(ImGui.ImDrawVert), xx 8);
    glVertexAttribPointer(g_AttribLocationColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, size_of(ImGui.ImDrawVert), xx 16);

    ImGui_ImplGlfw_CreateFontsTexture();

    // Restore modified GL state
    glBindTexture(GL_TEXTURE_2D, last_texture);
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer);
    glBindVertexArray(last_vertex_array);

    return true;
}

ImGui_ImplGlfw_InvalidateDeviceObjects :: () {
    if g_VaoHandle { glDeleteVertexArrays(1, *g_VaoHandle); g_VaoHandle = 0; }
    if g_VboHandle { glDeleteBuffers(1, *g_VboHandle); g_VboHandle = 0; }
    if g_ElementsHandle { glDeleteBuffers(1, *g_ElementsHandle); g_ElementsHandle = 0; }

    if g_ShaderHandle && g_VertHandle glDetachShader(g_ShaderHandle, g_VertHandle);
    if g_ShaderHandle && g_FragHandle glDetachShader(g_ShaderHandle, g_FragHandle);
    if g_VertHandle { glDeleteShader(g_VertHandle); g_VertHandle = 0; }
    if g_FragHandle { glDeleteShader(g_FragHandle); g_FragHandle = 0; }
    if g_ShaderHandle { glDeleteProgram(g_ShaderHandle); g_ShaderHandle = 0; }

    if g_FontTexture {
        glDeleteTextures(1, *g_FontTexture);
        ImGui.GetIO().Fonts.TexID = null;
        g_FontTexture = 0;
    }
}

// install_callbacks: ImGui sets the GLFW mouse button / scroll / key / char callbacks and calls the ones
// that were set before (so call this after your own glfwSet*Callback calls). If you pass false,
// forward the events yourself from your callbacks to ImGui_ImplGlfw_{MouseButton,Scroll,Key,Char}Callback.
ImGui_ImplGlfw_Init :: (window: *GLFWwindow, install_callbacks := true) -> bool {
    g_Window = window;
    g_Time = 0.0;

    io := ImGui.GetIO();
    io.KeyMap[ImGui.Key.Tab] = xx GLFW_KEY_TAB;                 // Keyboard mapping. ImGui will use those indices to peek into the io.KeysDown[] array.
    io.KeyMap[ImGui.Key.LeftArrow] = xx GLFW_KEY_LEFT;
    io.KeyMap[ImGui.Key.RightArrow] = xx GLFW_KEY_RIGHT;
    io.KeyMap[ImGui.Key.UpArrow] = xx GLFW_KEY_UP;
    io.KeyMap[ImGui.Key.DownArrow] = xx GLFW_KEY_DOWN;
    io.KeyMap[ImGui.Key.PageUp] = xx GLFW_KEY_PAGE_UP;
    io.KeyMap[ImGui.Key.PageDown] = xx GLFW_KEY_PAGE_DOWN;
    io.KeyMap[ImGui.Key.Home] = xx GLFW_KEY_HOME;
    io.KeyMap[ImGui.Key.End] = xx GLFW_KEY_END;
    io.KeyMap[ImGui.Key.Delete] = xx GLFW_KEY_DELETE;
    io.KeyMap[ImGui.Key.Backspace] = xx GLFW_KEY_BACKSPACE;
    io.KeyMap[ImGui.Key.Enter] = xx GLFW_KEY_ENTER;
    io.KeyMap[ImGui.Key.Escape] = xx GLFW_KEY_ESCAPE;
    io.KeyMap[ImGui.Key.A] = xx GLFW_KEY_A;
    io.KeyMap[ImGui.Key.C] = xx GLFW_KEY_C;
    io.KeyMap[ImGui.Key.V] = xx GLFW_KEY_V;
    io.KeyMap[ImGui.Key.X] = xx GLFW_KEY_X;
    io.KeyMap[ImGui.Key.Y] = xx GLFW_KEY_Y;
    io.KeyMap[ImGui.Key.Z] = xx GLFW_KEY_Z;

    io.SetClipboardTextFn = ImGui_ImplGlfw_SetClipboardText;
    io.GetClipboardTextFn = ImGui_ImplGlfw_GetClipboardText;
    io.ClipboardUserData = xx window;

    g_CursorArrow = glfwCreateStandardCursor(GLFW_ARROW_CURSOR);
    g_CursorTextInput = glfwCreateStandardCursor(GLFW_IBEAM_CURSOR);
    g_CursorHand = glfwCreateStandardCursor(GLFW_HAND_CURSOR);
    g_CursorResizeNS = glfwCreateStandardCursor(GLFW_VRESIZE_CURSOR);
    g_CursorResizeEW = glfwCreateStandardCursor(GLFW_HRESIZE_CURSOR);

    // diagonal resize cursors exist only in GLFW 3.4+
    nesw_shape: s32 = GLFW_ARROW_CURSOR;
    nwse_shape: s32 = GLFW_ARROW_CURSOR;
    #if #exists(GLFW_RESIZE_NESW_CURSOR) {
        nesw_shape = GLFW_RESIZE_NESW_CURSOR;
        nwse_shape = GLFW_RESIZE_NWSE_CURSOR;
    }
    g_CursorResizeNESW = glfwCreateStandardCursor(nesw_shape);
    g_CursorResizeNWSE = glfwCreateStandardCursor(nwse_shape);

    g_CallbacksInstalled = install_callbacks;
    if install_callbacks {
        g_PrevMouseButtonCallback = glfwSetMouseButtonCallback(window, ImGui_ImplGlfw_MouseButtonCallback);
        g_PrevScrollCallback = glfwSetScrollCallback(window, ImGui_ImplGlfw_ScrollCallback);
        g_PrevKeyCallback = glfwSetKeyCallback(window, ImGui_ImplGlfw_KeyCallback);
        g_PrevCharCallback = glfwSetCharCallback(window, ImGui_ImplGlfw_CharCallback);
    }

    return true;
}

ImGui_ImplGlfw_Shutdown :: () {
    if g_CallbacksInstalled {
        glfwSetMouseButtonCallback(g_Window, g_PrevMouseButtonCallback);
        glfwSetScrollCallback(g_Window, g_PrevScrollCallback);
        glfwSetKeyCallback(g_Window, g_PrevKeyCallback);
        glfwSetCharCallback(g_Window, g_PrevCharCallback);
        g_CallbacksInstalled = false;
    }

    glfwDestroyCursor(g_CursorArrow);
    glfwDestroyCursor(g_CursorTextInput);
    glfwDestroyCursor(g_CursorHand);
    glfwDestroyCursor(g_CursorResizeNS);
    glfwDestroyCursor(g_CursorResizeEW);
    glfwDestroyCursor(g_CursorResizeNESW);
    glfwDestroyCursor(g_CursorResizeNWSE);

    g_CursorArrow = null;
    g_CursorTextInput = null;
    g_CursorHand = null;
    g_CursorResizeNS = null;
    g_CursorResizeEW = null;
    g_CursorResizeNESW = null;
    g_CursorResizeNWSE = null;

    ImGui_ImplGlfw_InvalidateDeviceObjects();
}

// Follows the mouse cursor shape ImGui asks for. Does nothing while the cursor is disabled (camera mode),
// so it does not fight with your own GLFW_CURSOR_DISABLED handling.
ImGui_ImplGlfw_UpdateMouseCursor :: (window: *GLFWwindow) {
    if glfwGetInputMode(window, GLFW_CURSOR) == GLFW_CURSOR_DISABLED return;

    io := ImGui.GetIO();
    if io.MouseDrawCursor {
        // ImGui draws the cursor itself - hide the OS one
        glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_HIDDEN);
        return;
    }

    cursor := g_CursorArrow;
    if ImGui.GetMouseCursor() == {
        case .Arrow;         cursor = g_CursorArrow;
        case .TextInput;     cursor = g_CursorTextInput;
        case .Hand;          cursor = g_CursorHand;
        case .ResizeNS;      cursor = g_CursorResizeNS;
        case .ResizeEW;      cursor = g_CursorResizeEW;
        case .ResizeNESW;    cursor = g_CursorResizeNESW;
        case .ResizeNWSE;    cursor = g_CursorResizeNWSE;
    }

    glfwSetCursor(window, cursor);
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
}

// Call once per frame before ImGui.NewFrame().
ImGui_ImplGlfw_NewFrame :: (window: *GLFWwindow) {
    if !g_FontTexture ImGui_ImplGlfw_CreateDeviceObjects();

    io := ImGui.GetIO();

    // Setup display size (every frame to accommodate for window resizing)
    w, h: s32;
    display_w, display_h: s32;
    glfwGetWindowSize(window, *w, *h);
    glfwGetFramebufferSize(window, *display_w, *display_h);
    io.DisplaySize = .{xx w, xx h};
    if w > 0 && h > 0 {
        io.DisplayFramebufferScale = .{cast(float) display_w / w, cast(float) display_h / h};
    } else {
        io.DisplayFramebufferScale = .{1.0, 1.0};
    }

    // Setup time step
    current_time := glfwGetTime();
    if g_Time > 0.0 {
        io.DeltaTime = cast(float)(current_time - g_Time);
    } else {
        io.DeltaTime = (1.0/60.0);
    }
    if io.DeltaTime <= 0.0  io.DeltaTime = (1.0/1000.0); // ImGui requires a positive delta time
    g_Time = current_time;

    // Setup inputs
    // (keyboard keys, characters and the mouse wheel were collected by the GLFW callbacks)
    cursor_disabled := glfwGetInputMode(window, GLFW_CURSOR) == GLFW_CURSOR_DISABLED;
    if glfwGetWindowAttrib(window, GLFW_FOCUSED) != 0 && !cursor_disabled {
        mx, my: float64;
        glfwGetCursorPos(window, *mx, *my);
        io.MousePos = .{cast(float) mx, cast(float) my};   // Mouse position, in screen coordinates
    } else {
        io.MousePos = .{-FLOAT32_MAX, -FLOAT32_MAX};       // no cursor for ImGui (unfocused or captured by the camera)
    }

    // If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
    for i: 0..2 {
        io.MouseDown[i] = g_MousePressed[i] || glfwGetMouseButton(window, xx i) != 0;
        g_MousePressed[i] = false;
    }

    io.MouseWheel = g_MouseWheel;
    g_MouseWheel = 0.0;

    ImGui_ImplGlfw_UpdateMouseCursor(window);
}
