const IFile = @import("IFile.zig").IFile;
const SeekableStream = @import("SeekableStream.zig").SeekableStream;

pub const IFileSeekableStreamAdapter = struct {
  subject: *IFile,
  seek_error: ?IFile.SeekError,
  get_seek_pos_error: ?IFile.GetSeekPosError,

  pub fn init(subject: *IFile) IFileSeekableStreamAdapter {
    return IFileSeekableStreamAdapter{
      .subject = subject,
      .seek_error = null,
      .get_seek_pos_error = null,
    };
  }

  pub fn seekableStream(self: *IFileSeekableStreamAdapter) SeekableStream {
    return SeekableStream.init(self);
  }

  fn seekTo(self: *IFileSeekableStreamAdapter, pos: usize) SeekableStream.SeekError!void {
    self.subject.seekTo(pos) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  fn seekForward(self: *IFileSeekableStreamAdapter, amt: isize) SeekableStream.SeekError!void {
    self.subject.seekForward(amt) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  fn getEndPos(self: *IFileSeekableStreamAdapter) SeekableStream.GetSeekPosError!usize {
    return self.subject.getEndPos() catch |err| {
      self.get_seek_pos_error = err;
      return SeekableStream.GetSeekPosError.GetSeekPosError;
    };
  }

  fn getPos(self: *IFileSeekableStreamAdapter) SeekableStream.GetSeekPosError!usize {
    return self.subject.getPos() catch |err| {
      self.get_seek_pos_error = err;
      return SeekableStream.GetSeekPosError.GetSeekPosError;
    };
  }
};
