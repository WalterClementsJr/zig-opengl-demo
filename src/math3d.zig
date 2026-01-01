const std = @import("std");

const math = std.math;
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const VectorOp = enum {
    add,
    sub,
    divide,
    mul,
    neg,
};

/// Generic matrix
pub fn Matrix(comptime x: u8, comptime y: u8) type {
    return struct {
        const Self = @This();

        pub const identityMatrix = Matrix(4, 4).init(
            [_][4]f32{
                [_]f32{ 1, 0, 0, 0 },
                [_]f32{ 0, 1, 0, 0 },
                [_]f32{ 0, 0, 1, 0 },
                [_]f32{ 0, 0, 0, 1 },
            },
        );

        xDim: u8 = x,
        yDim: u8 = y,
        val: [x][y]f32 = undefined,

        pub fn initZero() Self {
            return Self{
                .val = std.mem.zeroes([x][y]f32),
            };
        }

        pub fn initFlat(items: [x * y]f32) Self {
            var @"2dVal": [x][y]f32 = undefined;

            var row: u8 = 0;
            var col: u8 = 0;

            for (items) |item| {
                @"2dVal"[row][col] = item;
                col += 1;
                if (col == y) {
                    col = 0;
                    row += 1;
                }
            }
            return Self{
                .val = @"2dVal",
            };
        }
        pub fn init(items: [x][y]f32) Self {
            return Self{
                .val = items,
            };
        }

        /// rotating 4x4 matrices
        pub fn rotate4x4(o1: Matrix(4, 4), angleDeg: f32, axis: Vector(3)) Matrix(4, 4) {
            const normalized = axis.normalize();
            const angleRadian: f32 = angleDeg * (math.pi / 180.0);
            const nx = normalized.val[0];
            const ny = normalized.val[1];
            const nz = normalized.val[2];

            const cos = math.cos(angleRadian);
            const sin = math.sin(angleRadian);
            const t = 1 - cos;

            const @"3dRotationalMatrix" = Matrix(4, 4).init([_][4]f32{
                [_]f32{ cos + nx * nx * t, nx * ny * t - nz * sin, nx * nz * t + ny * sin, 0 },
                [_]f32{ ny * nx * t + nz * sin, cos + ny * ny * t, ny * nz * t - nx * sin, 0 },
                [_]f32{ nz * nx * t - ny * sin, nz * ny * t + nx * sin, cos + nz * nz * t, 0 },
                [_]f32{ 0, 0, 0, 1 },
            });
            return Matrix(4, 4).multiply(4, 4, 4, o1, @"3dRotationalMatrix");
        }

        pub fn orthoProjection(left: f32, right: f32, bottom: f32, top: f32, zNear: f32, zFar: f32) Matrix(4, 4) {
            var perspective = identityMatrix;

            perspective.val[0][0] = 2 / (right - left);
            perspective.val[1][1] = 2 / (top - bottom);
            perspective.val[2][2] = -2 / (zFar - zNear);
            perspective.val[0][3] = -(right + left) / (right - left);
            perspective.val[1][3] = -(top + bottom) / (top - bottom);
            perspective.val[2][3] = -(zFar + zNear) / (zFar - zNear);

            return perspective;
        }

        pub fn flatten(self: Self) [x * y]f32 {
            var result: [x * y]f32 = undefined;
            var counter: usize = 0;

            for (0..x) |i| {
                for (0..y) |j| {
                    result[counter] = self.val[i][j];
                    counter += 1;
                }
            }
            return result;
        }

        pub fn totalElements(self: Self) usize {
            _ = self;
            return x * y;
        }

        pub fn transform(self: Self, vertex: Vector(y)) Vector(x) {
            var result = Vector(x).initZero();

            for (0..x) |i| {
                for (0..y) |j| {
                    result.val[i] += self.val[i][j] * vertex.val[j];
                }
            }
            return result;
        }

        pub fn scale(self: Matrix(x, y), vector: Vector(y)) Vector(x) {
            var result = Vector(x).initZero();
            for (0..x) |i| {
                var sum: f32 = 0;
                for (0..y) |j| {
                    sum += self.val[i][j] * vector.val[j];
                }
                result.val[i] = sum;
            }
            return result;
        }

        pub fn multiply(
            comptime X: u8, // 1st matrix row
            comptime Y: u8, // 1st matrix col, 2nd matrix row
            comptime Z: u8, // 2nd matrix col
            m1: Matrix(X, Y),
            m2: Matrix(Y, Z),
        ) Matrix(X, Z) {
            var result = Matrix(X, Z).initZero();
            for (0..X) |i| {
                for (0..Y) |j| {
                    for (0..Z) |k| {
                        result.val[i][k] += m1.val[i][j] * m2.val[j][k];
                    }
                }
            }
            return result;
        }

        pub fn lookAt(eye: Vector(3), center: Vector(3), up: Vector(3)) Matrix(4, 4) {
            var Z = eye.subtract(center);
            Z = Z.normalize();
            var Y = up;
            var X = Y.cross(Z);
            Y = Z.cross(X);
            X = X.normalize();
            Y = Y.normalize();

            var M = identityMatrix;
            M.val[0][0] = X.val[0];
            M.val[0][1] = X.val[1];
            M.val[0][2] = X.val[2];
            M.val[0][3] = -1 * X.dot(eye);

            M.val[1][0] = Y.val[0];
            M.val[1][1] = Y.val[1];
            M.val[1][2] = Y.val[2];
            M.val[1][3] = -1 * Y.dot(eye);

            M.val[2][0] = Z.val[0];
            M.val[2][1] = Z.val[1];
            M.val[2][2] = Z.val[2];
            M.val[2][3] = -Z.dot(eye);

            M.val[3][0] = 0;
            M.val[3][1] = 0;
            M.val[3][2] = 0;
            M.val[3][3] = 1.0;

            return M;
        }

        pub fn subtract(self: Matrix(x, y), other: Matrix(x, y)) Matrix(x, y) {
            const result = Matrix(x, y).init();
            for (0..x) |i| {
                for (0..y) |j| {
                    result.val[i][j] = self.val[i][j] - other.val[i][j];
                }
            }

            return result;
        }

        pub fn add(self: Matrix(x, y), other: Matrix(x, y)) Matrix(x, y) {
            const result = Matrix(x, y).init();
            for (0..x) |i| {
                for (0..y) |j| {
                    result.val[i][j] = self.val[i][j] + other.val[i][j];
                }
            }

            return result;
        }

        pub fn eq(self: Self, other: Matrix(x, y)) bool {
            for (0..x) |i| {
                for (0..y) |j| {
                    if (other.val[i][j] != self.val[i][j]) {
                        return false;
                    }
                }
            }
            return true;
        }
    };
}

