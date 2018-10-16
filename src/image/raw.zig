const std = @import("std");
const image = @import("image.zig");

pub const RawFormat = enum.{
  R8G8B8,
  R8G8B8A8,
};

pub fn WriteRaw(comptime WriteError: type) type {
  return struct.{
    pub fn write(img: *const image.Image, stream: *std.io.OutStream(WriteError), format: RawFormat) !void {
      var y: u32 = 0;
      while (y < img.info.height) : (y += 1) {
        var x: u32 = 0;
        while (x < img.info.width) : (x += 1) {
          try writePixel(image.getPixelUnsafe(img, x, y), stream, format);
        }
      }
    }

    fn writePixel(pixel: image.Pixel, stream: *std.io.OutStream(WriteError), format: RawFormat) !void {
      switch (format) {
        RawFormat.R8G8B8 => {
          try stream.write([]u8.{pixel.r, pixel.g, pixel.b});
        },
        RawFormat.R8G8B8A8 => {
          try stream.write([]u8.{pixel.r, pixel.g, pixel.b, pixel.a});
        },
      }
    }
  };
}
