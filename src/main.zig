const std = @import("std");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const glad = @cImport({
    @cInclude("glad/glad.h");
});
const builtin = @import("builtin");
const glmath = @import("./math3d.zig");
const Matrix = glmath.Matrix;
const Vector = glmath.Vector;
const shaderSrc = @import("./shader.zig");

var stdout = std.fs.File.stdout().writer(&.{});

pub const isDebug = if (builtin.mode == .ReleaseFast) c.GL_FALSE else c.GL_TRUE;

fn createShaderProgram() !glad.GLuint {
    const vertexShader = try initShader(shaderSrc.vertex1, "vertex", glad.GL_VERTEX_SHADER);
    const fragmentShader = try initShader(shaderSrc.fragment1, "fragmentColor", glad.GL_FRAGMENT_SHADER);

    defer glad.glDeleteShader(vertexShader);
    defer glad.glDeleteShader(fragmentShader);

    const shaderProgram: glad.GLuint = glad.glCreateProgram();
    glad.glAttachShader(shaderProgram, vertexShader);
    glad.glAttachShader(shaderProgram, fragmentShader);
    glad.glLinkProgram(shaderProgram);

    // debug
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
    try stdout.interface.print("Error compiling shader {s}: {s}\n", .{ name, message });
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
    const width = 800;
    const height = 600;

    const window: ?*c.GLFWwindow = c.glfwCreateWindow(width, height, "OpenGL sphere cube demo", null, null) orelse @panic("Cannot create GLFW window");
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    // init GLAD
    if (glad.gladLoadGLLoader(gladLoader) != c.GL_TRUE) {
        @panic("OpenGL extension linking failed");
    }

    c.glfwSetInputMode(window, c.GLFW_STICKY_KEYS, c.GL_TRUE);
    c.glFrontFace(c.GL_CW);
    const shaderProgram = try createShaderProgram();

    glad.glUseProgram(shaderProgram);
    // Put the shader program, and the VAO, in focus in OpenGL's state machine.
    const mat3 = glmath.Matrix(3, 3).initFlat(.{
        -1, -1, 0,
        1,  -1, 0,
        0,  4, 0,
    });

    var vbo: c.GLuint = 0;
    glad.glGenBuffers(1, &vbo);
    glad.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    glad.glBufferData(c.GL_ARRAY_BUFFER, @intCast(mat3.totalElements() * @sizeOf(f32)), &mat3.val[0][0], c.GL_STATIC_DRAW);

    var vao: c.GLuint = 0;
    glad.glGenVertexArrays(1, &vao);
    glad.glBindVertexArray(vao);
    glad.glEnableVertexAttribArray(0);
    glad.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    glad.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 0, null);

    // Model, view, Projection set up
    const projection = glmath.Matrix(4, 4).orthoProjection(-10, 10, -10, 10, 0, 100);

    const view = glmath.Matrix(4, 4).lookAt(
        Vector(3).init(.{ 4, 3, 3 }),
        Vector(3).init(.{ 0, 0, 0 }),
        Vector(3).init(.{ 0, 1, 0 }),
    );

    const model = Matrix(4, 4).identityMatrix;
    const mvp: Matrix(4, 4) = Matrix(4, 4).multiply(4, 4, 4, projection, Matrix(4, 4).multiply(4, 4, 4, view, model));

    const matrixId = glad.glGetUniformLocation(shaderProgram, "MVP");

    glad.glUniformMatrix4fv(matrixId, 1, c.GL_TRUE, &mvp.val[0][0]); // enable transpose

    while ((c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) != c.GLFW_PRESS) & (c.glfwWindowShouldClose(window) == 0)) {
        glad.glClearColor(0.2, 0.3, 0.3, 1.0);
        glad.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        glad.glUseProgram(shaderProgram);
        const greenValue = @sin(c.glfwGetTime()) + 0.5;

        const vertexColorLocation = glad.glGetUniformLocation(shaderProgram, "InFragColor");
        const colorVector = glmath.Vector(4).init(.{ @floatCast(greenValue), 0, 0, 1 });

        glad.glUseProgram(shaderProgram);
        glad.glUniform4fv(vertexColorLocation, 1, &colorVector.val[0]);

        glad.glBindVertexArray(vao);
        glad.glDrawArrays(glad.GL_TRIANGLE_STRIP, 0, 3);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    return 0;
}
