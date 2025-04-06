const std = @import("std");
const cli = @import("deadsimple").cli;

const err = @import("error.zig");
const scat = @import("scat.zig");
const pong = @import("pong.zig");

pub fn main() void {
    //
    // Args
    //

    const stdoutFile = std.io.getStdOut().writer();
    const stderrFile = std.io.getStdErr().writer();
    const stdinFile = std.io.getStdIn().reader();

    const Args = cli.ArgStruct(
        "A collection of card games for an ANSI based terminal.",
        &.{ .{
            .name = "help",
            .desc = "Displays this help message.",
        }, .{
            .name = "scat",
            .desc = "Also Thiry One, using a 52 card deck approach 31 points as close as possible.",
        }, .{
            .name = "pong",
            .desc = "A dynamic game with 2 paddles and a ball.",
        } },
        &.{},
        &.{},
        null,
    );

    const parsedArgs = Args.parseArgs(std.os.argv[1..]) catch |e| {
        err.unknownCliError(e, stderrFile);
        return;
    };

    const args = parsedArgs.args;

    if (args.help) {
        Args.displayHelp(stdoutFile, std.os.argv[0]) catch err.termIOError();
        return;
    }

    //
    // Random Generator
    //

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch err.failedToInitRandom();
        break :blk seed;
    });

    //
    // Dispatch
    //

    var options: u64 = 0;
    if (args.scat) options |= 1;
    if (args.pong) options |= 2;

    switch (options) {
        1 => scat.run(stdoutFile, stdinFile, prng.random()),
        2 => pong.run(stdoutFile, prng.random()),

        0 => err.noCardgame(stderrFile),
        else => err.tooManyCardGames(stderrFile),
    }
}
