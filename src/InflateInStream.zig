const std = @import("std");
const Inflater = @import("Inflater.zig").Inflater;
const OwnerId = @import("OwnerId.zig").OwnerId;

// TODO - support custom dictionary
// TODO - add more tests

pub fn InflateInStream(comptime SourceError: type) type {
  return struct.{
    const Self = @This();

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

      return Self.{
        .source = source,
        .inflater = inflater,
        .compressed_buffer = buffer,
        .owner_id = owner_id,
        .stream = ImplStream.{
          .readFn = readFn,
        },
      };
    }

    pub fn deinit(self: *InflateInStream(SourceError)) void {
      self.inflater.detachOwner(self.owner_id);
    }

    fn maybeRefillInput(self: *InflateInStream(SourceError)) SourceError!void {
      if (self.inflater.isInputExhausted()) {
        const num_bytes = try self.source.read(self.compressed_buffer);

        self.inflater.setInput(self.owner_id, self.compressed_buffer[0..num_bytes]);
      }
    }

    fn readFn(in_stream: *ImplStream, buffer: []u8) Error!usize {
      const self = @fieldParentPtr(InflateInStream(SourceError), "stream", in_stream);

      // anticipate footgun (sometimes forget you need two buffers)
      std.debug.assert(buffer.ptr != self.compressed_buffer.ptr);

      if (buffer.len == 0) {
        return 0;
      }

      try self.maybeRefillInput();
      try self.inflater.prepare(self.owner_id, buffer);

      // this is weird, `while(x) |y|` has three possible meanings...
      // boolean, null, error... i guess error outranks boolean?
      while (self.inflater.inflate(self.owner_id)) |done| {
        if (done) {
          return self.inflater.getNumBytesWritten();
        } else {
          try self.maybeRefillInput();
        }
      } else |err| {
        return err;
      }
    }
  };
}

test "InflateInStream: works on valid input" {
  const ssaf = @import("test/util/test_allocator.zig").ssaf;
  const allocator = &ssaf.allocator;
  const mark = ssaf.get_mark();
  defer ssaf.free_to_mark(mark);

  const MemoryInStream = @import("MemoryInStream.zig").MemoryInStream;

  const compressedData = @embedFile("testdata/adler32.c-compressed");
  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = MemoryInStream.init(compressedData);

  var inflater = Inflater.init(allocator, -15);
  defer inflater.deinit();
  var inflaterBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream(MemoryInStream.ReadError).init(&inflater, &source.stream, inflaterBuf[0..]);
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
  const ssaf = @import("test/util/test_allocator.zig").ssaf;
  const allocator = &ssaf.allocator;
  const mark = ssaf.get_mark();
  defer ssaf.free_to_mark(mark);

  const MemoryInStream = @import("MemoryInStream.zig").MemoryInStream;

  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = MemoryInStream.init(uncompressedData);

  var inflater = Inflater.init(allocator, -15);
  defer inflater.deinit();
  var inflateBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream(MemoryInStream.ReadError).init(&inflater, &source.stream, inflateBuf[0..]);
  defer inflateStream.deinit();

  var buffer: [256]u8 = undefined;

  if (inflateStream.stream.read(buffer[0..])) {
    unreachable;
  } else |err| {
    std.debug.assert(err == InflateInStream(MemoryInStream.ReadError).Error.InvalidStream);
  }
}
