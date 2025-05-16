const c = @import("c.zig").c;

const std = @import("std");
const scn = @import("curses.zig");

const gamerows = 32;
const gamecols = 96;
const pixelwidth = 2;

const WorldSpace = scn.WorldSpace(gamecols, gamerows, pixelwidth);
const Screen = scn.Curses(gamerows, gamecols);

pub fn run(
    stdoutFile: anytype,
    rand: std.Random,
) void {
    const stats = rungame(stdoutFile, rand);
    _ = stats;
}

pub fn rungame(
    stdoutFile: anytype,
    rand: std.Random,
) ?Stats() {
    var screen = Screen.init(stdoutFile) orelse return null;
    defer screen.deinit();

    var game = Snake().init(rand);
    const stats = Stats().init();

    while (true) {
        const ch = scn.getInputNonBlocking();

        switch (ch) {
            'q' => return stats,
            'h' => game.player.tryTurnLeft(),
            'j' => game.player.tryTurnDown(),
            'k' => game.player.tryTurnUp(),
            'l' => game.player.tryTurnRight(),
            else => {},
        }

        game.updateGame();

        game.render(screen, stats);
        screen.refresh();

        std.Thread.sleep(std.time.ns_per_ms * 128);
    }

    return stats;
}

pub fn Snake() type {
    return struct {
        const Direction = enum { LEFT, DOWN, UP, RIGHT };
        const Body = std.BoundedArray(Screen.WorldPixel, gamerows * gamecols);

        const Player = struct {
            direction: Direction,

            body: Body,
            body_end: usize,

            pub fn init(x: i64, y: i64) !@This() {
                var body = Body.init(2) catch unreachable;
                body.set(0, try Screen.WorldPixel.init(x, y));
                body.set(1, try Screen.WorldPixel.init(x, y));

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

            pub fn move(self: *@This()) void {
                const head = self.body.get(self.body_end);
                self.body_end = (self.body_end + 1) % self.body.len;

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

                self.body.set(self.body_end, Screen.WorldPixel.init(x, y) catch unreachable); // Should be valid
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

            pub fn random(rand: std.Random) @This() {
                return .{ .x = rand.intRangeAtMost(u64, 0, gamecols / 2 - 1) * 2 + 1, .y = rand.intRangeAtMost(u64, 1, gamerows - 2) };
            }

            pub fn render(self: @This(), screen: Screen) void {
                screen.drawPixel(self.pos, c.NCURSES_ACS('0'));
            }
        };

        player: Player,
        apple: Apple,

        pub fn init(rand: std.Random) @This() {
            _ = rand;

            return .{
                .player = Player.init(0, 1) catch unreachable,
                .apple = Apple.init(0, 0) catch unreachable,
            };
        }

        pub fn updateGame(self: *@This()) void {
            self.player.move();
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
    };
}
