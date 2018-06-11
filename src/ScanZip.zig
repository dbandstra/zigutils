const std = @import("std");
const InStream = std.io.InStream;
const Seekable = @import("traits/Seekable.zig").Seekable;

// currently able to locate a single file in a zip archive.
// TODO - figure out what a scanning/iterating interface would look like

const LOCALHEADER_SIGNATURE: u32 = 0x04034b50;
const FILEHEADER_SIGNATURE: u32 = 0x02014b50;
//#define ENDRECORD_SIGNATURE   0x06054b50

const COMPRESSION_NONE: u8 = 0;
const COMPRESSION_DEFLATE: u8 = 8;

const LASTSUPPORTEDVERSION: u8 = 20; // 2.0

const LOCALHEADER_SIZE: u32 = 30;
const DATADESCRIPTOR_SIZE: u32 = 12;
//#define ENDRECORD_SIZE      22
//#define DIRRECORD_SIZE      46

//#define FS_ZLIB_STREAM_SIZE_THRESHOLD (1 << 22) /* 4 MB size */

//#define MAX_WBITS    15
//#define Z_OK         0
//#define Z_STREAM_END 1
//#define Z_FINISH     4
//#define ZLIB_VERSION "1.2.3"

// 15 shorts = 30 bytes
const ZipHeader = packed struct {
  header: u32,
  version: u16,
  gpFlag: u16,
  compressionType: u16,
  lastModifiedTime: u16,
  lastModifiedDate: u16,
  crc32: u32,
  compressedSize: u32,
  uncompressedSize: u32,
  filenameLength: u16,
  extraFieldLength: u16,
};

comptime {
  std.debug.assert(@sizeOf(ZipHeader) == 30);
}

pub const ZipFileInfo = struct {
  isCompressed: bool,
  compressedSize: u32,
  uncompressedSize: u32,
  offset: usize,
};

pub fn ScanZip(comptime ReadError: type) type {
  return struct {
    pub fn find_file(
      stream: *InStream(ReadError),
      seekable: *Seekable,
      filename: []const u8,
    ) !?ZipFileInfo {
      std.debug.warn("\n");
      while (true) {
        var valid = true;
        var descriptor = false;
        var isCompressed = false;

        var header: ZipHeader = undefined;

        try readOneNoEof(stream, ZipHeader, &header);

        // have we reached the central directory?
        if (header.header == FILEHEADER_SIGNATURE) {
          // rewind that previous read and break
          break;
        }

        if (header.header != LOCALHEADER_SIGNATURE) {
          std.debug.warn("lost! {x}\n", header.header);
          break;
        }

        // version needed to extract
        if (header.version > LASTSUPPORTEDVERSION) {
//          std.debug.warn("bad version {}\n", header.version);
          valid = false;
        }

        // gp flag
        if ((header.gpFlag & (u16(1) << 3) != 0)) {
          // there is a data descriptor for the file
          descriptor = true;
          std.debug.warn("data descriptor\n");
          valid = false;
          // TODO - add support for data descriptors
        }

        // compression type
        if (header.compressionType == COMPRESSION_NONE) {
          isCompressed = false;
        } else if (header.compressionType == COMPRESSION_DEFLATE) {
          isCompressed = true;
        } else {
          std.debug.warn("unsupported compression type\n");
          valid = false;
        }

        // read filename
        var buf: [200]u8 = undefined;
        var curFilename = buf[0..header.filenameLength];
        try stream.readNoEof(curFilename);

        // skip extra field
        try seekable.seekForward(header.extraFieldLength);

        const fileCompressedOffset = try seekable.getPos();

        // const isDir = curFilename.len > 0 and curFilename[curFilename.len - 1] == '/';

        // skip file
        try seekable.seekForward(header.compressedSize);

        // skip data descriptor
        // TODO

        // check ...
        if (std.mem.eql(u8, curFilename, filename)) {
          return ZipFileInfo{
            .isCompressed = isCompressed,
            .compressedSize = header.compressedSize,
            .uncompressedSize = header.uncompressedSize,
            .offset = fileCompressedOffset,
          };
        }
      }

      return null;
    }

    // copied from macho.zig
    fn readNoEof(in: *InStream(ReadError), comptime T: type, result: []T) !void {
      return in.readNoEof(([]u8)(result));
    }

    fn readOneNoEof(in: *InStream(ReadError), comptime T: type, result: *T) !void {
      return readNoEof(in, T, (*[1]T)(result)[0..]);
    }
  };
}
