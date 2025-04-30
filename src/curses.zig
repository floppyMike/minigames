const std = @import("std");
const c = @import("c.zig").c;

const CursesError = error {
    NcursesFailed,
    ScreenSmall,
};

pub fn Curses(comptime gamerows: comptime_int, comptime gamecols: comptime_int) type {
    return struct {
        gamewin: ?*c.WINDOW,

        pub fn init() CursesError!@This() {
            if (c.initscr() == null) return error.NcursesFailed;

            const wincols: u64 = @intCast(c.getmaxx(c.stdscr));
            const winrows: u64 = @intCast(c.getmaxy(c.stdscr));

            if (winrows < gamerows or wincols < gamecols) return error.ScreenSmall;

            _ = c.cbreak();
            _ = c.noecho();
            _ = c.curs_set(0);
            _ = c.nodelay(c.stdscr, true);

            const gamewin = c.newwin(gamerows, gamecols, @intCast((winrows - gamerows) / 2), @intCast((wincols - gamecols) / 2));

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
            _ = c.mvwaddstr(self.gamewin, gamerows - 1, 1, str);
        }

        pub fn writeSubtitleArgs(self: @This(), str: [*c]const u8, args: anytype) void {
            _ = @call(std.builtin.CallModifier.auto, c.mvwprintw, .{ self.gamewin, gamerows - 1, 1, str } ++ args);
        }

        pub fn drawPixel(self: @This(), x: u64, y: u64, ch: c.chtype) void {
            _ = c.mvwaddch(self.gamewin, @intCast(y), @intCast(x), ch);
        }

        pub fn drawFilledBox(self: @This(), fromx: u64, fromy: u64, tox: u64, toy: u64, ch: c.chtype) void {
            for (fromy..(toy + 1)) |y| for (fromx..(tox + 1)) |x| self.drawPixel(x, y, ch);
        }
    };
}
