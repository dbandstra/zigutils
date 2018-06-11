const std = @import("std");

// should this be added to InStream?
// FIXME - i can't use `!void` return type, it complains
// that i don't return any error, but i do. compiler bug?
pub fn skip(comptime Error: type, instream: *std.io.InStream(Error), n: usize) Error!void {
  var buffer: [200]u8 = undefined;
  var i: usize = 0;

  while (i < n) {
    var count = n - i;
    if (count > buffer.len) {
      count = buffer.len;
    }
    _ = try instream.read(buffer[0..count]);
    i += count;
  }
}

pub fn clearStruct(comptime T: type, value: *T) void {
  const sliceOfOne: []T = (*[1]T)(value)[0..];
  const memory: []u8 = ([]u8)(sliceOfOne);
  std.mem.set(u8, memory, 0);
}

pub fn allocCPointer(allocator: *std.mem.Allocator, n: usize) ?*c_void {
  if (n == 0) {
    return @intToPtr(*c_void, 0);
  }

  const alignment = @alignOf(usize);

  // include the length on the heap, at the beginning of the allocated memory
  const numBytes = @sizeOf(usize) + n;
  const bytes = allocator.alignedAlloc(u8, alignment, numBytes) catch return @intToPtr(*c_void, 0);
  const lenPtr = @ptrCast(*usize, bytes.ptr);
  lenPtr.* = numBytes;
  const lenPtrInt = @ptrToInt(lenPtr);
  const dataPtrInt = lenPtrInt + @sizeOf(usize);
  const dataPtr = @intToPtr(*c_void, dataPtrInt);
  return dataPtr;
}

pub fn freeCPointer(allocator: *std.mem.Allocator, address: ?*c_void) void {
  const dataPtrInt = @ptrToInt(address);

  if (dataPtrInt == 0) {
    return;
  }

  const lenPtrInt = dataPtrInt - @sizeOf(usize);
  const lenPtr = @intToPtr(*usize, lenPtrInt);
  const len = lenPtr.*;
  const bytes = @ptrCast([*]u8, address)[0..len];

  allocator.free(bytes);
}
