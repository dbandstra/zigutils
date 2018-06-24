// TODO - remove this in favour of SingleStackAllocator, once i figure
// out why it's crashing and fix it.

// this version is the same except the nested traits have been flattened.
// (it's ssa.allocator instead of ssa.stack.allocator)

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const SingleStackAllocatorFlat = struct {
  allocator: Allocator,
  used: usize,
  buffer: []u8,

  pub fn init(buffer: []u8) SingleStackAllocatorFlat {
    return SingleStackAllocatorFlat{
      .allocator = Allocator{
        .allocFn = alloc,
        .reallocFn = realloc,
        .freeFn = free,
      },
      .used = 0,
      .buffer = buffer,
    };
  }

  fn alloc(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
    const self = @fieldParentPtr(SingleStackAllocatorFlat, "allocator", allocator);
  
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

  fn free(allocator: *Allocator, bytes: []u8) void {}

  fn get_mark(self: *SingleStackAllocatorFlat) usize {
    return self.used;
  }

  fn free_to_mark(self: *SingleStackAllocatorFlat, pos: usize) void {
    std.debug.assert(pos <= self.used);
    if (pos < self.used) {
      if (builtin.mode == builtin.Mode.Debug) {
        std.mem.set(u8, self.buffer[pos..pos + self.used], 0xcc);
      }
      self.used = pos;
    }
  }
};

test "SingleStackAllocatorFlat" {
  var buf: [100 * 1024]u8 = undefined;
  var ssaf = SingleStackAllocatorFlat.init(buf[0..]);

  _ = ssaf.allocator.alloc(u8, 7);
}
