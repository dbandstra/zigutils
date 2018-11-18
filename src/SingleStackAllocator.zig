// WARNING: this will probably crash if instantiated at the global scope
// see https://github.com/ziglang/zig/issues/1636

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

const StackAllocator = @import("traits/StackAllocator.zig").StackAllocator;

// this one crashes because of the nested traits

// should the name of this reflect that it's taking a fixed buffer?

pub const SingleStackAllocator = struct{
  stack: StackAllocator,
  used: usize,
  buffer: []u8,

  pub fn init(buffer: []u8) SingleStackAllocator {
    return SingleStackAllocator{
      .stack = StackAllocator{
        .allocator = Allocator{
          .allocFn = alloc,
          .reallocFn = realloc,
          .freeFn = free,
        },
        .getMarkFn = get_mark,
        .freeToMarkFn = free_to_mark,
      },
      .used = 0,
      .buffer = buffer,
    };
  }

  fn alloc(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
    const stack = @fieldParentPtr(StackAllocator, "allocator", allocator);
    const self = @fieldParentPtr(SingleStackAllocator, "stack", stack);

    const addr = @ptrToInt(self.buffer.ptr) + self.used;
    const rem = @rem(addr, alignment);
    const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
    const adjusted_index = self.used + march_forward_bytes;
    const new_end_index = adjusted_index + n;
    if (new_end_index > self.buffer.len) {
      return error.OutOfMemory;
    }
    const result = self.buffer[adjusted_index..new_end_index];
    self.used = new_end_index;
    return result;
  }

  fn realloc(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
    if (new_size <= old_mem.len) {
      return old_mem[0..new_size];
    } else {
      const result = try alloc(allocator, new_size, alignment);
      std.mem.copy(u8, result, old_mem);
      return result;
    }
  }

  fn free(allocator: *Allocator, bytes: []u8) void {
    std.debug.warn("Warning: StackAllocator free function does nothing!\n");
  }

  fn get_mark(stack: *StackAllocator) usize {
    const self = @fieldParentPtr(SingleStackAllocator, "stack", stack);
    return self.used;
  }

  fn free_to_mark(stack: *StackAllocator, pos: usize) void {
    const self = @fieldParentPtr(SingleStackAllocator, "stack", stack);
    std.debug.assert(pos <= self.used);
    if (pos < self.used) {
      if (builtin.mode == builtin.Mode.Debug) {
        std.mem.set(u8, self.buffer[pos..pos + self.used], 0xcc);
      }
      self.used = pos;
    }
  }
};

test "SingleStackAllocator" {
  var buf: [100 * 1024]u8 = undefined;
  var hunk = SingleStackAllocator.init(buf[0..]);

  _ = hunk.stack.allocator.alloc(u8, 7);
}
