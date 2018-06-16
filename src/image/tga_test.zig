const std = @import("std");
const ArrayListOutStream = @import("../ArrayListOutStream.zig").ArrayListOutStream;
const MemoryInStream = @import("../MemoryInStream.zig").MemoryInStream;
const ImageFormat = @import("image.zig").ImageFormat;
const getPixelUnsafe = @import("image.zig").getPixelUnsafe;
const WriteRaw = @import("raw.zig").WriteRaw;
const RawFormat = @import("raw.zig").RawFormat;
const LoadTga = @import("tga.zig").LoadTga;

test "LoadTga: load compressed 32-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-compressed-32bit.tga",
    RawFormat.R8G8B8A8,
    "../testdata/image/gem-raw-r8g8b8a8.data",
    0,
  );
}

test "LoadTga: load uncompressed 32-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-uncompressed-32bit.tga",
    RawFormat.R8G8B8A8,
    "../testdata/image/gem-raw-r8g8b8a8.data",
    0,
  );
}

test "LoadTga: load compressed 24-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-compressed-24bit.tga",
    RawFormat.R8G8B8,
    "../testdata/image/gem-raw-r8g8b8.data",
    0,
  );
}

test "LoadTga: load uncompressed 24-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-uncompressed-24bit.tga",
    RawFormat.R8G8B8,
    "../testdata/image/gem-raw-r8g8b8.data",
    0,
  );
}

test "LoadTga: load compressed 16-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-compressed-16bit.tga",
    RawFormat.R8G8B8A8,
    "../testdata/image/gem-raw-r8g8b8a8.data",
    8,
  );
}

test "LoadTga: load uncompressed 16-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-uncompressed-16bit.tga",
    RawFormat.R8G8B8A8,
    "../testdata/image/gem-raw-r8g8b8a8.data",
    8,
  );
}

fn testLoadTga(
  comptime tgaFilename: []const u8,
  rawFormat: RawFormat,
  comptime rawFilename: []const u8,
  tolerance: i32,
) !void {
  var source = MemoryInStream.init(@embedFile(tgaFilename));

  const image = try LoadTga(MemoryInStream.ReadError).load(&source.stream, ImageFormat.RGBA, std.debug.global_allocator);
  defer std.debug.global_allocator.destroy(image);

  // write image in raw format and compare it the copy in testdata
  var arrayList = std.ArrayList(u8).init(std.debug.global_allocator);
  defer arrayList.deinit();
  var alos = ArrayListOutStream.init(&arrayList);

  try WriteRaw(ArrayListOutStream.Error).write(image, &alos.stream, rawFormat);

  // compare raw data. as for the tolerance variable: when we load a 16-bit
  // image, we upsample it to 24-bit. there are a few ways you can do the
  // rounding, which will result in slightly different colour values. all we
  // care about in the tests is that they aren't completely wrong (we aren't
  // testing the exact rounding method).
  const a = arrayList.toSliceConst();
  const b = @embedFile(rawFilename);

  std.debug.assert(blk: {
    if (a.len != b.len) {
      break :blk false;
    }
    var i: u32 = 0;
    while (i < a.len) : (i += 1) {
      const d = i32(a[i]) - i32(b[i]);

      if (d < -tolerance or d > tolerance) {
        break :blk false;
      }
    }
    break :blk true;
  });
}

// TODO:
// do 15 bit exist? or does 16 bit always have alpha bit?
// test top to bottom?
// 'readheader' function, assert some header bits in these tests?
// rewrite all tgas so they have the same comment at the end
