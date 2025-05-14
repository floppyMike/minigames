const std = @import("std");
const err = @import("error.zig");

const Location = struct { x: u64, y: u64 };
const PieceType = enum { Tower, Horse, Bishop, Queen, King, Pawn };
const PlayerType = enum { Human, AI };

const Piece = struct {
    type: PieceType,
    player: PlayerType,
};

pub fn Chess() type {
    return struct {
        const SIZE = 8;
        board: [SIZE * SIZE](?Piece),

        fn getLoc(x: u64, y: u64) u64 {
            std.debug.assert(x < SIZE and y < SIZE);
            return SIZE * y + x;
        }

        fn createPawns(board: *[8](?Piece), playerType: Piece.PlayerType) void {
            @memset(board, .{ .type = .Pawn, .player = playerType });
        }

        fn createStart(board: *[8](?Piece), playerType: Piece.PlayerType) void {
            board[0] = .{ .type = .Tower, .player = playerType };
            board[1] = .{ .type = .Horse, .player = playerType };
            board[2] = .{ .type = .Bishop, .player = playerType };
            board[3] = .{ .type = .Queen, .player = playerType };
            board[4] = .{ .type = .King, .player = playerType };
            board[5] = .{ .type = .Bishop, .player = playerType };
            board[6] = .{ .type = .Horse, .player = playerType };
            board[7] = .{ .type = .Tower, .player = playerType };
        }

        pub fn init() @This() {
            var board: [8 * 8](?Piece) = undefined;
            createStart(board[getLoc(0, 0)..getLoc(7, 0)], .AI);
            createPawns(board[getLoc(0, 1)..getLoc(7, 1)], .AI);
            @memset(board[getLoc(0, 2)..getLoc(7, 5)], null);
            createStart(board[getLoc(0, 6)..getLoc(7, 6)], .Human);
            createPawns(board[getLoc(0, 7)..getLoc(7, 7)], .Human);

            return .{ .board = board };
        }

        pub fn printBoard(self: @This(), stdout: anytype) void {
            stdout.print(
                \\   +--+--+--+--+--+--+--+--+
                \\ 8 |{0c}{0c}|{1c}{1c}|{2c}{2c}|{3c}{3c}|{4c}{4c}|{5c}{5c}|{6c}{6c}|{7c}{7c}|
                \\   +--+--+--+--+--+--+--+--+
                \\ 7 |{8c}{8c}|{9c}{9c}|{10c}{10c}|{0c}{0c}|{0c}{0c}|{0c}{0c}|{0c}{0c}|{0c}{0c}|
                \\   +--+--+--+--+--+--+--+--+
                \\ 6 |{16c}{16c}|{17c}{17c}|{18c}{18c}|{19c}{19c}|{20c}{20c}|{21c}{21c}|{22c}{22c}|{23c}{23c}|
                \\   +--+--+--+--+--+--+--+--+
                \\ 5 |{24c}{24c}|{25c}{25c}|{26c}{26c}|{27c}{27c}|{28c}{28c}|{29c}{29c}|{30c}{30c}|{31c}{31c}|
                \\   +--+--+--+--+--+--+--+--+
                \\ 4 |{32c}{32c}|{33c}{33c}|{34c}{34c}|{35c}{35c}|{36c}{36c}|{37c}{37c}|{38c}{38c}|{39c}{39c}|
                \\   +--+--+--+--+--+--+--+--+
                \\ 3 |{40c}{40c}|{41c}{41c}|{42c}{42c}|{43c}{43c}|{44c}{44c}|{45c}{45c}|{46c}{46c}|{47c}{47c}|
                \\   +--+--+--+--+--+--+--+--+
                \\ 2 |{48c}{48c}|{49c}{49c}|{50c}{50c}|{51c}{51c}|{52c}{52c}|{53c}{53c}|{54c}{54c}|{55c}{55c}|
                \\   +--+--+--+--+--+--+--+--+
                \\ 1 |{56c}{56c}|{57c}{57c}|{58c}{58c}|{59c}{59c}|{60c}{60c}|{61c}{61c}|{62c}{62c}|{63c}{63c}|
                \\   +--+--+--+--+--+--+--+--+
                \\     a  b  c  d  e  f  g  h
                , self.board);
        }
    };
}

pub fn run(
    stdoutFile: anytype,
    stdinFile: anytype,
    rand: std.Random,
) void {
    var game = Chess().init();
    var state: PlayerType = .Human;

    while (true) {
        switch (state) {
            .Human => {}
            .AI => {}
        }
    }
}
