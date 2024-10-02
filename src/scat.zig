const std = @import("std");

const err = @import("error.zig");

const Deck = @import("scat/deck.zig");
const Screen = @import("scat/screen.zig");
const ai = @import("scat/ai.zig");

const State = enum {
    Player,
    Opponent,
    KnockPlayer,
    KnockOpponent,
};

pub fn Scat(Out: type, In: type) type {
    return struct {
        screen: Screen.Screen(Out, In),
        deck: Deck,

        pub fn init(out: Out, in: In) @This() {
            var prng = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                std.posix.getrandom(std.mem.asBytes(&seed)) catch err.failedToInitRandom();
                break :blk seed;
            });

            const rand = prng.random();

            var game = @This(){
                .deck = Deck.init(rand),
                .screen = .{
                    .bw = .{ .unbuffered_writer = out },
                    .br = .{ .unbuffered_reader = in },
                },
            };

            game.screen.writeAIAction("Dealt the cards.");

            return game;
        }

        pub fn writeBoard(self: *@This()) void {
            self.screen.writeBoard(self.deck);
        }

        pub fn writeCheatBoard(self: *@This()) void {
            self.screen.writeCheatBoard(self.deck);
        }

        pub fn getPlayerActionNoKnock(self: *@This()) ?u8 {
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

        pub fn getPlayerAction(self: *@This()) ?u8 {
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

        pub fn playerTakeStock(self: *@This()) void {
            const takenCard = self.deck.peekStock() orelse unreachable; // getPlayerAction shouldn't give access.
            self.screen.writeCard(takenCard);
            const cardIdx = self.screen.getAction(
                &.{ '1', '2', '3', '4' },
                "Select card in hand to swap out with or itself to discard.",
                "1/2/3/4 (1,2,3: In Hand / 4: Taken card)",
            ) orelse return;

            self.deck.playerTakeStock((std.fmt.charToDigit(cardIdx, 10) catch unreachable) - 1);
        }

        pub fn playerTakeDicard(self: *@This()) void {
            self.screen.writeCard(self.deck.discard);
            const cardIdx = self.screen.getAction(
                &.{ '1', '2', '3' },
                "Select card in hand to swap out with.",
                "1/2/3 (In Hand)",
            ) orelse return;

            self.deck.playerTakeDiscard((std.fmt.charToDigit(cardIdx, 10) catch unreachable) - 1);
        }

        pub fn opponentTakeStock(self: *@This(), cardIdx: usize) void {
            self.deck.opponentTakeStock(cardIdx);
            self.screen.writeAIAction("Took a card from stock.");
        }

        pub fn opponentTakeDiscard(self: *@This(), cardIdx: usize) void {
            self.deck.opponentTakeDiscard(cardIdx);
            self.screen.writeAIAction("Took a card from discard.");
        }

        pub fn opponentKnocks(self: *@This()) void {
            self.screen.writeAIAction("Knocks");
        }

        pub fn getBestAIMove(self: @This()) ai.Move {
            return ai.bestMove(self.deck);
        }

        pub fn getBestAIMoveNoKnock(self: @This()) ai.Move {
            return ai.bestMoveNoKnock(self.deck);
        }

        pub fn getPlayerScore(self: @This()) u64 {
            return self.deck.getPlayerScore();
        }

        pub fn getOpponentScore(self: @This()) u64 {
            return self.deck.getOpponentScore();
        }

        pub fn flush(self: *@This()) void {
            self.screen.flush();
        }
    };
}

pub fn run(
    stdoutFile: anytype,
    stdinFile: anytype,
) void {
    var game = Scat(@TypeOf(stdoutFile), @TypeOf(stdinFile))
        .init(stdoutFile, stdinFile);
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
    game.flush();

    const playerScore = game.getPlayerScore();
    const opponentScore = game.getOpponentScore();

    stdoutFile.print("Player: {d}\nOpponent: {d}\n=> {s}\n", .{
        playerScore,
        opponentScore,
        if (playerScore > opponentScore) "You Win!" else if (playerScore < opponentScore) "You Lose!" else "Tie!",
    }) catch err.termIOError();
}
