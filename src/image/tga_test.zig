const std = @import("std");
const Hunk = @import("../Hunk.zig").Hunk;
const ArrayListOutStream = @import("../ArrayListOutStream.zig").ArrayListOutStream;
const my_io = @import("../SliceStream.zig");
const image = @import("image.zig");
const WriteRaw = @import("raw.zig").WriteRaw;
const RawFormat = @import("raw.zig").RawFormat;
const LoadTga = @import("tga.zig").LoadTga;
const tgaBestStoreFormat = @import("tga.zig").tgaBestStoreFormat;

// TODO:
// - test top-to-bottom images
// - rewrite testdata tgas so they have the same comment at the end
// - write a utility to strip tga comments?

test "LoadTga: load compressed 32-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-compressed-32bit.tga",
    "../testdata/image/gem-raw-r8g8b8a8.data",
    TestLoadTgaParams{
      .expectedImageType = 10,
      .expectedPixelSize = 32,
      .expectedAttrBits = 8,
      .rawFormat = RawFormat.R8G8B8A8,
      .tolerance = 0,
    },
  );
}

test "LoadTga: load uncompressed 32-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-uncompressed-32bit.tga",
    "../testdata/image/gem-raw-r8g8b8a8.data",
    TestLoadTgaParams{
      .expectedImageType = 2,
      .expectedPixelSize = 32,
      .expectedAttrBits = 8,
      .rawFormat = RawFormat.R8G8B8A8,
      .tolerance = 0,
    },
  );
}

test "LoadTga: load compressed 24-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-compressed-24bit.tga",
    "../testdata/image/gem-raw-r8g8b8.data",
    TestLoadTgaParams{
      .expectedImageType = 10,
      .expectedPixelSize = 24,
      .expectedAttrBits = 0,
      .rawFormat = RawFormat.R8G8B8,
      .tolerance = 0,
    },
  );
}

test "LoadTga: load uncompressed 24-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-uncompressed-24bit.tga",
    "../testdata/image/gem-raw-r8g8b8.data",
    TestLoadTgaParams{
      .expectedImageType = 2,
      .expectedPixelSize = 24,
      .expectedAttrBits = 0,
      .rawFormat = RawFormat.R8G8B8,
      .tolerance = 0,
    },
  );
}

test "LoadTga: load compressed 16-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-compressed-16bit.tga",
    "../testdata/image/gem-raw-r8g8b8a8.data",
    TestLoadTgaParams{
      .expectedImageType = 10,
      .expectedPixelSize = 16,
      .expectedAttrBits = 1,
      .rawFormat = RawFormat.R8G8B8A8,
      .tolerance = 8,
    },
  );
}

test "LoadTga: load uncompressed 16-bit tga" {
  try testLoadTga(
    "../testdata/image/gem-uncompressed-16bit.tga",
    "../testdata/image/gem-raw-r8g8b8a8.data",
    TestLoadTgaParams{
      .expectedImageType = 2,
      .expectedPixelSize = 16,
      .expectedAttrBits = 1,
      .rawFormat = RawFormat.R8G8B8A8,
      .tolerance = 8,
    },
  );
}

const TestLoadTgaParams = struct{
  expectedImageType: u8,
  expectedPixelSize: u8,
  expectedAttrBits: u4,
  rawFormat: RawFormat,
  tolerance: i32,
};

fn testLoadTga(
  comptime tgaFilename: []const u8,
  comptime rawFilename: []const u8,
  params: TestLoadTgaParams,
) !void {
  var memory: [100 * 1024]u8 = undefined;
  var hunk = Hunk.init(memory[0..]);
  var hunk_side = hunk.low();
  const allocator = &hunk_side.allocator;

  const mark = hunk_side.getMark();
  defer hunk_side.freeToMark(mark);

  var swc = my_io.SliceWithCursor.init(@embedFile(tgaFilename));
  var in_stream = my_io.SliceInStream2.init(&swc);
  var seekable = my_io.SliceSeekableStream.init(&swc);

  // load tga
  const LoadTgaType = LoadTga(
    my_io.SliceInStream2.Error,
    my_io.SliceSeekableStream.SeekError,
    my_io.SliceSeekableStream.GetSeekPosError,
  );
  const tgaInfo = try LoadTgaType.preload(&in_stream.stream, &seekable.stream);
  std.testing.expectEqual(params.expectedImageType, tgaInfo.image_type);
  std.testing.expectEqual(params.expectedPixelSize, tgaInfo.pixel_size);
  std.testing.expectEqual(params.expectedAttrBits, tgaInfo.attr_bits);
  const img = try image.createImage(allocator, image.Info{
    .width = tgaInfo.width,
    .height = tgaInfo.height,
    .format = tgaBestStoreFormat(tgaInfo),
  });
  defer image.destroyImage(allocator, img);
  try LoadTgaType.load(&in_stream.stream, &seekable.stream, tgaInfo, img);

  // write image in raw format and compare it the copy in testdata
  var arrayList = std.ArrayList(u8).init(allocator);
  defer arrayList.deinit();
  var alos = ArrayListOutStream.init(&arrayList);

  try WriteRaw(ArrayListOutStream.Error).write(img, &alos.stream, params.rawFormat);

  // compare raw data. as for the tolerance variable: when we load a 16-bit
  // image, we upsample it to 24-bit. there are a few ways you can do the
  // rounding, which will result in slightly different colour values. all we
  // care about in the tests is that they aren't completely wrong (we aren't
  // testing the exact rounding method).
  const a = arrayList.toSliceConst();
  const b = @embedFile(rawFilename);

  std.testing.expect(blk: {
    if (a.len != b.len) {
      break :blk false;
    }
    var i: u32 = 0;
    while (i < a.len) : (i += 1) {
      const d = i32(a[i]) - i32(b[i]);

      if (d < -params.tolerance or d > params.tolerance) {
        break :blk false;
      }
    }
    break :blk true;
  });
}
