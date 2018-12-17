const std = @import("std");

const SeekableStream = @import("SeekableStream.zig").SeekableStream;

pub const FileSeekableStreamAdapter = struct {
  subject: std.os.File,
  seek_error: ?std.os.File.SeekError,
  get_seek_pos_error: ?std.os.File.GetSeekPosError,

  pub fn init(subject: std.os.File) FileSeekableStreamAdapter {
    return FileSeekableStreamAdapter{
      .subject = subject,
      .seek_error = null,
      .get_seek_pos_error = null,
    };
  }

  pub fn seekableStream(self: *FileSeekableStreamAdapter) SeekableStream {
    return SeekableStream.init(self);
  }

  fn seekTo(self: *FileSeekableStreamAdapter, pos: usize) SeekableStream.SeekError!void {
    self.subject.seekTo(pos) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  fn seekForward(self: *FileSeekableStreamAdapter, amt: isize) SeekableStream.SeekError!void {
    self.subject.seekForward(amt) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  fn getEndPos(self: *FileSeekableStreamAdapter) SeekableStream.GetSeekPosError!usize {
    return self.subject.getEndPos() catch |err| {
      self.get_seek_pos_error = err;
      return SeekableStream.GetSeekPosError.GetSeekPosError;
    };
  }

  fn getPos(self: *FileSeekableStreamAdapter) SeekableStream.GetSeekPosError!usize {
    return self.subject.getPos() catch |err| {
      self.get_seek_pos_error = err;
      return SeekableStream.GetSeekPosError.GetSeekPosError;
    };
  }
};
