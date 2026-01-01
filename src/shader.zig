pub const vertex1: []const u8 =
    \\#version 410 core
    \\layout (location = 0) in vec3 vertex;
    \\layout (location = 1) in vec3 vertexColor;
    \\uniform mat4 MVP;
    \\
    \\out vec3 fragmentColor;
    \\
    \\void main() {
    \\  gl_Position = MVP * vec4( vertex, 1.0 );
    \\  fragmentColor = vertexColor;
    \\}
;

pub const fragment1: []const u8 =
    \\#version 410 core
    \\
    \\in vec3 fragmentColor;
    \\out vec3 color;
    \\
    \\void main() {
    \\  color = fragmentColor;
    \\}
;
