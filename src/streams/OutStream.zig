const std = @import("std");

const vtable = @import("../vtable.zig");

pub fn OutStream(comptime E: type) type {
  return struct {
    pub const Error = E;

    const VTable = struct {
      write: fn (impl: *c_void, buf: []const u8) Error!void,
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

    pub fn print(self: @This(), comptime format: []const u8, args: ...) Error!void {
      return std.fmt.format(self.impl, Error, self.vtable.write, format, args);
    }

    pub fn write(self: @This(), bytes: []const u8) Error!void {
      return self.vtable.write(self.impl, bytes);
    }

    pub fn writeByte(self: @This(), byte: u8) Error!void {
      const slice = (*[1]u8)(&byte)[0..];
      return self.vtable.write(self.impl, slice);
    }
  };
}
