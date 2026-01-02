const std = @import("std");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const math = std.math;
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

    var state = ProgramState{
        .WIDTH = 800,
        .HEIGHT = 600,
        .FPS = 30,
        .lastTime = std.time.milliTimestamp(),
        .mouseSpeed = 0.005,
        .moveSpeed = 3,
        .position = Vector(3).init(.{ 0, 0, 5 }),
        // horizontal angle : toward -Z
        .horizontalAngle = 3.14,
        // vertical angle : 0, look at the horizon
        .verticalAngle = 0.0,
        // Initial Field of View
        // const initialFoV: f32 = 45.0;
    };

    const mainTitle = "OpenGL sphere/cube demo";
    const window: ?*c.GLFWwindow = c.glfwCreateWindow(@intCast(state.WIDTH), @intCast(state.HEIGHT), mainTitle, null, null) orelse @panic("Cannot create GLFW window");
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    state.window = window;

    // init GLAD
    if (glad.gladLoadGLLoader(gladLoader) != c.GL_TRUE) {
        @panic("OpenGL extension linking failed");
    }

    c.glfwSetInputMode(window, c.GLFW_STICKY_KEYS, c.GL_TRUE);
    c.glFrontFace(c.GL_CW);
    const shaderProgram = try createShaderProgram();

    glad.glUseProgram(shaderProgram);
    // Put the shader program, and the VAO, in focus in OpenGL's state machine.
    var triangle = Matrix(3, 3).initFlat(.{
        -2, -2, 10,
        2,  -2, 10,
        0,  2,  10,
    });

    var cube = Matrix(36, 3).initFlat(.{
        -1, -1, -1, // triangle 1 : begin
        -1, -1, 1,
        -1, 1, 1, // triangle 1 : end
        1,  1,  -1, // triangle 2 : begin
        -1, -1, -1,
        -1, 1,  -1, // triangle 2 : end
        1,  -1, 1,
        -1, -1, -1,
        1,  -1, -1,
        1,  1,  -1,
        1,  -1, -1,
        -1, -1, -1,
        -1, -1, -1,
        -1, 1,  1,
        -1, 1,  -1,
        1,  -1, 1,
        -1, -1, 1,
        -1, -1, -1,
        -1, 1,  1,
        -1, -1, 1,
        1,  -1, 1,
        1,  1,  1,
        1,  -1, -1,
        1,  1,  -1,
        1,  -1, -1,
        1,  1,  1,
        1,  -1, 1,
        1,  1,  1,
        1,  1,  -1,
        -1, 1,  -1,
        1,  1,  1,
        -1, 1,  -1,
        -1, 1,  1,
        1,  1,  1,
        -1, 1,  1,
        1,  -1, 1,
    });
    const g_color_buffer_data = [_]f32{
        0.583, 0.771, 0.014,
        0.609, 0.115, 0.436,
        0.327, 0.483, 0.844,
        0.822, 0.569, 0.201,
        0.435, 0.602, 0.223,
        0.310, 0.747, 0.185,
        0.597, 0.770, 0.761,
        0.559, 0.436, 0.730,
        0.359, 0.583, 0.152,
        0.483, 0.596, 0.789,
        0.559, 0.861, 0.639,
        0.195, 0.548, 0.859,
        0.014, 0.184, 0.576,
        0.771, 0.328, 0.970,
        0.406, 0.615, 0.116,
        0.676, 0.977, 0.133,
        0.971, 0.572, 0.833,
        0.140, 0.616, 0.489,
        0.997, 0.513, 0.064,
        0.945, 0.719, 0.592,
        0.543, 0.021, 0.978,
        0.279, 0.317, 0.505,
        0.167, 0.620, 0.077,
        0.347, 0.857, 0.137,
        0.055, 0.953, 0.042,
        0.714, 0.505, 0.345,
        0.783, 0.290, 0.734,
        0.722, 0.645, 0.174,
        0.302, 0.455, 0.848,
        0.225, 0.587, 0.040,
        0.517, 0.713, 0.338,
        0.053, 0.959, 0.120,
        0.393, 0.621, 0.362,
        0.673, 0.211, 0.457,
        0.820, 0.883, 0.371,
        0.982, 0.099, 0.879,
    };

    // vertex init
    var vertexArrayId: c.GLuint = undefined;
    glad.glGenVertexArrays(1, &vertexArrayId);
    glad.glBindVertexArray(vertexArrayId);

    // buffers
    var triangleBuffer: c.GLuint = 0;
    glad.glGenBuffers(1, &triangleBuffer);
    glad.glBindBuffer(c.GL_ARRAY_BUFFER, triangleBuffer);
    glad.glBufferData(c.GL_ARRAY_BUFFER, @intCast(triangle.totalElements() * @sizeOf(f32)), &triangle.val[0], c.GL_STATIC_DRAW);

    var shapeBuffer: c.GLuint = 0;
    glad.glGenBuffers(1, &shapeBuffer);
    glad.glBindBuffer(c.GL_ARRAY_BUFFER, shapeBuffer);
    glad.glBufferData(c.GL_ARRAY_BUFFER, @intCast(cube.totalElements() * @sizeOf(f32)), &cube.val[0][0], c.GL_STATIC_DRAW);

    var colorbuffer: c.GLuint = 0;
    glad.glGenBuffers(1, &colorbuffer);
    glad.glBindBuffer(c.GL_ARRAY_BUFFER, colorbuffer);
    glad.glBufferData(c.GL_ARRAY_BUFFER, @intCast(@sizeOf(f32) * g_color_buffer_data.len), &g_color_buffer_data[0], c.GL_STATIC_DRAW);

    c.glEnable(c.GL_DEPTH_TEST);
    c.glDepthFunc(c.GL_LESS);
    c.glEnable(c.GL_CULL_FACE);

    const mvpId = glad.glGetUniformLocation(shaderProgram, "MVP");

    // Model, view, Projection set up
    const projection = glmath.Matrix(4, 4).orthoProjection(-10, 10, -10, 10, 0, 100);
    const model = Matrix(4, 4).identityMatrix;
    var view: Matrix(4, 4) = undefined;

    var lastTime: f64 = 0;
    var currentTime: f64 = 0;
    var nbFrames: usize = 0;
    // render loop
    while ((c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) != c.GLFW_PRESS) & (c.glfwWindowShouldClose(window) == 0)) {
        glad.glClearColor(0, 0.1, 0.1, 1);
        glad.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        glad.glUseProgram(shaderProgram);

        // fps counting
        // Measure speed
        currentTime = c.glfwGetTime();
        nbFrames += 1;
        const timePerFrame = 1000.0 / @as(f32, @floatFromInt(nbFrames));
        const timeDiff = currentTime - lastTime;
        if (timeDiff >= 1.0 / @as(f32, @floatFromInt(state.FPS))) {
            var title: [70]u8 = undefined;
            const fps: f64 = 1.0 / timeDiff * @as(f64, @floatFromInt(nbFrames));
            const out = try std.fmt.bufPrint(&title, "{s}: {d} fps | {d} ms/frame", .{ mainTitle, fps, timePerFrame });
            title[out.len] = 0;
            c.glfwSetWindowTitle(state.window, &title);
            nbFrames += 1;
            lastTime = currentTime;
            nbFrames = 0;
            computeMatricesFromInput(&state, &view);
        }
        const mvp: Matrix(4, 4) = Matrix(4, 4).multiply(4, 4, 4, projection, Matrix(4, 4).multiply(4, 4, 4, view, model));
        glad.glUniformMatrix4fv(mvpId, 1, c.GL_TRUE, &mvp.val[0][0]); // enable transpose

        // 1st attribute: vertex
        glad.glEnableVertexAttribArray(0);
        glad.glBindBuffer(c.GL_ARRAY_BUFFER, shapeBuffer);
        glad.glBindVertexArray(shapeBuffer);
        glad.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 0, null);

        // 2nd attribute: color
        glad.glEnableVertexAttribArray(1);
        glad.glBindBuffer(c.GL_ARRAY_BUFFER, colorbuffer);
        glad.glVertexAttribPointer(
            1, // attribute. No particular reason for 1, but must match the layout in the shader.
            3, // size
            c.GL_FLOAT, // type
            c.GL_FALSE, // normalized?
            0, // stride
            null, // array buffer offset
        );

        // draw
        glad.glDrawArrays(glad.GL_TRIANGLES, 0, 12 * 3);

        // 1st attribute for drawing triangle
        glad.glEnableVertexAttribArray(0);
        glad.glBindBuffer(c.GL_ARRAY_BUFFER, triangleBuffer);
        glad.glBindVertexArray(triangleBuffer);
        glad.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 0, null);

        glad.glDrawArrays(glad.GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
    // Cleanup VBO and shader
    glad.glDeleteBuffers(1, &shapeBuffer);
    glad.glDeleteBuffers(1, &colorbuffer);
    glad.glDeleteProgram(shaderProgram);
    glad.glDeleteVertexArrays(1, &vertexArrayId);

    return 0;
}

