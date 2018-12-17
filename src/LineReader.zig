const std = @import("std");

const InStream = @import("streams/InStream.zig").InStream;
const OutStream = @import("streams/OutStream.zig").OutStream;

const FileInStreamAdapter = @import("streams/File_InStream.zig").FileInStreamAdapter;

//
// Read a line from stdin
//

pub const LineReader = struct {
  // TODO - move this out... too specialized
  // TODO - if read failed, get the actual error from stdin and add it to error return type
  pub fn read_line_from_stdin(out_stream: OutStream) !void {
    var stdin = std.io.getStdIn() catch return error.StdInUnavailable;
    var file_in_stream_adapter = FileInStreamAdapter.init(stdin);
    var in_stream = file_in_stream_adapter.inStream();
    return read_line_from_stream(in_stream, out_stream) catch |err| {
      if (err == InStream.Error.ReadError) {
        return file_in_stream_adapter.read_error.?;
      } else {
        return err;
      }
    };
  }

  // this function is split off so it can be tested
  pub fn read_line_from_stream(in_stream: InStream, out_stream: OutStream) (InStream.Error || error{EndOfStream} || OutStream.Error)!void {
    var failed: ?OutStream.Error = null;

    while (true) {
      const byte = try in_stream.readByte();
      switch (byte) {
        '\r' => {
          // trash the following \n
          _ = try in_stream.readByte();
          break;
        },
        '\n' => break,
        else => {
          // if a write fails, we will keep consuming stdin till end of line
          if (failed == null) {
            out_stream.writeByte(byte) catch |err| {
              failed = err;
            };
          }
        },
      }
    }

    if (failed) |err| {
      return err;
    }
  }
};

test "LineReader: reads lines and fails upon EOF" {
  const IConstSlice = @import("streams/IConstSlice.zig").IConstSlice;
  const IConstSliceInStreamAdapter = @import("streams/IConstSlice_InStream.zig").IConstSliceInStreamAdapter;
  const ISlice = @import("streams/ISlice.zig").ISlice;
  const ISliceOutStreamAdapter = @import("streams/ISlice_OutStream.zig").ISliceOutStreamAdapter;

  // test the `read_line_from_stream` function directly to avoid stdin

  var source = IConstSlice.init("First line\nSecond line\n\nUnterminated line");
  var in_stream_adapter = IConstSliceInStreamAdapter.init(&source);
  var in_stream = in_stream_adapter.inStream();

  var out_buf: [100]u8 = undefined;
  var dest = ISlice.init(out_buf[0..]);
  var dest_out_stream_adapter = ISliceOutStreamAdapter.init(&dest);
  var out_stream = dest_out_stream_adapter.outStream();

  dest.reset();
  try LineReader.read_line_from_stream(in_stream, out_stream);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "First line"));

  dest.reset();
  try LineReader.read_line_from_stream(in_stream, out_stream);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "Second line"));

  dest.reset();
  try LineReader.read_line_from_stream(in_stream, out_stream);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), ""));

  // current behaviour is to throw an error when a read fails (e.g. end of
  // file). not sure if this is ideal
  dest.reset();
  std.debug.assertError(
    LineReader.read_line_from_stream(in_stream, out_stream),
    error.EndOfStream,
  );
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "Unterminated line"));
}

test "LineReader: keeps consuming till EOL even if write fails" {
  const IConstSlice = @import("streams/IConstSlice.zig").IConstSlice;
  const IConstSliceInStreamAdapter = @import("streams/IConstSlice_InStream.zig").IConstSliceInStreamAdapter;
  const ISlice = @import("streams/ISlice.zig").ISlice;
  const ISliceOutStreamAdapter = @import("streams/ISlice_OutStream.zig").ISliceOutStreamAdapter;

  var source = IConstSlice.init("First line is pretty long\nSecond\n");
  var in_stream_adapter = IConstSliceInStreamAdapter.init(&source);
  var in_stream = in_stream_adapter.inStream();

  var out_buf: [12]u8 = undefined;
  var dest = ISlice.init(out_buf[0..]);
  var dest_out_stream_adapter = ISliceOutStreamAdapter.init(&dest);
  var out_stream = dest_out_stream_adapter.outStream();

  dest.reset();
  std.debug.assertError(
    LineReader.read_line_from_stream(in_stream, out_stream),
    OutStream.Error.WriteError,
  );
  std.debug.assert(dest_out_stream_adapter.write_error.? == error.OutOfSpace);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "First line i"));

  dest.reset();
  try LineReader.read_line_from_stream(in_stream, out_stream);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "Second"));
}

// TODO - test line ending handling, i guess
