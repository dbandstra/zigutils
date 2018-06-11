const std = @import("std");
const Seekable = @import("traits/Seekable.zig").Seekable;

//
// SimpleInStream:
// creates an InStream that simply reads from a static array.
//
// implements the following traits: InStream, Seekable
//

pub const SimpleInStreamError = error {};

pub const SimpleInStream = struct {
  source_buffer: []const u8,
  index: usize,
  stream: Stream,
  seekable: Seekable,

  pub const ReadError = SimpleInStreamError;
  pub const SeekError = Seekable.Error;
  pub const Stream = std.io.InStream(ReadError);

  pub fn init(buffer: []const u8) SimpleInStream {
    return SimpleInStream{
      .source_buffer = buffer,
      .index = 0,
      .stream = Stream{
        .readFn = readFn,
      },
      .seekable = Seekable{
        .seekForwardFn = seekForwardFn,
        .seekToFn = seekToFn,
        .getPosFn = getPosFn,
        .getEndPosFn = getEndPosFn,
      },
    };
  }

  // InStream trait implementation

  fn readFn(in_stream: *Stream, buffer: []u8) SimpleInStreamError!usize {
    if (buffer.len == 0) {
      return 0;
    }

    const self = @fieldParentPtr(SimpleInStream, "stream", in_stream);

    if (self.index >= self.source_buffer.len) {
      // we are at the end of the source buffer
      return 0;
    }

    const bytes_remaining = self.source_buffer.len - self.index;

    var num_bytes_to_read = buffer.len;

    if (num_bytes_to_read > bytes_remaining) {
      num_bytes_to_read = bytes_remaining;
    }

    std.mem.copy(u8, buffer[0..num_bytes_to_read], self.source_buffer[self.index..self.index + num_bytes_to_read]);
    self.index += num_bytes_to_read;

    return num_bytes_to_read;
  }

  // Seekable trait implementation

  fn seekForwardFn(seekable: *Seekable, amount: isize) SeekError!void {
    const self = @fieldParentPtr(SimpleInStream, "seekable", seekable);

    if (amount > 0) {
      const uamount = usize(amount);

      if (self.index + uamount <= self.source_buffer.len) {
        self.index += uamount;
      } else {
        return SeekError.SeekError;
      }
    } else if (amount < 0) {
      const uamount = usize(-amount);

      if (self.index >= uamount) {
        self.index -= uamount;
      } else {
        return SeekError.SeekError;
      }
    }
  }

  fn seekToFn(seekable: *Seekable, pos: usize) SeekError!void {
    const self = @fieldParentPtr(SimpleInStream, "seekable", seekable);

    if (pos >= 0 and pos < self.source_buffer.len) {
      self.index = pos;
    } else {
      return SeekError.SeekError;
    }
  }

  fn getPosFn(seekable: *Seekable) SeekError!usize {
    const self = @fieldParentPtr(SimpleInStream, "seekable", seekable);

    return self.index;
  }

  fn getEndPosFn(seekable: *Seekable) SeekError!usize {
    const self = @fieldParentPtr(SimpleInStream, "seekable", seekable);

    return self.source_buffer.len;
  }
};

test "SimpleInStream: source buffer smaller than read buffer" {
  var sis = SimpleInStream.init("Hello world");

  var dest_buf: [100]u8 = undefined;

  // unfortunately, you have to `try`, even though this function never throws
  const br0 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "Hello world"));
}

test "SimpleInStream: source buffer longer than read buffer" {
  var sis = SimpleInStream.init("Between 15 and 20.");

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

test "SimpleInStream: seeking around" {
  var sis = SimpleInStream.init("This is a decently long sentence.");

  var dest_buf: [5]u8 = undefined;

  const br0 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "This "));

  try sis.seekable.seekForward(3);
  const br1 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br1], "a dec"));

  try sis.seekable.seekForward(-2);
  const br2 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br2], "ecent"));

  std.debug.assert((try sis.seekable.getPos()) == 16);

  try sis.seekable.seekTo(1);
  const br3 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br3], "his i"));

  try sis.seekable.seekTo((try sis.seekable.getEndPos()) - 3);
  const br4 = try sis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br4], "ce."));

  if (sis.seekable.seekTo(999)) {
    unreachable;
  } else |err| {
    std.debug.assert(err == Seekable.Error.SeekError);
  }

  if (sis.seekable.seekForward(-999)) {
    unreachable;
  } else |err| {
    std.debug.assert(err == Seekable.Error.SeekError);
  }
}
