const std = @import("std");
const c = @import("c.zig").c;
const err = @import("error.zig");

pub fn TerminalSpace() type {
    return struct {
        x: u64,
        y: u64,
    };
}

pub fn WorldSpace(comptime terminalcols: comptime_int, comptime terminalrows: comptime_int, comptime pixelwidth: comptime_int) type {
    if (terminalcols < 2) @compileError("Terminalspace must be at least 2 wide.");
    if (terminalrows < 2) @compileError("Terminalspace must be at least 2 high.");

    if (terminalcols % 2 == 0) @compileError("Terminalspace width must be even to allow block pixels.");

    return struct {
        x: u64,
        y: u64,

        const terminalcols = terminalcols;

        const worldcols = terminalcols / 2 - 1;
        const worldrows = terminalrows - 1;

        pub fn toTerminal(self: @This()) TerminalSpace() {
            return .{ .x = self.x * pixelwidth + 1, .y = self.y + 1 };
        }
    };
}

pub fn Curses(comptime gamerows: comptime_int, comptime gamecols: comptime_int) type {
    return struct {
        gamewin: ?*c.WINDOW,

        pub fn init(stdoutFile: anytype) ?@This() {
            _ = c.initscr() orelse {
                err.ncursesInitFail(stdoutFile);
                return null;
            };
            errdefer _ = c.endwin();

            const wincols: u64 = @intCast(c.getmaxx(c.stdscr));
            const winrows: u64 = @intCast(c.getmaxy(c.stdscr));

            if (winrows < gamerows or wincols < gamecols) {
                err.screenToSmall(gamerows, gamecols, winrows, wincols, stdoutFile);
                return null;
            }

            _ = c.cbreak();
            _ = c.noecho();
            _ = c.curs_set(0);
            _ = c.nodelay(c.stdscr, true);

            const gamewin = c.newwin(gamerows, gamecols, @intCast((winrows - gamerows) / 2), @intCast((wincols - gamecols) / 2));
            errdefer _ = c.delwin(gamewin);

            return .{ .gamewin = gamewin };
        }

        pub fn deinit(self: @This()) void {
            _ = c.delwin(self.gamewin);
            _ = c.endwin();
        }

        pub fn getInputNonBlockingFinal() c_int {
            const ch = getInputNonBlocking();
            _ = c.flushinp();
            return ch;
        }

        pub fn getInputNonBlocking() c_int {
            return c.getch();
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
            _ = c.mvwaddstr(self.gamewin, gamerows - 1, 1, str);
        }

        pub fn writeSubtitleArgs(self: @This(), str: [*c]const u8, args: anytype) void {
            _ = @call(std.builtin.CallModifier.auto, c.mvwprintw, .{ self.gamewin, gamerows - 1, 1, str } ++ args);
        }

        pub fn drawHalfPixel(self: @This(), xy: TerminalSpace(), ch: c.chtype) void {
            _ = c.mvwaddch(self.gamewin, @intCast(y), @intCast(x), ch);
        }

        pub fn drawPixel(self: @This(), xy: anytype, width: u64, ch: c.chtype) void {
            self.drawHalfPixel(x, y, ch);
            self.drawHalfPixel(x + width - 1, y, ch);
        }

        pub fn drawFilledBox(self: @This(), fromx: u64, fromy: u64, tox: u64, toy: u64, ch: c.chtype) void {
            for (fromy..(toy + 1)) |y| for (fromx..(tox + 1)) |x| self.drawHalfPixel(x, y, ch);
        }
    };
}
