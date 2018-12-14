// single object implementing all the traits...

const std = @import("std");

const InStream = @import("InStream.zig").InStream;
const SeekableStream = @import("SeekableStream.zig").SeekableStream;

pub const IConstSlice = struct {
  pub const ReadError = error{};
  pub const SeekError = error{SliceSeekOutOfBounds};
  pub const GetSeekPosError = error{};

  slice: []const u8,
  pos: usize,

  pub fn init(slice: []const u8) IConstSlice {
    return IConstSlice{
      .slice = slice,
      .pos = 0,
    };
  }

  pub fn inStream(self: *IConstSlice) InStream(ReadError) {
    return InStream(ReadError).init(self);
  }

  pub fn seekableStream(self: *IConstSlice) SeekableStream(SeekError, GetSeekPosError) {
    return SeekableStream(SeekError, GetSeekPosError).init(self);
  }

  pub fn read(self: *IConstSlice, dest: []u8) ReadError!usize {
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

  pub fn getEndPos(self: *IConstSlice) GetSeekPosError!usize {
    return self.slice.len;
  }

  pub fn getPos(self: *IConstSlice) GetSeekPosError!usize {
    return self.pos;
  }
};
