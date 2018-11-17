const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const DoubleStackAllocatorFlat = struct{
  low_allocator: Allocator,
  high_allocator: Allocator,
  low_used: usize,
  high_used: usize,
  buffer: []u8,

  pub fn init(buffer: []u8) DoubleStackAllocatorFlat {
    return DoubleStackAllocatorFlat{
      .low_allocator = Allocator{
        .allocFn = alloc_low,
        .reallocFn = realloc_low,
        .freeFn = free,
      },
      .high_allocator = Allocator{
        .allocFn = alloc_high,
        .reallocFn = realloc_high,
        .freeFn = free,
      },
      .low_used = 0,
      .high_used = 0,
      .buffer = buffer,
    };
  }

  fn alloc_low(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
    const self = @fieldParentPtr(DoubleStackAllocatorFlat, "low_allocator", allocator);
    const addr = @ptrToInt(self.buffer.ptr) + self.low_used;
    const rem = @rem(addr, alignment);
    const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
    const adjusted_index = self.low_used + march_forward_bytes;
    const new_low_used = adjusted_index + n;
    if (new_low_used > self.buffer.len - self.high_used) {
      return error.OutOfMemory;
    }
    const result = self.buffer[adjusted_index..new_low_used];
    self.low_used = new_low_used;
    return result;
  }

  fn alloc_high(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
    const self = @fieldParentPtr(DoubleStackAllocatorFlat, "high_allocator", allocator);
    const addr = @ptrToInt(self.buffer.ptr) + self.buffer.len - self.high_used;
    const rem = @rem(addr, alignment);
    const march_backward_bytes = rem;
    const adjusted_index = self.high_used + march_backward_bytes;
    const new_high_used = adjusted_index + n;
    if (new_high_used > self.buffer.len - self.low_used) {
      return error.OutOfMemory;
    }
    const start = self.buffer.len - adjusted_index - n;
    const result = self.buffer[start..start + n];
    self.high_used = new_high_used;
    return result;
  }

  fn realloc_low(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
    if (new_size <= old_mem.len) {
      return old_mem[0..new_size];
    } else {
      const result = try alloc_low(allocator, new_size, alignment);
      std.mem.copy(u8, result, old_mem);
      return result;
    }
  }

  fn realloc_high(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
    if (new_size <= old_mem.len) {
      return old_mem[0..new_size];
    } else {
      const result = try alloc_high(allocator, new_size, alignment);
      std.mem.copy(u8, result, old_mem);
      return result;
    }
  }

  fn free(allocator: *Allocator, bytes: []u8) void {}

  fn get_low_mark(self: *DoubleStackAllocatorFlat) usize {
    return self.low_used;
  }

  fn get_high_mark(self: *DoubleStackAllocatorFlat) usize {
    return self.high_used;
  }

  fn free_to_low_mark(self: *DoubleStackAllocatorFlat, pos: usize) void {
    std.debug.assert(pos <= self.low_used);
    if (pos < self.low_used) {
      if (builtin.mode == builtin.Mode.Debug) {
        std.mem.set(u8, self.buffer[pos..pos + self.low_used], 0xcc);
      }
      self.low_used = pos;
    }
  }

  fn free_to_high_mark(self: *DoubleStackAllocatorFlat, pos: usize) void {
    std.debug.assert(pos <= self.high_used);
    if (pos < self.high_used) {
      if (builtin.mode == builtin.Mode.Debug) {
        const i = self.buffer.len - self.high_used;
        const n = self.high_used - pos;
        std.mem.set(u8, self.buffer[i..i + n], 0xcc);
      }
      self.high_used = pos;
    }
  }
};

test "DoubleStackAllocatorFlat" {
  var buf: [100 * 1024]u8 = undefined;
  var dsaf = DoubleStackAllocatorFlat.init(buf[0..]);

  _ = dsaf.low_allocator.alloc(u8, 7);
  _ = dsaf.high_allocator.alloc(u8, 7);
}
