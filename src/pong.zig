const c = @import("c.zig").c;

const std = @import("std");
const err = @import("error.zig");

const stats = @import("pong/stats.zig");

const gamerows = 32;
const gamecols = 96;

const PongError = error{
    ScreenSmall,
    NcursesFailed,
};

pub fn drawFilledBox(
    win: ?*c.WINDOW,
    fromx: u64,
    fromy: u64,
    tox: u64,
    toy: u64,
    ch: c.chtype,
) void {
    for (fromy..(toy + 1)) |y| {
        for (fromx..(tox + 1)) |x| {
            _ = c.mvwaddch(win, @intCast(y), @intCast(x), ch);
        }
    }
}

pub fn Pong() type {
    return struct {
        const paddlewidth = 5;
        const ballwidth = 2;

        const uXY = struct { x: u64, y: u64 };
        const fXY = struct { x: f64, y: f64 };

        gamewin: ?*c.WINDOW,

        playerPos: uXY,
        AIPos: uXY,
        ballPos: fXY,

        ballSpeed: fXY,
        ballMagnatude: f64,

        rand: std.Random,

        pub fn init(gamewin: ?*c.WINDOW, rand: std.Random, speed: f64) @This() {
            return .{
                .gamewin = gamewin,
                .playerPos = .{
                    .x = 2,
                    .y = (gamerows - paddlewidth) / 2,
                },
                .AIPos = .{
                    .x = gamecols - 3,
                    .y = (gamerows - paddlewidth) / 2,
                },
                .ballPos = .{
                    .x = (gamecols - ballwidth) / 2,
                    .y = (gamerows - ballwidth) / 2,
                },
                .rand = rand,
                .ballSpeed = .{ .x = speed, .y = 0 },
                .ballMagnatude = speed,
            };
        }

        pub fn movePlayerDown(self: *@This()) void {
            if (self.playerPos.y + paddlewidth == gamerows - 1) return;
            self.playerPos.y += 1;
        }

        pub fn movePlayerUp(self: *@This()) void {
            if (self.playerPos.y == 1) return;
            self.playerPos.y -= 1;
        }

        pub fn updateAI(self: *@This()) void {
            const posdiff = @as(i64, @intFromFloat(self.ballPos.y)) - @as(i64, @intCast(self.AIPos.y + paddlewidth / 2));
            const step = std.math.clamp(posdiff, -1, 1);

            const next: u64 = @intCast(@as(i64, @intCast(self.AIPos.y)) + step);
            if (next + paddlewidth == gamerows or next == 0) return;

            self.AIPos.y = next;
        }

        pub fn updateBall(self: *@This()) ?enum {
            PlayerScored,
            AIScored,
        } {
            // Update Position
            self.ballPos.x += self.ballSpeed.x;
            self.ballPos.y += self.ballSpeed.y;

            // Wall Reflection
            const balltop = self.ballPos.y < 1;
            const ballbottom = self.ballPos.y >= gamerows - 1;

            if (balltop or ballbottom) {
                const r = std.math.pi * 6.0 / 16.0 * self.rand.float(f64) + std.math.pi / 16.0;
                const x = self.ballMagnatude * @cos(r);
                const y = self.ballMagnatude * @sin(r);

                if (balltop) {
                    self.ballPos.y = 2 + (1 - self.ballPos.y);
                    self.ballSpeed.x = std.math.copysign(x, self.ballSpeed.x);
                    self.ballSpeed.y = y;
                }
                if (ballbottom) {
                    self.ballPos.y = gamerows - 2 - (self.ballPos.y - (gamerows - 1));
                    self.ballSpeed.x = std.math.copysign(x, self.ballSpeed.x);
                    self.ballSpeed.y = -y;
                }
            }

            // Paddle Reflection And Win Condition
            const playerfPosY: f64 = @floatFromInt(self.playerPos.y);
            const AIfPosY: f64 = @floatFromInt(self.AIPos.y);

            const ballleft = self.ballPos.x < 3;
            const ballright = self.ballPos.x + ballwidth >= gamecols - 2;
            const ballplayer = self.ballPos.y >= playerfPosY and self.ballPos.y <= playerfPosY + paddlewidth;
            const ballAI = self.ballPos.y >= AIfPosY and self.ballPos.y <= AIfPosY + paddlewidth;

            if (ballleft or ballright) {
                const r = std.math.pi * 14.0 / 16.0 * self.rand.float(f64) + std.math.pi / 16.0;
                const x = self.ballMagnatude * @sin(r);
                const y = self.ballMagnatude * @cos(r);

                if (ballleft) {
                    if (ballplayer) {
                        self.ballPos.x = 4 + (3 - self.ballPos.x);
                        self.ballSpeed.x = x;
                        self.ballSpeed.y = y;
                    } else {
                        return .AIScored;
                    }
                }
                if (ballright) {
                    if (ballAI) {
                        self.ballPos.x = gamecols - 4 - (self.ballPos.x + ballwidth - (gamecols - 3));
                        self.ballSpeed.x = -x;
                        self.ballSpeed.y = y;
                    } else {
                        return .PlayerScored;
                    }
                }
            }

            return null;
        }

        pub fn redraw(self: @This(), s: stats.Stats()) void {
            // Clear Screen
            _ = c.werase(self.gamewin);

            // Draw Border
            _ = c.box(self.gamewin, 0, 0);
            _ = c.mvwaddstr(self.gamewin, 0, 1, "Pong: Down(j), Up(k); Angle from ball to paddle is reflection angle");
            _ = c.mvwprintw(self.gamewin, gamerows - 1, 1, "Level: %llu", s.levelsSurvived);

            // Draw Player
            drawFilledBox(
                self.gamewin,
                self.playerPos.x,
                self.playerPos.y,
                self.playerPos.x,
                self.playerPos.y + paddlewidth - 1,
                c.NCURSES_ACS('0'),
            );

            // Draw AI
            drawFilledBox(
                self.gamewin,
                self.AIPos.x,
                self.AIPos.y,
                self.AIPos.x,
                self.AIPos.y + paddlewidth - 1,
                c.NCURSES_ACS('0'),
            );

            // Draw Ball
            drawFilledBox(
                self.gamewin,
                @intFromFloat(self.ballPos.x),
                @intFromFloat(self.ballPos.y),
                @as(u64, @intFromFloat(self.ballPos.x)) + ballwidth - 1,
                @intFromFloat(self.ballPos.y),
                c.NCURSES_ACS('0'),
            );
        }

        pub fn refresh(self: @This()) void {
            _ = c.refresh();
            _ = c.wrefresh(self.gamewin);
        }
    };
}

