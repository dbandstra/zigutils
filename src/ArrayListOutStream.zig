const std = @import("std");
const ArrayList = std.ArrayList;

//
// creates an OutStream that writes to an ArrayList(u8).
// (caller provides the array list instance)
//

pub const ArrayListOutStream = struct{
  array_list: *ArrayList(u8),
  stream: Stream,

  pub const Error = std.mem.Allocator.Error; // this is what ArrayList::appendSlice can throw
  pub const Stream = std.io.OutStream(Error);

  pub fn init(array_list: *ArrayList(u8)) ArrayListOutStream {
    return ArrayListOutStream{
      .array_list = array_list,
      .stream = Stream{ .writeFn = writeFn },
    };
  }

  fn writeFn(out_stream: *Stream, bytes: []const u8) !void {
    const self = @fieldParentPtr(ArrayListOutStream, "stream", out_stream);

    try self.array_list.appendSlice(bytes);
  }
};

test "ArrayListOutStream" {
  var memory: [1024]u8 = undefined;
  var ssa = @import("SingleStackAllocator.zig").SingleStackAllocator.init(memory[0..]);
  const allocator = &ssa.stack.allocator;
  const mark = ssa.stack.get_mark();
  defer ssa.stack.free_to_mark(mark);

  var array_list = ArrayList(u8).init(allocator);
  defer array_list.deinit();

  var alos = ArrayListOutStream.init(&array_list);

  try alos.stream.print("This is pretty nice, no buffer limit.");

  std.debug.assert(std.mem.eql(u8, array_list.toSlice(), "This is pretty nice, no buffer limit."));
}
