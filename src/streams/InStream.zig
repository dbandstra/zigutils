const std = @import("std");

const vtable = @import("../vtable.zig");

pub fn InStream(comptime E: type) type {
  return struct {
    pub const Error = E;

    const VTable = struct {
      read: fn (impl: *c_void, buf: []u8) Error!usize,
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

    pub fn read(self: @This(), buf: []u8) Error!usize {
      return self.vtable.read(self.impl, buf);
    }

    pub fn readNoEof(self: @This(), buf: []u8) !void {
      const amt_read = try self.read(buf);
      if (amt_read < buf.len) return error.EndOfStream;
    }

    pub fn readByte(self: @This()) !u8 {
      var result: [1]u8 = undefined;
      try self.readNoEof(result[0..]);
      return result[0];
    }

    pub fn readIntNe(self: @This(), comptime T: type) !T {
      return self.readInt(builtin.endian, T);
    }

    pub fn readIntLe(self: @This(), comptime T: type) !T {
      var bytes: [@sizeOf(T)]u8 = undefined;
      try self.readNoEof(bytes[0..]);
      return std.mem.readIntSliceLittle(T, bytes);
    }

    pub fn readIntBe(self: @This(), comptime T: type) !T {
      var bytes: [@sizeOf(T)]u8 = undefined;
      try self.readNoEof(bytes[0..]);
      return std.mem.readIntSliceBig(T, bytes);
    }
  };
}
