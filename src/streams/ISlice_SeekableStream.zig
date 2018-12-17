const ISlice = @import("ISlice.zig").ISlice;
const SeekableStream = @import("SeekableStream.zig").SeekableStream;

pub const ISliceSeekableStreamAdapter = struct {
  subject: *ISlice,
  seek_error: ?ISlice.SeekError,

  pub fn init(subject: *ISlice) ISliceSeekableStreamAdapter {
    return ISliceSeekableStreamAdapter{
      .subject = subject,
      .seek_error = null,
    };
  }

  pub fn seekableStream(self: *ISliceSeekableStreamAdapter) SeekableStream {
    return SeekableStream.init(self);
  }

  fn seekTo(self: *ISliceSeekableStreamAdapter, pos: usize) SeekableStream.SeekError!void {
    self.subject.seekTo(pos) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  fn seekForward(self: *ISliceSeekableStreamAdapter, amt: isize) SeekableStream.SeekError!void {
    self.subject.seekForward(amt) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  fn getEndPos(self: *ISliceSeekableStreamAdapter) SeekableStream.GetSeekPosError!usize {
    return self.subject.getEndPos();
  }

  fn getPos(self: *ISliceSeekableStreamAdapter) SeekableStream.GetSeekPosError!usize {
    return self.subject.getPos();
  }
};
