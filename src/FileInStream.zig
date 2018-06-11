const std = @import("std");
const File = std.os.File;
const InStream = std.io.InStream;

const Seekable = @import("traits/Seekable.zig").Seekable;

//
// FileInStream:
// creates an InStream that reads from a file.
//
// implements the following traits: InStream, Seekable
//

pub const SeekableFileInStream = struct {
  file: *File,
  stream: Stream,
  seekable: Seekable,

  pub const ReadError = @typeOf(File.read).ReturnType.ErrorSet;
  pub const SeekError = Seekable.Error;
  pub const Stream = InStream(ReadError);

  pub fn init(file: *File) SeekableFileInStream {
    return SeekableFileInStream{
      .file = file,
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

  fn readFn(in_stream: *Stream, buffer: []u8) ReadError!usize {
    const self = @fieldParentPtr(SeekableFileInStream, "stream", in_stream);

    return self.file.read(buffer);
  }

  // Seekable trait implementation

  fn seekForwardFn(seekable: *Seekable, amount: isize) SeekError!void {
    const self = @fieldParentPtr(SeekableFileInStream, "seekable", seekable);

    return self.file.seekForward(amount) catch SeekError.SeekError;
  }

  fn seekToFn(seekable: *Seekable, pos: usize) SeekError!void {
    const self = @fieldParentPtr(SeekableFileInStream, "seekable", seekable);

    return self.file.seekTo(pos) catch SeekError.SeekError;
  }

  fn getPosFn(seekable: *Seekable) SeekError!usize {
    const self = @fieldParentPtr(SeekableFileInStream, "seekable", seekable);

    return self.file.getPos() catch SeekError.SeekError;
  }

  fn getEndPosFn(seekable: *Seekable) SeekError!usize {
    const self = @fieldParentPtr(SeekableFileInStream, "seekable", seekable);

    return self.file.getEndPos() catch SeekError.SeekError;
  }
};

test "FileInStream" {
  var file = try File.openRead(std.debug.global_allocator, "README.md");
  var sfis = SeekableFileInStream.init(&file);

  try sfis.seekable.seekForward(20);

  var buf: [20]u8 = undefined;
  const n = try sfis.stream.read(buf[0..]);
  std.debug.warn("'{}'\n", buf[0..n]);
}