/// Generic vector
pub fn Vector(comptime size: u8) type {
    return struct {
        const Self = @This();
        val: [size]f32 = undefined,

        pub fn toMatrix(self: Self) Matrix(size, 1) {
            var result = Matrix(size, 1).initZero();
            for (0..size) |i| {
                result.val[i][0] = self.val[i];
            }
            return result;
        }

        pub fn toVec4(v3: Vector(3), x: f32) Vector(4) {
            return Vector(4).init(.{ v3.val[0], v3.val[1], v3.val[2], x });
        }

        pub fn initZero() Self {
            return Self{
                .val = std.mem.zeroes([size]f32),
            };
        }

        pub fn init(items: [size]f32) Self {
            return Self{ .val = items };
        }

        pub fn getVector3(self: Self) Vector(3) {
            if (size < 3) {
                @panic("Cannot extract Vector 3 from this");
            }
            return Vector(3).init(.{ self.val[0], self.val[1], self.val[2] });
        }

        pub fn values(self: Self) [size]f32 {
            return self.val;
        }

        pub fn len(self: Self) u8 {
            _ = self;
            return size;
        }

        pub fn subtract(self: Vector(size), other: Vector(size)) Vector(size) {
            var res = Vector(size){};
            for (0..size) |i| {
                res.val[i] = self.val[i] - other.val[i];
            }
            return res;
        }

        pub fn add(self: Vector(size), other: Vector(size)) Vector(size) {
            var res = Vector(size){};
            for (0..size) |i| {
                res.val[i] = self.val[i] + other.val[i];
            }
            return res;
        }

        pub fn normalize(self: Self) Vector(size) {
            const vectorLen: f32 = self.length();
            if (vectorLen == 0) {
                // cannot normalize this
                return Self.initZero();
            }

            var result = Self.initZero();
            for (0..size) |i| {
                result.val[i] = self.val[i] / vectorLen;
            }
            return result;
        }

        pub fn length(self: Self) f32 {
            var acc: f32 = 0;
            for (0..size) |i| {
                acc += self.val[i] * self.val[i];
            }
            return math.sqrt(acc);
        }

        pub fn cross(self: Self, o2: Vector(3)) Vector(3) {
            const ax = self.val[0];
            const ay = self.val[1];
            const az = self.val[2];

            const bx = o2.val[0];
            const by = o2.val[1];
            const bz = o2.val[2];

            return Vector(3).init(.{ ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx });
        }

        pub fn dot(self: Self, other: Self) f32 {
            var scalar: f32 = 0.0;
            for (0..self.val.len) |i| {
                scalar += self.val[i] * other.val[i];
            }
            return scalar;
        }

        /// scalar operations
        pub fn scale(self: *Self, scalar: f32, operator: VectorOp) Self {
            var result = Self.initZero();

            for (self.val, 0..) |item, i| {
                switch (operator) {
                    VectorOp.add => result.val[i] = item + scalar,
                    VectorOp.sub => result.val[i] = item - scalar,
                    VectorOp.mul => result.val[i] = item * scalar,
                    VectorOp.divide => result.val[i] = item / scalar,
                    VectorOp.neg => result.val[i] = item * -1.0,
                }
            }
            return result;
        }
    };
}

