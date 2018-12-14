const std = @import("std");

const OutStream = @import("streams/OutStream.zig").OutStream;

//
// creates an OutStream that writes to an ArrayList(u8).
// (caller provides the array list instance)
//

pub const ArrayListOutStream = struct{
  pub const Error = std.mem.Allocator.Error; // this is what ArrayList::appendSlice can throw

  array_list: *std.ArrayList(u8),

  pub fn init(array_list: *std.ArrayList(u8)) ArrayListOutStream {
    return ArrayListOutStream{
      .array_list = array_list,
    };
  }

  pub fn outStream(self: *ArrayListOutStream) OutStream(Error) {
    return OutStream(Error).init(self);
  }

  pub fn write(self: *ArrayListOutStream, bytes: []const u8) Error!void {
    try self.array_list.appendSlice(bytes);
  }
};

test "ArrayListOutStream" {
  var memory: [1024]u8 = undefined;
  var ssa = @import("SingleStackAllocator.zig").SingleStackAllocator.init(memory[0..]);
  const allocator = &ssa.stack.allocator;
  const mark = ssa.stack.get_mark();
  defer ssa.stack.free_to_mark(mark);

  var array_list = std.ArrayList(u8).init(allocator);
  defer array_list.deinit();

  var alos = ArrayListOutStream.init(&array_list);
  var out_stream = alos.outStream();

  try out_stream.print("This is pretty nice, no buffer limit.");

  std.debug.assert(std.mem.eql(u8, array_list.toSlice(), "This is pretty nice, no buffer limit."));
}
