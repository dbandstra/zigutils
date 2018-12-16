const std = @import("std");

const OutStream = @import("OutStream.zig").OutStream;
const SeekableStream = @import("SeekableStream.zig").SeekableStream;

pub const ISlice = struct {
  pub const WriteError = error{OutOfSpace};
  pub const SeekError = error{SliceSeekOutOfBounds};
  pub const GetSeekPosError = error{};

  slice: []u8,
  pos: usize,
  write_error: ?WriteError,

  pub fn init(slice: []u8) ISlice {
    return ISlice{
      .slice = slice,
      .pos = 0,
      .write_error = null,
    };
  }

  pub fn outStream(self: *ISlice) OutStream {
    const GlobalStorage = struct {
      const vtable = OutStream.VTable{
        .write = outStreamWrite,
      };
    };
    return OutStream{
      .impl = @ptrCast(*c_void, self),
      .vtable = &GlobalStorage.vtable,
    };
  }

  pub fn seekableStream(self: *ISlice) SeekableStream(SeekError, GetSeekPosError) {
    return SeekableStream(SeekError, GetSeekPosError).init(self);
  }

  pub fn getWritten(self: *const ISlice) []const u8 {
    return self.slice[0..self.pos];
  }

  pub fn reset(self: *ISlice) void {
    self.pos = 0;
  }

  pub fn write(self: *ISlice, bytes: []const u8) WriteError!void {
    std.debug.assert(self.pos <= self.slice.len);

    const n = if (self.pos + bytes.len <= self.slice.len)
      bytes.len
    else
      self.slice.len - self.pos;

    std.mem.copy(u8, self.slice[self.pos .. self.pos + n], bytes[0..n]);
    self.pos += n;

    if (n < bytes.len) {
      return WriteError.OutOfSpace;
    }
  }

  fn outStreamWrite(impl: *c_void, bytes: []const u8) OutStream.Error!void {
    const self = @ptrCast(*ISlice, @alignCast(@alignOf(ISlice), impl));
    self.write(bytes) catch |err| {
      self.write_error = err;
      return OutStream.Error.WriteError;
    };
  }

  pub fn seekTo(self: *ISlice, pos: usize) SeekError!void {
    // FIXME - are you supposed to be able to seek past the end without an error?
    // i suppose it would only fail if you tried to read at that point?

    if (pos < self.slice.len) {
      self.pos = pos;
    } else {
      return SeekError.SliceSeekOutOfBounds;
    }
  }

  pub fn seekForward(self: *ISlice, amt: isize) SeekError!void {
    if (amt > 0) {
      const uofs = @intCast(usize, amt); // should never fail

      if (self.pos + uofs <= self.slice.len) {
        self.pos += uofs;
      } else {
        return SeekError.SliceSeekOutOfBounds;
      }
    } else if (amt < 0) {
      const uofs = @intCast(usize, -amt); // should never fail

      if (self.pos >= uofs) {
        self.pos -= uofs;
      } else {
        return SeekError.SliceSeekOutOfBounds;
      }
    }
  }

  pub fn getEndPos(self: *ISlice) GetSeekPosError!usize {
    return self.slice.len;
  }

  pub fn getPos(self: *ISlice) GetSeekPosError!usize {
    return self.pos;
  }
};
