const std = @import("std");
const skip = @import("util.zig").skip;

pub const ImageFormat = enum {
  RGBA,
  RGB,
};

pub const Image = struct{
  width: u32,
  height: u32,
  format: ImageFormat,
  pixels: []u8,
};

pub fn LoadTga(comptime ReadError: type) type {
  return struct {
    const Self = this;

    // FIXME - need EndOfStream and OutOfMemory in my other functions?
    const LoadError =
      ReadError ||
      error{EndOfStream} ||
      error{OutOfMemory} ||
      error{PlaceholderError};

    pub fn load(
      source: *std.io.InStream(ReadError),
      allocator: *std.mem.Allocator,
    ) LoadError!*Image {
      const id_length       = try source.readByte();
      const colormap_type   = try source.readByte();
      const image_type      = try source.readByte();
      const colormap_index  = try source.readIntLe(u16);
      const colormap_length = try source.readIntLe(u16);
      const colormap_size   = try source.readByte();
      const x_origin        = try source.readIntLe(u16);
      const y_origin        = try source.readIntLe(u16);
      const width           = try source.readIntLe(u16);
      const height          = try source.readIntLe(u16);
      const pixel_size      = try source.readByte();
      const attributes      = try source.readByte();

      try skip(ReadError, source, id_length);

      if ((attributes & ~u8(0x28)) != 0) {
        std.debug.warn("bad attributes\n");
        return LoadError.PlaceholderError;
      }

      // if bit 5 of attributes isn't set, the image has been stored from bottom to top */
      const bottom_to_top = (attributes & u8(0x20)) == 0;

      var compressed = false;
      var x: i32 = 0;
      var y: i32 = 0;
      var red: u8 = 255;
      var green: u8 = 255;
      var blue: u8 = 255;
      var alpha: u8 = 255;

      switch (image_type) {
        // BGR or BGRA
        10, 2 => {
          compressed = image_type == 10;

          if (pixel_size != 24 and pixel_size != 32) {
            std.debug.warn("bad pixel_size\n");
            return LoadError.PlaceholderError;
          }

          const pixels = try allocator.alloc(u8, width * height * 4);
          var image = try allocator.construct(Image{
            .width = width,
            .height = height,
            .format = ImageFormat.RGBA,
            .pixels = pixels,
          });

          var data: [*]u8 = pixels.ptr;
          var pixbuf: [*]u8 = undefined;
          var row_dec: usize = undefined;
          var readpixelcount: i32 = undefined;
          var runlen: i32 = undefined;

          if (bottom_to_top) {
            pixbuf = data + (height - 1) * width * 4;
            row_dec = usize(width) * 4 * 2;
          } else {
            pixbuf = data;
            row_dec = 0;
          }

          if (compressed) {
            while (y < i32(height)) {
              readpixelcount = 1000000;

              runlen = try source.readByte();
              // high bit indicates this is an RLE compressed run
              if ((runlen & 0x80) != 0) {
                readpixelcount = 1;
              }
              runlen = 1 + (runlen & 0x7f);

              // while ((runlen--) && y < height) {
              while (true) {
                const old_runlen = runlen;
                runlen -= 1;
                if (old_runlen == 0) {
                  break;
                }
                if (y >= i32(height)) {
                  break;
                }
                if (readpixelcount > 0) {
                  readpixelcount -= 1;

                  blue  = try source.readByte();
                  green = try source.readByte();
                  red   = try source.readByte();
                  if (pixel_size == 32) {
                    alpha = try source.readByte();
                  } else {
                    alpha = 255;
                  }
                }

                pixbuf[0] = red;
                pixbuf[1] = green;
                pixbuf[2] = blue;
                pixbuf[3] = alpha;
                pixbuf += 4;

                x += 1;
                if (x == i32(width)) {
                  // end of line, advance to next
                  x = 0;
                  y += 1;
                  pixbuf -= row_dec;
                }
              }
            }
          } else {
            while (y < i32(height)) {
              pixbuf[2] = try source.readByte();
              pixbuf[1] = try source.readByte();
              pixbuf[0] = try source.readByte();
              if (pixel_size == 32) {
                pixbuf[3] = try source.readByte();
              } else {
                pixbuf[3] = 255;
              }
              
              pixbuf += 4;

              x += 1;
              if (x == i32(width)) {
                // end of line, advance to next
                x = 0;
                y += 1;
                pixbuf -= row_dec;
              }
            }
          }

          return image;
        },
        else => {
          std.debug.warn("bad image_type\n");
          return LoadError.PlaceholderError;
        },
      }
    }
  };
}

test "LoadTga" {
  const MemoryInStream = @import("MemoryInStream.zig").MemoryInStream;
  const allocator = std.debug.global_allocator;

  var source = MemoryInStream.init(@embedFile("testdata/gem.tga"));

  const image = try LoadTga(MemoryInStream.ReadError).load(&source.stream, allocator);
  defer allocator.destroy(image);

  std.debug.assert(image.width == 12);
  std.debug.assert(image.height == 12);

  var file = try std.os.File.openWrite(std.debug.global_allocator, "out.ppm");
  defer file.close();
  var fos = std.io.FileOutStream.init(&file);
  try fos.stream.print("P3\n");
  try fos.stream.print("{} {}\n", image.width, image.height);
  try fos.stream.print("255\n");
  var y: usize = 0;
  while (y < image.height) {
    var x: usize = 0;
    while (x < image.width) {
      const r = image.pixels[(y * image.width + x) * 4 + 0];
      const g = image.pixels[(y * image.width + x) * 4 + 1];
      const b = image.pixels[(y * image.width + x) * 4 + 2];
      try fos.stream.print("{} {} {} ", r, g, b);
      x += 1;
    }
    try fos.stream.print("\n");
    y += 1;
  }
}
