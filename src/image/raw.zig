const std = @import("std");
const image = @import("image.zig");

const OutStream = @import("../streams/OutStream.zig").OutStream;

pub const RawFormat = enum{
  R8G8B8,
  R8G8B8A8,
};

pub const WriteRaw = struct{
  pub fn write(img: *const image.Image, stream: OutStream, format: RawFormat) OutStream.Error!void {
    var y: u32 = 0;
    while (y < img.info.height) : (y += 1) {
      var x: u32 = 0;
      while (x < img.info.width) : (x += 1) {
        try writePixel(image.getPixelUnsafe(img, x, y), stream, format);
      }
    }
  }

  fn writePixel(pixel: image.Pixel, stream: OutStream, format: RawFormat) OutStream.Error!void {
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
