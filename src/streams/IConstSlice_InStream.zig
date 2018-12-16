const IConstSlice = @import("IConstSlice.zig").IConstSlice;
const InStream = @import("InStream.zig").InStream;

pub const IConstSliceInStreamAdapter = struct {
  subject: *IConstSlice,

  pub fn init(subject: *IConstSlice) IConstSliceInStreamAdapter {
    return IConstSliceInStreamAdapter{
      .subject = subject,
    };
  }

  pub fn inStream(self: *IConstSliceInStreamAdapter) InStream {
    return InStream.init(self);
  }

  // this looks like an extra indirection...
  // maybe it could be removed if the vtable library were changed so that
  // each of these callbacks takes two pointers, `self` and `subject`?
  fn read(self: *IConstSliceInStreamAdapter, dest: []u8) InStream.Error!usize {
    return self.subject.read(dest);
  }
};
