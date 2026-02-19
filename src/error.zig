const std = @import("std");

pub fn termIOError(reason: anyerror) noreturn {
    std.debug.panic("Panic: Can't access terminal IO: {any}", .{reason});
}

pub fn failedToInitRandom(reason: anyerror) noreturn {
    std.debug.panic("Panic: Can't generate random number: {any}", .{reason});
}

pub fn unknownCliError(reason: anyerror, wrt: *std.Io.Writer) void {
    wrt.print("Error: Failed to interpret CLI: {any}\n", .{reason}) catch |e| termIOError(e);
}

pub fn noGame(wrt: *std.Io.Writer) void {
    wrt.writeAll("Error: No game selected\n") catch |e| termIOError(e);
}

pub fn tooManyGames(wrt: *std.Io.Writer) void {
    wrt.writeAll("Error: Too many cardgames selected\n") catch |e| termIOError(e);
}

pub fn ncursesInitFail(wrt: *std.Io.Writer) void {
    wrt.writeAll("Error: Failed ncurses init\n") catch |e| termIOError(e);
}

pub fn screenToSmall(need_rows: u64, need_cols: u64, was_rows: u64, was_cols: u64, wrt: *std.Io.Writer) void {
    wrt.print("Error: Screen to small. Needs: ({d}x{d}). Was: ({d}x{d})\n", .{
        need_cols,
        need_rows,
        was_cols,
        was_rows,
    }) catch |e| termIOError(e);
}

pub const CriticalError = error{
    ScreenToSmall,
    CursesInitFail,
};

pub const CriticalErrorContext = union {
    ScreenToSmall: struct {
        need_rows: u64,
        need_cols: u64,
        was_rows: u64,
        was_cols: u64,
    },
};
