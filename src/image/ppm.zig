const std = @import("std");

pub fn WritePpm(comptime WriteError: type) type {
  return struct.{
    pub fn write(image: *const Image, stream: *std.io.OutStream(WriteError)) !void {
      try stream.print("P3\n");
      try stream.print("{} {}\n", image.width, image.height);
      try stream.print("255\n");
      var y: u32 = 0;
      while (y < image.height) : (y += 1) {
        var x: u32 = 0;
        while (x < image.width) : (x += 1) {
          if (x > 0) {
            try stream.print(" ");
          }
          const pixel = getPixel(image, x, y).?;
          try stream.print("{} {} {}", pixel.r, pixel.g, pixel.b);
        }
        try stream.print("\n");
      }
    }
  };
}
