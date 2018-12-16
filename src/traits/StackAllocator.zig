const std = @import("std");

pub const StackAllocator = struct{
  const VTable = struct {
    getMark: fn (impl: *c_void) usize,
    freeToMark: fn (impl: *c_void, pos: usize) void,
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

  pub fn initCustom(impl: var, vtable_obj: var) @This() {
    const T = @typeOf(vtable_obj).Child;
    return @This(){
      .vtable = comptime vtable.populate(VTable, T, T),
      .impl = @ptrCast(*c_void, impl),
    };
  }

  pub fn getMark(self: @This()) usize {
    return self.vtable.getMark(self.impl);
  }

  pub fn freeToMark(self: @This(), pos: usize) void {
    self.vtable.freeToMark(self.impl, pos);
  }
};
