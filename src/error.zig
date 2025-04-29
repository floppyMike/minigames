const std = @import("std");

pub fn termIOError() noreturn {
    @panic("Panic: Can't access terminal IO.");
}

pub fn failedToInitRandom() noreturn {
    @panic("Panic: Can't generate random number (std.posix.getrandom).");
}

pub fn unknownCliError(reason: anyerror, wrt: anytype) void {
    wrt.print("Error: Failed to interpret CLI: {any}\n", .{reason}) catch termIOError();
}

pub fn noGame(wrt: anytype) void {
    wrt.writeAll("Error: No game selected.") catch termIOError();
}

pub fn tooManyGames(wrt: anytype) void {
    wrt.writeAll("Error: Too many cardgames selected.") catch termIOError();
}

pub fn ncursesInitFail(wrt: anytype) void {
    wrt.writeAll("Error: Failed ncurses init.") catch termIOError();
}

pub fn screenToSmall(rows: u64, cols: u64, wrt: anytype) void {
    wrt.print("Error: Screen to small. Needs: ({d}x{d})\n", .{ rows, cols }) catch termIOError();
}
