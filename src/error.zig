const std = @import("std");

pub fn termIOError() noreturn {
    @panic("Can't access terminal IO.");
}

pub fn failedToInitRandom() noreturn {
    @panic("Can't generate random number (std.posix.getrandom).");
}

pub fn unknownCliError(reason: anyerror, wrt: anytype) void {
    wrt.print("Failed to interpret CLI: {any}\n", .{reason}) catch termIOError();
}

pub fn noCardgame(wrt: anytype) void {
    wrt.writeAll("No cardname selected.") catch termIOError();
}

pub fn tooManyCardGames(wrt: anytype) void {
    wrt.writeAll("Too many cardgames selected.") catch termIOError();
}
