const std = @import("std");

//
// MemoryOutStream:
// creates an OutStream that simply writes into a static sized array.
// throws OutOfSpace error when it runs out of space.
// includes getSlice() method for convenience.
//

pub const MemoryOutStream = struct {
  buffer: []u8,
  index: usize,
  stream: Stream,

  pub const WriteError = error{OutOfSpace};
  pub const Stream = std.io.OutStream(WriteError);

  pub fn init(buffer: []u8) MemoryOutStream {
    return MemoryOutStream{
      .buffer = buffer,
      .index = 0,
      .stream = Stream{ .writeFn = writeFn },
    };
  }

  // no deinit function.

  pub fn getSlice(self: *const MemoryOutStream) []const u8 {
    return self.buffer[0..self.index];
  }

  pub fn reset(self: *MemoryOutStream) void {
    self.index = 0;
  }

  fn writeFn(out_stream: *Stream, bytes: []const u8) WriteError!void {
    if (bytes.len == 0) {
      return;
    }

    const self = @fieldParentPtr(MemoryOutStream, "stream", out_stream);

    var num_bytes_to_copy = bytes.len;
    var not_enough_space = false;

    if (self.index + num_bytes_to_copy > self.buffer.len) {
      num_bytes_to_copy = self.buffer.len - self.index;
      not_enough_space = true;
    }

    std.mem.copy(u8, self.buffer[self.index..self.index + num_bytes_to_copy], bytes[0..num_bytes_to_copy]);
    self.index += num_bytes_to_copy;

    if (not_enough_space) {
      return WriteError.OutOfSpace;
    }
  }
};

test "MemoryOutStream: writing a string that easily fits" {
  var buffer: [10]u8 = undefined;
  var mos = MemoryOutStream.init(buffer[0..]);

  try mos.stream.print("Hello.");

  std.debug.assert(std.mem.eql(u8, mos.getSlice(), "Hello."));
}

test "MemoryOutStream: writing a string that just fits" {
  var buffer: [10]u8 = undefined;
  var mos = MemoryOutStream.init(buffer[0..]);

  try mos.stream.print("I am glad.");

  std.debug.assert(std.mem.eql(u8, mos.getSlice(), "I am glad."));
}

test "MemoryOutStream: writing a string that doesn't fit" {
  var buffer: [10]u8 = undefined;
  var mos = MemoryOutStream.init(buffer[0..]);

  if (mos.stream.print("This string is too long.")) {
    unreachable;
  } else |err| {
    std.debug.assert(err == MemoryOutStream.WriteError.OutOfSpace);
  }

  std.debug.assert(std.mem.eql(u8, mos.getSlice(), "This strin"));
}
