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
