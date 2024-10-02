const std = @import("std");
const di = @import("deadcli");

const err = @import("error.zig");

pub fn main() void {
    //
    // Args
    //

    const stdoutFile = std.io.getStdOut().writer();
    const stderrFile = std.io.getStdErr().writer();

    const Args = di.ArgStruct(
        "deadcards",
        "A collection of card games for an ANSI based terminal.",
        &.{.{
            .name = "help",
            .desc = "Displays this help message.",
        }},
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
}
