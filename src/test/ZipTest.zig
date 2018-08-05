const std = @import("std");
const File = std.os.File;
const InStream = std.io.InStream;
const ssaf = @import("util/test_allocator.zig").ssaf;
const Seekable = @import("../traits/Seekable.zig").Seekable;
const SeekableFileInStream = @import("../FileInStream.zig").SeekableFileInStream;
const ScanZip = @import("../ScanZip.zig").ScanZip;
const COMPRESSION_DEFLATE = @import("../ScanZip.zig").COMPRESSION_DEFLATE;
const ZipWalkState = @import("../ScanZip.zig").ZipWalkState;
const Inflater = @import("../Inflater.zig").Inflater;
const InflateInStream = @import("../InflateInStream.zig").InflateInStream;

test "ZipTest: locate and decompress a file from a zip archive" {
  const allocator = &ssaf.allocator;
  const mark = ssaf.get_mark();
  defer ssaf.free_to_mark(mark);

  const uncompressedData = @embedFile("../testdata/adler32.c");

  var file = try File.openRead(allocator, "src/testdata/zlib1211.zip");
  defer file.close();
  var sfis = SeekableFileInStream.init(&file);

  const info = try ScanZip(SeekableFileInStream.ReadError).find_file(&sfis.stream, &sfis.seekable, "zlib-1.2.11/adler32.c");

  if (info) |fileInfo| {
    const pos = std.math.cast(i64, fileInfo.offset) catch unreachable;
    _ = try sfis.seekable.seek(pos, Seekable.Whence.Start);

    std.debug.assert(fileInfo.compressionMethod == COMPRESSION_DEFLATE);
    std.debug.assert(fileInfo.uncompressedSize == uncompressedData.len);

    var inflater = Inflater.init(allocator, -15);
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

test "ZipTest: count files inside a zip archive" {
  const allocator = &ssaf.allocator;
  const mark = ssaf.get_mark();
  defer ssaf.free_to_mark(mark);

  var file = try File.openRead(allocator, "src/testdata/zlib1211.zip");
  defer file.close();
  var sfis = SeekableFileInStream.init(&file);

  const sz = ScanZip(SeekableFileInStream.ReadError);

  const isZipFile = try sz.is_zip_file(&sfis.stream, &sfis.seekable);
  std.debug.assert(isZipFile);
  const cdInfo = try sz.find_central_directory(&sfis.stream, &sfis.seekable);
  var walkState: ZipWalkState = undefined;
  var filenameBuf: [260]u8 = undefined;
  sz.walkInit(cdInfo, &walkState, filenameBuf[0..]);

  var count: usize = 0;
  while (try sz.walk(&walkState, &sfis.stream, &sfis.seekable)) |f| {
    count += 1;
    if (count > 1000) {
      unreachable;
    }
  }

  std.debug.assert(count == 293);
}
