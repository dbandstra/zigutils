const std = @import("std");

const InStream = @import("InStream.zig").InStream;

pub const FileInStreamAdapter = struct {
  subject: std.os.File,
  read_error: ?std.os.File.ReadError,

  pub fn init(subject: std.os.File) FileInStreamAdapter {
    return FileInStreamAdapter{
      .subject = subject,
      .read_error = null,
    };
  }

  pub fn inStream(self: *FileInStreamAdapter) InStream {
    return InStream.init(self);
  }

  fn read(self: *FileInStreamAdapter, dest: []u8) InStream.Error!usize {
    return self.subject.read(dest) catch |err| {
      self.read_error = err;
      return InStream.Error.ReadError;
    };
  }
};
