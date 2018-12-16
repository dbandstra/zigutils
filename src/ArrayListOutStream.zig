const std = @import("std");
const mem = std.mem;

const Allocator = @import("traits/Allocator.zig").Allocator;
const OutStream = @import("streams/OutStream.zig").OutStream;

pub fn ArrayList(comptime T: type) type {
    return AlignedArrayList(T, @alignOf(T));
}

pub fn AlignedArrayList(comptime T: type, comptime A: u29) type {
    return struct {
        const Self = @This();

        /// Use toSlice instead of slicing this directly, because if you don't
        /// specify the end position of the slice, this will potentially give
        /// you uninitialized memory.
        items: []align(A) T,
        len: usize,
        allocator: Allocator,

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = []align(A) T{},
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.items);
        }

        pub fn toSlice(self: Self) []align(A) T {
            return self.items[0..self.len];
        }

        pub fn toSliceConst(self: Self) []align(A) const T {
            return self.items[0..self.len];
        }

        pub fn count(self: Self) usize {
            return self.len;
        }

        pub fn capacity(self: Self) usize {
            return self.items.len;
        }

        pub fn appendSlice(self: *Self, items: []align(A) const T) !void {
            try self.ensureCapacity(self.len + items.len);
            mem.copy(T, self.items[self.len..], items);
            self.len += items.len;
        }

        pub fn ensureCapacity(self: *Self, new_capacity: usize) !void {
            var better_capacity = self.capacity();
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            self.items = try self.allocator.alignedRealloc(T, A, self.items, better_capacity);
        }
    };
}

//
// creates an OutStream that writes to an ArrayList(u8).
// (caller provides the array list instance)
//

pub const ArrayListOutStream = struct{
  pub const WriteError = Allocator.Error; // this is what ArrayList::appendSlice can throw

  array_list: *ArrayList(u8),
  write_error: ?WriteError,

  pub fn init(array_list: *ArrayList(u8)) ArrayListOutStream {
    return ArrayListOutStream{
      .array_list = array_list,
      .write_error = null,
    };
  }

  pub fn outStream(self: *ArrayListOutStream) OutStream {
    const GlobalStorage = struct {
      const vtable = OutStream.VTable{
        .write = outStreamWrite,
      };
    };
    return OutStream{
      .impl = @ptrCast(*c_void, self),
      .vtable = &GlobalStorage.vtable,
    };
  }

  pub fn write(self: *ArrayListOutStream, bytes: []const u8) WriteError!void {
    try self.array_list.appendSlice(bytes);
  }

  fn outStreamWrite(impl: *c_void, bytes: []const u8) OutStream.Error!void {
    const self = @ptrCast(*ArrayListOutStream, @alignCast(@alignOf(ArrayListOutStream), impl));
    self.write(bytes) catch |err| {
      self.write_error = err;
      return OutStream.Error.WriteError;
    };
  }
};

test "ArrayListOutStream" {
  const SingleStackAllocator = @import("SingleStackAllocator.zig").SingleStackAllocator;

  var memory: [1024]u8 = undefined;
  var ssa = SingleStackAllocator.init(memory[0..]);
  const allocator = ssa.allocator();
  const mark = ssa.getMark();
  defer ssa.freeToMark(mark);

  var array_list = ArrayList(u8).init(allocator);
  defer array_list.deinit();

  var alos = ArrayListOutStream.init(&array_list);
  var out_stream = alos.outStream();

  try out_stream.print("This is pretty nice, no buffer limit.");

  std.debug.assert(std.mem.eql(u8, array_list.toSlice(), "This is pretty nice, no buffer limit."));
}
