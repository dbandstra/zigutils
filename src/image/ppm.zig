const std = @import("std");
const Image = @import("image.zig").Image;

pub fn WritePpm(comptime WriteError: type) type {
  return struct {
    fn write(image: *const Image, stream: *std.io.OutStream(WriteError)) !void {
      try stream.print("P3\n");
      try stream.print("{} {}\n", image.width, image.height);
      try stream.print("255\n");
      var y: usize = 0;
      while (y < image.height) {
        var x: usize = 0;
        while (x < image.width) {
          // FIXME - assumes RGBA
          const r = image.pixels[(y * image.width + x) * 4 + 0];
          const g = image.pixels[(y * image.width + x) * 4 + 1];
          const b = image.pixels[(y * image.width + x) * 4 + 2];
          if (x > 0) {
            try stream.print(" ");
          }
          try stream.print("{} {} {}", r, g, b);
          x += 1;
        }
        try stream.print("\n");
        y += 1;
      }
    }
  };
}
