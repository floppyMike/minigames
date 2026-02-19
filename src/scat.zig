const std = @import("std");

const random = @import("prng.zig");
const console = @import("console.zig");

const Deck = @import("scat/deck.zig");
const Screen = @import("scat/screen.zig");
const ai = @import("scat/ai.zig");

const State = enum {
    Player,
    Opponent,
    KnockPlayer,
    KnockOpponent,
};

pub fn run() void {
    var prng = random.init();
    const rand = prng.random();

    var bufout: [512]u8 = undefined;
    var bufin: [512]u8 = undefined;
    var io = console.init(&bufout, &bufin);
    defer io.flush();

    var game = init(&io, rand);
    var state: State = .Player;

    while (true) {
        game.writeBoard();

        switch (state) {
            .Player => {
                switch (game.getPlayerAction() orelse return) {
                    'S' => game.playerTakeStock(),
                    'D' => game.playerTakeDicard(),
                    else => unreachable,

                    'K' => {
                        state = .KnockOpponent;
                        continue;
                    },
                }

                state = .Opponent;
            },

            .KnockPlayer => {
                switch (game.getPlayerActionNoKnock() orelse return) {
                    'S' => game.playerTakeStock(),
                    'D' => game.playerTakeDicard(),
                    else => unreachable,
                }

                break;
            },

            .Opponent => {
                const bestMove = game.getBestAIMove();

                switch (bestMove.action) {
                    'S' => game.opponentTakeStock(bestMove.cardIdx),
                    'D' => game.opponentTakeDiscard(bestMove.cardIdx),
                    else => unreachable,

                    'K' => {
                        game.opponentKnocks();
                        state = .KnockPlayer;
                        continue;
                    },
                }

                state = .Player;
            },

            .KnockOpponent => {
                const bestMove = game.getBestAIMoveNoKnock();

                switch (bestMove.action) {
                    'S' => game.opponentTakeStock(bestMove.cardIdx),
                    'D' => game.opponentTakeDiscard(bestMove.cardIdx),
                    else => unreachable,
                }

                break;
            },
        }
    }

    game.writeCheatBoard();
    game.writeResults();
}

screen: Screen,
deck: Deck,

fn init(io: *console, rand: std.Random) @This() {
    var game = @This(){
        .deck = Deck.init(rand),
        .screen = Screen.init(io),
    };

    game.screen.printAIAction("Dealt the cards.", .{});

    return game;
}

fn writeBoard(self: *@This()) void {
    self.screen.writeBoard(self.deck);
}

fn writeCheatBoard(self: *@This()) void {
    self.screen.writeCheatBoard(self.deck);
}

fn getPlayerActionNoKnock(self: *@This()) ?u8 {
    const prompt: []const u8 = "Select a action to take.";
    return if (self.deck.peekStock() == null) self.screen.getAction(
        &.{'D'},
        prompt,
        "D (Draw Discard)",
    ) else self.screen.getAction(
        &.{ 'D', 'S' },
        prompt,
        "S/D (Draw Stock/Draw Discard)",
    );
}

fn getPlayerAction(self: *@This()) ?u8 {
    const prompt: []const u8 = "Select a action to take.";
    return if (self.deck.peekStock() == null) self.screen.getAction(
        &.{ 'K', 'D' },
        prompt,
        "K/D (Knock/Draw Discard)",
    ) else self.screen.getAction(
        &.{ 'K', 'D', 'S' },
        prompt,
        "S/K/D (Draw Stock/Knock/Draw Discard)",
    );
}

fn playerTakeStock(self: *@This()) void {
    const takenCard = self.deck.peekStock() orelse unreachable; // getPlayerAction shouldn't give access.
    self.screen.writeCard(takenCard);
    const cardIdx = self.screen.getAction(
        &.{ '1', '2', '3', '4' },
        "Select card in hand to swap out with or itself to discard.",
        "1/2/3/4 (1,2,3: In Hand / 4: Taken card)",
    ) orelse return;

    self.deck.playerTakeStock((std.fmt.charToDigit(cardIdx, 10) catch unreachable) - 1);
}

fn playerTakeDicard(self: *@This()) void {
    self.screen.writeCard(self.deck.discard);
    const cardIdx = self.screen.getAction(
        &.{ '1', '2', '3' },
        "Select card in hand to swap out with.",
        "1/2/3 (In Hand)",
    ) orelse return;

    self.deck.playerTakeDiscard((std.fmt.charToDigit(cardIdx, 10) catch unreachable) - 1);
}

fn opponentTakeStock(self: *@This(), cardIdx: usize) void {
    self.deck.opponentTakeStock(cardIdx);
    self.screen.printAIAction("Took a card from stock.", .{});
    self.screen.printAIAction("Swapped stock card with {d}.", .{cardIdx});
}

fn opponentTakeDiscard(self: *@This(), cardIdx: usize) void {
    self.deck.opponentTakeDiscard(cardIdx);
    self.screen.printAIAction("Took a card from discard.", .{});
}

fn opponentKnocks(self: *@This()) void {
    self.screen.printAIAction("Knocks", .{});
}

fn getBestAIMove(self: @This()) ai.Move {
    return ai.bestMove(self.deck);
}

fn getBestAIMoveNoKnock(self: @This()) ai.Move {
    return ai.bestMoveNoKnock(self.deck);
}

fn writeResults(self: *@This()) void {
    const player = self.deck.getPlayerScore();
    const opponent = self.deck.getOpponentScore();

    self.screen.writeResults(player, opponent);
}
