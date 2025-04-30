const c = @import("c.zig").c;

const std = @import("std");
const scn = @import("curses.zig");
const err = @import("error.zig");

const Screen = scn.Curses(32, 96);

//
// Game General
//

pub fn run(
    stdoutFile: anytype,
    rand: std.Random,
) void {
    const res = rungame(stdoutFile, rand) orelse return;
    res.printScore(stdoutFile);
}

pub fn rungame(
    stdoutFile: anytype,
    rand: std.Random,
) ?Stats() {
    var screen = Screen.init(stdoutFile) orelse return null;
    defer screen.deinit();

    var s = Stats().init();

    while (s.currentLevel()) |level| {
        var game = Pong().init(level.ballSpeed);
        var AItick: u64 = 0;
        var pause = false;

        while (true) {
            std.Thread.sleep(std.time.ns_per_ms * 32);

            if (game.playerScored()) {
                s.nextlevel();
                break;
            }

            if (game.AIScored()) {
                return s;
            }

            const ch = scn.getInputNonBlockingFinal();

            switch (ch) {
                'q' => return s,
                'j' => game.tryMovePlayer(1),
                'k' => game.tryMovePlayer(-1),
                'p' => pause = !pause,

                else => {},
            }

            if (pause) continue;

            AItick = (AItick + 1) % level.AItick;
            if (AItick == 0) game.updateAI();

            game.updateBall(rand);

            game.render(screen, s);
            screen.refresh();
        }
    }

    return s;
}

