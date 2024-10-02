const std = @import("std");

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
    var total = std.mem.zeroes([@typeInfo(Type).Enum.fields.len]u64);
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
