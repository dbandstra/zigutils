const swapSlices = @import("../util.zig").swapSlices;

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

pub const Pixel = struct {
  r: u8,
  g: u8,
  b: u8,
  a: u8,
};

pub fn flipImageVertical(image: *Image) void {
  const bpp = ImageFormat.getBytesPerPixel(image.format);
  const rb = bpp * image.width;

  var y: u32 = 0;

  while (y < image.height / 2) : (y += 1) {
    const ofs0 = rb * y;
    const ofs1 = rb * (image.height - 1 - y);

    const row0 = image.pixels[ofs0..ofs0 + rb];
    const row1 = image.pixels[ofs1..ofs1 + rb];

    swapSlices(u8, row0, row1);
  }
}

pub fn getPixel(image: *const Image, x: u32, y: u32) ?Pixel {
  if (x >= image.width or y >= image.height) {
    return null;
  } else {
    const ofs = y * image.width + x;

    switch (image.format) {
      ImageFormat.RGBA => {
        const mem = image.pixels[ofs * 4..ofs * 4 + 4];

        return Pixel{
          .r = mem[0],
          .g = mem[1],
          .b = mem[2],
          .a = mem[3],
        };
      },
      ImageFormat.RGB => {
        const mem = image.pixels[ofs * 3..ofs * 3 + 3];

        return Pixel{
          .r = mem[0],
          .g = mem[1],
          .b = mem[2],
          .a = 255,
        };
      },
    }
  }
}
