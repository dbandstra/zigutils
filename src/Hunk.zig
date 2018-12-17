// WARNING: this will probably crash if instantiated at the global scope
// see https://github.com/ziglang/zig/issues/1636

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

const StackAllocator = @import("traits/StackAllocator.zig").StackAllocator;

// this is like FixedBufferAllocator, but supports freeing.
// also, it allows allocating at either end of the buffer, kind of like two
// stacks.

// maybe rename `low_allocator` to just `allocator`, so the high allocator
// is more like a bonus feature?

// you can allocate from either end of the buffer. typically, you would
// allocate persistent things at the low end, and temporary things at the
// high end.
// you can't free allocations directly, but you can clear the entire
// buffer to a previous position.
// low_used and high_used both count from 0, but high_used is actually counting
// back from the end of the buffer.
// the buffer is full when (buffer.len - low_used - high_used) is too small
// to fit a new allocation.
// this is inspired by the hunk system in Quake by id Software.

// TODO - return errors instead of crashing
// TODO - write tests
// i haven't even tried to use the high_allocator so there's a good chance
// the code is wrong

pub const Hunk = struct{
  low: StackAllocator,
  high: StackAllocator,
  low_used: usize,
  high_used: usize,
  buffer: []u8,

  pub fn init(buffer: []u8) Hunk {
    return Hunk{
      .low = StackAllocator{
        .allocator = Allocator{
          .allocFn = allocLow,
          .reallocFn = reallocLow,
          .freeFn = free,
        },
        .getMarkFn = getLowMark,
        .freeToMarkFn = freeToLowMark,
      },
      .high = StackAllocator{
        .allocator = Allocator{
          .allocFn = allocHigh,
          .reallocFn = reallocHigh,
          .freeFn = free,
        },
        .getMarkFn = getHighMark,
        .freeToMarkFn = freeToHighMark,
      },
      .low_used = 0,
      .high_used = 0,
      .buffer = buffer,
    };
  }

  fn allocLow(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
    const stack_allocator = @fieldParentPtr(StackAllocator, "allocator", allocator);
    const self = @fieldParentPtr(Hunk, "low", stack_allocator);
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

  fn allocHigh(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
    const stack_allocator = @fieldParentPtr(StackAllocator, "allocator", allocator);
    const self = @fieldParentPtr(Hunk, "high", stack_allocator);
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

  fn reallocLow(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
    if (new_size <= old_mem.len) {
      return old_mem[0..new_size];
    } else {
      const result = try allocLow(allocator, new_size, alignment);
      std.mem.copy(u8, result, old_mem);
      return result;
    }
  }

  fn reallocHigh(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
    if (new_size <= old_mem.len) {
      return old_mem[0..new_size];
    } else {
      const result = try allocHigh(allocator, new_size, alignment);
      std.mem.copy(u8, result, old_mem);
      return result;
    }
  }

  fn free(allocator: *Allocator, bytes: []u8) void {
    // std.debug.warn("Warning: StackAllocator free function does nothing!\n");
  }

  fn getLowMark(stack_allocator: *StackAllocator) usize {
    const self = @fieldParentPtr(Hunk, "low", stack_allocator);
    return self.low_used;
  }

  fn getHighMark(stack_allocator: *StackAllocator) usize {
    const self = @fieldParentPtr(Hunk, "high", stack_allocator);
    return self.high_used;
  }

  fn freeToLowMark(stack_allocator: *StackAllocator, pos: usize) void {
    const self = @fieldParentPtr(Hunk, "low", stack_allocator);
    std.debug.assert(pos <= self.low_used);
    if (pos < self.low_used) {
      if (builtin.mode == builtin.Mode.Debug) {
        std.mem.set(u8, self.buffer[pos..pos + self.low_used], 0xcc);
      }
      self.low_used = pos;
    }
  }

  fn freeToHighMark(stack_allocator: *StackAllocator, pos: usize) void {
    const self = @fieldParentPtr(Hunk, "high", stack_allocator);
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

test "Hunk" {
  // test a few random operations. very low coverage. write more later
  var buf: [100]u8 = undefined;
  var hunk = Hunk.init(buf[0..]);

  const high_mark = hunk.high.getMark();

  _ = try hunk.low.allocator.alloc(u8, 7);
  _ = try hunk.high.allocator.alloc(u8, 8);

  std.debug.assert(hunk.low_used == 7);
  std.debug.assert(hunk.high_used == 8);

  _ = try hunk.high.allocator.alloc(u8, 8);

  std.debug.assert(hunk.high_used == 16);

  const low_mark = hunk.low.getMark();

  _ = try hunk.low.allocator.alloc(u8, 100 - 7 - 16);

  std.debug.assert(hunk.low_used == 100 - 16);

  std.debug.assertError(hunk.high.allocator.alloc(u8, 1), error.OutOfMemory);

  hunk.low.freeToMark(low_mark);

  _ = try hunk.high.allocator.alloc(u8, 1);

  hunk.high.freeToMark(high_mark);

  std.debug.assert(hunk.high_used == 0);
}
