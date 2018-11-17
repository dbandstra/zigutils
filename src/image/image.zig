const std = @import("std");
const swapSlices = @import("../util.zig").swapSlices;

pub const Format = enum{
  RGBA,
  RGB,
  INDEXED,

  pub fn getBytesPerPixel(imageFormat: Format) u32 {
    switch (imageFormat) {
      Format.RGBA => return 4,
      Format.RGB => return 3,
      Format.INDEXED => return 1,
    }
  }
};

pub const Info = struct{
  width: u32,
  height: u32,
  format: Format,
};

pub const Palette = struct{
  format: Format,
  data: []u8,
};

pub const Image = struct{
  info: Info,
  pixels: []u8,
};

pub const Pixel = struct{
  r: u8,
  g: u8,
  b: u8,
  a: u8,
};

pub fn createImage(allocator: *std.mem.Allocator, info: Info) !*Image {
  const pixels = try allocator.alloc(u8, info.width * info.height * Format.getBytesPerPixel(info.format));

  var image = try allocator.create(Image{
    .info = info,
    .pixels = pixels,
  });

  return image;
}

pub fn destroyImage(allocator: *std.mem.Allocator, img: *Image) void {
  allocator.free(img.pixels);
  allocator.destroy(img);
}

pub fn createPalette(allocator: *std.mem.Allocator) !*Palette {
  const data = try allocator.alloc(u8, 256*3);

  var palette = try allocator.create(Palette{
    .format = Format.RGB,
    .data = data,
  });

  return palette;
}

pub fn destroyPalette(allocator: *std.mem.Allocator, palette: *Palette) void {
  allocator.free(palette.data);
  allocator.destroy(palette);
}

pub fn convertToTrueColor(
  dest: *Image,
  source: *const Image,
  sourcePalette: *const Palette,
  transparent_color_index: ?u8,
) void {
  std.debug.assert(dest.info.width == source.info.width);
  std.debug.assert(dest.info.height == source.info.height);
  std.debug.assert(source.info.format == Format.INDEXED);

  var i: usize = 0;
  while (i < dest.info.width * dest.info.height) : (i += 1) {
    const index = source.pixels[i];
    if ((transparent_color_index orelse ~index) == index) {
      setColor(dest.info.format, dest.pixels, i, Pixel{
        .r = 0,
        .g = 0,
        .b = 0,
        .a = 0,
      });
    } else {
      const p = getColor(sourcePalette.format, sourcePalette.data, index);
      setColor(dest.info.format, dest.pixels, i, p);
    }
  }
}

pub fn flipHorizontal(image: *Image) void {
  var y: u32 = 0;
  while (y < image.info.height) : (y += 1) {
    var x0: u32 = 0;
    while (x0 < @divTrunc(image.info.width, 2)) : (x0 += 1) {
      const x1 = image.info.width - 1 - x0;
      const p0 = getPixel(image, x0, y).?;
      const p1 = getPixel(image, x1, y).?;
      setPixel(image, x0, y, p1);
      setPixel(image, x1, y, p0);
    }
  }
}

pub fn flipVertical(image: *Image) void {
  const bpp = Format.getBytesPerPixel(image.info.format);
  const rb = bpp * image.info.width;

  var y: u32 = 0;

  while (y < image.info.height / 2) : (y += 1) {
    const ofs0 = rb * y;
    const ofs1 = rb * (image.info.height - 1 - y);

    const row0 = image.pixels[ofs0..ofs0 + rb];
    const row1 = image.pixels[ofs1..ofs1 + rb];

    swapSlices(u8, row0, row1);
  }
}

pub fn getPixel(image: *const Image, x: u32, y: u32) ?Pixel {
  if (x >= image.info.width or y >= image.info.height) {
    return null;
  } else {
    return getPixelUnsafe(image, x, y);
  }
}

// dumb name
pub fn getPixelUnsafe(image: *const Image, x: u32, y: u32) Pixel {
  return getColor(image.info.format, image.pixels, y * image.info.width + x);
}

pub fn getColor(format: Format, data: []const u8, ofs: usize) Pixel {
  switch (format) {
    Format.RGBA => {
      const mem = data[ofs * 4..ofs * 4 + 4];

      return Pixel{
        .r = mem[0],
        .g = mem[1],
        .b = mem[2],
        .a = mem[3],
      };
    },
    Format.RGB => {
      const mem = data[ofs * 3..ofs * 3 + 3];

      return Pixel{
        .r = mem[0],
        .g = mem[1],
        .b = mem[2],
        .a = 255,
      };
    },
    Format.INDEXED => {
      const index = data[ofs];

      return Pixel{
        .r = index,
        .g = index,
        .b = index,
        .a = 255,
      };
    },
  }
}

pub fn setPixel(image: *Image, x: u32, y: u32, pixel: Pixel) void {
  if (x < image.info.width and y < image.info.height) {
    return setColor(image.info.format, image.pixels, y * image.info.width + x, pixel);
  }
}

pub fn setColor(format: Format, data: []u8, ofs: usize, p: Pixel) void {
  switch (format) {
    Format.RGBA => {
      const mem = data[ofs * 4..ofs * 4 + 4];
      mem[0] = p.r;
      mem[1] = p.g;
      mem[2] = p.b;
      mem[3] = p.a;
    },
    Format.RGB => {
      const mem = data[ofs * 3..ofs * 3 + 3];
      mem[0] = p.r;
      mem[1] = p.g;
      mem[2] = p.b;
    },
    Format.INDEXED => {
      @panic("Cannot call setColor on indexed-color images");
    },
  }
}
