const std = @import("std");
const Seekable = @import("traits/Seekable.zig").Seekable;

//
// MemoryInStream:
// creates an InStream that simply reads from a static array.
//
// implements the following traits: InStream, Seekable
//

pub const MemoryInStream = struct.{
  source_buffer: []const u8,
  index: usize,
  stream: Stream,
  seekable: Seekable,

  pub const ReadError = error.{};
  pub const Stream = std.io.InStream(ReadError);

  pub fn init(buffer: []const u8) MemoryInStream {
    return MemoryInStream.{
      .source_buffer = buffer,
      .index = 0,
      .stream = Stream.{
        .readFn = readFn,
      },
      .seekable = Seekable.{
        .seekFn = seekFn,
      },
    };
  }

  // no deinit function.

  // InStream trait implementation

  fn readFn(in_stream: *Stream, buffer: []u8) ReadError!usize {
    if (buffer.len == 0) {
      return 0;
    }

    const self = @fieldParentPtr(MemoryInStream, "stream", in_stream);

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

  fn seekFn(seekable: *Seekable, ofs: i64, whence: Seekable.Whence) Seekable.Error!i64 {
    const self = @fieldParentPtr(MemoryInStream, "seekable", seekable);

    const end_pos = std.math.cast(i64, self.source_buffer.len) catch return Seekable.Error.SeekError;

    switch (whence) {
      Seekable.Whence.Start => {
        if (ofs >= 0 and ofs < end_pos) {
          const uofs = std.math.cast(usize, ofs) catch return Seekable.Error.SeekError;
          self.index = uofs;
        } else {
          return Seekable.Error.SeekError;
        }
      },
      Seekable.Whence.Current => {
        if (ofs > 0) {
          const uofs = @intCast(usize, ofs);

          if (self.index + uofs <= self.source_buffer.len) {
            self.index += uofs;
          } else {
            return Seekable.Error.SeekError;
          }
        } else if (ofs < 0) {
          const uofs = @intCast(usize, -ofs);

          if (self.index >= uofs) {
            self.index -= uofs;
          } else {
            return Seekable.Error.SeekError;
          }
        }
      },
      Seekable.Whence.End => {
        if (ofs <= 0 and -ofs < end_pos) {
          const unofs = std.math.cast(usize, -ofs) catch return Seekable.Error.SeekError;
          self.index = self.source_buffer.len - unofs;
        } else {
          return Seekable.Error.SeekError;
        }
      },
    }

    return std.math.cast(i64, self.index) catch Seekable.Error.SeekError;
  }
};

test "MemoryInStream: source buffer smaller than read buffer" {
  var mis = MemoryInStream.init("Hello world");

  var dest_buf: [100]u8 = undefined;

  // unfortunately, you have to `try`, even though this function never throws
  const br0 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "Hello world"));
}

test "MemoryInStream: source buffer longer than read buffer" {
  var mis = MemoryInStream.init("Between 15 and 20.");

  var dest_buf: [5]u8 = undefined;

  const br0 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "Betwe"));

  const br1 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br1], "en 15"));

  const br2 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br2], " and "));

  const br3 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br3], "20."));

  const br4 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(br4 == 0);
}

test "MemoryInStream: seeking around" {
  var mis = MemoryInStream.init("This is a decently long sentence.");

  var dest_buf: [5]u8 = undefined;

  const br0 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "This "));

  _ = try mis.seekable.seek(3, Seekable.Whence.Current);
  const br1 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br1], "a dec"));

  _ = try mis.seekable.seek(-2, Seekable.Whence.Current);
  const br2 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br2], "ecent"));

  const cur_pos = try mis.seekable.seek(0, Seekable.Whence.Current);
  std.debug.assert(cur_pos == 16);

  _ = try mis.seekable.seek(1, Seekable.Whence.Start);
  const br3 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br3], "his i"));

  _ = try mis.seekable.seek(-3, Seekable.Whence.End);
  const br4 = try mis.stream.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br4], "ce."));

  std.debug.assertError(mis.seekable.seek(999, Seekable.Whence.Start), Seekable.Error.SeekError);
  std.debug.assertError(mis.seekable.seek(-999, Seekable.Whence.Current), Seekable.Error.SeekError);
}
