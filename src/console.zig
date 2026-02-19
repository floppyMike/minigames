const std = @import("std");
const err = @import("error.zig");

stdout: std.fs.File.Writer,
stdin: std.fs.File.Reader,

pub fn init(outbuf: []u8, inbuf: []u8) @This() {
    return @This(){
        .stdout = std.fs.File.stdout().writer(outbuf),
        .stdin = std.fs.File.stdin().reader(inbuf),
    };
}

pub fn print(self: *@This(), comptime fmt: []const u8, args: anytype) void {
    self.stdout.interface.print(fmt, args) catch |e| err.termIOError(e);
}

pub fn flush(self: *@This()) void {
    self.stdout.interface.flush() catch |e| err.termIOError(e);
}

pub fn readByte(self: *@This()) error{WantsExit}!u8 {
    return self.stdin.interface.takeByte() catch |e| switch (e) {
        error.EndOfStream => return error.WantsExit, // Ctrl+d
        else => err.termIOError(e),
    };
}

pub fn skipLine(self: *@This()) error{WantsExit}!void {
    _ = self.stdin.interface.discardDelimiterInclusive('\n') catch |e| switch (e) {
        error.EndOfStream => return error.WantsExit,
        else => err.termIOError(e),
    };
}

