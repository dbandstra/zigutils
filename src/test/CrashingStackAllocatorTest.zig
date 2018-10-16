const std = @import("std");
const Allocator = std.mem.Allocator;

var whatever = "aewfoahewgfiauhfeoaiuwehfoaiuewhfoaiwuehfoaiwuehf";

pub const Inner = struct.{
  allocator: Allocator,
  inner_field: i32,
};

pub const Outer = struct.{
  inner: Inner,
  outer_field: i32,

  pub fn init() Outer {
    return Outer.{
      .inner = Inner.{
        .allocator = Allocator.{
          .allocFn = alloc,
          .reallocFn = realloc,
          .freeFn = free,
        },
        .inner_field = 200,
      },
      .outer_field = 100,
    };
  }

  fn alloc(allocator: *Allocator, n: usize, alignment: u29) ![]u8 {
    const inner = @fieldParentPtr(Inner, "allocator", allocator);

    std.debug.warn("inner_field before: {}\n", inner.inner_field); // this works fine
    inner.inner_field = 2; // this crashes
    std.debug.warn("inner_field after: {}\n", inner.inner_field);

    const outer = @fieldParentPtr(Outer, "inner", inner);

    std.debug.warn("outer_field before: {}\n", outer.outer_field); // this works fine
    outer.outer_field = 1; // this crashes
    std.debug.warn("outer_field after: {}\n", outer.outer_field);

    if (n == 12345) return error.OutOfMemory else return whatever[0..n];
  }

  fn realloc(allocator: *Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
    return error.OutOfMemory;
  }

  fn free(allocator: *Allocator, bytes: []u8) void {
    unreachable;
  }
};

// if this is in global scope it crashes
pub const outer_instance_ref = &outer_instance;
var outer_instance = Outer.init();

test "replicate crash" {
  std.debug.warn("\n");

  // this works fine
  // var outer_instance = Outer.init();
  // const outer_instance_ref = &outer_instance;

  _ = try outer_instance_ref.inner.allocator.alloc(u8, 10);
}
