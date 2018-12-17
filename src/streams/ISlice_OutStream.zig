const std = @import("std");

const ISlice = @import("ISlice.zig").ISlice;
const OutStream = @import("OutStream.zig").OutStream;

pub const ISliceOutStreamAdapter = struct {
  subject: *ISlice,
  write_error: ?ISlice.WriteError,

  pub fn init(subject: *ISlice) ISliceOutStreamAdapter {
    return ISliceOutStreamAdapter{
      .subject = subject,
      .write_error = null,
    };
  }

  pub fn outStream(self: *ISliceOutStreamAdapter) OutStream {
    return OutStream.init(self);
  }

  fn write(self: *ISliceOutStreamAdapter, bytes: []const u8) OutStream.Error!void {
    self.subject.write(bytes) catch |err| {
      self.write_error = err;
      return OutStream.Error.WriteError;
    };
  }
};