const ProgramState = struct {
    WIDTH: usize,
    HEIGHT: usize,
    FPS: usize,
    lastTime: i64,
    window: ?*c.GLFWwindow = undefined,
    mouseSpeed: f32,
    moveSpeed: f32,
    position: Vector(3) = undefined,
    horizontalAngle: f32 = undefined,
    verticalAngle: f32 = undefined,
};

fn computeMatricesFromInput(state: *ProgramState, view: *Matrix(4, 4)) void {
    var mouseX: f64 = undefined;
    var mouseY: f64 = undefined;

    const currentTime = std.time.milliTimestamp();
    const deltaTime = @as(f32, @floatFromInt(currentTime - state.lastTime)) / 1000;

    // get mouse pos
    c.glfwGetCursorPos(state.window, &mouseX, &mouseY);
    std.debug.print("x, y: ({d}, {d})\n", .{ mouseX, mouseY });
    c.glfwSetCursorPos(state.window, @floatFromInt(state.WIDTH / 2), @floatFromInt(state.HEIGHT / 2));

    state.horizontalAngle += state.mouseSpeed * deltaTime * (@as(f32, @floatFromInt(state.WIDTH)) / 2 - @as(f32, @floatCast(mouseX)));
    state.verticalAngle += state.mouseSpeed * deltaTime * (@as(f32, @floatFromInt(state.HEIGHT)) / 2 - @as(f32, @floatCast(mouseY)));

    // const FoV = initialFoV - 5 * c.glfwGetMouseWheel();
    var direction = Vector(3).init(.{ math.cos(state.verticalAngle) * math.sin(state.horizontalAngle), math.sin(state.verticalAngle), math.cos(state.verticalAngle) * math.cos(state.horizontalAngle) });

    var right = Vector(3).init(.{
        math.sin(state.horizontalAngle - 3.14 / 2.0),
        0,
        math.cos(state.horizontalAngle - 3.14 / 2.0),
    });
    const up = right.cross(direction);

    const vectorOp = glmath.VectorOp;

    const isUp: bool = (c.glfwGetKey(state.window, c.GLFW_KEY_UP) == c.GLFW_PRESS) or c.glfwGetKey(state.window, c.GLFW_KEY_W) == c.GLFW_PRESS;
    const isDown: bool = (c.glfwGetKey(state.window, c.GLFW_KEY_DOWN) == c.GLFW_PRESS) or (c.glfwGetKey(state.window, c.GLFW_KEY_S) == c.GLFW_PRESS);
    const isLeft: bool = (c.glfwGetKey(state.window, c.GLFW_KEY_LEFT) == c.GLFW_PRESS) or (c.glfwGetKey(state.window, c.GLFW_KEY_A) == c.GLFW_PRESS);
    const isRight = (c.glfwGetKey(state.window, c.GLFW_KEY_RIGHT) == c.GLFW_PRESS) or (c.glfwGetKey(state.window, c.GLFW_KEY_D) == c.GLFW_PRESS);

    //Move forward
    if (isUp) {
        std.debug.print("up", .{});
        state.position = state.position.add(direction.scale(deltaTime * state.moveSpeed, vectorOp.mul));
    }
    // Move backward
    if (isDown) {
        std.debug.print("down", .{});
        state.position = state.position.subtract(direction.scale(deltaTime * state.moveSpeed, vectorOp.mul));
    }
    // Strafe right
    if (isRight) {
        std.debug.print("right", .{});
        state.position = state.position.add(right.scale(deltaTime * state.moveSpeed, vectorOp.mul));
    }
    // Strafe left
    if (isLeft) {
        std.debug.print("left", .{});
        state.position = state.position.subtract(right.scale(deltaTime * state.moveSpeed, vectorOp.mul));
    }

    view.* = Matrix(4, 4).lookAt(
        state.position,
        state.position.add(direction),
        up,
    );

    state.lastTime = currentTime;
}
