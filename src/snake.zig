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
    var screen = Screen.init(stdoutFile) orelse return;
    defer screen.deinit();

    rungame(screen, rand);
}

pub fn rungame(
    screen: Screen,
    rand: std.Random,
) void {
    var game = Snake().init(rand);
    const stats = Stats().init();

    while (true) {
        const ch = Screen.getInputNonBlocking();

        switch (ch) {
            'q' => return,
            'h' => game.tryTurnLeft(),
            'j' => game.tryTurnDown(),
            'k' => game.tryTurnUp(),
            'l' => game.tryTurnRight(),
            else => {},
        }

        game.updateGame();

        game.render(screen, stats);
        screen.refresh();

        std.Thread.sleep(std.time.ns_per_ms * 128);
    }
}

pub fn Snake() type {
    return struct {
        const Direction = enum { LEFT, DOWN, UP, RIGHT };

        const Body = std.BoundedArray(uXY, gamerows * gamecols);
        const uXY = struct {
            x: u64,
            y: u64,

            pub fn random(rand: std.Random) @This() {
                return .{ .x = rand.intRangeAtMost(u64, 0, gamecols / 2 - 1) * 2 + 1, .y = rand.intRangeAtMost(u64, 1, gamerows - 2) };
            }
        };

        player_body: Body, // We could do wacky optimizations but keeping it simple tends to make stuff also efficient
        player_direction: Direction,
        apple_pos: uXY,

        pub fn init(rand: std.Random) @This() {
            var body = Body.init(1) catch unreachable;
            body.set(0, uXY.random(rand));

            return .{
                .player_body = body,
                .player_direction = Direction.RIGHT,
                .apple_pos = uXY.random(rand),
            };
        }

        pub fn tryTurnLeft(self: *@This()) void {
            if (self.player_direction == Direction.RIGHT) return;
            self.player_direction = Direction.LEFT;
        }

        pub fn tryTurnDown(self: *@This()) void {
            if (self.player_direction == Direction.UP) return;
            self.player_direction = Direction.DOWN;
        }

        pub fn tryTurnUp(self: *@This()) void {
            if (self.player_direction == Direction.DOWN) return;
            self.player_direction = Direction.UP;
        }

        pub fn tryTurnRight(self: *@This()) void {
            if (self.player_direction == Direction.LEFT) return;
            self.player_direction = Direction.RIGHT;
        }

        pub fn updateGame(self: *@This()) void {
            const pbody = self.player_body.slice();

            // Move player
            var playerfront = pbody[0];
            pbody[0] = switch (self.player_direction) {
                Direction.LEFT => .{ .x = if (playerfront.x == 1) gamecols - 3 else playerfront.x - 2, .y = playerfront.y },
                Direction.DOWN => .{ .x = playerfront.x, .y = if (playerfront.y >= gamerows - 2) 1 else playerfront.y + 1 },
                Direction.UP => .{ .x = playerfront.x, .y = if (playerfront.y == 1) gamerows - 2 else playerfront.y - 1 },
                Direction.RIGHT => .{ .x = if (playerfront.x >= gamecols - 3) 1 else playerfront.x + 2, .y = playerfront.y },
            };
            for (1..pbody.len) |i| std.mem.swap(uXY, &pbody[i], &playerfront);
        }

        pub fn render(self: @This(), screen: Screen, stat: Stats()) void {
            screen.clear();
            screen.writeTitle("Snake: Down(j), Up(k), Left(h), Right(l)");
            screen.writeSubtitleArgs("Apples eaten: %llu", .{stat.apples_eaten});

            // Draw Player
            for (self.player_body.slice()) |pos| screen.drawPixel(pos.x, pos.y, pixelwidth, c.NCURSES_ACS('0'));

            // Draw Apple
            screen.drawPixel(self.apple_pos.x, self.apple_pos.y, pixelwidth, c.NCURSES_ACS('0'));
        }
    };
}

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
