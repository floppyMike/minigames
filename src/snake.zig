const c = @import("c.zig").c;

const std = @import("std");
const scn = @import("curses.zig");
const err = @import("error.zig");

const gamerows = 32;
const gamecols = 96;
const pixelwidth = 2;

const WorldSpace = scn.WorldSpace(gamecols, gamerows, pixelwidth);
const Screen = scn.Curses(gamerows, gamecols);

pub fn run(
    stdoutFile: anytype,
    rand: std.Random,
) void {
    const stats = rungame(stdoutFile, rand) orelse return;
    stats.printScore(stdoutFile);
}

pub fn rungame(
    stdoutFile: anytype,
    rand: std.Random,
) ?Stats() {
    var screen = Screen.init(stdoutFile) orelse return null;
    defer screen.deinit();

    var game = Snake().init(rand);
    var stats = Stats().init();

    while (true) {
        const ch = scn.getInputNonBlocking();

        switch (ch) {
            'q' => return stats,
            'h', c.KEY_LEFT => game.player.tryTurnLeft(),
            'j', c.KEY_DOWN => game.player.tryTurnDown(),
            'k', c.KEY_UP => game.player.tryTurnUp(),
            'l', c.KEY_RIGHT => game.player.tryTurnRight(),
            else => {},
        }

        game.updateGame(&stats, rand) catch |e| switch (e) {
            error.Crash => break,
            error.NoSpace => break,
        };

        game.render(screen, stats);
        screen.refresh();

        std.Thread.sleep(std.time.ns_per_ms * 32);
    }

    return stats;
}

pub fn Snake() type {
    return struct {
        const bodylength = Screen.worldarea;
        const Direction = enum { LEFT, DOWN, UP, RIGHT };
        const Body = std.BoundedArray(Screen.WorldPixel, bodylength);

        const Player = struct {
            direction: Direction,

            body: Body,
            body_end: usize,

            pub fn init(x: i64, y: i64) !@This() {
                var body = Body.init(1) catch unreachable;
                body.set(0, try Screen.WorldPixel.init(x, y));

                return .{
                    .direction = Direction.RIGHT,
                    .body = body,
                    .body_end = 0,
                };
            }

            pub fn tryTurnLeft(self: *@This()) void {
                if (self.direction == Direction.RIGHT) return;
                self.direction = Direction.LEFT;
            }

            pub fn tryTurnDown(self: *@This()) void {
                if (self.direction == Direction.UP) return;
                self.direction = Direction.DOWN;
            }

            pub fn tryTurnUp(self: *@This()) void {
                if (self.direction == Direction.DOWN) return;
                self.direction = Direction.UP;
            }

            pub fn tryTurnRight(self: *@This()) void {
                if (self.direction == Direction.LEFT) return;
                self.direction = Direction.RIGHT;
            }

            pub fn nextStep(self: @This()) Screen.WorldPixel {
                const head = self.getHead();

                const x = switch (self.direction) {
                    Direction.LEFT => if (head.x == 0) Screen.worldcols - 1 else head.x - 1,
                    Direction.RIGHT => if (head.x == Screen.worldcols - 1) 0 else head.x + 1,
                    else => head.x,
                };

                const y = switch (self.direction) {
                    Direction.UP => if (head.y == 0) Screen.worldrows - 1 else head.y - 1,
                    Direction.DOWN => if (head.y == Screen.worldrows - 1) 0 else head.y + 1,
                    else => head.y,
                };

                return Screen.WorldPixel.init(x, y) catch unreachable; // Should be valid
            }

            pub fn moveTo(self: *@This(), next: Screen.WorldPixel) void {
                self.body_end = (self.body_end + 1) % self.body.len;
                self.body.set(self.body_end, next);
            }

            pub fn moveToExtend(self: *@This(), next: Screen.WorldPixel) error{SnakeTooBig}!void {
                self.body_end += 1;
                self.body.insert(self.body_end, next) catch return error.SnakeTooBig;
            }

            pub fn getHead(self: @This()) Screen.WorldPixel {
                return self.body.get(self.body_end);
            }

            pub fn onBody(self: @This(), point: Screen.WorldPixel) bool {
                for (0.., self.body.buffer[0..self.body.len]) |i, b| {
                    if (i != self.body_end and std.meta.eql(b, point)) return true;
                }

                return false;
            }

            pub fn render(self: @This(), screen: Screen) void {
                for (self.body.slice()) |pos| screen.drawPixel(pos, c.NCURSES_ACS('0'));
            }
        };

        const Apple = struct {
            pos: Screen.WorldPixel,

            pub fn init(x: i64, y: i64) !@This() {
                return .{
                    .pos = try Screen.WorldPixel.init(x, y),
                };
            }

            pub fn random(rand: std.Random, excluding: []const Screen.WorldPixel) error{NoRoom}!@This() {
                var map = std.StaticBitSet(Screen.worldarea).initEmpty();
                for (excluding) |pos| map.set(pos.linearPos());

                const avail_length = Screen.worldarea - excluding.len;
                if (avail_length == 0) return error.NoRoom;

                var rand_pos = rand.intRangeAtMost(u64, 0, avail_length - 1);
                var nocollision_pos: u64 = 0;

                while (rand_pos > 0) {
                    if (!map.isSet(nocollision_pos)) rand_pos -= 1;
                    nocollision_pos += 1;
                }

                const pos = Screen.WorldPixel.fromLinearPos(nocollision_pos) catch unreachable; // Should always be in bounds
                return Apple.init(pos.x, pos.y) catch unreachable; // Rand coords are correct
            }

            pub fn render(self: @This(), screen: Screen) void {
                screen.drawPixel(self.pos, c.NCURSES_ACS('0'));
            }
        };

        player: Player,
        apple: Apple,

        pub fn init(rand: std.Random) @This() {
            const player = Player.init(0, 0) catch unreachable;
            const apple = Apple.random(rand, player.body.constSlice()) catch unreachable; // This could result in a crash if the area is 1x1, but this will not happen

            return .{
                .player = player,
                .apple = apple,
            };
        }

        pub fn updateGame(self: *@This(), stats: *Stats(), rand: std.Random) error{ NoSpace, Crash }!void {
            const next = self.player.nextStep();

            if (std.meta.eql(next, self.apple.pos)) {
                stats.eatApple();
                self.player.moveToExtend(next) catch unreachable; // Since the next cell MUST be a body => already handled before
                self.apple = Apple.random(rand, self.player.body.constSlice()) catch return error.NoSpace;
            } else {
                self.player.moveTo(next);
            }

            if (self.player.onBody(next)) return error.Crash;
        }

        pub fn render(self: @This(), screen: Screen, stat: Stats()) void {
            screen.clear();
            screen.writeTitle("Snake: Down(j), Up(k), Left(h), Right(l)");
            screen.writeSubtitleArgs("Apples eaten: %llu", .{stat.apples_eaten});

            self.player.render(screen);
            self.apple.render(screen);
        }
    };
}

//
// Stats
//

pub fn Stats() type {
    return struct {
        apples_eaten: u64,

        pub fn init() @This() {
            return .{
                .apples_eaten = 0,
            };
        }

        pub fn eatApple(self: *@This()) void {
            self.apples_eaten += 1;
        }

        pub fn printScore(self: @This(), stdoutFile: anytype) void {
            stdoutFile.print("Apples eaten: {d}\n", .{self.apples_eaten}) catch err.termIOError();
        }
    };
}
