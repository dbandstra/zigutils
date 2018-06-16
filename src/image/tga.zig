const builtin = @import("builtin");
const std = @import("std");
const MemoryOutStream = @import("../MemoryOutStream.zig").MemoryOutStream;
const readOneNoEof = @import("../util.zig").readOneNoEof;
const skip = @import("../util.zig").skip;
const Image = @import("image.zig").Image;
const ImageFormat = @import("image.zig").ImageFormat;
const Pixel = @import("image.zig").Pixel;
const flipImageVertical = @import("image.zig").flipImageVertical;

// resources:
// https://en.wikipedia.org/wiki/Truevision_TGA
// http://www.paulbourke.net/dataformats/tga/

// the goal is for this to be a "reference" tga loader. cleanest possible code,
// support everything, no concern for performance, robust test suite.
// once that's done, a performance-oriented implementation can be added

pub fn LoadTga(comptime ReadError: type) type {
  return struct {
    const Self = this;

    // FIXME - need EndOfStream and OutOfMemory in my other functions?
    const LoadError =
      ReadError ||
      error{EndOfStream} ||
      error{OutOfMemory} ||
      error{Corrupt, Unsupported};

    // TODO - write a function that just returns metadata about the image.
    // then the caller could call that, look at it to decide which storeFormat
    // to use, then call load()

    pub fn load(
      source: *std.io.InStream(ReadError),
      storeFormat: ImageFormat,
      allocator: *std.mem.Allocator,
    ) LoadError!*Image {
      const id_length = try source.readByte();
      const colormap_type = try source.readByte();
      const image_type = try source.readByte();
      const colormap_index = try source.readIntLe(u16);
      const colormap_length = try source.readIntLe(u16);
      const colormap_size = try source.readByte();
      const x_origin = try source.readIntLe(u16);
      const y_origin = try source.readIntLe(u16);
      const width = try source.readIntLe(u16);
      const height = try source.readIntLe(u16);
      const pixel_size = try source.readByte();
      const descriptor = try source.readByte();

      const attr_bits = descriptor & 0x0F;
      const reserved = (descriptor & 0x10) >> 4;
      const origin = (descriptor & 0x20) >> 5;
      const interleaving = (descriptor & 0xC0) >> 6;

      if (colormap_type != 0) {
        return LoadError.Unsupported; // TODO
      }
      if (reserved != 0) {
        return LoadError.Corrupt;
      }
      if (interleaving != 0) {
        return LoadError.Unsupported;
      }

      try skip(ReadError, source, id_length);

      const bottom_to_top = origin == 0;

      switch (image_type) {
        else => return LoadError.Corrupt,
        1, 9 => return LoadError.Unsupported, // colormapped (TODO)
        3, 11 => return LoadError.Unsupported, // greyscale (TODO)
        2, 10 => {
          const compressed = image_type == 10;

          if (pixel_size == 16) {
            if (attr_bits != 1) {
              return LoadError.Corrupt;
            }
          } else if (pixel_size == 24) {
            if (attr_bits != 0) {
              return LoadError.Corrupt;
            }
          } else if (pixel_size == 32) {
            if (attr_bits != 8) {
              return LoadError.Corrupt;
            }
          } else {
            return LoadError.Corrupt;
          }

          const pixels = try allocator.alloc(u8, width * height * ImageFormat.getBytesPerPixel(storeFormat));
          var image = try allocator.construct(Image{
            .width = width,
            .height = height,
            .format = storeFormat,
            .pixels = pixels,
          });

          var dest = MemoryOutStream.init(pixels);

          var i: u32 = 0;

          while (i < width * height) {
            var run_length: u32 = undefined;
            var is_raw_packet: bool = undefined;

            if (compressed) {
              const run_header = try source.readByte();

              run_length = 1 + (run_header & 0x7f);
              is_raw_packet = (run_header & 0x80) == 0;
            } else {
              run_length = 1;
              is_raw_packet = true;
            }

            if (i + run_length > width * height) {
              allocator.destroy(image);
              return LoadError.Corrupt;
            }

            var j: u32 = 0;

            if (is_raw_packet) {
              while (j < run_length) : (j += 1) {
                const pixel = try readPixel(pixel_size, source);
                writePixel(storeFormat, &dest, pixel);
              }
            } else {
              const pixel = try readPixel(pixel_size, source);

              while (j < run_length) : (j += 1) {
                writePixel(storeFormat, &dest, pixel);
              }
            }

            i += run_length;
          }

          if (bottom_to_top) {
            flipImageVertical(image);
          }

          return image;
        },
      }
    }

    fn readPixel(pixelSize: u8, source: *std.io.InStream(ReadError)) ReadError!Pixel {
      switch (pixelSize) {
        16 => {
          var p: [2]u8 = undefined;
          std.debug.assert(2 == try source.read(p[0..]));
          const r = (p[1] & 0x7C) >> 2;
          const g = ((p[1] & 0x03) << 3) | ((p[0] & 0xE0) >> 5);
          const b = (p[0] & 0x1F);
          const a = (p[1] & 0x80) >> 7;
          return Pixel{
            .r = (r << 3) | (r >> 2),
            .g = (g << 3) | (g >> 2),
            .b = (b << 3) | (b >> 2),
            .a = a * 0xFF,
          };
        },
        24 => {
          var bgr: [3]u8 = undefined;
          std.debug.assert(3 == try source.read(bgr[0..]));
          return Pixel{ .r = bgr[2], .g = bgr[1], .b = bgr[0], .a = 255 };
        },
        32 => {
          var bgra: [4]u8 = undefined;
          std.debug.assert(4 == try source.read(bgra[0..]));
          return Pixel{ .r = bgra[2], .g = bgra[1], .b = bgra[0], .a = bgra[3] };
        },
        else => unreachable,
      }
    }

    fn writePixel(storeFormat: ImageFormat, dest: *MemoryOutStream, pixel: *const Pixel) void {
      switch (storeFormat) {
        // `catch unreachable` because we allocated the whole buffer at the right size
        ImageFormat.RGBA => dest.stream.write([]u8 { pixel.r, pixel.g, pixel.b, pixel.a }) catch unreachable,
        ImageFormat.RGB => dest.stream.write([]u8 { pixel.r, pixel.g, pixel.b }) catch unreachable,
      }
    }
  };
}
