const std = @import("std");

pub const StackAllocator = struct{
  allocator: std.mem.Allocator,

  getMarkFn: fn (self: *StackAllocator) usize,
  freeToMarkFn: fn (self: *StackAllocator, pos: usize) void,

  pub fn getMark(self: *StackAllocator) usize {
    return self.getMarkFn(self);
  }

  pub fn freeToMark(self: *StackAllocator, pos: usize) void {
    self.freeToMarkFn(self, pos);
  }
};
