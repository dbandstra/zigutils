const std = @import("std");
const assert = std.debug.assert;
const math = std.math;

const vtable = @import("../vtable.zig");

pub const Allocator = struct {
  pub const Error = error{OutOfMemory};

  const VTable = struct {
    alloc: fn (impl: *c_void, byte_count: usize, alignment: u29) Error![]u8,
    realloc: fn (impl: *c_void, old_mem: []u8, new_byte_count: usize, alignment: u29) Error![]u8,
    free: fn (impl: *c_void, old_mem: []u8) void,
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

  /// Call `destroy` with the result
  /// TODO this is deprecated. use createOne instead
  pub fn create(self: @This(), init_: var) Error!*@typeOf(init_) {
    const T = @typeOf(init_);
    if (@sizeOf(T) == 0) return &(T{});
    const slice = try self.alloc(T, 1);
    const ptr = &slice[0];
    ptr.* = init_;
    return ptr;
  }

  /// Call `destroy` with the result.
  /// Returns undefined memory.
  pub fn createOne(self: @This(), comptime T: type) Error!*T {
    if (@sizeOf(T) == 0) return &(T{});
    const slice = try self.alloc(T, 1);
    return &slice[0];
  }

  /// `ptr` should be the return value of `create`
  pub fn destroy(self: @This(), ptr: var) void {
    const non_const_ptr = @intToPtr([*]u8, @ptrToInt(ptr));
    self.vtable.free(self.impl, non_const_ptr[0..@sizeOf(@typeOf(ptr).Child)]);
  }

  pub fn alloc(self: @This(), comptime T: type, n: usize) ![]T {
    return self.alignedAlloc(T, @alignOf(T), n);
  }

  pub fn alignedAlloc(self: @This(), comptime T: type, comptime alignment: u29, n: usize) ![]align(alignment) T {
    if (n == 0) {
      return ([*]align(alignment) T)(undefined)[0..0];
    }
    const byte_count = math.mul(usize, @sizeOf(T), n) catch return Error.OutOfMemory;
    const byte_slice = try self.vtable.alloc(self.impl, byte_count, alignment);
    assert(byte_slice.len == byte_count);
    // This loop gets optimized out in ReleaseFast mode
    for (byte_slice) |*byte| {
      byte.* = undefined;
    }
    return @bytesToSlice(T, @alignCast(alignment, byte_slice));
  }

  pub fn realloc(self: @This(), comptime T: type, old_mem: []T, n: usize) ![]T {
    return self.alignedRealloc(T, @alignOf(T), @alignCast(@alignOf(T), old_mem), n);
  }

  pub fn alignedRealloc(self: @This(), comptime T: type, comptime alignment: u29, old_mem: []align(alignment) T, n: usize) ![]align(alignment) T {
    if (old_mem.len == 0) {
      return self.alignedAlloc(T, alignment, n);
    }
    if (n == 0) {
      self.free(old_mem);
      return ([*]align(alignment) T)(undefined)[0..0];
    }

    const old_byte_slice = @sliceToBytes(old_mem);
    const byte_count = math.mul(usize, @sizeOf(T), n) catch return Error.OutOfMemory;
    const byte_slice = try self.vtable.realloc(self.impl, old_byte_slice, byte_count, alignment);
    assert(byte_slice.len == byte_count);
    if (n > old_mem.len) {
      // This loop gets optimized out in ReleaseFast mode
      for (byte_slice[old_byte_slice.len..]) |*byte| {
        byte.* = undefined;
      }
    }
    return @bytesToSlice(T, @alignCast(alignment, byte_slice));
  }

  /// Reallocate, but `n` must be less than or equal to `old_mem.len`.
  /// Unlike `realloc`, this function cannot fail.
  /// Shrinking to 0 is the same as calling `free`.
  pub fn shrink(self: @This(), comptime T: type, old_mem: []T, n: usize) []T {
    return self.alignedShrink(T, @alignOf(T), @alignCast(@alignOf(T), old_mem), n);
  }

  pub fn alignedShrink(self: @This(), comptime T: type, comptime alignment: u29, old_mem: []align(alignment) T, n: usize) []align(alignment) T {
    if (n == 0) {
      self.free(old_mem);
      return old_mem[0..0];
    }

    assert(n <= old_mem.len);

    // Here we skip the overflow checking on the multiplication because
    // n <= old_mem.len and the multiplication didn't overflow for that operation.
    const byte_count = @sizeOf(T) * n;

    const byte_slice = self.vtable.realloc(self.impl, @sliceToBytes(old_mem), byte_count, alignment) catch unreachable;
    assert(byte_slice.len == byte_count);
    return @bytesToSlice(T, @alignCast(alignment, byte_slice));
  }

  pub fn free(self: @This(), memory: var) void {
    const bytes = @sliceToBytes(memory);
    if (bytes.len == 0) return;
    const non_const_ptr = @intToPtr([*]u8, @ptrToInt(bytes.ptr));
    self.vtable.free(self.impl, non_const_ptr[0..bytes.len]);
  }
};
