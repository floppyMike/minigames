const std = @import("std");

const console = @import("../console.zig");
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

io: *console,

//
// Output
//

pub fn init(io: *console) @This() {
    return @This(){ .io = io };
}

pub fn writeBoard(self: *@This(), deck: Deck) void {
    self.io.print(gameBoard, .{
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
    });
}

pub fn writeCheatBoard(self: *@This(), deck: Deck) void {
    self.io.print(cheatBoard, .{
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
    });
}

pub fn printPrompt(self: *@This(), comptime fmt: []const u8, items: anytype) void {
    self.io.print(fmt ++ "\n> ", items);
}

pub fn printAIAction(self: *@This(), comptime fmt: []const u8, items: anytype) void {
    self.io.print("AI> " ++ fmt ++ "\n", items);
}

pub fn writeCard(self: *@This(), card: Deck.Card) void {
    self.io.print("Card is \x1b[{s}m{s}\x1b[0m.\n", .{
        colorToANSI(card.color),
        &card.name,
    });
}

pub fn writeResults(self: *@This(), playerScore: u64, opponentScore: u64) void {
    const winMsg = if (playerScore > opponentScore) "You Win!" else if (playerScore < opponentScore) "You Lose!" else "Tie!";

    self.io.print("Player: {d}\nOpponent: {d}\n=> {s}\n", .{
        playerScore,
        opponentScore,
        winMsg,
    });
}

//
// Input
//

pub fn getAction(
    self: *@This(),
    comptime accept: []const u8,
    comptime prompt: []const u8,
    comptime help: []const u8,
) ?u8 {
    self.printPrompt(prompt, .{});

    while (true) {
        const actionsStr = ": " ++ help;

        const action = blk: {
            self.io.flush();

            const action = self.io.readByte() catch break :blk error.WantsExit;
            if (action == '\n') break :blk error.Nothing; // Empty line

            const after = self.io.readByte() catch break :blk error.WantsExit;

            if (after != '\n') {
                self.io.skipLine() catch break :blk error.WantsExit; // Clean up line
                break :blk error.TooMany;
            }

            break :blk action;
        } catch |e| {
            switch (e) {
                error.WantsExit => return null,
                error.Nothing => self.printPrompt("Write a action" ++ actionsStr, .{}),
                error.TooMany => self.printPrompt("Only one action" ++ actionsStr, .{}),
            }

            continue;
        };

        for (accept) |acc| if (action == acc) return action;
        self.printPrompt("Invalid action" ++ actionsStr, .{});
    }
}
