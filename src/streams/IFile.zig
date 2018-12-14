// single object implementing all the traits...

const std = @import("std");

const InStream = @import("InStream.zig").InStream;
const OutStream = @import("OutStream.zig").OutStream;
const SeekableStream = @import("SeekableStream.zig").SeekableStream;

pub const IFile = struct {
  pub const ReadError = std.os.File.ReadError;
  pub const WriteError = std.os.File.WriteError;
  pub const SeekError = std.os.File.SeekError;
  pub const GetSeekPosError = std.os.File.GetSeekPosError;

  file: std.os.File,

  pub fn init(file: std.os.File) IFile {
    return IFile{
      .file = file,
    };
  }

  pub fn inStream(self: *IFile) InStream(ReadError) {
    return InStream(ReadError).init(self);
  }

  pub fn outStream(self: *IFile) OutStream(WriteError) {
    return OutStream(WriteError).init(self);
  }

  pub fn seekableStream(self: *IFile) SeekableStream(SeekError, GetSeekPosError) {
    return SeekableStream(SeekError, GetSeekPosError).init(self);
  }

  pub fn read(self: *IFile, buffer: []u8) ReadError!usize {
    return self.file.read(buffer);
  }

  pub fn write(self: *IFile, bytes: []const u8) WriteError!void {
    return self.file.write(bytes);
  }

  pub fn seekTo(self: *IFile, pos: usize) SeekError!void {
    return self.file.seekTo(pos);
  }

  pub fn seekForward(self: *IFile, amt: isize) SeekError!void {
    return self.file.seekForward(amt);
  }

  pub fn getEndPos(self: *IFile) GetSeekPosError!usize {
    return self.file.getEndPos();
  }

  pub fn getPos(self: *IFile) GetSeekPosError!usize {
    return self.file.getPos(self);
  }
};
