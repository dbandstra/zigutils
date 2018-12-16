const IConstSlice = @import("IConstSlice.zig").IConstSlice;
const SeekableStream = @import("SeekableStream.zig").SeekableStream;

pub const IConstSliceSeekableStreamAdapter = struct {
  subject: *IConstSlice,
  seek_error: ?IConstSlice.SeekError,

  pub fn init(subject: *IConstSlice) IConstSliceSeekableStreamAdapter {
    return IConstSliceSeekableStreamAdapter{
      .subject = subject,
      .seek_error = null,
    };
  }

  pub fn seekableStream(self: *IConstSliceSeekableStreamAdapter) SeekableStream {
    return SeekableStream.init(self);
  }

  fn seekTo(self: *IConstSliceSeekableStreamAdapter, pos: usize) SeekableStream.SeekError!void {
    self.subject.seekTo(pos) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  fn seekForward(self: *IConstSliceSeekableStreamAdapter, amt: isize) SeekableStream.SeekError!void {
    self.subject.seekForward(amt) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  fn getEndPos(self: *IConstSliceSeekableStreamAdapter) SeekableStream.GetSeekPosError!usize {
    return self.subject.getEndPos();
  }

  fn getPos(self: *IConstSliceSeekableStreamAdapter) SeekableStream.GetSeekPosError!usize {
    return self.subject.getPos();
  }
};
