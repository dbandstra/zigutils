const std = @import("std");

const LineReader = @import("src/LineReader.zig").LineReader;
const OutStream = @import("src/streams/OutStream.zig").OutStream;
const SliceOutStream = @import("src/streams/SliceOutStream.zig").SliceOutStream;

pub fn main() !void {
  var buf: [20]u8 = undefined;
  var slice_out_stream = SliceOutStream.init(buf[0..]);
  var out_stream = OutStream(SliceOutStream.Error).init(&slice_out_stream);

  const line_reader = LineReader(SliceOutStream.Error);

  try line_reader.read_line_from_stdin(out_stream);

  std.debug.warn("buf: '{}'\n", buf[0..]);
}
