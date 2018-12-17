const std = @import("std");

const LineReader = @import("src/LineReader.zig").LineReader;
const OutStream = @import("src/streams/OutStream.zig").OutStream;
const ISlice = @import("src/streams/ISlice.zig").ISlice;
const ISliceOutStreamAdapter = @import("src/streams/ISlice_OutStream.zig").ISliceOutStreamAdapter;

pub fn main() void {
  var buf: [20]u8 = undefined;
  var dest = ISlice.init(buf[0..]);
  var dest_out_stream_adapter = ISliceOutStreamAdapter.init(&dest);
  var out_stream = dest_out_stream_adapter.outStream();

  std.debug.warn("type something (limit 20 characters): ");

  LineReader.read_line_from_stdin(out_stream) catch |err| {
    if (err == OutStream.Error.WriteError) {
      std.debug.warn("write error: {}\n", dest_out_stream_adapter.write_error.?);
    } else {
      std.debug.warn("err: {}\n", err);
    }
  };

  std.debug.warn("buf: '{}'\n", buf[0..]);
}
