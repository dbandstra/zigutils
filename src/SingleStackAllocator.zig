const builtin = @import("builtin");
const std = @import("std");

const Allocator = @import("traits/Allocator.zig").Allocator;
const StackAllocator = @import("traits/StackAllocator.zig").StackAllocator;

// should the name of this reflect that it's taking a fixed buffer?

pub const SingleStackAllocator = struct{
  used: usize,
  buffer: []u8,

  pub fn init(buffer: []u8) SingleStackAllocator {
    return SingleStackAllocator{
      .used = 0,
      .buffer = buffer,
    };
  }

  pub fn allocator(self: *SingleStackAllocator) Allocator {
    // return Allocator.init(self);

    const GlobalStorage = struct {
      const vtable = Allocator.VTable{
        .alloc = @ptrCast(fn (impl: *c_void, byte_count: usize, alignment: u29) Allocator.Error![]u8, alloc),
        .realloc = @ptrCast(fn (impl: *c_void, old_mem: []u8, new_byte_count: usize, alignment: u29) Allocator.Error![]u8, realloc),
        .free = @ptrCast(fn (impl: *c_void, old_mem: []u8) void, free),
      };
    };

    return Allocator{
      .impl = @ptrCast(*c_void, self),
      .vtable = &GlobalStorage.vtable,
    };
  }

  pub fn stackAllocator(self: *SingleStackAllocator) StackAllocator {
    return StackAllocator.init(self);
  }

  pub fn alloc(self: *SingleStackAllocator, n: usize, alignment: u29) Allocator.Error![]u8 {
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

  pub fn realloc(self: *SingleStackAllocator, old_mem: []u8, new_size: usize, alignment: u29) Allocator.Error![]u8 {
    if (new_size <= old_mem.len) {
      return old_mem[0..new_size];
    } else {
      const result = try self.alloc(new_size, alignment);
      std.mem.copy(u8, result, old_mem);
      return result;
    }
  }

  pub fn free(self: *SingleStackAllocator, bytes: []u8) void {
    // std.debug.warn("Warning: StackAllocator free function does nothing!\n");
  }

  pub fn getMark(self: *SingleStackAllocator) usize {
    return self.used;
  }

  pub fn freeToMark(self: *SingleStackAllocator, pos: usize) void {
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
  var hunk_allocator = hunk.allocator();

  _ = hunk_allocator.alloc(u8, 7);
}