pub fn Pong() type {
    if (Screen.worldrows < 5 or Screen.worldcols < 7) @compileError("Screen to small for pong.");

    return struct {
        //
        // Paddle
        //

        pub fn Paddle(x: comptime_int) type {
            return struct {
                const height = 5;
                const posx = x;

                const startPaddle = @This().init((Screen.worldrows - height + 1) / 2) catch unreachable;

                posy: i64,

                pub fn getPaddleTop(y: i64) i64 {
                    return y;
                }

                pub fn getPaddleBottom(y: i64) i64 {
                    return y + height - 1;
                }

                pub fn init(y: i64) !@This() {
                    const top = getPaddleTop(y);
                    const bottom = getPaddleBottom(y);

                    if (!Screen.contains(posx, top) or !Screen.contains(posx, bottom)) return error.OutOfBounds;

                    return .{ .posy = y };
                }

                pub fn paddleMiddle(self: @This()) i64 {
                    return self.posy + height / 2;
                }

                pub fn tryShift(self: *@This(), dy: i64) void {
                    self.* = @This().init(self.posy + dy) catch return;
                }

                pub fn render(self: @This(), screen: Screen) void {
                    const top = getPaddleTop(self.posy);
                    const bottom = getPaddleBottom(self.posy);

                    const top_pixel = Screen.WorldPixel.init(x, top) catch unreachable; // Must be within game
                    const bottom_pixel = Screen.WorldPixel.init(x, bottom) catch unreachable; // Must be within game

                    screen.drawFilledBox(top_pixel, bottom_pixel, c.NCURSES_ACS('0'));
                }
            };
        }

        //
        // Ball
        //

        const Ball = struct {
            const startmid = Screen.WorldPixelF.safeInit(Screen.worldcols / 2, Screen.worldrows / 2) catch unreachable;

            pos: Screen.WorldPixelF,
            speed: struct { dx: f64, dy: f64 },
            magnatude: f64,

            pub fn init(speed: f64) @This() {
                return .{
                    .pos = startmid,
                    .speed = .{ .dx = -speed, .dy = 0 },
                    .magnatude = speed,
                };
            }

            pub fn nextStep(self: @This()) !Screen.WorldPixelF {
                return self.pos.shift(self.speed.dx, self.speed.dy);
            }

            pub fn render(self: @This(), screen: Screen) void {
                screen.drawPixel(self.pos.toInt(), c.NCURSES_ACS('0'));
            }
        };

        //
        // Collisions
        //

        const Collision = packed struct(u6) {
            up: bool,
            down: bool,
            leftscore: bool,
            rightscore: bool,

            player: bool,
            ai: bool,

            const init: Collision = @bitCast(@as(u6, 0));
        };

        //
        // Logic
        //

        const PlayerPaddle = Paddle(0);
        const AIPaddle = Paddle(Screen.worldcols - 1);

        player: PlayerPaddle,
        AI: AIPaddle,
        ball: Ball,

        pub fn init(speed: f64) @This() {
            return .{
                .player = PlayerPaddle.startPaddle,
                .AI = AIPaddle.startPaddle,
                .ball = Ball.init(speed),
            };
        }

        pub fn AIScored(self: @This()) bool {
            return self.ball.pos.x < 1;
        }

        pub fn playerScored(self: @This()) bool {
            return self.ball.pos.x >= Screen.worldcols - 1;
        }

        pub fn anyScored(self: @This()) bool {
            return self.AIScored() or self.playerScored();
        }

        pub fn tryMovePlayer(self: *@This(), dy: i64) void {
            if (self.anyScored()) return; // Game is done

            self.player.tryShift(dy);
        }

        pub fn updateAI(self: *@This()) void {
            if (self.anyScored()) return; // Game is done

            const bally: i64 = @intFromFloat(self.ball.pos.y);
            const AIymid: i64 = @intCast(self.AI.paddleMiddle());

            const diff = bally - AIymid;
            const step = std.math.clamp(diff, -1, 1);

            self.AI.tryShift(step);
        }

        pub fn updateBall(self: *@This(), rand: std.Random) void {
            if (self.anyScored()) return; // Game is done

            const playertop: f64 = @floatFromInt(PlayerPaddle.getPaddleTop(self.player.posy));
            const playerbottom: f64 = @floatFromInt(PlayerPaddle.getPaddleBottom(self.player.posy));
            const AItop: f64 = @floatFromInt(PlayerPaddle.getPaddleTop(self.AI.posy));
            const AIbottom: f64 = @floatFromInt(PlayerPaddle.getPaddleBottom(self.AI.posy));

            var newsx = self.ball.speed.dx;
            var newsy = self.ball.speed.dy;
            var newx = self.ball.pos.x + newsx;
            var newy = self.ball.pos.y + newsy;

            const up = newy < 0;
            const down = newy >= Screen.worldrows;

            if (up or down) {
                const r = std.math.pi * 6.0 / 16.0 * rand.float(f64) + std.math.pi / 16.0;
                const sx = self.ball.magnatude * @cos(r);
                const sy = self.ball.magnatude * @sin(r);

                newsx = std.math.copysign(sx, newsx);

                if (up) {
                    newy = -newy + 1;
                    newsy = sy;
                }
                if (down) {
                    newy = Screen.worldrows - (newy - Screen.worldrows) - 1;
                    newsy = -sy;
                }
            }

            const leftscore = newx < 1;
            const rightscore = newx >= Screen.worldcols - 1;
            const player = playertop <= newy and newy < playerbottom + 1;
            const AI = AItop <= newy and newy < AIbottom + 1;

            if (leftscore or rightscore) {
                const r = std.math.pi * 14.0 / 16.0 * rand.float(f64) + std.math.pi / 16.0;
                const sx = self.ball.magnatude * @sin(r);
                const sy = self.ball.magnatude * @cos(r);

                newsy = std.math.copysign(sy, newsy);

                if (leftscore) {
                    if (player) newx = (1 - newx) + 2;
                    newsx = sx;
                }
                if (rightscore) {
                    if (AI) newx = (Screen.worldcols - 1) - (newx - (Screen.worldcols - 1)) - 1;
                    newsx = -sx;
                }
            }

            self.ball.pos = Screen.WorldPixelF.init(newx, newy) catch unreachable;
            self.ball.speed = .{ .dx = newsx, .dy = newsy };
        }

        pub fn render(self: @This(), screen: Screen, s: Stats()) void {
            screen.clear();
            screen.writeTitle("Pong: Down(j), Up(k), Pause(p); Ball reflects randomly!");
            screen.writeSubtitleArgs("Level: %llu", .{s.levelsSurvived});

            self.player.render(screen);
            self.AI.render(screen);
            self.ball.render(screen);
        }
    };
}

//
// Stats
//

pub const Level = struct {
    ballSpeed: f64,
    AItick: u64,
};

pub const levels = [_]Level{
    .{ .ballSpeed = 0.4, .AItick = 10 },
    .{ .ballSpeed = 0.4, .AItick = 8 },
    .{ .ballSpeed = 0.6, .AItick = 6 },
    .{ .ballSpeed = 0.8, .AItick = 4 },
    .{ .ballSpeed = 1.0, .AItick = 2 },
};

pub fn Stats() type {
    return struct {
        levelsSurvived: u64,

        pub fn init() @This() {
            return .{
                .levelsSurvived = 0,
            };
        }

        pub fn currentLevel(self: @This()) ?Level {
            if (self.levelsSurvived < levels.len) return levels[self.levelsSurvived] else return null;
        }

        pub fn nextlevel(self: *@This()) void {
            self.levelsSurvived += 1;
        }

        pub fn printScore(self: @This(), stdoutFile: anytype) void {
            stdoutFile.print("{s}\nLevels survived: {d}\n", .{
                if (self.levelsSurvived >= levels.len) "You Won!" else "You Lose!",
                self.levelsSurvived,
            }) catch err.termIOError();
        }
    };
}
