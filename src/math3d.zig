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

        const identityMatrix = Matrix(4, 4).init(
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

        pub fn init(items: [x][y]f32) Self {
            return Self{
                .val = items,
            };
        }

        /// rotating 4x4 matrices
        pub fn rotate(o1: Matrix(4, 4), distance: f32, axis: Vector(3)) Matrix(4, 4) {
            const normalized = axis.normalize();
            const nx = normalized[0];
            const ny = normalized[1];
            const nz = normalized[2];

            const cos = math.cos(distance);
            const sin = math.sin(distance);
            const t = 1 - cos;

            const @"3dRotationalMatrix" = Matrix(4, 4).init([_][4]f32{
                [_]f32{ cos + nx * nx * t, nx * ny * t - nz * sin, nx * nz * t + ny * sin, 0 },
                [_]f32{ ny * nx * t + nz * sin, cos + ny * ny * t, ny * nz * t - nx * sin, 0 },
                [_]f32{ nz * nx * t - ny * sin, nz * ny * t + nx * sin, cos + nz * nz * t, 0 },
                [_]f32{ 0, 0, 0, 1 },
            });
            return Matrix(4, 4).multiply(4, 4, 4, o1, @"3dRotationalMatrix");
        }

        pub fn transform(self: Self, vertex: Vector(x)) Vector(x) {
            var result = Vector(x).initZero();

            for (0..x) |i| {
                for (0..y) |j| {
                    result.val[i] += self.val[i][j] * vertex.val[j];
                }
            }
            return result;
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

        pub fn scale(self: Matrix(x, y), vector: Vector(y)) Vector(x) {
            const matYx1: Matrix(y, 1) = vector.toMatrix();
            const matResult: Matrix(x, 1) = multiply(x, y, 1, self, matYx1);

            var result = Vector(x).initZero();

            for (0..x) |i| {
                result.val[i] = matResult.val[i][0];
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

        pub fn len() u8 {
            return size;
        }

        pub fn normalize(self: Self) Vector(size) {
            const vectorLen: f32 = self.length();
            if (vectorLen == 0) {
                // cannot normalize this
                return Self.initZero();
            }

            var result = Self.initZero();
            for (0..size) |i| {
                result.val[i] = self[i] / length;
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

        pub fn cross(o1: Vector(3), o2: Vector(3)) Vector(3) {
            const ax = o1.val[0];
            const ay = o1.val[1];
            const az = o1.val[2];

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
    var mat = Matrix(4, 4).init(
        [_][4]f32{
            [_]f32{ 1.0, 1.0, 1.0, 1.0 },
            [_]f32{ 2.0, 2.0, 2.0, 2.0 },
            [_]f32{ 1.0, 1.0, 1.0, 1.0 },
            [_]f32{ 4.0, 4.0, 4.0, 4.0 },
        },
    );
    const vec = Vector(4).init(.{ 1.0, 2.0, 1.0, 1.0 });

    try testing.expectEqual(
        Vector(4){ .val = [_]f32{ 5.0, 10.0, 5.0, 20.0 } },
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

    try testing.expectEqual(Matrix(3, 1).init([_][1]f32{
        [_]f32{0},
        [_]f32{3},
        [_]f32{3},
    }), Matrix(3, 2).multiply(
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

test "matrix equality" {
    try testing.expectEqual(true, (&Matrix(4, 4){
        .val = [_][4]f32{
            [_]f32{ 1.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        },
    }).eq(Matrix(4, 4){
        .val = [_][4]f32{
            [_]f32{ 1.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        },
    }));

    try testing.expectEqual(false, (&Matrix(4, 4){
        .val = [_][4]f32{
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        },
    }).eq(Matrix(4, 4){
        .val = [_][4]f32{
            [_]f32{ 2.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        },
    }));
}

test "generic vector" {
    try testing.expectEqual(3, Vector(3).len());
    try testing.expectEqual(5, Vector(5).len());

    var v3 = Vector(3).init(.{ 1.0, 2.0, 3.0 });
    try testing.expectEqual(3, v3.values().len);
    try testing.expectEqual(1.0, v3.values()[0]);
    try testing.expectEqual(2.0, v3.values()[1]);
    try testing.expectEqual(3.0, v3.values()[2]);
}

test "cross product" {
    const va = Vector(3).init(.{ 1, 2, 3 });
    const vb = Vector(3).init(.{ 4, 5, 6 });
    try testing.expectEqual(Vector(3).init(.{ -3, 6, -3 }), Vector(3).cross(va, vb));
}

test "vector dot product" {
    try testing.expectEqual(32, Vector(3).dot(Vector(3).init(.{ 1, 2, 3 }), Vector(3).init(.{ 4, 5, 6 })));
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
