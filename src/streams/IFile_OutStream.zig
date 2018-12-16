const IFile = @import("IFile.zig").IFile;
const OutStream = @import("OutStream.zig").OutStream;

pub const IFileOutStreamAdapter = struct {
  subject: *IFile,
  write_error: ?IFile.WriteError,

  pub fn init(subject: *IFile) IFileOutStreamAdapter {
    return IFileOutStreamAdapter{
      .subject = subject,
      .write_error = null,
    };
  }

  pub fn outStream(self: *IFileOutStreamAdapter) OutStream {
    return OutStream.init(self);
  }

  fn write(self: *IFileOutStreamAdapter, dest: []u8) OutStream.Error!usize {
    return self.subject.write(dest);
  }
};
