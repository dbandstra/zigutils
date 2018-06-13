// resources:
// https://en.wikipedia.org/wiki/Zip_(file_format)
// https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
// https://stackoverflow.com/questions/20762094/how-are-zlib-gzip-and-zip-related-what-do-they-have-in-common-and-how-are-they

const std = @import("std");
const InStream = std.io.InStream;
const Seekable = @import("traits/Seekable.zig").Seekable;
const readOneNoEof = @import("util.zig").readOneNoEof;

// currently able to locate a single file in a zip archive.
// TODO - figure out what a scanning/iterating interface would look like

// TODO - write tests!

pub const COMPRESSION_NONE: u16 = 0;
pub const COMPRESSION_DEFLATE: u16 = 8;

const LocalFileHeader = packed struct {
  signature: u32, // 0x04034b50
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
  // extraField: [extraFieldLength]u8,
  // compressedData: [compressedSize]u8,
};

const CentralDirectoryFileHeader = packed struct {
  signature: u32, // 0x02014b50
  versionMadeBy: u16,
  minVersionNeededToExtract: u16,
  gpFlag: u16,
  compressionMethod: u16,
  fileLastModifiedTime: u16,
  fileLastModifiedDate: u16,
  crc32: u32,
  compressedSize: u32,
  uncompressedSize: u32,
  fileNameLength: u16,
  extraFieldLength: u16,
  fileCommentLength: u16,
  diskNumberWhereFileStarts: u16,
  internalFileAttributes: u16,
  externalFileAttributes: u32,
  relativeOffsetOfLocalFileHeader: u32,
  // fileName: [fileNameLength]u8,
  // extraField: [extraFieldLength]u8,
  // fileComment: [fileCommentLengthu8],
};

const EndOfCentralDirectoryRecord = packed struct {
  signature: u32, // 0x06054b50
  diskNumber: u16,
  cdStartDisk: u16,
  cdNumRecordsOnDisk: u16,
  cdTotalNumRecords: u16,
  cdSize: u32,
  cdOffset: u32,
  commentLength: u16,
  // comment: [commentLength]u8,
};

pub const CentralDirectoryInfo = struct {
  offset: u32,
  size: u32,
};

pub const ZipFileInfo = struct {
  compressionMethod: u16,
  compressedSize: u32,
  uncompressedSize: u32,
  offset: usize,
};

pub fn ScanZip(comptime ReadError: type) type {
  return struct {
    pub const Error = error{
      NotZipFile,
      Unsupported, // known feature but not implemented
      Corrupt, // corrupt or unsupported future thing
    };

    // try to decide if the file is actually a zip file. this could be improved
    pub fn is_zip_file(
      stream: *InStream(ReadError),
      seekable: *Seekable,
    ) !bool {
      try seekable.seekTo(0);

      const a = try stream.readByte();
      const b = try stream.readByte();

      // "MZ" is a self-executing zip file
      return (a == 'P' and b == 'K') or (a == 'M' and b == 'Z');
    }

    // locate the central directory by searching backward from the end of the
    // file.
    // assume the seek position is undefined after calling this function.
    // TODO - optimize this function!
    pub fn find_central_directory(
      stream: *InStream(ReadError),
      seekable: *Seekable,
    ) !CentralDirectoryInfo {
      const endPos = try seekable.getEndPos();

      // what happens if this goes below 0? zig does something?
      var pos = endPos - @sizeOf(EndOfCentralDirectoryRecord);

      // only search back 65536 bytes because that's the max possible comment
      // length
      while (pos > endPos - @sizeOf(EndOfCentralDirectoryRecord) - @maxValue(u16)) {
        try seekable.seekTo(pos);

        const signature = try stream.readIntLe(u32);

        if (signature == 0x06054b50) {
          // signature seems correct, but it could actually be part of the
          // comment. check (what would be) the commentLength and see if it
          // points to the end of the file.
          // FIXME - that could be part of the comment as well? but if that was
          // the case, is it even possible to find the central directory?
          try seekable.seekTo(pos + @offsetOf(EndOfCentralDirectoryRecord, "commentLength"));

          const commentLength = try stream.readIntLe(u16);

          if (pos + @sizeOf(EndOfCentralDirectoryRecord) + commentLength == endPos) {
            try seekable.seekTo(pos + @offsetOf(EndOfCentralDirectoryRecord, "cdSize"));

            const cdSize = try stream.readIntLe(u32);
            const cdOffset = try stream.readIntLe(u32);

            return CentralDirectoryInfo{
              .offset = cdOffset,
              .size = cdSize,
            };
          }
        }

        pos -= 1; // ew
      }

      return Error.NotZipFile;
    }

    pub fn find_file_in_directory(
      cdInfo: *const CentralDirectoryInfo,
      stream: *InStream(ReadError),
      seekable: *Seekable,
      filename: []const u8,
    ) !?ZipFileInfo {
      var relPos: usize = 0;

      while (relPos < cdInfo.size) {
        try seekable.seekTo(cdInfo.offset + relPos);

        const signature = try stream.readIntLe(u32);

        if (signature != 0x02014b50) {
          return Error.Corrupt;
        }

        try seekable.seekTo(cdInfo.offset + relPos + @offsetOf(CentralDirectoryFileHeader, "compressionMethod"));
        const compressionMethod = try stream.readIntLe(u16);
        try seekable.seekTo(cdInfo.offset + relPos + @offsetOf(CentralDirectoryFileHeader, "compressedSize"));
        const compressedSize = try stream.readIntLe(u32);
        const uncompressedSize = try stream.readIntLe(u32);
        const fileNameLength = try stream.readIntLe(u16);
        const extraFieldLength = try stream.readIntLe(u16);
        const fileCommentLength = try stream.readIntLe(u16);
        // TODO - make sure disk number is 0 or whatever
        try seekable.seekTo(cdInfo.offset + relPos + @offsetOf(CentralDirectoryFileHeader, "relativeOffsetOfLocalFileHeader"));
        const offset = try stream.readIntLe(u32);

        var filenameBuf: [500]u8 = undefined; // FIXME
        const n = try stream.read(filenameBuf[0..fileNameLength]);

        if (std.mem.eql(u8, filename, filenameBuf[0..n])) {
          return ZipFileInfo{
            .compressionMethod = compressionMethod,
            .compressedSize = compressedSize,
            .uncompressedSize = uncompressedSize,
            .offset = offset + @sizeOf(LocalFileHeader) + fileNameLength + extraFieldLength,
          };
        }

        relPos += @sizeOf(CentralDirectoryFileHeader);
        relPos += fileNameLength;
        relPos += extraFieldLength;
        relPos += fileCommentLength;
      }

      return null;
    }

    pub fn find_file(
      stream: *InStream(ReadError),
      seekable: *Seekable,
      filename: []const u8,
    ) !?ZipFileInfo {
      const isZipFile = try is_zip_file(stream, seekable);

      if (!isZipFile) {
        return Error.NotZipFile;
      }

      const cdInfo = try find_central_directory(stream, seekable);

      return try find_file_in_directory(cdInfo, stream, seekable, filename);
    }
  };
}
