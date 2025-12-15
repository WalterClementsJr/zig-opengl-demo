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

fn createShaderProgram() !glad.GLuint {
    const vertexSource: []const u8 =
        \\#version 410 core
        \\
        \\in vec3 vp;
        \\
        \\void main() {
        \\  gl_Position = vec4( vp, 1.0 );
        \\}
    ;
    const fragmentSource: []const u8 =
        \\#version 410 core
        \\
        \\out vec4 frag_colour;
        \\
        \\void main() {
        \\  frag_colour = vec4( 0.1, 0.0, 0.9, 1.0 );
        \\}
    ;
    const vertexShader = try initShader(vertexSource, "vertex", glad.GL_VERTEX_SHADER);
    const fragmentShader = try initShader(fragmentSource, "fragment", glad.GL_FRAGMENT_SHADER);

    defer glad.glDeleteShader(vertexShader);
    defer glad.glDeleteShader(fragmentShader);

    const shaderProgram: glad.GLuint = glad.glCreateProgram();
    glad.glAttachShader(shaderProgram, vertexShader);
    glad.glAttachShader(shaderProgram, fragmentShader);
    glad.glLinkProgram(shaderProgram);

    var ok: c.GLint = undefined;
    glad.glGetProgramiv(shaderProgram, c.GL_LINK_STATUS, &ok);

    if (ok == c.GL_TRUE) return shaderProgram;
    // or panic
    defer @panic("Program linking failed");

    var errorSize: c.GLint = undefined;
    glad.glGetProgramiv(shaderProgram, c.GL_INFO_LOG_LENGTH, &errorSize);

    if (errorSize == 0) {
        return shaderProgram;
    }
    var gpa = std.heap.page_allocator;
    const message = try gpa.alloc(u8, @intCast(errorSize));
    defer gpa.free(message);

    var written: c.GLsizei = 0;
    glad.glGetProgramInfoLog(shaderProgram, errorSize, &written, message.ptr);

    try stdout.interface.print("Error linking shader program: {s}\n", .{message});
    return shaderProgram;
}

fn initShader(source: []const u8, name: []const u8, shaderType: glad.GLenum) !c.GLuint {
    var ptr: [*c]const u8 = @ptrCast(source.ptr);
    const ptrPtr: [*c][*c]const u8 = @ptrCast(&ptr);
    var shaderLen: glad.GLint = @intCast(source.len);

    const shaderId: glad.GLuint = glad.glCreateShader(shaderType);
    glad.glShaderSource(shaderId, 1, ptrPtr, &shaderLen);
    glad.glCompileShader(shaderId);

    // get shader compilation result
    var ok: c.GLint = undefined;
    glad.glGetShaderiv(shaderId, c.GL_COMPILE_STATUS, &ok);

    if (ok == c.GL_TRUE) return shaderId;
    // or panic
    defer @panic("Shader failed compiling");

    var errorSize: c.GLint = undefined;
    glad.glGetShaderiv(shaderId, c.GL_INFO_LOG_LENGTH, &errorSize);

    if (errorSize == 0) {
        return shaderId;
    }
    var gpa = std.heap.page_allocator;
    const message = try gpa.alloc(u8, @intCast(errorSize));
    defer gpa.free(message);

    var written: c.GLsizei = 0;
    glad.glGetShaderInfoLog(shaderId, errorSize, &written, message.ptr);
    try stdout.interface.print("Error compiling shader {s}: {s}\n", .{name, message});
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

    const shaderProgram = try createShaderProgram();

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
