const std = @import("std");
const InStream = std.io.InStream;
const Seekable = @import("../traits/Seekable.zig").Seekable;
const MemoryInStream = @import("../MemoryInStream.zig").MemoryInStream;

// this is an example of a function that takes in something with multiple
// traits. not very elegant, they have to be passed in separate args...
fn ConsumeSeekableInStream(comptime ReadError: type) type {
  return struct {
    pub fn consume(
      stream: *InStream(ReadError),
      seekable: *Seekable,
      out_buf: []u8,
    ) !usize {
      try seekable.seekTo(10);
      return try stream.read(out_buf);
    }
  };
}

test "ConsumeSeekableInStream" {
  var mis = MemoryInStream.init("This is a decently long sentence.");
  var buf: [100]u8 = undefined;
  const n = try ConsumeSeekableInStream(MemoryInStream.ReadError).consume(&mis.stream, &mis.seekable, buf[0..]);
  std.debug.assert(std.mem.eql(u8, buf[0..n], "decently long sentence."));
}
