const std = @import("std");

//
// SimpleOutStream:
// creates an OutStream that simply writes into a static sized array.
// throws OutOfSpace error when it runs out of space.
// includes getSlice() method for convenience.
//

pub const SimpleOutStreamError = error {
  OutOfSpace,
};

// this is the "bring your own buffer" implementation
pub const SimpleOutStream = struct {
  buffer: []u8,
  index: usize,
  stream: Stream,

  pub const Error = SimpleOutStreamError;
  pub const Stream = std.io.OutStream(Error);

  pub fn init(buffer: []u8) SimpleOutStream {
    return SimpleOutStream{
      .buffer = buffer,
      .index = 0,
      .stream = Stream{ .writeFn = writeFn },
    };
  }

  pub fn getSlice(self: *const SimpleOutStream) []const u8 {
    return self.buffer[0..self.index];
  }

  pub fn reset(self: *SimpleOutStream) void {
    self.index = 0;
  }

  fn writeFn(out_stream: *Stream, bytes: []const u8) !void {
    if (bytes.len == 0) {
      return;
    }

    const self = @fieldParentPtr(SimpleOutStream, "stream", out_stream);

    var num_bytes_to_copy = bytes.len;
    var not_enough_space = false;

    if (self.index + num_bytes_to_copy > self.buffer.len) {
      num_bytes_to_copy = self.buffer.len - self.index;
      not_enough_space = true;
    }

    std.mem.copy(u8, self.buffer[self.index..self.index + num_bytes_to_copy], bytes[0..num_bytes_to_copy]);
    self.index += num_bytes_to_copy;

    if (not_enough_space) {
      return SimpleOutStreamError.OutOfSpace;
    }
  }
};

test "SimpleOutStream: writing a string that easily fits" {
  var buffer: [10]u8 = undefined;
  var sos = SimpleOutStream.init(buffer[0..]);

  try sos.stream.print("Hello.");

  std.debug.assert(std.mem.eql(u8, sos.getSlice(), "Hello."));
}

test "SimpleOutStream: writing a string that just fits" {
  var buffer: [10]u8 = undefined;
  var sos = SimpleOutStream.init(buffer[0..]);

  try sos.stream.print("I am glad.");

  std.debug.assert(std.mem.eql(u8, sos.getSlice(), "I am glad."));
}

test "SimpleOutStream: writing a string that doesn't fit" {
  var buffer: [10]u8 = undefined;
  var sos = SimpleOutStream.init(buffer[0..]);

  // FIXME - there must be a better way to write this
  var outOfSpaceErrorThrown = false;

  sos.stream.print("This string is too long.") catch |err| switch (err) {
    SimpleOutStreamError.OutOfSpace => outOfSpaceErrorThrown = true, // ok
    else => {}, // (print function can throw errors) not ok
  };

  std.debug.assert(outOfSpaceErrorThrown == true);
  std.debug.assert(std.mem.eql(u8, sos.getSlice(), "This strin"));
}
