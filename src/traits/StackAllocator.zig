const std = @import("std");
const Allocator = std.mem.Allocator;

pub const StackAllocator = struct {
  allocator: Allocator,

  getMarkFn: fn (self: *StackAllocator) usize,
  freeToMarkFn: fn (self: *StackAllocator, pos: usize) void,
};
