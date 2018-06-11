const std = @import("std");
const File = std.os.File;
const InStream = std.io.InStream;
const Seekable = @import("../traits/Seekable.zig").Seekable;
const SeekableFileInStream = @import("../FileInStream.zig").SeekableFileInStream;
const ScanZip = @import("../ScanZip.zig").ScanZip;
const InflateInStream = @import("../InflateInStream.zig").InflateInStream;

// not really a test...
test "ScanZip" {
  var file = try File.openRead(std.debug.global_allocator, "zlib1211.zip");
  defer file.close();
  var sfis = SeekableFileInStream.init(&file);

  const info = try ScanZip(SeekableFileInStream.ReadError).find_file(&sfis.stream, &sfis.seekable, "zlib-1.2.11/zconf.h");

  if (info) |fileInfo| {
    std.debug.warn("got\n");

    // now inflate
    try sfis.seekable.seekTo(fileInfo.offset);

    if (fileInfo.isCompressed) {
      std.debug.warn("compressed ({}), full {}\n", fileInfo.compressedSize, fileInfo.uncompressedSize);

      var inflateBuf: [256]u8 = undefined;
      var iis = InflateInStream(SeekableFileInStream.ReadError).init(&sfis.stream, std.debug.global_allocator);
      defer iis.deinit();

      while (true) {
        const bytesRead = try iis.stream.read(inflateBuf[0..]);
        if (bytesRead == 0) {
          break;
        }
        std.debug.warn("{}", inflateBuf[0..bytesRead]);
      }

      std.debug.warn("\n");
    }
  } else {
    std.debug.warn("didn't got\n");
  }
}
