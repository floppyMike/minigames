const std = @import("std");
const c = @import("c.zig").c;
const err = @import("error.zig");
const mth = @import("math.zig");

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

pub fn Curses(comptime termrows: comptime_int, comptime termcols: comptime_int, comptime pixelwidth: comptime_int) type {
    if (termcols < 2) @compileError("Game must be at least 2 wide.");
    if (termrows < 2) @compileError("Game must be at least 2 high.");

    if (termcols % pixelwidth != 0) @compileError("Game width must be even to allow block pixels.");

    return struct {
        pub const worldcols = termcols / pixelwidth - 1;
        pub const worldrows = termrows - 2;

        pub const worldarea = worldcols * worldrows;

        pub const WorldBorder = mth.RectBounds(worldrows, worldcols);

        pub const WorldPixel = mth.Pixel(worldrows, worldcols);
        pub const WorldPixelF = mth.PixelF(worldrows, worldcols);

        pub const TermPixel = struct {
            x: u64,
            y: u64,

            pub fn init(x: u64, y: u64) !@This() {
                const fits = x > 0 and y > 0 and x < termcols - 1 and y < termrows - 1;
                return if (fits) .{ .x = x, .y = y } else error.OutOfBounds;
            }
        };

        pub fn world2term(wld: WorldPixel) [pixelwidth]TermPixel {
            var pixels: [pixelwidth]TermPixel = undefined;
            inline for (&pixels, 0..) |*p, i| p.* = TermPixel.init(@intCast(wld.x * pixelwidth + 1 + i), @intCast(wld.y + 1)) catch unreachable; // WorldPixel is already in a valid spot
            return pixels;
        }

        gamewin: ?*c.WINDOW,

        pub fn init(ctx: *err.CriticalErrorContext) err.CriticalError!@This() {
            _ = c.initscr() orelse return err.CriticalError.CursesInitFail;
            errdefer _ = c.endwin();

            const wincols: u64 = @intCast(c.getmaxx(c.stdscr));
            const winrows: u64 = @intCast(c.getmaxy(c.stdscr));

            if (winrows < termrows or wincols < termcols) {
                ctx.ScreenToSmall = .{
                    .need_rows = termrows,
                    .need_cols = termcols,
                    .was_rows = winrows,
                    .was_cols = wincols,
                };

                return err.CriticalError.ScreenToSmall;
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
            for (world2term(xy)) |hp| self.drawHalfPixel(hp, ch);
        }

        pub fn drawFilledBox(self: @This(), from: WorldPixel, to: WorldPixel, ch: c.chtype) void {
            const tx: usize = @intCast(to.x);
            const ty: usize = @intCast(to.y);
            const fx: usize = @intCast(from.x);
            const fy: usize = @intCast(from.y);

            for (fy..(ty + 1)) |y| for (fx..(tx + 1)) |x| {
                const ix: i64 = @intCast(x);
                const iy: i64 = @intCast(y);
                const wp = WorldPixel.init(ix, iy) catch unreachable; // Rectangular sections should be valid
                self.drawPixel(wp, ch);
            };
        }
    };
}
