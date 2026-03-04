const std = @import("std");

const random = @import("prng.zig");
const console = @import("console.zig");

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

    var game = Scat().init(&io, rand);
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

pub fn Scat() type {
    return struct {
        //
        // Display
        //

        pub const Screen = struct {
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
        };

        //
        // Deck
        //

        pub const Deck = struct {
            pub const Type = enum(u8) {
                Diamond,
                Heart,
                Spade,
                Club,
            };

            pub const Card = struct {
                name: [2]u8,
                color: Type,
                value: u8,
            };

            pub fn countScore(cards: [3]Card) u64 {
                var total = std.mem.zeroes([@typeInfo(Type).@"enum".fields.len]u64);
                for (cards) |c| total[@intFromEnum(c.color)] += c.value;
                return std.mem.max(u64, &total);
            }

            player: [3]Card,
            opponent: [3]Card,
            discard: Card,

            stock: [45]Card,
            used: usize,

            pub fn init(rand: std.Random) @This() {
                var mem: [52]Card = undefined;
                @memcpy(&mem, &deck52);
                rand.shuffle(Card, &mem);

                return .{
                    .player = mem[0..3].*,
                    .opponent = mem[3..6].*,
                    .discard = mem[6],
                    .stock = mem[7..].*,
                    .used = 0,
                };
            }

            pub fn peekStock(self: @This()) ?Card {
                if (self.used >= self.stock.len) return null;
                return self.stock[self.used];
            }

            pub fn getPlayerScore(self: @This()) u64 {
                return countScore(self.player);
            }

            pub fn playerTakeStock(self: *@This(), chIdx: usize) void {
                self.takeStock(&self.player, chIdx);
            }

            pub fn playerTakeDiscard(self: *@This(), chIdx: usize) void {
                self.takeDiscard(&self.player, chIdx);
            }

            pub fn getOpponentScore(self: @This()) u64 {
                return countScore(self.opponent);
            }

            pub fn opponentTakeStock(self: *@This(), chIdx: usize) void {
                self.takeStock(&self.opponent, chIdx);
            }

            pub fn opponentTakeDiscard(self: *@This(), chIdx: usize) void {
                self.takeDiscard(&self.opponent, chIdx);
            }

            fn takeStock(self: *@This(), cards: *[3]Card, chIdx: usize) void {
                const discarded = self.discard; // Will be "deleted" (out of reach)

                if (chIdx >= 3) {
                    self.discard = self.stock[self.used];
                } else {
                    self.discard = cards[chIdx];
                    cards[chIdx] = self.stock[self.used];
                }

                self.stock[self.used] = discarded;
                self.used += 1;
            }

            fn takeDiscard(self: *@This(), cards: *[3]Card, chIdx: usize) void {
                std.mem.swap(Card, &cards[chIdx], &self.discard);
            }

            const deck52 = [_]Card{
                .{ .name = .{ '0', '2' }, .color = Type.Diamond, .value = 2 },
                .{ .name = .{ '0', '3' }, .color = Type.Diamond, .value = 3 },
                .{ .name = .{ '0', '4' }, .color = Type.Diamond, .value = 4 },
                .{ .name = .{ '0', '5' }, .color = Type.Diamond, .value = 5 },
                .{ .name = .{ '0', '6' }, .color = Type.Diamond, .value = 6 },
                .{ .name = .{ '0', '7' }, .color = Type.Diamond, .value = 7 },
                .{ .name = .{ '0', '8' }, .color = Type.Diamond, .value = 8 },
                .{ .name = .{ '0', '9' }, .color = Type.Diamond, .value = 9 },
                .{ .name = .{ '1', '0' }, .color = Type.Diamond, .value = 10 },
                .{ .name = .{ 'J', 'J' }, .color = Type.Diamond, .value = 10 },
                .{ .name = .{ 'Q', 'Q' }, .color = Type.Diamond, .value = 10 },
                .{ .name = .{ 'K', 'K' }, .color = Type.Diamond, .value = 10 },
                .{ .name = .{ 'A', 'A' }, .color = Type.Diamond, .value = 11 },

                .{ .name = .{ '0', '2' }, .color = Type.Heart, .value = 2 },
                .{ .name = .{ '0', '3' }, .color = Type.Heart, .value = 3 },
                .{ .name = .{ '0', '4' }, .color = Type.Heart, .value = 4 },
                .{ .name = .{ '0', '5' }, .color = Type.Heart, .value = 5 },
                .{ .name = .{ '0', '6' }, .color = Type.Heart, .value = 6 },
                .{ .name = .{ '0', '7' }, .color = Type.Heart, .value = 7 },
                .{ .name = .{ '0', '8' }, .color = Type.Heart, .value = 8 },
                .{ .name = .{ '0', '9' }, .color = Type.Heart, .value = 9 },
                .{ .name = .{ '1', '0' }, .color = Type.Heart, .value = 10 },
                .{ .name = .{ 'J', 'J' }, .color = Type.Heart, .value = 10 },
                .{ .name = .{ 'Q', 'Q' }, .color = Type.Heart, .value = 10 },
                .{ .name = .{ 'K', 'K' }, .color = Type.Heart, .value = 10 },
                .{ .name = .{ 'A', 'A' }, .color = Type.Heart, .value = 11 },

                .{ .name = .{ '0', '2' }, .color = Type.Spade, .value = 2 },
                .{ .name = .{ '0', '3' }, .color = Type.Spade, .value = 3 },
                .{ .name = .{ '0', '4' }, .color = Type.Spade, .value = 4 },
                .{ .name = .{ '0', '5' }, .color = Type.Spade, .value = 5 },
                .{ .name = .{ '0', '6' }, .color = Type.Spade, .value = 6 },
                .{ .name = .{ '0', '7' }, .color = Type.Spade, .value = 7 },
                .{ .name = .{ '0', '8' }, .color = Type.Spade, .value = 8 },
                .{ .name = .{ '0', '9' }, .color = Type.Spade, .value = 9 },
                .{ .name = .{ '1', '0' }, .color = Type.Spade, .value = 10 },
                .{ .name = .{ 'J', 'J' }, .color = Type.Spade, .value = 10 },
                .{ .name = .{ 'Q', 'Q' }, .color = Type.Spade, .value = 10 },
                .{ .name = .{ 'K', 'K' }, .color = Type.Spade, .value = 10 },
                .{ .name = .{ 'A', 'A' }, .color = Type.Spade, .value = 11 },

                .{ .name = .{ '0', '2' }, .color = Type.Club, .value = 2 },
                .{ .name = .{ '0', '3' }, .color = Type.Club, .value = 3 },
                .{ .name = .{ '0', '4' }, .color = Type.Club, .value = 4 },
                .{ .name = .{ '0', '5' }, .color = Type.Club, .value = 5 },
                .{ .name = .{ '0', '6' }, .color = Type.Club, .value = 6 },
                .{ .name = .{ '0', '7' }, .color = Type.Club, .value = 7 },
                .{ .name = .{ '0', '8' }, .color = Type.Club, .value = 8 },
                .{ .name = .{ '0', '9' }, .color = Type.Club, .value = 9 },
                .{ .name = .{ '1', '0' }, .color = Type.Club, .value = 10 },
                .{ .name = .{ 'J', 'J' }, .color = Type.Club, .value = 10 },
                .{ .name = .{ 'Q', 'Q' }, .color = Type.Club, .value = 10 },
                .{ .name = .{ 'K', 'K' }, .color = Type.Club, .value = 10 },
                .{ .name = .{ 'A', 'A' }, .color = Type.Club, .value = 11 },
            };
        };

        //
        // AI
        //

        pub const Move = struct {
            action: u8,
            cardIdx: usize,

            pub fn bestMove(deck: Deck) Move {
                if (deck.opponent[0].color == deck.opponent[1].color and deck.opponent[0].color == deck.opponent[2].color) {
                    return .{ .action = 'K', .cardIdx = 0 };
                }

                return bestMoveNoKnock(deck);
            }

            pub fn bestMoveNoKnock(deck: Deck) Move {
                var scores: [7]u64 = std.mem.zeroes([7]u64);

                scores[0] = Deck.countScore(.{ deck.discard, deck.opponent[1], deck.opponent[2] });
                scores[1] = Deck.countScore(.{ deck.opponent[0], deck.discard, deck.opponent[2] });
                scores[2] = Deck.countScore(.{ deck.opponent[0], deck.opponent[1], deck.discard });

                if (deck.peekStock()) |topStock| {
                    scores[3] = Deck.countScore(.{ topStock, deck.opponent[1], deck.opponent[2] });
                    scores[4] = Deck.countScore(.{ deck.opponent[0], topStock, deck.opponent[2] });
                    scores[5] = Deck.countScore(.{ deck.opponent[0], deck.opponent[1], topStock });
                }

                scores[6] = Deck.countScore(deck.opponent);

                const maxIdx = std.mem.indexOfMax(u64, &scores);

                if (maxIdx < 3) {
                    return .{ .action = 'D', .cardIdx = maxIdx };
                }

                // Best must be from taking stock
                return .{ .action = 'S', .cardIdx = maxIdx - 3 };
            }
        };

        //
        // Game Logic
        //

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

        fn getBestAIMove(self: @This()) Move {
            return Move.bestMove(self.deck);
        }

        fn getBestAIMoveNoKnock(self: @This()) Move {
            return Move.bestMoveNoKnock(self.deck);
        }

        fn writeResults(self: *@This()) void {
            const player = self.deck.getPlayerScore();
            const opponent = self.deck.getOpponentScore();

            self.screen.writeResults(player, opponent);
        }
    };
}
