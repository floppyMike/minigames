const std = @import("std");
const di = @import("deadcli");

const err = @import("error.zig");
const scat = @import("scat.zig");

pub fn main() void {
    //
    // Args
    //

    const stdoutFile = std.io.getStdOut().writer();
    const stderrFile = std.io.getStdErr().writer();
    const stdinFile = std.io.getStdIn().reader();

    const Args = di.ArgStruct(
        "deadcards",
        "A collection of card games for an ANSI based terminal.",
        &.{ .{
            .name = "help",
            .desc = "Displays this help message.",
        }, .{
            .name = "scat",
            .desc = "Also Thiry One, using a 52 card deck approach 31 points as close as possible.",
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
        Args.displayHelp(stdoutFile) catch err.termIOError();
        return;
    }

    //
    // Dispatch
    //

    var options: u64 = 0;
    if (args.scat) options |= 1;

    switch (options) {
        1 => scat.run(stdoutFile, stdinFile),

        0 => err.noCardgame(stderrFile),
        else => err.tooManyCardGames(stderrFile),
    }
}
