const std = @import("std");
const Deck = @import("deck.zig");

pub const Move = struct {
    action: u8,
    cardIdx: usize,
};

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
