pub fn RectBounds(comptime rows: comptime_int, comptime cols: comptime_int) type {
    return packed struct(u4) {
        left: bool,
        up: bool,
        down: bool,
        right: bool,

        const init: @This() = @bitCast(@as(u4, 0));

        pub fn check(x: i64, y: i64) @This() {
            var b = @This().init;

            b.left = x < 0;
            b.up = y < 0;
            b.right = x >= cols;
            b.down = y >= rows;

            return b;
        }

        pub fn contains(x: i64, y: i64) bool {
            return @This().init == check(x, y);
        }

        pub fn checkF(x: f64, y: f64) @This() {
            return check(@intFromFloat(x), @intFromFloat(y));
        }

        pub fn containsF(x: f64, y: f64) bool {
            return contains(@intFromFloat(x), @intFromFloat(y));
        }
    };
}

pub fn Pixel(comptime r: comptime_int, comptime c: comptime_int) type {
    return struct {
        pub const rows = r;
        pub const cols = c;

        pub const Border = RectBounds(rows, cols);

        x: i64,
        y: i64,

        pub fn init(x: i64, y: i64) !@This() {
            return if (Border.contains(x, y)) .{ .x = x, .y = y } else error.OutOfBounds;
        }

        pub fn linearPos(self: @This()) u64 {
            return @intCast(self.x + self.y * cols);
        }

        pub fn fromLinearPos(xy: u64) !@This() {
            return init(@intCast(xy % cols), @intCast(xy / cols));
        }

        pub fn shift(self: @This(), dx: i64, dy: i64) !@This() {
            return init(self.x + dx, self.y + dy);
        }

        pub fn expand(self: @This(), comptime nr: comptime_int, comptime nc: comptime_int) Pixel(nr, nc) {
            return .init(self.x, self.y);
        }
    };
}

pub fn PixelF(comptime r: comptime_int, comptime c: comptime_int) type {
    return struct {
        pub const rows = r;
        pub const cols = c;

        pub const Border = RectBounds(rows, cols);

        x: f64,
        y: f64,

        pub fn init(x: f64, y: f64) !@This() {
            return if (Border.containsF(x, y)) .{ .x = x, .y = y } else error.OutOfBounds;
        }

        pub fn safeInit(x: f64, y: f64) !@This() {
            return init(x + 0.5, y + 0.5); // Init in the middle to be more numerically resistant
        }

        pub fn shift(self: @This(), dx: f64, dy: f64) !@This() {
            return init(self.x + dx, self.y + dy);
        }

        pub fn toInt(self: @This()) Pixel(rows, cols) {
            return Pixel(rows, cols).init(@intFromFloat(self.x), @intFromFloat(self.y)) catch unreachable; // Should always be in a valid position
        }
    };
}

pub const Delta = struct {
    dx: i64,
    dy: i64,

    pub fn init(dx: i64, dy: i64) @This() {
        return .{ .dx = dx, .dy = dy };
    }

    pub fn shift(self: @This(), other: @This()) @This() {
        return init(self.dx + other.dx, self.dy + other.dy);
    }
};
