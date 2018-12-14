const std = @import("../index.zig");

const vtable = @import("../vtable.zig");

pub fn SeekableStream(comptime SeekErrorType: type, comptime GetSeekPosErrorType: type) type {
  return struct {
    pub const SeekError = SeekErrorType;
    pub const GetSeekPosError = GetSeekPosErrorType;

    const VTable = struct {
      seekTo: fn (impl: *c_void, pos: usize) SeekError!void,
      seekForward: fn (impl: *c_void, pos: isize) SeekError!void,
      getPos: fn (impl: *c_void) GetSeekPosError!usize,
      getEndPos: fn (impl: *c_void) GetSeekPosError!usize,
    };

    vtable: *const VTable,
    impl: *c_void,

    pub fn init(impl: var) @This() {
      const T = @typeOf(impl).Child;
      return @This(){
        .vtable = comptime vtable.populate(VTable, T, T),
        .impl = @ptrCast(*c_void, impl),
      };
    }

    pub fn seekTo(self: @This(), pos: usize) SeekError!void {
      return self.vtable.seekTo(self.impl, pos);
    }

    pub fn seekForward(self: @This(), amt: isize) SeekError!void {
      return self.vtable.seekForward(self.impl, amt);
    }

    pub fn getEndPos(self: @This()) GetSeekPosError!usize {
      return self.vtable.getEndPos(self.impl);
    }

    pub fn getPos(self: @This()) GetSeekPosError!usize {
      return self.vtable.getPos(self.impl);
    }
  };
}
