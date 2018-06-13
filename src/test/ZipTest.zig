const std = @import("std");
const File = std.os.File;
const InStream = std.io.InStream;
const Seekable = @import("../traits/Seekable.zig").Seekable;
const SeekableFileInStream = @import("../FileInStream.zig").SeekableFileInStream;
const ScanZip = @import("../ScanZip.zig").ScanZip;
const Inflater = @import("../Inflater.zig").Inflater;
const InflateInStream = @import("../InflateInStream.zig").InflateInStream;

test "ZipTest: locale and uncompress a file from a zip archive" {
  const uncompressedData = @embedFile("../testdata/adler32.c");

  var file = try File.openRead(std.debug.global_allocator, "src/testdata/zlib1211.zip");
  defer file.close();
  var sfis = SeekableFileInStream.init(&file);

  const info = try ScanZip(SeekableFileInStream.ReadError).find_file(&sfis.stream, &sfis.seekable, "zlib-1.2.11/adler32.c");

  if (info) |fileInfo| {
    try sfis.seekable.seekTo(fileInfo.offset);

    std.debug.assert(fileInfo.isCompressed);
    std.debug.assert(fileInfo.uncompressedSize == uncompressedData.len);

    var inflater = Inflater.init(std.debug.global_allocator, -15);
    defer inflater.deinit();
    var inflateBuf: [256]u8 = undefined;
    var iis = InflateInStream(SeekableFileInStream.ReadError).init(&inflater, &sfis.stream, inflateBuf[0..]);
    defer iis.deinit();

    var index: usize = 0;
    while (true) {
      var buffer: [256]u8 = undefined;
      const bytesRead = try iis.stream.read(buffer[0..]);
      if (bytesRead == 0) {
        break;
      }
      std.debug.assert(std.mem.eql(u8, buffer[0..bytesRead], uncompressedData[index..index + bytesRead]));
      index += bytesRead;
    }
  } else {
    unreachable;
  }
}
