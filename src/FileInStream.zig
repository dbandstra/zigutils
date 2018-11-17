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

pub const SeekableFileInStream = struct{
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
        .seekFn = seekFn,
      },
    };
  }

  // InStream trait implementation

  fn readFn(in_stream: *Stream, buffer: []u8) ReadError!usize {
    const self = @fieldParentPtr(SeekableFileInStream, "stream", in_stream);

    return self.file.read(buffer);
  }

  // Seekable trait implementation

  fn seekFn(seekable: *Seekable, ofs: i64, whence: Seekable.Whence) SeekError!i64 {
    const self = @fieldParentPtr(SeekableFileInStream, "seekable", seekable);

    switch (whence) {
      Seekable.Whence.Start => {
        const uofs = std.math.cast(usize, ofs) catch return SeekError.SeekError;
        self.file.seekTo(uofs) catch return SeekError.SeekError;
        return ofs;
      },
      Seekable.Whence.Current => {
        self.file.seekForward(ofs) catch return SeekError.SeekError;
        const new_pos = self.file.getPos() catch return SeekError.SeekError;
        const upos = std.math.cast(i64, new_pos) catch return SeekError.SeekError;
        return upos;
      },
      Seekable.Whence.End => {
        const end_pos = self.file.getEndPos() catch return SeekError.SeekError;
        const end_upos = std.math.cast(i64, end_pos) catch return SeekError.SeekError;
        if (-ofs > end_upos) return SeekError.SeekError;
        const new_pos = end_upos + ofs;
        const new_upos = std.math.cast(usize, new_pos) catch return SeekError.SeekError;
        self.file.seekTo(new_upos) catch return SeekError.SeekError;
        return new_pos;
      },
    }
  }
};

test "FileInStream" {
  var file = try File.openRead("README.md");
  var sfis = SeekableFileInStream.init(&file);

  _ = try sfis.seekable.seek(20, Seekable.Whence.Current);

  var buf: [20]u8 = undefined;
  const n = try sfis.stream.read(buf[0..]);
  std.debug.warn("'{}'\n", buf[0..n]);
}
