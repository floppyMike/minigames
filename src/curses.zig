const std = @import("std");
const c = @import("c.zig").c;
const err = @import("error.zig");

//
// Curses Input
//

pub fn getInputNonBlockingFinal() c_int {
    const ch = getInputNonBlocking();
    _ = c.flushinp();
    return ch;
}

pub fn getInputNonBlocking() c_int {
    return c.getch();
}

pub fn Curses(comptime termrows: comptime_int, comptime termcols: comptime_int) type {
    const pixelwidth = 2;

    if (termcols < 2) @compileError("Game must be at least 2 wide.");
    if (termrows < 2) @compileError("Game must be at least 2 high.");

    if (termcols % pixelwidth != 0) @compileError("Game width must be even to allow block pixels.");

    return struct {
        pub const worldcols = termcols / pixelwidth - 1;
        pub const worldrows = termrows - 2;

        pub const worldarea = worldcols * worldrows;

        //
        // Collisions
        //

        pub const Bounds = packed struct(u4) {
            left: bool,
            up: bool,
            down: bool,
            right: bool,

            const init: Bounds = @bitCast(@as(u4, 0));
        };

        pub fn check(x: i64, y: i64) Bounds {
            var b = Bounds.init;

            b.left = x < 0;
            b.up = y < 0;
            b.right = x >= worldcols;
            b.down = y >= worldrows;

            return b;
        }

        pub fn contains(x: i64, y: i64) bool {
            return Bounds.init == check(x, y);
        }

        pub fn containsTerm(x: u64, y: u64) bool {
            return x > 0 and y > 0 and x < termcols - 1 and y < termrows - 1;
        }

        pub fn checkF(x: f64, y: f64) Bounds {
            return check(@intFromFloat(x), @intFromFloat(y));
        }

        pub fn containsF(x: f64, y: f64) bool {
            return contains(@intFromFloat(x), @intFromFloat(y));
        }

        //
        // Pixel Types
        //

        pub const WorldPixelF = struct {
            x: f64,
            y: f64,

            pub fn init(x: f64, y: f64) !@This() {
                return if (containsF(x, y)) .{ .x = x, .y = y } else error.OutOfBounds;
            }

            pub fn safeInit(x: f64, y: f64) !@This() {
                return WorldPixelF.init(x + 0.5, y + 0.5); // Init in the middle to be more numerically resistant
            }

            pub fn shift(self: @This(), dx: f64, dy: f64) !@This() {
                return WorldPixelF.init(self.x + dx, self.y + dy);
            }

            pub fn toInt(self: @This()) WorldPixel {
                return WorldPixel.init(@intFromFloat(self.x), @intFromFloat(self.y)) catch unreachable; // Should always be in a valid position
            }
        };

        pub const WorldPixel = struct {
            x: i64,
            y: i64,

            pub fn init(x: i64, y: i64) !@This() {
                return if (contains(x, y)) .{ .x = x, .y = y } else error.OutOfBounds;
            }

            pub fn linearPos(self: @This()) u64 {
                return @intCast(self.x + self.y * worldcols);
            }

            pub fn fromLinearPos(xy: u64) !@This() {
                return WorldPixel.init(@intCast(xy % worldcols), @intCast(xy / worldcols));
            }

            pub fn shift(self: @This(), dx: i64, dy: i64) !@This() {
                return WorldPixel.init(self.x + dx, self.y + dy);
            }

            pub fn termPixel(self: @This()) [pixelwidth]TermPixel {
                var pixels: [pixelwidth]TermPixel = undefined;
                inline for (&pixels, 0..) |*p, i| p.* = TermPixel.init(@intCast(self.x * pixelwidth + 1 + i), @intCast(self.y + 1)) catch unreachable; // WorldPixel is already in a valid spot
                return pixels;
            }
        };

        pub const TermPixel = struct {
            x: u64,
            y: u64,

            pub fn init(x: u64, y: u64) !@This() {
                return if (containsTerm(x, y)) .{ .x = x, .y = y } else error.OutOfBounds;
            }
        };

        //
        // Curses Terminal
        //

        gamewin: ?*c.WINDOW,

        pub fn init(stdoutFile: anytype) ?@This() {
            _ = c.initscr() orelse {
                err.ncursesInitFail(stdoutFile);
                return null;
            };
            errdefer _ = c.endwin();

            const wincols: u64 = @intCast(c.getmaxx(c.stdscr));
            const winrows: u64 = @intCast(c.getmaxy(c.stdscr));

            if (winrows < termrows or wincols < termcols) {
                err.screenToSmall(termrows, termcols, winrows, wincols, stdoutFile);
                return null;
            }

            _ = c.cbreak();
            _ = c.noecho();
            _ = c.curs_set(0);
            _ = c.nodelay(c.stdscr, true);
            _ = c.keypad(c.stdscr, true); // Enable arrow keys

            const gamewin = c.newwin(termrows, termcols, @intCast((winrows - termrows) / 2), @intCast((wincols - termcols) / 2));
            errdefer _ = c.delwin(gamewin);

            return .{ .gamewin = gamewin };
        }

        pub fn deinit(self: @This()) void {
            _ = c.delwin(self.gamewin);
            _ = c.endwin();
        }

        pub fn clear(self: @This()) void {
            _ = c.werase(self.gamewin);
            _ = c.box(self.gamewin, 0, 0);
        }

        pub fn refresh(self: @This()) void {
            _ = c.refresh();
            _ = c.wrefresh(self.gamewin);
        }

        pub fn writeTitle(self: @This(), str: [*c]const u8) void {
            _ = c.mvwaddstr(self.gamewin, 0, 1, str);
        }

        pub fn writeTitleArgs(self: @This(), str: [*c]const u8, args: anytype) void {
            _ = @call(std.builtin.CallModifier.auto, c.mvwprintw, .{ self.gamewin, 0, 1, str } ++ args);
        }

        pub fn writeSubtitle(self: @This(), str: [*c]const u8) void {
            _ = c.mvwaddstr(self.gamewin, termrows - 1, 1, str);
        }

        pub fn writeSubtitleArgs(self: @This(), str: [*c]const u8, args: anytype) void {
            _ = @call(std.builtin.CallModifier.auto, c.mvwprintw, .{ self.gamewin, termrows - 1, 1, str } ++ args);
        }

        pub fn drawHalfPixel(self: @This(), xy: TermPixel, ch: c.chtype) void {
            _ = c.mvwaddch(self.gamewin, @intCast(xy.y), @intCast(xy.x), ch);
        }

        pub fn drawPixel(self: @This(), xy: WorldPixel, ch: c.chtype) void {
            for (xy.termPixel()) |hp| self.drawHalfPixel(hp, ch);
        }

        pub fn drawFilledBox(self: @This(), from: WorldPixel, to: WorldPixel, ch: c.chtype) void {
            const fy: usize = @intCast(from.y);
            const ty: usize = @intCast(to.y);
            const fx: usize = @intCast(from.x);
            const tx: usize = @intCast(to.x);

            for (fy..(ty + 1)) |y| for (fx..(tx + 1)) |x| {
                const ix: i64 = @intCast(x);
                const iy: i64 = @intCast(y);
                const wp = WorldPixel.init(ix, iy) catch unreachable; // Rectangular sections should be valid
                self.drawPixel(wp, ch);
            };
        }
    };
}
