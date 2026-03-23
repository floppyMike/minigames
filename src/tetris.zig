const c = @import("c.zig").c;

const std = @import("std");
const mth = @import("math.zig");
const scn = @import("curses.zig");
const err = @import("error.zig");
const utl = @import("util.zig");
const rng = @import("prng.zig");
const trm = @import("console.zig");

const Screen = scn.Curses(30, 22, 2);
const WP = Screen.WorldPixel;

pub fn run(ctx: *err.CriticalErrorContext) err.CriticalError!void {
    const stats = try rungame(ctx);

    var bufout: [512]u8 = undefined;
    var bufin: [512]u8 = undefined;
    var io = trm.init(&bufout, &bufin);
    defer io.flush();

    io.print("Lines cleared: {d}\n", .{stats.linesCleared});
}

pub fn rungame(ctx: *err.CriticalErrorContext) err.CriticalError!Tetris.Stats {
    var prng = rng.init();
    const rand = prng.random();

    var screen = try Screen.init(ctx);
    defer screen.deinit();

    var game = Tetris.init(rand) orelse return error.ScreenToSmall;
    var stats = Tetris.Stats.init();

    var i: u64 = 0;
    while (true) : (i += 1) {
        const ch = scn.getInputNonBlocking();

        switch (ch) {
            'q' => break,

            c.KEY_UP => game.rotate(),

            c.KEY_LEFT => game.playerSide(-1),
            c.KEY_RIGHT => game.playerSide(1),

            else => {},
        }

        screen.clear();
        game.render(screen, stats);
        screen.refresh();

        std.Thread.sleep(std.time.ns_per_ms * 32);

        if (i % 4 == 0) game.playerDown() orelse {
            const lines = game.place(rand) orelse break;
            stats.clearLines(lines);
        };
    }

    return stats;
}

