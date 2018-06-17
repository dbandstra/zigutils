const std = @import("std");
const Image = @import("image.zig").Image;
const ImageFormat = @import("image.zig").ImageFormat;
const getPixelUnsafe = @import("image.zig").getPixelUnsafe;
const Pixel = @import("image.zig").Pixel;

pub const RawFormat = enum{
  R8G8B8,
  R8G8B8A8,
};

pub fn WriteRaw(comptime WriteError: type) type {
  return struct {
    pub fn write(image: *const Image, stream: *std.io.OutStream(WriteError), format: RawFormat) !void {
      var y: u32 = 0;
      while (y < image.info.height) : (y += 1) {
        var x: u32 = 0;
        while (x < image.info.width) : (x += 1) {
          try writePixel(getPixelUnsafe(image, x, y), stream, format);
        }
      }
    }

    fn writePixel(pixel: *const Pixel, stream: *std.io.OutStream(WriteError), format: RawFormat) !void {
      switch (format) {
        RawFormat.R8G8B8 => {
          try stream.write([]u8{pixel.r, pixel.g, pixel.b});
        },
        RawFormat.R8G8B8A8 => {
          try stream.write([]u8{pixel.r, pixel.g, pixel.b, pixel.a});
        },
      }
    }
  };
}
