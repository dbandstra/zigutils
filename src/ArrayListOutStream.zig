const std = @import("std");

//
// creates an OutStream that writes to an ArrayList(u8).
// (caller provides the array list instance)
//

pub const ArrayListOutStream = struct{
  array_list: *std.ArrayList(u8),
  stream: Stream,

  pub const Error = std.mem.Allocator.Error; // this is what ArrayList::appendSlice can throw
  pub const Stream = std.io.OutStream(Error);

  pub fn init(array_list: *std.ArrayList(u8)) ArrayListOutStream {
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
  const Hunk = @import("Hunk.zig").Hunk;

  var memory: [1024]u8 = undefined;
  var hunk = Hunk.init(memory[0..]);
  var hunk_side = hunk.low();
  const allocator = &hunk_side.allocator;

  const mark = hunk_side.getMark();
  defer hunk_side.freeToMark(mark);

  var array_list = std.ArrayList(u8).init(allocator);
  defer array_list.deinit();

  var alos = ArrayListOutStream.init(&array_list);

  try alos.stream.print("This is pretty nice, no buffer limit.");

  std.testing.expect(std.mem.eql(u8, array_list.toSlice(), "This is pretty nice, no buffer limit."));
}
