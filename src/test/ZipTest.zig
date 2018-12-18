const std = @import("std");
const File = std.os.File;
const InStream = std.io.InStream;
const Hunk = @import("../Hunk.zig").Hunk;
const ScanZip = @import("../ScanZip.zig").ScanZip;
const COMPRESSION_DEFLATE = @import("../ScanZip.zig").COMPRESSION_DEFLATE;
const ZipWalkState = @import("../ScanZip.zig").ZipWalkState;
const Inflater = @import("../Inflater.zig").Inflater;
const InflateInStream = @import("../InflateInStream.zig").InflateInStream;

test "ZipTest: locate and decompress a file from a zip archive" {
  var memory: [100 * 1024]u8 = undefined;
  var hunk = Hunk.init(memory[0..]);
  var hunk_side = hunk.low();
  const allocator = &hunk_side.allocator;

  const mark = hunk_side.getMark();
  defer hunk_side.freeToMark(mark);

  const uncompressedData = @embedFile("../testdata/adler32.c");

  var file = try File.openRead("src/testdata/zlib1211.zip");
  defer file.close();
  var in_stream = std.os.File.inStream(file);
  var seekable = std.os.File.seekableStream(file);

  const sz = ScanZip(
    std.os.File.InStream.Error,
    std.os.File.SeekError,
    std.os.File.GetSeekPosError,
  );

  const info = try sz.find_file(&in_stream.stream, &seekable.stream, "zlib-1.2.11/adler32.c");

  if (info) |fileInfo| {
    const pos = std.math.cast(usize, fileInfo.offset) catch unreachable;
    try seekable.stream.seekTo(pos);

    std.debug.assert(fileInfo.compressionMethod == COMPRESSION_DEFLATE);
    std.debug.assert(fileInfo.uncompressedSize == uncompressedData.len);

    var inflater = Inflater.init(allocator, -15);
    defer inflater.deinit();
    var inflateBuf: [256]u8 = undefined;
    var iis = InflateInStream(std.os.File.InStream.Error).init(&inflater, &in_stream.stream, inflateBuf[0..]);
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
  var file = try File.openRead("src/testdata/zlib1211.zip");
  defer file.close();
  var in_stream = std.os.File.inStream(file);
  var seekable = std.os.File.seekableStream(file);

  const sz = ScanZip(
    std.os.File.InStream.Error,
    std.os.File.SeekError,
    std.os.File.GetSeekPosError,
  );

  const isZipFile = try sz.is_zip_file(&in_stream.stream, &seekable.stream);
  std.debug.assert(isZipFile);
  const cdInfo = try sz.find_central_directory(&in_stream.stream, &seekable.stream);
  var walkState: ZipWalkState = undefined;
  var filenameBuf: [260]u8 = undefined;
  sz.walkInit(cdInfo, &walkState, filenameBuf[0..]);

  var count: usize = 0;
  while (try sz.walk(&walkState, &in_stream.stream, &seekable.stream)) |f| {
    count += 1;
    if (count > 1000) {
      unreachable;
    }
  }

  std.debug.assert(count == 293);
}
