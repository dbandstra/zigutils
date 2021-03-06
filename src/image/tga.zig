const builtin = @import("builtin");
const std = @import("std");
const readOneNoEof = @import("../util.zig").readOneNoEof;
const image = @import("image.zig");

// resources:
// https://en.wikipedia.org/wiki/Truevision_TGA
// http://www.paulbourke.net/dataformats/tga/

// the goal is for this to be a "reference" tga loader. cleanest possible code,
// support everything, no concern for performance, robust test suite.
// once that's done, a performance-oriented implementation can be added

const TGA_HEADER_SIZE = 18;

pub const TgaInfo = struct{
  id_length: u8,
  colormap_type: u8,
  image_type: u8,
  colormap_index: u16,
  colormap_length: u16,
  colormap_size: u8,
  x_origin: u16,
  y_origin: u16,
  width: u16,
  height: u16,
  pixel_size: u8,
  attr_bits: u4,
  reserved: u1,
  origin: u1,
  interleaving: u2,
};

pub fn tgaBestStoreFormat(tgaInfo: TgaInfo) image.Format {
  if (tgaInfo.attr_bits > 0) {
    return image.Format.RGBA;
  } else {
    return image.Format.RGB;
  }
}

pub fn LoadTga(
  comptime ReadError: type,
  comptime SeekError: type,
  comptime GetSeekPosError: type,
) type {
  const MyInStream = std.io.InStream(ReadError);
  const MySeekableStream = std.io.SeekableStream(SeekError, GetSeekPosError);

  return struct{
    const Self = @This();

    const PreloadError =
      ReadError ||
      error{EndOfStream} || // returned by InStream::readByte
      error{Corrupt, Unsupported};

    const LoadError =
      ReadError ||
      SeekError ||
      error{EndOfStream} || // returned by InStream::readByte;
      error{Corrupt};

    pub fn preload(
      stream: *MyInStream,
      seekable: *MySeekableStream,
    ) PreloadError!TgaInfo {
      const id_length = try stream.readByte();
      const colormap_type = try stream.readByte();
      const image_type = try stream.readByte();
      const colormap_index = try stream.readIntLittle(u16);
      const colormap_length = try stream.readIntLittle(u16);
      const colormap_size = try stream.readByte();
      const x_origin = try stream.readIntLittle(u16);
      const y_origin = try stream.readIntLittle(u16);
      const width = try stream.readIntLittle(u16);
      const height = try stream.readIntLittle(u16);
      const pixel_size = try stream.readByte();
      const descriptor = try stream.readByte();

      const attr_bits = @truncate(u4, descriptor & 0x0F);
      const reserved = @truncate(u1, (descriptor & 0x10) >> 4);
      const origin = @truncate(u1, (descriptor & 0x20) >> 5);
      const interleaving = @truncate(u2, (descriptor & 0xC0) >> 6);

      if (colormap_type != 0) {
        return PreloadError.Unsupported; // TODO
      }
      if (reserved != 0) {
        return PreloadError.Corrupt;
      }
      if (interleaving != 0) {
        return PreloadError.Unsupported;
      }

      switch (image_type) {
        else => return PreloadError.Corrupt,
        0 => return PreloadError.Unsupported, // no image data included
        1, 9 => return PreloadError.Unsupported, // colormapped (TODO)
        3, 11 => return PreloadError.Unsupported, // greyscale (TODO)
        32, 33 => return PreloadError.Unsupported,
        2, 10 => {
          if (pixel_size == 16) {
            if (attr_bits != 1) {
              return PreloadError.Corrupt;
            }
          } else if (pixel_size == 24) {
            if (attr_bits != 0) {
              return PreloadError.Corrupt;
            }
          } else if (pixel_size == 32) {
            if (attr_bits != 8) {
              return PreloadError.Corrupt;
            }
          } else {
            return PreloadError.Corrupt;
          }
        },
      }

      return TgaInfo{
        .id_length = id_length,
        .colormap_type = colormap_type,
        .image_type = image_type,
        .colormap_index = colormap_index,
        .colormap_length = colormap_length,
        .colormap_size = colormap_size,
        .x_origin = x_origin,
        .y_origin = y_origin,
        .width = width,
        .height = height,
        .pixel_size = pixel_size,
        .attr_bits = attr_bits,
        .reserved = reserved,
        .origin = origin,
        .interleaving = interleaving,
      };
    }

    pub fn load(
      stream: *MyInStream,
      seekable: *MySeekableStream,
      tgaInfo: TgaInfo,
      img: *image.Image,
    ) LoadError!void {
      std.debug.assert(tgaInfo.width == img.info.width and tgaInfo.height == img.info.height);

      try seekable.seekTo(TGA_HEADER_SIZE + tgaInfo.id_length);

      switch (tgaInfo.image_type) {
        else => unreachable,
        2, 10 => {
          const compressed = tgaInfo.image_type == 10;

          const num_pixels = img.info.width * img.info.height;
          var dest = std.io.SliceOutStream.init(img.pixels);

          var i: u32 = 0;

          while (i < num_pixels) {
            var run_length: u32 = undefined;
            var is_raw_packet: bool = undefined;

            if (compressed) {
              const run_header = try stream.readByte();

              run_length = 1 + (run_header & 0x7f);
              is_raw_packet = (run_header & 0x80) == 0;
            } else {
              run_length = 1;
              is_raw_packet = true;
            }

            if (i + run_length > num_pixels) {
              return LoadError.Corrupt;
            }

            var j: u32 = 0;

            if (is_raw_packet) {
              while (j < run_length) : (j += 1) {
                const pixel = try readPixel(tgaInfo.pixel_size, stream);
                writePixel(img.info.format, &dest, pixel);
              }
            } else {
              const pixel = try readPixel(tgaInfo.pixel_size, stream);

              while (j < run_length) : (j += 1) {
                writePixel(img.info.format, &dest, pixel);
              }
            }

            i += run_length;
          }
        },
      }

      if (tgaInfo.origin == 0) {
        image.flipVertical(img);
      }
    }

    fn readPixel(pixelSize: u8, stream: *std.io.InStream(ReadError)) ReadError!image.Pixel {
      switch (pixelSize) {
        16 => {
          var p: [2]u8 = undefined;
          std.debug.assert(2 == try stream.read(p[0..]));
          const r = (p[1] & 0x7C) >> 2;
          const g = ((p[1] & 0x03) << 3) | ((p[0] & 0xE0) >> 5);
          const b = (p[0] & 0x1F);
          const a = (p[1] & 0x80) >> 7;
          return image.Pixel{
            .r = (r << 3) | (r >> 2),
            .g = (g << 3) | (g >> 2),
            .b = (b << 3) | (b >> 2),
            .a = a * 0xFF,
          };
        },
        24 => {
          var bgr: [3]u8 = undefined;
          std.debug.assert(3 == try stream.read(bgr[0..]));
          return image.Pixel{ .r = bgr[2], .g = bgr[1], .b = bgr[0], .a = 255 };
        },
        32 => {
          var bgra: [4]u8 = undefined;
          std.debug.assert(4 == try stream.read(bgra[0..]));
          return image.Pixel{ .r = bgra[2], .g = bgra[1], .b = bgra[0], .a = bgra[3] };
        },
        else => unreachable,
      }
    }

    fn writePixel(storeFormat: image.Format, dest: *std.io.SliceOutStream, pixel: image.Pixel) void {
      switch (storeFormat) {
        // `catch unreachable` because we allocated the whole buffer at the right size
        image.Format.RGBA => dest.stream.write([_]u8{ pixel.r, pixel.g, pixel.b, pixel.a }) catch unreachable,
        image.Format.RGB => dest.stream.write([_]u8{ pixel.r, pixel.g, pixel.b }) catch unreachable,
        else => unreachable, // FIXME...
      }
    }
  };
}
