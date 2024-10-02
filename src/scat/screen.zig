const std = @import("std");
const err = @import("../error.zig");
const Deck = @import("deck.zig");

pub const ActionError = error{
    Nothing,
    WantsExit,
    TooMany,
};

pub fn colorToANSI(col: Deck.Type) []const u8 {
    return switch (col) {
        Deck.Type.Diamond => "31", // Red
        Deck.Type.Heart => "32", // Green
        Deck.Type.Spade => "33", // Yellow
        Deck.Type.Club => "34", // Blue
    };
}

const gameBoard = "\n" ++
    "-------------\n" ++
    "# ?? ?? ??\n" ++
    "#\n" ++
    "#   \x1b[{s}m{s}\x1b[0m{d}\n" ++
    "#\n" ++
    "# \x1b[{s}m{s} \x1b[{s}m{s} \x1b[{s}m{s}\x1b[0m (Score: {d})\n";

const cheatBoard = "\n" ++
    "-------------\n" ++
    "# \x1b[{s}m{s} \x1b[{s}m{s} \x1b[{s}m{s}\x1b[0m (Score: {d})\n" ++
    "#\n" ++
    "#   \x1b[{s}m{s}\x1b[0m{d}\n" ++
    "#\n" ++
    "# \x1b[{s}m{s} \x1b[{s}m{s} \x1b[{s}m{s}\x1b[0m (Score: {d})\n";

pub fn Screen(Out: type, In: type) type {
    const BW = std.io.BufferedWriter(4096, Out);
    const BR = std.io.BufferedReader(4096, In);

    return struct {
        bw: BW,
        br: BR,

        //
        // Output
        //

        pub fn flush(self: *@This()) void {
            self.bw.flush() catch err.termIOError();
        }

        pub fn writeBoard(self: *@This(), deck: Deck) void {
            const w = self.bw.writer();

            w.print(gameBoard, .{
                colorToANSI(deck.discard.color),
                &deck.discard.name,
                deck.stock.len - deck.used,
                colorToANSI(deck.player[0].color),
                &deck.player[0].name,
                colorToANSI(deck.player[1].color),
                &deck.player[1].name,
                colorToANSI(deck.player[2].color),
                &deck.player[2].name,
                Deck.countScore(deck.player),
            }) catch err.termIOError();
        }

        pub fn writeCheatBoard(self: *@This(), deck: Deck) void {
            const w = self.bw.writer();

            w.print(cheatBoard, .{
                colorToANSI(deck.opponent[0].color),
                &deck.opponent[0].name,
                colorToANSI(deck.opponent[1].color),
                &deck.opponent[1].name,
                colorToANSI(deck.opponent[2].color),
                &deck.opponent[2].name,
                Deck.countScore(deck.opponent),
                colorToANSI(deck.discard.color),
                &deck.discard.name,
                deck.stock.len - deck.used,
                colorToANSI(deck.player[0].color),
                &deck.player[0].name,
                colorToANSI(deck.player[1].color),
                &deck.player[1].name,
                colorToANSI(deck.player[2].color),
                &deck.player[2].name,
                Deck.countScore(deck.player),
            }) catch err.termIOError();
        }

        pub fn writePrompt(self: *@This(), comptime prompt: []const u8) void {
            const w = self.bw.writer();
            w.writeAll(prompt ++ "\n> ") catch err.termIOError();
        }

        pub fn writeAIAction(self: *@This(), actionMsg: []const u8) void {
            const w = self.bw.writer();
            w.print("AI> {s}\n", .{actionMsg}) catch err.termIOError();
        }

        pub fn writeCard(self: *@This(), card: Deck.Card) void {
            const w = self.bw.writer();
            w.print("Card is \x1b[{s}m{s}\x1b[0m.\n", .{
                colorToANSI(card.color),
                &card.name,
            }) catch err.termIOError();
        }

        //
        // Input
        //

        pub fn inputAction(self: *@This()) ActionError!u8 {
            self.flush(); // Output previous characters
            const r = self.br.reader();

            const action = r.readByte() catch |e| switch (e) {
                error.EndOfStream => return error.WantsExit, // Ctrl+d
                else => err.termIOError(),
            };

            if (action == '\n') return error.Nothing; // Empty line

            const after = r.readByte() catch err.termIOError(); // Ctrl+d impossible as input already in buffer

            if (after != '\n') {
                r.skipUntilDelimiterOrEof('\n') catch err.termIOError();
                return error.TooMany;
            }

            return action;
        }

        pub fn getAction(
            self: *@This(),
            comptime accept: []const u8,
            comptime prompt: []const u8,
            comptime help: []const u8,
        ) ?u8 {
            self.writePrompt(prompt);

            while (true) {
                const actionsStr = ": " ++ help;

                const action = self.inputAction() catch |e| {
                    switch (e) {
                        error.WantsExit => return null,
                        error.Nothing => self.writePrompt("Write a action" ++ actionsStr),
                        error.TooMany => self.writePrompt("Only one action" ++ actionsStr),
                    }

                    continue;
                };

                for (accept) |acc| if (action == acc) return action;
                self.writePrompt("Invalid action" ++ actionsStr);
            }
        }
    };
}