const Tetris = struct {
    blocks: utl.StaticSet(WP, Screen.worldarea),
    player: Player,

    pub fn init(rand: std.Random) ?@This() {
        return .{
            .blocks = .init(),
            .player = Player.spawn(Player.randomPiece(rand)) catch return null,
        };
    }

    pub fn rotate(self: *@This()) void {
        self.player = self.player.rotate() catch return;
    }

    pub fn playerDown(self: *@This()) ?void {
        const np = self.player.move(0, 1) catch return null;
        if (self.doesCollide(&np.body)) return null;
        self.player = np;
    }

    pub fn doesCollide(self: @This(), array: []const WP) bool {
        for (self.blocks.slice()) |b| for (array) |p| {
            if (std.meta.eql(b, p)) return true;
        };

        return false;
    }

    pub fn playerSide(self: *@This(), dx: i64) void {
        self.player = self.player.move(dx, 0) catch return;
    }

    pub fn place(self: *@This(), rand: std.Random) ?u64 {
        self.blocks.append(&self.player.body) catch unreachable;
        const cleared = self.clearBoard();
        self.player = Player.spawn(Player.randomPiece(rand)) catch unreachable;
        if (self.doesCollide(&self.player.body)) return null;
        return cleared;
    }

    pub fn clearBoard(self: *@This()) u64 {
        var count = std.mem.zeroes([Screen.worldrows]u64);
        for (self.blocks.slice()) |b| count[@intCast(b.y)] += 1;

        var downShift: u64 = 0;
        var y: usize = Screen.worldrows;
        while (y > 0) {
            y -= 1;
            if (count[y] == Screen.worldcols) {
                downShift += 1;
            } else {
                count[y] = downShift;
            }
        }

        var i: usize = 0;
        while (i < self.blocks.len) {
            const blocks = self.blocks.slice();
            const y_idx: usize = @intCast(blocks[i].y);
            if (count[y_idx] == Screen.worldcols) {
                self.blocks.remove(i) catch unreachable;
            } else {
                blocks[i].y += @intCast(count[y_idx]);
                i += 1;
            }
        }

        return downShift;
    }

    pub fn render(self: @This(), screen: Screen, stats: Stats) void {
        screen.writeTitle("Tetris");
        screen.writeSubtitleArgs("Lines cleared: %lu", .{stats.linesCleared});

        self.player.render(screen);
        for (self.blocks.slice()) |b| screen.drawPixel(b, c.NCURSES_ACS('0'));
    }

    const Stats = struct {
        linesCleared: u64,

        pub fn init() @This() {
            return .{ .linesCleared = 0 };
        }

        pub fn clearLines(self: *@This(), lines: u64) void {
            self.linesCleared += lines;
        }
    };

    const Player = struct {
        pub const bodyAmount = 4;
        const LocalPixel = mth.Pixel(bodyAmount, bodyAmount);

        const PieceMap = struct {
            body: [bodyAmount * bodyAmount]u8,
            width: i64,
        };

        const Piece = struct {
            body: [bodyAmount]LocalPixel,
            width: i64,
        };

        fn mapToBody(comptime bmap: []const PieceMap) [bmap.len]Piece {
            var bpixel: [bmap.len]Piece = undefined;
            for (bmap, &bpixel) |mapPiece, *pixelPiece| {
                var used = 0;
                for (0..(bodyAmount * bodyAmount)) |ii| {
                    if (mapPiece.body[ii] == 1) {
                        pixelPiece.body[used] = LocalPixel.fromLinearPos(ii) catch unreachable; // We are iterating entire body
                        used += 1;
                    }
                }

                pixelPiece.width = mapPiece.width;
            }

            return bpixel;
        }

        const bodies = mapToBody(&[_]PieceMap{
            .{ .body = .{
                0, 1, 0, 0,
                0, 1, 1, 0,
                0, 1, 0, 0,
                0, 0, 0, 0,
            }, .width = 3 },
            .{ .body = .{
                0, 1, 1, 0,
                0, 1, 0, 0,
                0, 1, 0, 0,
                0, 0, 0, 0,
            }, .width = 3 },
            .{ .body = .{
                1, 1, 0, 0,
                0, 1, 0, 0,
                0, 1, 0, 0,
                0, 0, 0, 0,
            }, .width = 3 },
            .{ .body = .{
                0, 1, 0, 0,
                0, 1, 0, 0,
                0, 1, 0, 0,
                0, 1, 0, 0,
            }, .width = 4 },
            .{ .body = .{
                0, 1, 0, 0,
                1, 1, 0, 0,
                1, 0, 0, 0,
                0, 0, 0, 0,
            }, .width = 3 },
            .{ .body = .{
                1, 0, 0, 0,
                1, 1, 0, 0,
                0, 1, 0, 0,
                0, 0, 0, 0,
            }, .width = 3 },
            .{ .body = .{
                1, 1, 0, 0,
                1, 1, 0, 0,
                0, 0, 0, 0,
                0, 0, 0, 0,
            }, .width = 2 },
        });

        pub fn randomPiece(rand: std.Random) Piece {
            return bodies[rand.intRangeLessThan(usize, 0, bodies.len)];
        }

        pos: mth.Delta,
        body: [bodyAmount]WP,
        width: i64,

        pub fn init(pos: mth.Delta, body: [bodyAmount]WP, width: i64) @This() {
            return .{ .pos = pos, .body = body, .width = width };
        }

        pub fn spawn(piece: Piece) !@This() {
            const pos = mth.Delta.init((Screen.worldcols - bodyAmount) / 2, 0);

            var body: [bodyAmount]WP = undefined;
            for (piece.body, &body) |l, *w| w.* = WP.init(l.x + pos.dx, l.y + pos.dy) catch unreachable;

            return .init(pos, body, piece.width);
        }

        pub fn move(self: @This(), dx: i64, dy: i64) !@This() {
            const pos = self.pos.shift(mth.Delta.init(dx, dy));

            var world: [bodyAmount]WP = undefined;
            for (self.body, &world) |b, *w| w.* = try b.shift(dx, dy);

            return .init(pos, world, self.width);
        }

        pub fn rotate(self: @This()) !@This() {
            var body: [bodyAmount]WP = undefined;
            for (self.body, &body) |b, *nb| nb.* = WP.init(
                self.width - (b.y - self.pos.dy) - 1 + self.pos.dx,
                (b.x - self.pos.dx) + self.pos.dy,
            ) catch unreachable;

            return .init(self.pos, body, self.width);
        }

        pub fn render(self: @This(), screen: Screen) void {
            for (self.body) |b| screen.drawPixel(b, c.NCURSES_ACS('0'));
        }
    };
};
