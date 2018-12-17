const std = @import("std");

const InStream = @import("../streams/InStream.zig").InStream;
const SeekableStream = @import("../streams/SeekableStream.zig").SeekableStream;
const FileInStreamAdapter = @import("../streams/File_InStream.zig").FileInStreamAdapter;
const FileSeekableStreamAdapter = @import("../streams/File_SeekableStream.zig").FileSeekableStreamAdapter;
const Hunk = @import("../Hunk.zig").Hunk;
const ScanZip = @import("../ScanZip.zig").ScanZip;
const COMPRESSION_DEFLATE = @import("../ScanZip.zig").COMPRESSION_DEFLATE;
const ZipWalkState = @import("../ScanZip.zig").ZipWalkState;
const Inflater = @import("../Inflater.zig").Inflater;
const InflateInStream = @import("../InflateInStream.zig").InflateInStream;

test "ZipTest: locate and decompress a file from a zip archive" {
  var memory: [100 * 1024]u8 = undefined;
  var hunk = Hunk.init(memory[0..]);
  var allocator = hunk.lowAllocator();
  const mark = hunk.getLowMark();
  defer hunk.freeToLowMark(mark);

  const uncompressedData = @embedFile("../testdata/adler32.c");

  var file = try std.os.File.openRead("src/testdata/zlib1211.zip");
  defer file.close();
  var file_in_stream_adapter = FileInStreamAdapter.init(file);
  var file_seekable_adapter = FileSeekableStreamAdapter.init(file);
  var in_stream = file_in_stream_adapter.inStream();
  var seekable = file_seekable_adapter.seekableStream();

  const info = try ScanZip.find_file(in_stream, seekable, "zlib-1.2.11/adler32.c");

  if (info) |fileInfo| {
    const pos = std.math.cast(usize, fileInfo.offset) catch unreachable;
    try seekable.seekTo(pos);

    std.debug.assert(fileInfo.compressionMethod == COMPRESSION_DEFLATE);
    std.debug.assert(fileInfo.uncompressedSize == uncompressedData.len);

    var inflater = Inflater.init(&allocator, -15);
    defer inflater.deinit();
    var inflateBuf: [256]u8 = undefined;
    var iis = InflateInStream.init(&inflater, in_stream, inflateBuf[0..]);
    defer iis.deinit();

    var index: usize = 0;
    while (true) {
      var buffer: [256]u8 = undefined;
      const bytesRead = try iis.read(buffer[0..]);
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
  var file = try std.os.File.openRead("src/testdata/zlib1211.zip");
  defer file.close();
  var file_in_stream_adapter = FileInStreamAdapter.init(file);
  var file_seekable_adapter = FileSeekableStreamAdapter.init(file);
  var in_stream = file_in_stream_adapter.inStream();
  var seekable = file_seekable_adapter.seekableStream();

  const isZipFile = try ScanZip.is_zip_file(in_stream, seekable);
  std.debug.assert(isZipFile);
  const cdInfo = try ScanZip.find_central_directory(in_stream, seekable);
  var walkState: ZipWalkState = undefined;
  var filenameBuf: [260]u8 = undefined;
  ScanZip.walkInit(cdInfo, &walkState, filenameBuf[0..]);

  var count: usize = 0;
  while (try ScanZip.walk(&walkState, in_stream, seekable)) |f| {
    count += 1;
    if (count > 1000) {
      unreachable;
    }
  }

  std.debug.assert(count == 293);
}
