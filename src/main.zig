const std = @import("std");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const glad = @cImport({
    @cInclude("glad/glad.h");
});
const builtin = @import("builtin");

var stdout = std.fs.File.stdout().writer(&.{});

pub const isDebug = if (builtin.mode == .ReleaseFast) c.GL_FALSE else c.GL_TRUE;

fn createShaderProgram() glad.GLuint {
    const vertexShader: []const u8 =
        \\#version 410 core
        \\
        \\in vec3 vp;
        \\
        \\void main() {
        \\  gl_Position = vec4( vp, 1.0 );
        \\}
    ;
    const fragmentShader: []const u8 =
        \\#version 410 core
        \\
        \\out vec4 frag_colour;
        \\
        \\void main() {
        \\  frag_colour = vec4( 0.5, 0.0, 0.5, 1.0 );
        \\}
    ;
    var vertexPtr: [*c]const u8 = @ptrCast(vertexShader.ptr);
    const vertexPtrPtr: [*c][*c]const u8 = @ptrCast(&vertexPtr);
    var vertexShaderLen: glad.GLint = @intCast(vertexShader.len);

    const vs: glad.GLuint = glad.glCreateShader(c.GL_VERTEX_SHADER);
    glad.glShaderSource(vs, 1, vertexPtrPtr, &vertexShaderLen);
    glad.glCompileShader(vs);


    var fragPtr: [*c]const u8 = @ptrCast(fragmentShader.ptr);
    const fragPtrPtr: [*c][*c]const u8 = @ptrCast(&fragPtr);
    var fragShaderLen: glad.GLint = @intCast(fragmentShader.len);

    const fs: glad.GLuint = glad.glCreateShader(glad.GL_FRAGMENT_SHADER);
    glad.glShaderSource(fs, 1, fragPtrPtr, &fragShaderLen);
    glad.glCompileShader(fs);

    const shader_program: glad.GLuint = glad.glCreateProgram();
    glad.glAttachShader(shader_program, fs);
    glad.glAttachShader(shader_program, vs);
    glad.glLinkProgram(shader_program);

    return shader_program;
}

fn gladLoader(name: [*c]const u8) callconv(.c) ?*anyopaque {
    return @constCast(c.glfwGetProcAddress(name));
}

pub fn main() !u8 {
    if (c.glfwInit() != c.GL_TRUE) {
        @panic("ERROR: could not start GLFW3.");
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 6);
    c.glfwWindowHint(c.GLFW_OPENGL_DEBUG_CONTEXT, isDebug);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GL_FALSE);

    const window: ?*c.GLFWwindow = c.glfwCreateWindow(800, 600, "OpenGL sphere cube demo", null, null) orelse @panic("Cannot create GLFW window");
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    // init GLAD
    if (glad.gladLoadGLLoader(gladLoader) != c.GL_TRUE) {
        @panic("GLAD failed");
    }

    c.glfwSetInputMode(window, c.GLFW_STICKY_KEYS, c.GL_TRUE);

    const shaderProgram = createShaderProgram();

    while ((c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) != c.GLFW_PRESS) & (c.glfwWindowShouldClose(window) == 0)) {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        // Put the shader program, and the VAO, in focus in OpenGL's state machine.
        const points = [_]f32{
            0.0, 0.5, 0.0, // x,y,z o irst point.
            0.5, -0.5, 0.0, // x,y,z o second point.
            -0.5, -0.5, 0.0, // x,y,z o third point.
        };
        var vbo: c.GLuint = 0;
        glad.glGenBuffers(1, &vbo);
        glad.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        glad.glBufferData(c.GL_ARRAY_BUFFER, points.len * @sizeOf(f32), &points, c.GL_STATIC_DRAW);

        var vao: c.GLuint = 0;
        glad.glGenVertexArrays(1, &vao);
        glad.glBindVertexArray(vao);
        glad.glEnableVertexAttribArray(0);
        glad.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        glad.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 0, null);
        glad.glUseProgram(shaderProgram);
        glad.glBindVertexArray(vao);

        // Draw points 0-3 from the currently bound VAO with current in-use shader.
        glad.glDrawArrays(glad.GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    return 0;
}
