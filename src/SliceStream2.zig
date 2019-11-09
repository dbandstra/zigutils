// this variation was suggested by tgschultz here:
// https://github.com/ziglang/zig/issues/1815

const std = @import("std");

pub fn SliceSeekableStream(comptime SliceStream: type) type {
  return struct{
    const Self = @This();
    pub const SeekError = error{SliceSeekOutOfBounds};
    pub const GetSeekPosError = error{};
    pub const Stream = std.io.SeekableStream(SeekError, GetSeekPosError);

    stream: Stream,

    ss: *SliceStream,

    pub fn init(ss: *SliceStream) Self {
      return Self{
        .ss = ss,
        .stream = Stream{
          .seekToFn = seekToFn,
          .seekByFn = seekByFn,
          .getEndPosFn = getEndPosFn,
          .getPosFn = getPosFn,
        },
      };
    }

    fn seekToFn(seekable_stream: *Stream, pos: u64) SeekError!void {
      const self = @fieldParentPtr(Self, "stream", seekable_stream);

      // FIXME - are you supposed to be able to seek past the end without an error?
      // i suppose it would only fail if you tried to read at that point?

      const usize_pos = std.math.cast(usize, pos) catch return SeekError.SliceSeekOutOfBounds;

      if (usize_pos < self.ss.slice.len) {
        self.ss.pos = usize_pos;
      } else {
        return SeekError.SliceSeekOutOfBounds;
      }
    }

    fn seekByFn(seekable_stream: *Stream, amt: i64) SeekError!void {
      const self = @fieldParentPtr(Self, "stream", seekable_stream);

      if (amt > 0) {
        const uofs = std.math.cast(usize, amt) catch return SeekError.SliceSeekOutOfBounds;

        if (self.ss.pos + uofs <= self.ss.slice.len) {
          self.ss.pos += uofs;
        } else {
          return SeekError.SliceSeekOutOfBounds;
        }
      } else if (amt < 0) {
        const uofs = std.math.cast(usize, -amt) catch return SeekError.SliceSeekOutOfBounds;

        if (self.ss.pos >= uofs) {
          self.ss.pos -= uofs;
        } else {
          return SeekError.SliceSeekOutOfBounds;
        }
      }
    }

    fn getEndPosFn(seekable_stream: *Stream) GetSeekPosError!u64 {
      const self = @fieldParentPtr(Self, "stream", seekable_stream);

      return @intCast(usize, self.ss.slice.len);
    }

    fn getPosFn(seekable_stream: *Stream) GetSeekPosError!u64 {
      const self = @fieldParentPtr(Self, "stream", seekable_stream);

      return @intCast(usize, self.ss.pos);
    }
  };
}

test "SliceStream2: source buffer smaller than read buffer" {
  var sis = std.io.SliceInStream.init("Hello world");

  var dest_buf: [100]u8 = undefined;

  // unfortunately, you have to `try`, even though this function never throws
  const br0 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br0], "Hello world"));
}

test "SliceStream2: source buffer longer than read buffer" {
  var sis = std.io.SliceInStream.init("Between 15 and 20.");

  var dest_buf: [5]u8 = undefined;

  const br0 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br0], "Betwe"));

  const br1 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br1], "en 15"));

  const br2 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br2], " and "));

  const br3 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br3], "20."));

  const br4 = try sis.stream.read(dest_buf[0..]);
  std.testing.expectEqual(@as(usize, 0), br4);
}

test "SliceStream2: seeking around" {
  var sis = std.io.SliceInStream.init("This is a decently long sentence.");
  var sss = SliceSeekableStream(std.io.SliceInStream).init(&sis);

  var dest_buf: [5]u8 = undefined;

  const br0 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br0], "This "));

  try sss.stream.seekBy(3);
  const br1 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br1], "a dec"));

  try sss.stream.seekBy(-2);
  const br2 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br2], "ecent"));

  try sss.stream.seekBy(0);
  const cur_pos = try sss.stream.getPos();
  std.testing.expectEqual(@as(usize, 16), cur_pos);

  try sss.stream.seekTo(1);
  const br3 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br3], "his i"));

  try sss.stream.seekTo(sis.slice.len - 3);
  const br4 = try sis.stream.read(dest_buf[0..]);
  std.testing.expect(std.mem.eql(u8, dest_buf[0..br4], "ce."));

  std.testing.expectError(error.SliceSeekOutOfBounds, sss.stream.seekTo(999));
  std.testing.expectError(error.SliceSeekOutOfBounds, sss.stream.seekBy(-999));
}