const testing = std.testing;

test "matrix transformation" {
    var mat = Matrix(4, 4).initFlat(.{
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 1, 2, 3,
        4, 5, 6, 7,
    });
    const vec = Vector(4).init(.{ 1, 2, 3, 4 });

    try testing.expectEqual(
        Vector(4){ .val = [_]f32{ 30, 70, 29, 60 } },
        mat.transform(vec),
    );
}

test "matrix scale" {
    var mat = Matrix(4, 4).init(
        [_][4]f32{
            [_]f32{ 1, 0, 0, 0 },
            [_]f32{ 0, 1, 0, 0 },
            [_]f32{ 0, 0, 1, 0 },
            [_]f32{ 0, 0, 0, 1 },
        },
    );
    const vec = Vector(4).init(.{ 2, 4, 6, 1 });

    try testing.expectEqual(Vector(4).init(.{ 2, 4, 6, 1 }), mat.scale(vec));
}

test "matrix multiply" {
    try testing.expectEqual(Matrix(2, 2).init([_][2]f32{
        [_]f32{ 19, 22 },
        [_]f32{ 43, 50 },
    }), Matrix(0, 0).multiply(
        2,
        2,
        2,
        Matrix(2, 2).init(
            [_][2]f32{
                [_]f32{ 1, 2 },
                [_]f32{ 3, 4 },
            },
        ),
        Matrix(2, 2).init(
            [_][2]f32{
                [_]f32{ 5, 6 },
                [_]f32{ 7, 8 },
            },
        ),
    ));

    try testing.expectEqual(Matrix(3, 1).initFlat(.{ 0, 3, 3 }), Matrix(3, 1).multiply(
        3,
        2,
        1,
        Matrix(3, 2).init(
            [_][2]f32{
                [_]f32{ 0, 0 },
                [_]f32{ 3, 0 },
                [_]f32{ 0, 3 },
            },
        ),
        Matrix(2, 1).init(
            [_][1]f32{
                [_]f32{1},
                [_]f32{1},
            },
        ),
    ));

    const A = Matrix(3, 2).init(
        [_][2]f32{
            [_]f32{ 1, 2 },
            [_]f32{ 3, 4 },
            [_]f32{ 5, 6 },
        },
    );

    const I2 = Matrix(2, 2).init(
        [_][2]f32{
            [_]f32{ 1, 0 },
            [_]f32{ 0, 1 },
        },
    );

    try testing.expectEqual(
        A,
        Matrix(3, 2).multiply(
            3,
            2,
            2,
            A,
            I2,
        ),
    );
    const I3 = Matrix(3, 3).init(
        [_][3]f32{
            [_]f32{ 1, 0, 0 },
            [_]f32{ 0, 1, 0 },
            [_]f32{ 0, 0, 1 },
        },
    );

    try testing.expectEqual(
        A,
        Matrix(3, 2).multiply(
            3,
            3,
            2,
            I3,
            A,
        ),
    );
}

test "matrix multiplication association" {
    const A = Matrix(2, 3).initFlat(.{
        1,
        2,
        3,
        4,
        5,
        6,
    });

    const B = Matrix(3, 2).initFlat(.{
        7,
        8,
        9,
        10,
        11,
        12,
    });

    const C = Matrix(2, 2).initFlat(.{
        1,
        2,
        3,
        4,
    });

    const AB = Matrix(2, 2).multiply(
        2,
        3,
        2,
        A,
        B,
    );

    const left = Matrix(2, 2).multiply(
        2,
        2,
        2,
        AB,
        C,
    );

    const BC = Matrix(3, 2).multiply(
        3,
        2,
        2,
        B,
        C,
    );

    const right = Matrix(2, 2).multiply(
        2,
        3,
        2,
        A,
        BC,
    );

    try testing.expectEqual(left, right);
}

