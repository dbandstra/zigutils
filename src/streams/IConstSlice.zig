const std = @import("std");

const InStream = @import("InStream.zig").InStream;
const SeekableStream = @import("SeekableStream.zig").SeekableStream;

pub const IConstSlice = struct {
  pub const SeekError = error{SliceSeekOutOfBounds};

  slice: []const u8,
  pos: usize,
  seek_error: ?SeekError,

  pub fn init(slice: []const u8) IConstSlice {
    return IConstSlice{
      .slice = slice,
      .pos = 0,
      .seek_error = null,
    };
  }

  pub fn read(self: *IConstSlice, dest: []u8) usize {
    const size = std.math.min(dest.len, self.slice.len - self.pos);
    const end = self.pos + size;

    std.mem.copy(u8, dest[0..size], self.slice[self.pos..end]);
    self.pos = end;

    return size;
  }

  pub fn seekTo(self: *IConstSlice, pos: usize) SeekError!void {
    // FIXME - are you supposed to be able to seek past the end without an error?
    // i suppose it would only fail if you tried to read at that point?

    if (pos < self.slice.len) {
      self.pos = pos;
    } else {
      return SeekError.SliceSeekOutOfBounds;
    }
  }

  pub fn seekForward(self: *IConstSlice, amt: isize) SeekError!void {
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

  pub fn getEndPos(self: *IConstSlice) usize {
    return self.slice.len;
  }

  pub fn getPos(self: *IConstSlice) usize {
    return self.pos;
  }

  // InStream

  pub fn inStream(self: *IConstSlice) InStream {
    const GlobalStorage = struct {
      const vtable = InStream.VTable{
        .read = inStreamRead,
      };
    };
    return InStream{
      .impl = @ptrCast(*c_void, self),
      .vtable = &GlobalStorage.vtable,
    };
  }

  fn inStreamRead(impl: *c_void, dest: []u8) InStream.Error!usize {
    const self = @ptrCast(*IConstSlice, @alignCast(@alignOf(IConstSlice), impl));
    return self.read(dest);
  }

  // SeekableStream

  pub fn seekableStream(self: *IConstSlice) SeekableStream {
    const GlobalStorage = struct {
      const vtable = SeekableStream.VTable{
        .seekTo = seekableSeekTo,
        .seekForward = seekableSeekForward,
        .getPos = seekableGetPos,
        .getEndPos = seekableGetEndPos,
      };
    };
    return SeekableStream{
      .impl = @ptrCast(*c_void, self),
      .vtable = &GlobalStorage.vtable,
    };
  }

  pub fn seekableSeekTo(impl: *c_void, pos: usize) SeekableStream.SeekError!void {
    const self = @ptrCast(*IConstSlice, @alignCast(@alignOf(IConstSlice), impl));
    self.seekTo(pos) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  pub fn seekableSeekForward(impl: *c_void, amt: isize) SeekableStream.SeekError!void {
    const self = @ptrCast(*IConstSlice, @alignCast(@alignOf(IConstSlice), impl));
    self.seekForward(amt) catch |err| {
      self.seek_error = err;
      return SeekableStream.SeekError.SeekError;
    };
  }

  pub fn seekableGetEndPos(impl: *c_void) SeekableStream.GetSeekPosError!usize {
    const self = @ptrCast(*IConstSlice, @alignCast(@alignOf(IConstSlice), impl));
    return self.getEndPos();
  }

  pub fn seekableGetPos(impl: *c_void) SeekableStream.GetSeekPosError!usize {
    const self = @ptrCast(*IConstSlice, @alignCast(@alignOf(IConstSlice), impl));
    return self.getPos();
  }
};

test "IConstSlice: source buffer smaller than read buffer" {
  var source = IConstSlice.init("Hello world");

  var dest_buf: [100]u8 = undefined;

  const br0 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "Hello world"));
}

test "IConstSlice: source buffer longer than read buffer" {
  var source = IConstSlice.init("Between 15 and 20.");

  var dest_buf: [5]u8 = undefined;

  const br0 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "Betwe"));

  const br1 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br1], "en 15"));

  const br2 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br2], " and "));

  const br3 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br3], "20."));

  const br4 = source.read(dest_buf[0..]);
  std.debug.assert(br4 == 0);
}

test "IConstSlice: seeking around" {
  var source = IConstSlice.init("This is a decently long sentence.");

  var dest_buf: [5]u8 = undefined;

  const br0 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br0], "This "));

  try source.seekForward(3);
  const br1 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br1], "a dec"));

  try source.seekForward(-2);
  const br2 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br2], "ecent"));

  try source.seekForward(0);
  const cur_pos = source.getPos();
  std.debug.assert(cur_pos == 16);

  try source.seekTo(1);
  const br3 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br3], "his i"));

  try source.seekTo(source.slice.len - 3);
  const br4 = source.read(dest_buf[0..]);
  std.debug.assert(std.mem.eql(u8, dest_buf[0..br4], "ce."));

  std.debug.assertError(source.seekTo(999), error.SliceSeekOutOfBounds);
  std.debug.assertError(source.seekForward(-999), error.SliceSeekOutOfBounds);
}
