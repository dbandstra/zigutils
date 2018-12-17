const std = @import("std");

const OutStream = @import("OutStream.zig").OutStream;

pub const FileOutStreamAdapter = struct {
  subject: std.os.File,
  write_error: ?std.os.File.WriteError,

  pub fn init(subject: std.os.File) FileOutStreamAdapter {
    return FileOutStreamAdapter{
      .subject = subject,
      .write_error = null,
    };
  }

  pub fn outStream(self: *FileOutStreamAdapter) OutStream {
    return OutStream.init(self);
  }

  fn write(self: *FileOutStreamAdapter, bytes: []const u8) OutStream.Error!void {
    self.subject.write(bytes) catch |err| {
      self.write_error = err;
      return OutStream.Error.WriteError;
    };
  }
};