test "matrix properties" {
    const mat = Matrix(3, 2).init([_][2]f32{
        [_]f32{ 0, 1 },
        [_]f32{ 3, 1 },
        [_]f32{ 3, 1 },
    });
    try testing.expectEqual([_]f32{ 0, 1, 3, 1, 3, 1 }, mat.flatten());
    try testing.expectEqual(6, mat.totalElements());
}

test "matrix projection lookAt" {
    try testing.expectEqual(
        Matrix(4, 4).lookAt(
            Vector(3).init(.{ 0, 0, 1 }),
            Vector(3).init(.{ 0, 0, 0 }),
            Vector(3).init(.{ 0, 1, 0 }),
        ),
        Matrix(4, 4).initFlat(.{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, -1,
            0, 0, 0, 1,
        }),
    );
}

test "matrix ortho" {
    try testing.expectEqual(
        Matrix(4, 4).initFlat(.{
            0.1, 0,   0,     0,
            0,   0.1, 0,     0,
            0,   0,   -0.02, -1,
            0,   0,   0,     1,
        }),
        Matrix(4, 4).orthoProjection(-10, 10, -10, 10, 0, 100),
    );
}

test "generic vector" {
    var v3 = Vector(3).init(.{ 1.0, 2.0, 3.0 });
    try testing.expectEqual(3, v3.values().len);
    try testing.expectEqual(3, v3.len());
    try testing.expectEqual(1.0, v3.values()[0]);
    try testing.expectEqual(2.0, v3.values()[1]);
    try testing.expectEqual(3.0, v3.values()[2]);
}

test "vector cross product" {
    const va = Vector(3).init(.{ 1, 2, 3 });
    const vb = Vector(3).init(.{ 4, 5, 6 });
    try testing.expectEqual(Vector(3).init(.{ -3, 6, -3 }), Vector(3).cross(va, vb));
}

test "vector dot product" {
    try testing.expectEqual(32, Vector(3).init(.{ 1, 2, 3 }).dot(Vector(3).init(.{ 4, 5, 6 })));
}

test "vector normalize" {
    const actual = Vector(3).init(.{ 0.26726124, 0.5345225, 0.8017837 });
    const res = Vector(3).init(.{ 1, 2, 3 }).normalize();

    for (actual.val, res.val) |e, r| {
        try std.testing.expectApproxEqAbs(e, r, 0.0001);
    }
}

test "vector to matrix" {
    try testing.expectEqual(Matrix(3, 1).init([_][1]f32{
        [_]f32{1},
        [_]f32{2},
        [_]f32{3},
    }), Vector(3).init(.{ 1, 2, 3 }).toMatrix());
}

test "vector length" {
    var v3 = Vector(3).init(.{ 1, 2, 3 });
    try testing.expectEqual(@sqrt(14.0), v3.length());
}

test "vector subtract" {
    const v1 = Vector(3).init(.{ 1, 2, 3 });
    const v2 = Vector(3).init(.{ 4, 5, 6 });
    try testing.expectEqual(Vector(3).init(.{ -3, -3, -3 }), v1.subtract(v2));
}

test "vector scalar" {
    var v3 = Vector(3).init(.{ 1.0, 2.0, 3.0 });

    v3 = v3.scale(2.0, VectorOp.add);
    try testing.expectEqual(3.0, v3.values()[0]);
    try testing.expectEqual(4.0, v3.values()[1]);
    try testing.expectEqual(5.0, v3.values()[2]);

    v3 = Vector(3).init(.{ 1.0, 2.0, 3.0 });
    v3 = v3.scale(2.0, VectorOp.sub);

    try testing.expectEqual(-1.0, v3.values()[0]);
    try testing.expectEqual(0.0, v3.values()[1]);
    try testing.expectEqual(1.0, v3.values()[2]);

    v3 = Vector(3).init(.{ 1.0, 2.0, 3.0 });
    v3 = v3.scale(2.0, VectorOp.mul);
    try testing.expectEqual(2.0, v3.values()[0]);
    try testing.expectEqual(4.0, v3.values()[1]);
    try testing.expectEqual(6.0, v3.values()[2]);

    v3 = Vector(3).init(.{ 2.0, 4.0, 6.0 });
    v3 = v3.scale(2.0, VectorOp.divide);
    try testing.expectEqual(1.0, v3.values()[0]);
    try testing.expectEqual(2.0, v3.values()[1]);
    try testing.expectEqual(3.0, v3.values()[2]);

    v3 = Vector(3).init(.{ 1.0, 2.0, 3.0 });
    v3 = v3.scale(0.0, VectorOp.neg);
    try testing.expectEqual(-1.0, v3.values()[0]);
    try testing.expectEqual(-2.0, v3.values()[1]);
    try testing.expectEqual(-3.0, v3.values()[2]);
}
