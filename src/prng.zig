const std = @import("std");
const err = @import("error.zig");

pub fn init() std.Random.DefaultPrng {
    return std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch |e| err.failedToInitRandom(e);
        break :blk seed;
    });
}
