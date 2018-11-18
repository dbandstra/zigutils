const std = @import("std");
const Allocator = std.mem.Allocator;

pub const StackAllocator = struct{
  allocator: Allocator,

  getMarkFn: fn (self: *StackAllocator) usize,
  freeToMarkFn: fn (self: *StackAllocator, pos: usize) void,

  pub fn get_mark(self: *StackAllocator) usize {
    return self.getMarkFn(self);
  }

  pub fn free_to_mark(self: *StackAllocator, pos: usize) void {
    self.freeToMarkFn(self, pos);
  }
};
