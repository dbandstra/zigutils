const IFile = @import("IFile.zig").IFile;
const InStream = @import("InStream.zig").InStream;

pub const IFileInStreamAdapter = struct {
  subject: *IFile,
  read_error: ?IFile.ReadError,

  pub fn init(subject: *IFile) IFileInStreamAdapter {
    return IFileInStreamAdapter{
      .subject = subject,
      .read_error = null,
    };
  }

  pub fn inStream(self: *IFileInStreamAdapter) InStream {
    return InStream.init(self);
  }

  fn read(self: *IFileInStreamAdapter, dest: []u8) InStream.Error!usize {
    return self.subject.read(dest) catch |err| {
      self.read_error = err;
      return InStream.Error.ReadError;
    };
  }
};
