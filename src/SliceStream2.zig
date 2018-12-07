// this variation was suggested by tgschultz here:
// https://github.com/ziglang/zig/issues/1815

const std = @import("std");

pub fn SliceSeekableStream(comptime SliceStream: type) type {
  return struct{
    const Self = @This();
    pub const SeekError = error{SliceSeekOutOfBounds};
    pub const GetSeekPosError = error{};
    pub const Stream = std.io.SeekableStream(SeekError, GetSeekPosError);

    pub stream: Stream,

    ss: *SliceStream,

    pub fn init(ss: *SliceStream) Self {
      return Self{
        .ss = ss,
        .stream = Stream{
          .seekToFn = seekToFn,
          .seekForwardFn = seekForwardFn,
          .getEndPosFn = getEndPosFn,
          .getPosFn = getPosFn,
        },
      };
    }

    fn seekToFn(seekable_stream: *Stream, pos: usize) SeekError!void {
      const self = @fieldParentPtr(Self, "stream", seekable_stream);

      // FIXME - are you supposed to be able to seek past the end without an error?
      // i suppose it would only fail if you tried to read at that point?

      if (pos < self.ss.slice.len) {
        self.ss.pos = pos;
      } else {
        return SeekError.SliceSeekOutOfBounds;
      }
    }

    fn seekForwardFn(seekable_stream: *Stream, amt: isize) SeekError!void {
      const self = @fieldParentPtr(Self, "stream", seekable_stream);

      if (amt > 0) {
        const uofs = @intCast(usize, amt); // should never fail

        if (self.ss.pos + uofs <= self.ss.slice.len) {
          self.ss.pos += uofs;
        } else {
          return SeekError.SliceSeekOutOfBounds;
        }
      } else if (amt < 0) {
        const uofs = @intCast(usize, -amt); // should never fail

        if (self.ss.pos >= uofs) {
          self.ss.pos -= uofs;
        } else {
          return SeekError.SliceSeekOutOfBounds;
        }
      }
    }

    fn getEndPosFn(seekable_stream: *Stream) GetSeekPosError!usize {
      const self = @fieldParentPtr(Self, "stream", seekable_stream);

      return self.ss.slice.len;
    }

    fn getPosFn(seekable_stream: *Stream) GetSeekPosError!usize {
      const self = @fieldParentPtr(Self, "stream", seekable_stream);

      return self.ss.pos;
    }
  };
}

test "SliceStream2: source buffer smaller than read buffer" {
  var sis = std.io.SliceInStream.init("Hello world");

  var dest_buf: [100]u8 = undefined;

  // unfortunately, you have to `try`, even though this function never throws
  const br0 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "Hello world"));
}

test "SliceStream2: source buffer longer than read buffer" {
  var sis = std.io.SliceInStream.init("Between 15 and 20.");

  var dest_buf: [5]u8 = undefined;

  const br0 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "Betwe"));

  const br1 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br1], "en 15"));

  const br2 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br2], " and "));

  const br3 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br3], "20."));

  const br4 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(br4 == 0);
}

test "SliceStream2: seeking around" {
  var sis = std.io.SliceInStream.init("This is a decently long sentence.");
  var sss = SliceSeekableStream(std.io.SliceInStream).init(&sis);

  var dest_buf: [5]u8 = undefined;

  const br0 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "This "));

  try sss.stream.seekForward(3);
  const br1 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br1], "a dec"));

  try sss.stream.seekForward(-2);
  const br2 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br2], "ecent"));

  try sss.stream.seekForward(0);
  const cur_pos = try sss.stream.getPos();
  std.debug.assert(cur_pos == 16);

  try sss.stream.seekTo(1);
  const br3 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br3], "his i"));

  try sss.stream.seekTo(sis.slice.len - 3);
  const br4 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br4], "ce."));

  std.debug.assertError(sss.stream.seekTo(999), error.SliceSeekOutOfBounds);
  std.debug.assertError(sss.stream.seekForward(-999), error.SliceSeekOutOfBounds);
}
