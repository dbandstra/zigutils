const std = @import("std");

const InStream = @import("streams/InStream.zig").InStream;
const OutStream = @import("streams/OutStream.zig").OutStream;

const IFile = @import("streams/IFile.zig").IFile;

//
// Read a line from stdin
//

pub const LineReader = struct {
  // TODO - move this out... too specialized
  pub fn read_line_from_stdin(out_stream: OutStream) !void {
    var stdin = std.io.getStdIn() catch return error.StdInUnavailable;
    var ifile = IFile.init(stdin);
    var in_stream = ifile.inStream();
    return read_line_from_stream(std.os.File.ReadError, in_stream, out_stream);
  }

  // this function is split off so it can be tested
  pub fn read_line_from_stream(
    comptime InStreamError: type,
    stream: InStream(InStreamError),
    out_stream: OutStream,
  ) !void {
    var failed: ?OutStream.Error = null;

    while (true) {
      const byte = stream.readByte() catch return error.EndOfFile;
      switch (byte) {
        '\r' => {
          // trash the following \n
          _ = stream.readByte() catch return error.EndOfFile;
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
  const ISlice = @import("streams/ISlice.zig").ISlice;

  // test the `read_line_from_stream` function directly to avoid stdin

  var source = IConstSlice.init("First line\nSecond line\n\nUnterminated line");
  var in_stream = source.inStream();

  var out_buf: [100]u8 = undefined;
  var dest = ISlice.init(out_buf[0..]);
  var out_stream = dest.outStream();

  dest.reset();
  try LineReader.read_line_from_stream(IConstSlice.ReadError, in_stream, out_stream);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "First line"));

  dest.reset();
  try LineReader.read_line_from_stream(IConstSlice.ReadError, in_stream, out_stream);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "Second line"));

  dest.reset();
  try LineReader.read_line_from_stream(IConstSlice.ReadError, in_stream, out_stream);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), ""));

  // current behaviour is to throw an error when a read fails (e.g. end of
  // file). not sure if this is ideal
  var endOfFile = false;
  dest.reset();
  LineReader.read_line_from_stream(IConstSlice.ReadError, in_stream, out_stream) catch |err| switch (err) {
    error.EndOfFile => endOfFile = true,
    else => {},
  };
  std.debug.assert(endOfFile == true);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "Unterminated line"));
}

test "LineReader: keeps consuming till EOL even if write fails" {
  const IConstSlice = @import("streams/IConstSlice.zig").IConstSlice;
  const ISlice = @import("streams/ISlice.zig").ISlice;

  var source = IConstSlice.init("First line is pretty long\nSecond\n");
  var in_stream = source.inStream();

  var out_buf: [12]u8 = undefined;
  var dest = ISlice.init(out_buf[0..]);
  var out_stream = dest.outStream();

  dest.reset();
  std.debug.assertError(
    LineReader.read_line_from_stream(IConstSlice.ReadError, in_stream, out_stream),
    error.WriteError,
  );
  std.debug.assert(dest.write_error.? == error.OutOfSpace);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "First line i"));

  dest.reset();
  try LineReader.read_line_from_stream(IConstSlice.ReadError, in_stream, out_stream);
  std.debug.assert(std.mem.eql(u8, dest.getWritten(), "Second"));
}

// TODO - test line ending handling, i guess