pub fn openscreen(
    rand: std.Random,
) PongError!stats.Stats() {
    if (c.initscr() == null) return error.NcursesFailed;
    defer _ = c.endwin();

    const cols: u64 = @intCast(c.getmaxx(c.stdscr));
    const rows: u64 = @intCast(c.getmaxy(c.stdscr));

    if (rows < gamerows or cols < gamecols) return error.ScreenSmall;

    _ = c.cbreak();
    _ = c.noecho();
    _ = c.curs_set(0);
    _ = c.nodelay(c.stdscr, true);

    const gamewin = c.newwin(gamerows, gamecols, @intCast((rows - gamerows) / 2), @intCast((cols - gamecols) / 2));
    defer _ = c.delwin(gamewin);

    var s = stats.Stats().init();

    while (s.nextlevel()) |level| {
        var game = Pong().init(gamewin, rand, level.ballSpeed);
        var AItick: u64 = 0;

        while (true) {
            const ch = c.getch();
            _ = c.flushinp();

            switch (ch) {
                'q' => return s,
                'j' => game.movePlayerDown(),
                'k' => game.movePlayerUp(),
                else => {},
            }

            AItick = (AItick + 1) % level.AItick;
            if (AItick == 0) game.updateAI();

            const event = game.updateBall();

            game.redraw(s);
            game.refresh();

            std.time.sleep(std.time.ns_per_ms * 32);

            if (event) |e| switch (e) {
                .PlayerScored => break,
                .AIScored => return s,
            };
        }
    }

    return s;
}

pub fn run(
    stdoutFile: anytype,
    rand: std.Random,
) void {
    const s = openscreen(rand) catch |e| {
        switch (e) {
            error.ScreenSmall => err.screenToSmall(gamerows, gamecols, stdoutFile),
            error.NcursesFailed => err.ncursesInitFail(stdoutFile),
        }

        return;
    };

    s.printScore(stdoutFile);
}
