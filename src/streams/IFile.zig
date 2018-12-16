const std = @import("std");

const InStream = @import("InStream.zig").InStream;
const OutStream = @import("OutStream.zig").OutStream;
const SeekableStream = @import("SeekableStream.zig").SeekableStream;

// to be put directly into std.os.File eventually...
// problem: std.os.File's functions (read, write, etc) don't take self as a
// pointer. so the vtable code chokes on it

// pub fn inStreamFromFile(file: *std.os.File) InStream(std.os.File.ReadError) {
//   return InStream(std.os.File.ReadError).init(file);
// }

// pub fn outStreamFromFile(file: *std.os.File) InStream(std.os.File.WriteError) {
//   return OutStream(std.os.File.WriteError).init(file);
// }

// pub fn seekableStreamFromFile(file: *std.os.File) SeekableStream(std.os.File.SeekError, std.os.File.GetSeekPosError) {
//   return SeekableStream(std.os.File.SeekError, std.os.File.GetSeekPosError).init(file);
// }

pub const IFile = struct {
  pub const ReadError = std.os.File.ReadError;
  pub const WriteError = std.os.File.WriteError;
  pub const SeekError = std.os.File.SeekError;
  pub const GetSeekPosError = std.os.File.GetSeekPosError;

  file: std.os.File,
  read_error: ?ReadError,
  write_error: ?WriteError,

  pub fn init(file: std.os.File) IFile {
    return IFile{
      .file = file,
      .read_error = null,
      .write_error = null,
    };
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
    return self.file.getPos();
  }

  // InStream

  pub fn inStream(self: *IFile) InStream {
    const GlobalStorage = struct {
      const vtable = InStream.VTable{
        .read = inStreamRead,
      };
    };
    return InStream{
      .impl = @ptrCast(*c_void, self),
      .vtable = &GlobalStorage.vtable,
    };
  }

  fn inStreamRead(impl: *c_void, dest: []u8) InStream.Error!usize {
    const self = @ptrCast(*IFile, @alignCast(@alignOf(IFile), impl));
    return self.read(dest) catch |err| {
      self.read_error = err;
      return InStream.Error.ReadError;
    };
  }

  // OutStream

  pub fn outStream(self: *IFile) OutStream {
    const GlobalStorage = struct {
      const vtable = OutStream.VTable{
        .write = outStreamWrite,
      };
    };
    return OutStream{
      .impl = @ptrCast(*c_void, self),
      .vtable = &GlobalStorage.vtable,
    };
  }

  fn outStreamWrite(impl: *c_void, bytes: []u8) OutStream.Error!void {
    const self = @ptrCast(*IFile, @alignCast(@alignOf(IFile), impl));
    self.write(bytes) catch |err| {
      self.write_error = err;
      return OutStream.Error.WriteError;
    };
  }
};
