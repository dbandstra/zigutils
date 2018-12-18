const std = @import("std");

// zig std provides a SliceInStream, as well as a SeekableStream trait, but I
// don't see any obvious way to use them together. so this is an experiment to
// create a new type of object which contains the slice and the cursor
// position. so it's an analogue to the File object for files.

// this needs a better name
pub const SliceWithCursor = struct{
  slice: []const u8,
  pos: usize,

  pub fn init(slice: []const u8) SliceWithCursor {
    return SliceWithCursor{
      .slice = slice,
      .pos = 0,
    };
  }
};

pub const SliceInStream2 = struct{
  const Self = @This();
  pub const Error = error{};
  pub const Stream = std.io.InStream(Error);

  pub stream: Stream,

  swc: *SliceWithCursor,

  pub fn init(swc: *SliceWithCursor) Self {
    return Self{
      .swc = swc,
      .stream = Stream{ .readFn = readFn },
    };
  }

  fn readFn(in_stream: *Stream, dest: []u8) Error!usize {
    const self = @fieldParentPtr(Self, "stream", in_stream);
    const size = std.math.min(dest.len, self.swc.slice.len - self.swc.pos);
    const end = self.swc.pos + size;

    std.mem.copy(u8, dest[0..size], self.swc.slice[self.swc.pos..end]);
    self.swc.pos = end;

    return size;
  }
};

pub const SliceSeekableStream = struct{
  const Self = @This();
  pub const SeekError = error{SliceSeekOutOfBounds};
  pub const GetSeekPosError = error{};
  pub const Stream = std.io.SeekableStream(SeekError, GetSeekPosError);

  pub stream: Stream,

  swc: *SliceWithCursor,

  pub fn init(swc: *SliceWithCursor) Self {
    return Self{
      .swc = swc,
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

    if (pos < self.swc.slice.len) {
      self.swc.pos = pos;
    } else {
      return SeekError.SliceSeekOutOfBounds;
    }
  }

  fn seekForwardFn(seekable_stream: *Stream, amt: isize) SeekError!void {
    const self = @fieldParentPtr(Self, "stream", seekable_stream);

    if (amt > 0) {
      const uofs = @intCast(usize, amt); // should never fail

      if (self.swc.pos + uofs <= self.swc.slice.len) {
        self.swc.pos += uofs;
      } else {
        return SeekError.SliceSeekOutOfBounds;
      }
    } else if (amt < 0) {
      const uofs = @intCast(usize, -amt); // should never fail

      if (self.swc.pos >= uofs) {
        self.swc.pos -= uofs;
      } else {
        return SeekError.SliceSeekOutOfBounds;
      }
    }
  }

  fn getEndPosFn(seekable_stream: *Stream) GetSeekPosError!usize {
    const self = @fieldParentPtr(Self, "stream", seekable_stream);

    return self.swc.slice.len;
  }

  fn getPosFn(seekable_stream: *Stream) GetSeekPosError!usize {
    const self = @fieldParentPtr(Self, "stream", seekable_stream);

    return self.swc.pos;
  }
};

test "SliceStream: source buffer smaller than read buffer" {
  var swc = SliceWithCursor.init("Hello world");
  var sis = SliceInStream2.init(&swc);

  var dest_buf: [100]u8 = undefined;

  // unfortunately, you have to `try`, even though this function never throws
  const br0 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "Hello world"));
}

test "SliceStream: source buffer longer than read buffer" {
  var swc = SliceWithCursor.init("Between 15 and 20.");
  var sis = SliceInStream2.init(&swc);

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

test "SliceStream: seeking around" {
  var swc = SliceWithCursor.init("This is a decently long sentence.");
  var sis = SliceInStream2.init(&swc);
  var sss = SliceSeekableStream.init(&swc);

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

  try sss.stream.seekTo(swc.slice.len - 3);
  const br4 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br4], "ce."));

  std.debug.assertError(sss.stream.seekTo(999), error.SliceSeekOutOfBounds);
  std.debug.assertError(sss.stream.seekForward(-999), error.SliceSeekOutOfBounds);
}