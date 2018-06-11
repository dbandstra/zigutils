const std = @import("std");
const c = @import("c.zig");
const util = @import("util.zig");

// TODO - pass along source instream errors (if possible)
// TODO - data descriptors
// TODO - configurable buffer size
// TODO - support custom dictionary
// TODO - add more tests

const DEF_WBITS = c.MAX_WBITS; // this is probably 15

pub fn InflateInStream(comptime SourceError: type) type {
  return struct {
    const Self = this;

    pub const Error = error{
      SourceError, // FIXME - how to include source error types?
      ZlibVersionError,
      InvalidStream, // invalid/corrupt input
      OutOfMemory, // zlib's internal allocation failed
    };

    pub const ImplStream = std.io.InStream(Error);

    // trait implementations
    stream: ImplStream,

    // parameters
    source: *std.io.InStream(SourceError),
    allocator: *std.mem.Allocator,

    // private data
    compressed_buffer: [256]u8,

    windowBits: i32,
    zlib_stream_active: bool,
    zlib_stream: c.z_stream,

    pub fn init(source: *std.io.InStream(SourceError), allocator: *std.mem.Allocator) Self {
      var self = Self{
        .source = source,
        .allocator = allocator,
        .compressed_buffer = undefined,
        .windowBits = DEF_WBITS,
        .zlib_stream_active = false,
        .zlib_stream = undefined,
        .stream = ImplStream{
          .readFn = readFn,
        },
      };
      util.clearStruct(c.z_stream, &self.zlib_stream); // 112 bytes
      self.zlib_stream.zalloc = zalloc;
      self.zlib_stream.zfree = zfree;
      self.zlib_stream.opaque = @ptrCast(*c_void, allocator);
      return self;
    }

    pub fn deinit(self: *InflateInStream(SourceError)) void {
      if (self.zlib_stream_active) {
        _ = inflateEnd(&self.zlib_stream);
        self.zlib_stream_active = false;
      }
    }

    // set the window size, to be passed to inflateInit2. a negative number
    // means 'raw inflate' - no zlib header (see comment in zlib.h).
    // this will have no effect if called after the first read.
    // TODO - find a better way to expose this configuration
    pub fn setWindowBits(self: *InflateInStream(SourceError), windowBits: i32) void {
      self.windowBits = windowBits;
    }

    extern fn zalloc(opaque: ?*c_void, items: c_uint, size: c_uint) ?*c_void {
      const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(std.mem.Allocator), opaque.?));

      return util.allocCPointer(allocator, items * size);
    }

    extern fn zfree(opaque: ?*c_void, address: ?*c_void) void {
      const allocator = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(std.mem.Allocator), opaque.?));

      util.freeCPointer(allocator, address);
    }

    fn refillCompressedBuffer(self: *InflateInStream(SourceError)) Error!void {
      const bytes_read = self.source.read(self.compressed_buffer[0..])
        catch |err| return Error.ReadError;

      self.zlib_stream.next_in = self.compressed_buffer[0..].ptr;
      self.zlib_stream.avail_in = c_uint(bytes_read);
      self.zlib_stream.total_in = 0;
    }

    fn readFn(in_stream: *ImplStream, buffer: []u8) Error!usize {
      if (buffer.len == 0) {
        return 0;
      }

      const self = @fieldParentPtr(InflateInStream(SourceError), "stream", in_stream);

      if (self.zlib_stream.avail_in == 0) {
        try self.refillCompressedBuffer();
      }

      if (!self.zlib_stream_active) {
        switch (inflateInit2(&self.zlib_stream, self.windowBits)) {
          c.Z_OK => {},
          c.Z_VERSION_ERROR => return Error.ZlibVersionError,
          c.Z_MEM_ERROR => return Error.OutOfMemory,
          else => unreachable,
        }
        self.zlib_stream_active = true;
      }

      self.zlib_stream.next_out = buffer[0..].ptr;
      self.zlib_stream.avail_out = c_uint(buffer.len);
      self.zlib_stream.total_out = 0;

      while (true) {
        switch (inflate(&self.zlib_stream, c.Z_SYNC_FLUSH)) {
          c.Z_STREAM_END => {
            // reached the end of the file
            return usize(self.zlib_stream.total_out);
          },
          c.Z_OK => {
            if (self.zlib_stream.avail_out == 0) {
              // filled the output buffer, finished
              return usize(self.zlib_stream.total_out);
            }

            if (self.zlib_stream.avail_in == 0) {
              // consumed the input buffer, refill it
              try self.refillCompressedBuffer();
            }
          },
          c.Z_STREAM_ERROR => {
            // state was not initialized properly. but we did initialize it,
            // so this could only happen if the memory for this object got
            // clobbered by other code in the application
            unreachable;
          },
          c.Z_NEED_DICT => {
            // this data was compressed with a custom dictionary
            return Error.InvalidStream;
          },
          c.Z_DATA_ERROR => {
            // invalid/corrupted data in stream
            return Error.InvalidStream;
          },
          c.Z_MEM_ERROR => {
            // allocation failed
            return Error.OutOfMemory;
          },
          else => unreachable,
        }
      }
    }
  };
}

// this is a macro in zlib.h
fn inflateInit2(strm: *c.z_stream, windowBits: c_int) c_int {
  const version = c.ZLIB_VERSION;
  const stream_size: c_int = @sizeOf(c.z_stream);

  return c.inflateInit2_(c.ptr(strm), windowBits, version, stream_size);
}

fn inflate(strm: *c.z_stream, flush: c_int) c_int {
  return c.inflate(c.ptr(strm), flush);
}

fn inflateEnd(strm: *c.z_stream) c_int {
  return c.inflateEnd(c.ptr(strm));
}

test "InflateInStream: works on valid input" {
  const SimpleInStream = @import("SimpleInStream.zig").SimpleInStream;

  const compressedData = @embedFile("testdata/adler32.c-compressed");
  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = SimpleInStream.init(compressedData);

  var inflateStream = InflateInStream(SimpleInStream.ReadError).init(
    &source.stream,
    std.debug.global_allocator,
  );
  defer inflateStream.deinit();

  inflateStream.setWindowBits(-15);

  var buffer: [256]u8 = undefined;
  var index: usize = 0;

  while (true) {
    const n = try inflateStream.stream.read(buffer[0..]);
    if (n == 0) {
      break;
    }
    std.debug.assert(std.mem.eql(u8, buffer[0..n], uncompressedData[index..index + n]));
    index += n;
  }

  std.debug.assert(index == uncompressedData.len);
}

test "InflateInStream: fails with InvalidStream on bad input" {
  const SimpleInStream = @import("SimpleInStream.zig").SimpleInStream;

  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = SimpleInStream.init(uncompressedData);

  var inflateStream = InflateInStream(SimpleInStream.ReadError).init(
    &source.stream,
    std.debug.global_allocator,
  );
  defer inflateStream.deinit();

  inflateStream.setWindowBits(-15);

  var buffer: [256]u8 = undefined;

  if (inflateStream.stream.read(buffer[0..])) |_| {
    unreachable;
  } else |err| {
    std.debug.assert(err == InflateInStream(SimpleInStream.ReadError).Error.InvalidStream);
  }
}
