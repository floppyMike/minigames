const std = @import("std");

pub fn termIOError() noreturn {
    @panic("Can't access terminal.");
}

pub fn unknownCliError(reason: anyerror, wrt: anytype) void {
    wrt.print("Failed to interpret CLI: {any}\n", .{reason}) catch termIOError();
}
