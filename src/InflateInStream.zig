const std = @import("std");
const c = @import("c.zig");
const Inflater = @import("Inflater.zig").Inflater;
const OwnerId = @import("OwnerId.zig").OwnerId;

// TODO - data descriptors
// TODO - support custom dictionary
// TODO - add more tests

pub fn InflateInStream(comptime SourceError: type) type {
  return struct {
    const Self = this;

    pub const Error = SourceError || Inflater.Error;

    pub const ImplStream = std.io.InStream(Error);

    // trait implementations
    stream: ImplStream,

    // parameters
    inflater: *Inflater,
    source: *std.io.InStream(SourceError),
    compressed_buffer: []u8,

    owner_id: OwnerId,

    pub fn init(inflater: *Inflater, source: *std.io.InStream(SourceError), buffer: []u8) Self {
      const owner_id = OwnerId.generate();

      inflater.attachOwner(owner_id);

      return Self{
        .source = source,
        .inflater = inflater,
        .compressed_buffer = buffer,
        .owner_id = owner_id,
        .stream = ImplStream{
          .readFn = readFn,
        },
      };
    }

    pub fn deinit(self: *InflateInStream(SourceError)) void {
      self.inflater.detachOwner(self.owner_id);
    }

    fn readFn(in_stream: *ImplStream, buffer: []u8) Error!usize {
      if (buffer.len == 0) {
        return 0;
      }

      const self = @fieldParentPtr(InflateInStream(SourceError), "stream", in_stream);

      // possible states coming into this function:

      // - first run.
      //    * self.inflater.zlib_stream_active == false
      //    * self.inflater.zlib_stream.avail_in == 0
      //    * self.inflater.zlib_stream.avail_out == 0

      // - ran before, output buffer was full that time.
      //    * self.inflater.zlib_stream_active == true
      //    * self.inflater.zlib_stream.avail_in >= 0
      //    * self.inflater.zlib_stream.avail_out == 0

      // - ran before, done.
      //    * self.inflater.zlib_stream_active == true
      //    * self.inflater.zlib_stream.avail_in == 0
      //    * self.inflater.zlib_stream.avail_out == ?

      // this must be called before the first call to `prepare`!
      if (self.inflater.zlib_stream.avail_in == 0) {
        const num_bytes = try self.source.read(self.compressed_buffer);
        self.inflater.setInput(self.owner_id, self.compressed_buffer[0..num_bytes]);
      }

      try self.inflater.prepare(self.owner_id, buffer);

      // loop until source is finished, or the output buffer is full.
      // if inflate runs out of input, feed it more and do it again.
      while (true) {
        switch (self.inflater.inflate(self.owner_id)) {
          c.Z_STREAM_END => {
            // reached the end of the file
            return usize(self.inflater.zlib_stream.total_out);
          },
          c.Z_OK => {
            if (self.inflater.zlib_stream.avail_out == 0) {
              // filled the output buffer, finished
              return usize(self.inflater.zlib_stream.total_out);
            }

            if (self.inflater.zlib_stream.avail_in == 0) {
              // consumed the input buffer, refill it
              const num_bytes = try self.source.read(self.compressed_buffer);
              self.inflater.setInput(self.owner_id, self.compressed_buffer[0..num_bytes]);
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

test "InflateInStream: works on valid input" {
  const SimpleInStream = @import("SimpleInStream.zig").SimpleInStream;

  const compressedData = @embedFile("testdata/adler32.c-compressed");
  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = SimpleInStream.init(compressedData);

  var inflater = Inflater.init(std.debug.global_allocator, -15);
  defer inflater.deinit();
  var inflaterBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream(SimpleInStream.ReadError).init(&inflater, &source.stream, inflaterBuf[0..]);
  defer inflateStream.deinit();

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

  var inflater = Inflater.init(std.debug.global_allocator, -15);
  defer inflater.deinit();
  var inflateBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream(SimpleInStream.ReadError).init(&inflater, &source.stream, inflateBuf[0..]);
  defer inflateStream.deinit();

  var buffer: [256]u8 = undefined;

  if (inflateStream.stream.read(buffer[0..])) {
    unreachable;
  } else |err| {
    std.debug.assert(err == InflateInStream(SimpleInStream.ReadError).Error.InvalidStream);
  }
}
