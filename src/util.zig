const std = @import("std");

pub fn exchange(comptime T: type, v: *T, new: T) T {
    const old = v.*;
    v.* = new;
    return old;
}

pub fn StaticSet(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T = undefined,
        len: usize = 0,

        pub fn init() @This() {
            return .{};
        }

        pub fn slice(self: anytype) switch (@TypeOf(&self.buffer)) {
            *[capacity]T => []T,
            *const [capacity]T => []const T,
            else => unreachable,
        } {
            return self.buffer[0..self.len];
        }

        pub fn add(self: *@This(), item: T) error{Overflow}!void {
            const ptr = try self.emplace();
            ptr.* = item;
        }

        pub fn append(self: *@This(), items: []const T) error{Overflow}!void {
            const old = self.len;
            const new = self.len + items.len;

            if (new > capacity) return error.Overflow;

            for (self.buffer[old..new], items) |*b, i| b.* = i;
            self.len = new;
        }

        pub fn remove(self: *@This(), idx: usize) error{OutOfBounds}!void {
            if (idx >= self.len) return error.OutOfBounds;
            std.mem.swap(T, &self.buffer[idx], &self.buffer[self.len - 1]);
            self.len -= 1;
        }
    };
}
