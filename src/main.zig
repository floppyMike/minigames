const std = @import("std");
const cli = @import("deadsimple").cli;

const err = @import("error.zig");
const scat = @import("scat.zig");
const pong = @import("pong.zig");
const snake = @import("snake.zig");

pub fn main() void {
    //
    // IO
    //

    var buferr: [512]u8 = undefined;
    var stderr = std.fs.File.stderr().writer(&buferr);
    defer stderr.interface.flush() catch |e| err.termIOError(e);

    //
    // Args
    //

    const Args = cli.ArgStruct(
        "A collection of card games for an ANSI based terminal.",
        &.{ .{
            .name = "help",
            .desc = "Displays this help message.",
        }, .{
            .name = "scat",
            .desc = "Also Thiry One, using a 52 card deck approach 31 points as close as possible.",
        }, .{
            .name = "snake",
            .desc = "A dynamic game of eating apples and growing in length.",
        }, .{
            .name = "pong",
            .desc = "A dynamic game with 2 paddles and a ball.",
        } },
        &.{},
        &.{},
        null,
    );

    const parsedArgs = Args.parseArgs(std.os.argv[1..]) catch |e| {
        err.unknownCliError(e, &stderr.interface);
        return;
    };

    const args = parsedArgs.args;

    if (args.help) {
        Args.displayHelp(&stderr.interface, std.os.argv[0]) catch |e| err.termIOError(e);
        return;
    }

    var options: u64 = 0;
    if (args.scat) options |= 1;
    if (args.pong) options |= 2;
    if (args.snake) options |= 4;

    var ctxErr: err.CriticalErrorContext = undefined;

    _ = switch (options) {
        1 => scat.run(),
        2 => pong.run(&ctxErr),
        4 => snake.run(&ctxErr),

        0 => err.noGame(&stderr.interface),
        else => err.tooManyGames(&stderr.interface),
    } catch |e| switch (e) {
        error.CursesInitFail => err.ncursesInitFail(&stderr.interface),
        error.ScreenToSmall => err.screenToSmall(ctxErr.ScreenToSmall.need_rows, ctxErr.ScreenToSmall.need_cols, ctxErr.ScreenToSmall.was_rows, ctxErr.ScreenToSmall.was_cols, &stderr.interface),
    };
}
