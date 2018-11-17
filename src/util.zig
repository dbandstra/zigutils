const builtin = @import("builtin");
const std = @import("std");

// read from the instream, expecting to find the given string.
// return true if it was found.
// FIXME - if i use `Error!bool` return type, i get a weird compile error
pub fn requireStringInStream(comptime Error: type, instream: *std.io.InStream(Error), string: []const u8) !bool {
  for (string) |expectedByte| {
    const actualByte = try instream.readByte();

    if (actualByte != expectedByte) {
      return false;
    }
  }

  return true;
}

pub fn swapSlices(comptime T: type, a: []T, b: []T) void {
  std.debug.assert(a.len == b.len);
  var i: usize = 0;
  while (i < a.len) : (i += 1) {
    const value = a[i];
    a[i] = b[i];
    b[i] = value;
  }
}

// copied from macho.zig
pub fn readNoEof(comptime ReadError: type, in: *std.io.InStream(ReadError), comptime T: type, result: []T) !void {
  return in.readNoEof(@sliceToBytes(result));
}

// copied from macho.zig
pub fn readOneNoEof(comptime ReadError: type, in: *std.io.InStream(ReadError), comptime T: type, result: *T) !void {
  return readNoEof(ReadError, in, T, (*[1]T)(result)[0..]);
}

pub fn clearStruct(comptime T: type, value: *T) void {
  const sliceOfOne: []T = (*[1]T)(value)[0..];
  const memory: []u8 = @sliceToBytes(sliceOfOne);
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

pub fn fieldMeta(comptime Struct: type, comptime fieldName: []const u8, comptime endian: builtin.Endian) type {
  const field = blk: {
    for (@typeInfo(Struct).Struct.fields) |field| {
      if (std.mem.eql(u8, field.name, fieldName)) {
        break :blk field;
      }
    }

    @compileError("fieldMeta: field not found");
  };

  if (field.offset == null) {
    // offset is null if field has no size?
    @compileError("fieldMeta: field has no offset");
  }

  const fieldSize = @sizeOf(field.field_type);
  const offset = field.offset orelse 0;

  return struct{
    fn read(instance: *const Struct) field.field_type {
      const bytes = @intToPtr([*]u8, @ptrToInt(instance) + offset)[0..fieldSize];

      // should be a compile error if type is not an integer. i could add support for other types later
      return std.mem.readInt(bytes, field.field_type, endian);
    }

    fn getType() type {
      return field.field_type;
    }
  };
}
