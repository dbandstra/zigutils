const std = @import("std");
const c = @import("c.zig");
const util = @import("util.zig");
const OwnerId = @import("OwnerId.zig").OwnerId;

// The reason this has been split off from InflateInStream is that it contains
// a lot of state and allocations. Splitting it off allows it to be reused by
// multiple InflateInStreams, e.g. to decompress multiple files

pub const Inflater = struct.{
  const Self = @This();

  pub const Error = error.{
    ZlibVersionError,
    InvalidStream, // invalid/corrupt input
    OutOfMemory, // zlib's internal allocation failed
  };

  allocator: *std.mem.Allocator,
  windowBits: i32,
  zlib_stream_active: bool,
  zlib_stream: c.z_stream,
  resetting: bool,
  owned_by: ?OwnerId,

  pub fn init(allocator: *std.mem.Allocator, windowBits: i32) Self {
    var self = Self.{
      .allocator = allocator,
      .windowBits = windowBits,
      .zlib_stream_active = false,
      .zlib_stream = undefined,
      .resetting = false,
      .owned_by = null,
    };
    util.clearStruct(c.z_stream, &self.zlib_stream); // 112 bytes
    self.zlib_stream.zalloc = zalloc;
    self.zlib_stream.zfree = zfree;
    self.zlib_stream.opaque = @ptrCast(*c_void, allocator);
    return self;
  }

  pub fn deinit(self: *Inflater) void {
    std.debug.assert(self.owned_by == null); // FIXME

    if (self.zlib_stream_active) {
      const ret = c.inflateEnd(c.ptr(&self.zlib_stream));
      std.debug.assert(ret == c.Z_OK);
      self.zlib_stream_active = false;
    }
  }

  pub fn attachOwner(self: *Inflater, owner_id: OwnerId) void {
    if (self.owned_by) |_| {
      unreachable;
    }
    self.owned_by = owner_id;
  }

  pub fn detachOwner(self: *Inflater, owner_id: OwnerId) void {
    self.verifyOwner(owner_id);
    self.owned_by = null;
    self.resetting = true;

    self.zlib_stream.next_in = @intToPtr([*]u8, 0);
    self.zlib_stream.avail_in = 0;
    self.zlib_stream.total_in = 0;
  }

  pub fn getNumBytesWritten(self: *const Inflater) usize {
    return self.zlib_stream.total_out;
  }

  pub fn isInputExhausted(self: *const Inflater) bool {
    return self.zlib_stream.avail_in == 0;
  }

  pub fn setInput(self: *Inflater, owner_id: OwnerId, source: []const u8) void {
    self.verifyOwner(owner_id);

    std.debug.assert(self.zlib_stream.avail_in == 0);

    // `next_in` is const, but zig didn't pick up on that
    self.zlib_stream.next_in = @intToPtr([*]u8, @ptrToInt(source.ptr));
    self.zlib_stream.avail_in = @intCast(c_uint, source.len);
    self.zlib_stream.total_in = 0;
  }

  pub fn prepare(self: *Inflater, owner_id: OwnerId, buffer: []u8) Error!void {
    self.verifyOwner(owner_id);

    if (!self.zlib_stream_active) {
      const version = c.ZLIB_VERSION;
      const stream_size: c_int = @sizeOf(c.z_stream);

      switch (c.inflateInit2_(c.ptr(&self.zlib_stream), self.windowBits, version, stream_size)) {
        c.Z_OK => {},
        c.Z_VERSION_ERROR => return Error.ZlibVersionError,
        c.Z_MEM_ERROR => return Error.OutOfMemory,
        else => unreachable,
      }
      self.zlib_stream_active = true;
    } else if (self.resetting) {
      // zlib_stream is already initialized, but owner has changed. reset it
      // (resetting is like end+init, but reuses allocations).
      const ret = c.inflateReset(c.ptr(&self.zlib_stream));
      std.debug.assert(ret == c.Z_OK);
    }

    self.resetting = false;

    self.zlib_stream.next_out = buffer.ptr;
    self.zlib_stream.avail_out = @intCast(c_uint, buffer.len);
    self.zlib_stream.total_out = 0;
  }

  // return true if done or output buffer is full.
  // return false if more input is needed
  pub fn inflate(self: *Inflater, owner_id: OwnerId) Error!bool {
    self.verifyOwner(owner_id);
    if (!self.zlib_stream_active) {
      unreachable; // FIXME
    }
    return switch (c.inflate(c.ptr(&self.zlib_stream), c.Z_SYNC_FLUSH)) {
      c.Z_STREAM_END => true,
      c.Z_OK => self.zlib_stream.avail_out == 0,
      c.Z_STREAM_ERROR => unreachable,
      c.Z_NEED_DICT => Error.InvalidStream,
      c.Z_DATA_ERROR => Error.InvalidStream,
      c.Z_MEM_ERROR => Error.OutOfMemory,
      else => unreachable,
    };
  }

  fn verifyOwner(self: *Inflater, owner_id: OwnerId) void {
    if (self.owned_by) |owned_by| {
      if (owned_by.id != owner_id.id) {
        unreachable; // FIXME
      }
    } else {
      unreachable; // FIXME
    }
  }

  extern fn zalloc(opaque: ?*c_void, items: c_uint, size: c_uint) ?*c_void {
    const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(std.mem.Allocator), opaque.?));

    return util.allocCPointer(allocator, items * size);
  }

  extern fn zfree(opaque: ?*c_void, address: ?*c_void) void {
    const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(std.mem.Allocator), opaque.?));

    util.freeCPointer(allocator, address);
  }
};
