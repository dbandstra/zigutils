const std = @import("std");

const LineReader = @import("src/LineReader.zig").LineReader;
const OutStream = @import("src/streams/OutStream.zig").OutStream;
const ISlice = @import("src/streams/ISlice.zig").ISlice;

pub fn main() !void {
  var buf: [20]u8 = undefined;
  var dest = ISlice.init(buf[0..]);
  var out_stream = dest.outStream();

  const line_reader = LineReader(ISlice.WriteError);

  try line_reader.read_line_from_stdin(out_stream);

  std.debug.warn("buf: '{}'\n", buf[0..]);
}
