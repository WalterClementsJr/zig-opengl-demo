pub const vertex1: []const u8 =
    \\#version 410 core
    \\layout (location = 0) in vec3 vp;
    \\uniform mat4 MVP;
    \\
    \\void main() {
    \\  gl_Position = MVP * vec4( vp, 1.0 );
    \\}
;

pub const fragment1: []const u8 =
    \\#version 410 core
    \\
    \\out vec4 FRAGCOLOR;
    \\uniform vec4 InFragColor; // can be modified from outside
    \\
    \\void main() {
    \\  FRAGCOLOR = InFragColor;
    \\}
;

pub const vertex2: []const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos; // the position variable has attribute position 0
    \\
    \\out vec4 vertexColor; // specify a color output to the fragment shader
    \\
    \\void main()
    \\{
    \\    gl_Position = vec4(aPos, 1.0); // see how we directly give a vec3 to vec4's constructor
    \\    vertexColor = vec4(0.5, 0.0, 0.0, 1.0); // set the output variable to a dark-red color
    \\}
;
