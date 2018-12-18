const builtin = @import("builtin");
const std = @import("std");

pub const HunkSide = struct{
  pub const VTable = struct{
    alloc: fn (self: *Hunk, n: usize, alignment: u29) std.mem.Allocator.Error![]u8,
    getMark: fn (self: *Hunk) usize,
    freeToMark: fn (self: *Hunk, pos: usize) void,
  };

  hunk: *Hunk,
  vtable: *const VTable,
  allocator: std.mem.Allocator,

  pub fn init(hunk: *Hunk, vtable: *const VTable) HunkSide {
    return HunkSide{
      .hunk = hunk,
      .vtable = vtable,
      .allocator = std.mem.Allocator{
        .allocFn = alloc,
        .reallocFn = realloc,
        .freeFn = free,
      },
    };
  }

  pub fn alloc(allocator: *std.mem.Allocator, n: usize, alignment: u29) std.mem.Allocator.Error![]u8 {
    const self = @fieldParentPtr(HunkSide, "allocator", allocator);
    return self.vtable.alloc(self.hunk, n, alignment);
  }

  pub fn realloc(allocator: *std.mem.Allocator, old_mem: []u8, new_byte_count: usize, alignment: u29) std.mem.Allocator.Error![]u8 {
    const self = @fieldParentPtr(HunkSide, "allocator", allocator);
    if (new_byte_count <= old_mem.len) {
      return old_mem[0..new_byte_count];
    } else {
      const result = try self.vtable.alloc(self.hunk, new_byte_count, alignment);
      std.mem.copy(u8, result, old_mem);
      return result;
    }
  }

  pub fn free(allocator: *std.mem.Allocator, old_mem: []u8) void {
    // do nothing
  }

  pub fn getMark(self: *HunkSide) usize {
    return self.vtable.getMark(self.hunk);
  }

  pub fn freeToMark(self: *HunkSide, pos: usize) void {
    self.vtable.freeToMark(self.hunk, pos);
  }
};

pub const Hunk = struct{
  low_used: usize,
  high_used: usize,
  buffer: []u8,

  pub fn init(buffer: []u8) Hunk {
    return Hunk{
      .low_used = 0,
      .high_used = 0,
      .buffer = buffer,
    };
  }

  pub fn low(self: *Hunk) HunkSide {
    const GlobalStorage = struct{
      const vtable = HunkSide.VTable{
        .alloc = allocLow,
        .getMark = getLowMark,
        .freeToMark = freeToLowMark,
      };
    };
    return HunkSide.init(self, &GlobalStorage.vtable);
  }

  pub fn high(self: *Hunk) HunkSide {
    const GlobalStorage = struct{
      const vtable = HunkSide.VTable{
        .alloc = allocHigh,
        .getMark = getHighMark,
        .freeToMark = freeToHighMark,
      };
    };
    return HunkSide.init(self, &GlobalStorage.vtable);
  }

  pub fn allocLow(self: *Hunk, n: usize, alignment: u29) ![]u8 {
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

  pub fn allocHigh(self: *Hunk, n: usize, alignment: u29) ![]u8 {
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

  pub fn getLowMark(self: *Hunk) usize {
    return self.low_used;
  }

  pub fn getHighMark(self: *Hunk) usize {
    return self.high_used;
  }

  pub fn freeToLowMark(self: *Hunk, pos: usize) void {
    std.debug.assert(pos <= self.low_used);
    if (pos < self.low_used) {
      if (builtin.mode == builtin.Mode.Debug) {
        std.mem.set(u8, self.buffer[pos..pos + self.low_used], 0xcc);
      }
      self.low_used = pos;
    }
  }

  pub fn freeToHighMark(self: *Hunk, pos: usize) void {
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

  const high_mark = hunk.getHighMark();

  _ = try hunk.low().allocator.alloc(u8, 7);
  _ = try hunk.high().allocator.alloc(u8, 8);

  std.debug.assert(hunk.low_used == 7);
  std.debug.assert(hunk.high_used == 8);

  _ = try hunk.high().allocator.alloc(u8, 8);

  std.debug.assert(hunk.high_used == 16);

  const low_mark = hunk.getLowMark();

  _ = try hunk.low().allocator.alloc(u8, 100 - 7 - 16);

  std.debug.assert(hunk.low_used == 100 - 16);

  std.debug.assertError(hunk.high().allocator.alloc(u8, 1), error.OutOfMemory);

  hunk.freeToLowMark(low_mark);

  _ = try hunk.high().allocator.alloc(u8, 1);

  hunk.freeToHighMark(high_mark);

  std.debug.assert(hunk.high_used == 0);
}
