const std = @import("std");

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
};
