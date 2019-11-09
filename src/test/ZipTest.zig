const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
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

  var file = try std.fs.File.openRead("src/testdata/zlib1211.zip");
  defer file.close();
  var in_stream = std.fs.File.inStream(file);
  var seekable = std.fs.File.seekableStream(file);

  const sz = ScanZip(
    std.fs.File.InStream.Error,
    std.fs.File.SeekError,
    std.fs.File.GetPosError,
  );

  const info = try sz.find_file(&in_stream.stream, &seekable.stream, "zlib-1.2.11/adler32.c");

  if (info) |fileInfo| {
    const pos = std.math.cast(usize, fileInfo.offset) catch unreachable;
    try seekable.stream.seekTo(pos);

    std.testing.expectEqual(COMPRESSION_DEFLATE, fileInfo.compressionMethod);
    std.testing.expectEqual(uncompressedData.len, fileInfo.uncompressedSize);

    var inflater = Inflater.init(allocator, -15);
    defer inflater.deinit();
    var inflateBuf: [256]u8 = undefined;
    var iis = InflateInStream(std.fs.File.InStream.Error).init(&inflater, &in_stream.stream, inflateBuf[0..]);
    defer iis.deinit();

    var index: usize = 0;
    while (true) {
      var buffer: [256]u8 = undefined;
      const bytesRead = try iis.stream.read(buffer[0..]);
      if (bytesRead == 0) {
        break;
      }
      std.testing.expect(std.mem.eql(u8, buffer[0..bytesRead], uncompressedData[index..index + bytesRead]));
      index += bytesRead;
    }
  } else {
    unreachable;
  }
}

test "ZipTest: count files inside a zip archive" {
  var file = try std.fs.File.openRead("src/testdata/zlib1211.zip");
  defer file.close();
  var in_stream = std.fs.File.inStream(file);
  var seekable = std.fs.File.seekableStream(file);

  const sz = ScanZip(
    std.fs.File.InStream.Error,
    std.fs.File.SeekError,
    std.fs.File.GetPosError,
  );

  const isZipFile = try sz.is_zip_file(&in_stream.stream, &seekable.stream);
  std.testing.expect(isZipFile);
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

  std.testing.expectEqual(@as(usize, 293), count);
}
