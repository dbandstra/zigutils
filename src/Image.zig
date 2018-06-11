const std = @import("std");
const skip = @import("util.zig").skip;

pub const Image = struct{
  width: u32,
  height: u32,
  pixels: []u8,
};

pub fn LoadTga(comptime ReadError: type) type {
  return struct {
    const Self = this;

    // FIXME - need EndOfStream and OutOfMemory in my other functions?
    const LoadError = ReadError || error{EndOfStream} || error{OutOfMemory} || error{
      PlaceholderError,
    };

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

      return allocator.construct(Image{
        .width = width,
        .height = height,
        .pixels = undefined, // TODO
      });
    }
  };
}

test "LoadTga" {
  const SimpleInStream = @import("SimpleInStream.zig").SimpleInStream;
  const allocator = std.debug.global_allocator;

  var source = SimpleInStream.init(@embedFile("testdata/gem.tga"));

  const image = try LoadTga(SimpleInStream.ReadError).load(&source.stream, allocator);
  defer allocator.destroy(image);

  std.debug.assert(image.width == 12);
  std.debug.assert(image.height == 12);
}
