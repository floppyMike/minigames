const err = @import("../error.zig");

pub const Level = struct {
    ballSpeed: f64,
    AItick: u64,
};

pub const levels: [5]Level = .{
    .{ .ballSpeed = 0.6, .AItick = 10 },
    .{ .ballSpeed = 0.7, .AItick = 8 },
    .{ .ballSpeed = 0.8, .AItick = 6 },
    .{ .ballSpeed = 0.9, .AItick = 4 },
    .{ .ballSpeed = 0.999, .AItick = 2 },
};

pub fn Stats() type {
    return struct {
        levelsSurvived: u64,

        pub fn init() @This() {
            return .{
                .levelsSurvived = 0,
            };
        }

        pub fn nextlevel(self: *@This()) ?Level {
            if (self.didWin()) return null;

            const l = levels[self.levelsSurvived];
            self.levelsSurvived += 1;
            return l;
        }

        pub fn didWin(self: @This()) bool {
            return self.levelsSurvived >= levels.len;
        }

        pub fn printScore(self: @This(), stdoutFile: anytype) void {
            stdoutFile.print("{s}\nLevels survived: {d}\n", .{
                if (self.didWin()) "You Won!" else "You Lose!",
                self.levelsSurvived,
            }) catch err.termIOError();
        }
    };
}
