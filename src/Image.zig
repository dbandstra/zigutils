// resources:
// https://en.wikipedia.org/wiki/Truevision_TGA
// http://www.paulbourke.net/dataformats/tga/

// the goal is for this to be a "reference" tga loader. cleanest possible code,
// support everything, no concern for performance, robust test suite.
// once that's done, a performance-oriented implementation can be added

const std = @import("std");
const skip = @import("util.zig").skip;
const MemoryOutStream = @import("MemoryOutStream.zig").MemoryOutStream;

pub const ImageFormat = enum {
  RGBA,
  RGB,

  pub fn getBytesPerPixel(imageFormat: ImageFormat) u32 {
    switch (imageFormat) {
      ImageFormat.RGBA => return 4,
      ImageFormat.RGB => return 3,
    }
  }
};

pub const Image = struct{
  width: u32,
  height: u32,
  format: ImageFormat,
  pixels: []u8,
};

pub fn flipImageVertical(image: *Image) void {
  const bpp = ImageFormat.getBytesPerPixel(image.format);

  var y: u32 = 0;

  while (y < image.height / 2) : (y += 1) {
    var x: u32 = 0;

    while (x < image.width * bpp) : (x += 1) {
      const y0 = y;
      const y1 = image.height - 1 - y;

      const a = image.pixels[y0 * image.width * bpp + x];
      image.pixels[y0 * image.width * bpp + x] = image.pixels[y1 * image.width * bpp + x];
      image.pixels[y1 * image.width * bpp + x] = a;
    }
  }
}

const Pixel = struct { r: u8, g: u8, b: u8, a: u8 };

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

      if (colormap_type != 0) {
        // TODO support colormap_type 1
        return LoadError.Unsupported;
      }
      if (colormap_length != 0) {
        return LoadError.Unsupported;
      }

      try skip(ReadError, source, id_length);

      if ((attributes & ~u8(0x28)) != 0) {
        std.debug.warn("bad attributes\n");
        return LoadError.Unsupported;
      }

      // if bit 5 of attributes isn't set, the image has been stored from bottom to top */
      const bottom_to_top = (attributes & u8(0x20)) == 0;

      switch (image_type) {
        else => return LoadError.Corrupt,
        1, 9 => return LoadError.Unsupported, // colormapped (TODO)
        3, 11 => return LoadError.Unsupported, // greyscale (TODO)
        2, 10 => {
          // true colour image
          const compressed = image_type == 10;

          if (pixel_size != 24 and pixel_size != 32) {
            std.debug.warn("bad pixel_size\n");
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
            if (compressed) {
              const run_header = try source.readByte();
              const run_length: u32 = 1 + (run_header & 0x7f); // between 1 and 128 inclusive
              const is_raw_packet = (run_header & 0x80) == 0;
              var pixel: Pixel = undefined;
              var j: u32 = 0;

              while (i < width * height and j < run_length) : ({ i += 1; j += 1; }) {
                if (j == 0 or is_raw_packet) {
                  pixel = try readPixel(pixel_size, source);
                }
                writePixel(storeFormat, &dest, pixel);
              }
            } else {
              writePixel(storeFormat, &dest, try readPixel(pixel_size, source));
              i += 1;
            }
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

fn WritePpm(comptime WriteError: type) type {
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

test "LoadTga: load compressed tga" {
  const ArrayListOutStream = @import("ArrayListOutStream.zig").ArrayListOutStream;
  const MemoryInStream = @import("MemoryInStream.zig").MemoryInStream;
  const allocator = std.debug.global_allocator;

  var source = MemoryInStream.init(@embedFile("testdata/gem-compressed.tga"));

  const image = try LoadTga(MemoryInStream.ReadError).load(&source.stream, ImageFormat.RGBA, allocator);
  defer allocator.destroy(image);

  // write image as PPM and compare it the copy in testdata
  var arrayList = std.ArrayList(u8).init(std.debug.global_allocator);
  defer arrayList.deinit();
  var alos = ArrayListOutStream.init(&arrayList);

  try WritePpm(ArrayListOutStream.Error).write(image, &alos.stream);

  std.debug.assert(std.mem.eql(u8, arrayList.toSliceConst(), @embedFile("testdata/gem.ppm")));
}

test "LoadTga: load uncompressed tga" {
  const ArrayListOutStream = @import("ArrayListOutStream.zig").ArrayListOutStream;
  const MemoryInStream = @import("MemoryInStream.zig").MemoryInStream;
  const allocator = std.debug.global_allocator;

  var source = MemoryInStream.init(@embedFile("testdata/gem-uncompressed.tga"));

  const image = try LoadTga(MemoryInStream.ReadError).load(&source.stream, ImageFormat.RGBA, allocator);
  defer allocator.destroy(image);

  // write image as PPM and compare it the copy in testdata
  var arrayList = std.ArrayList(u8).init(std.debug.global_allocator);
  defer arrayList.deinit();
  var alos = ArrayListOutStream.init(&arrayList);

  try WritePpm(ArrayListOutStream.Error).write(image, &alos.stream);

  std.debug.assert(std.mem.eql(u8, arrayList.toSliceConst(), @embedFile("testdata/gem.ppm")));
}
