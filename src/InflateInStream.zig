const std = @import("std");

const InStream = @import("streams/InStream.zig").InStream;
const Inflater = @import("Inflater.zig").Inflater;
const OwnerId = @import("OwnerId.zig").OwnerId;

// TODO - support custom dictionary
// TODO - add more tests

pub fn InflateInStream(comptime SourceError: type) type {
  return struct{
    pub const Error = SourceError || Inflater.Error;

    inflater: *Inflater,
    source: InStream(SourceError),
    compressed_buffer: []u8,

    owner_id: OwnerId,

    pub fn init(inflater: *Inflater, source: InStream(SourceError), buffer: []u8) @This() {
      const owner_id = OwnerId.generate();

      inflater.attachOwner(owner_id);

      return @This(){
        .source = source,
        .inflater = inflater,
        .compressed_buffer = buffer,
        .owner_id = owner_id,
      };
    }

    pub fn deinit(self: *@This()) void {
      self.inflater.detachOwner(self.owner_id);
    }

    pub fn inStream(self: *@This()) InStream(Error) {
      return InStream(Error).init(self);
    }

    // private
    fn maybeRefillInput(self: *@This()) SourceError!void {
      if (self.inflater.isInputExhausted()) {
        const num_bytes = try self.source.read(self.compressed_buffer);

        self.inflater.setInput(self.owner_id, self.compressed_buffer[0..num_bytes]);
      }
    }

    fn read(self: *@This(), buffer: []u8) Error!usize {
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
  const IConstSlice = @import("streams/IConstSlice.zig").IConstSlice;
  const SingleStackAllocator = @import("SingleStackAllocator.zig").SingleStackAllocator;

  var memory: [100 * 1024]u8 = undefined;
  var ssa = SingleStackAllocator.init(memory[0..]);
  const allocator = &ssa.stack.allocator;
  const mark = ssa.stack.get_mark();
  defer ssa.stack.free_to_mark(mark);

  const compressedData = @embedFile("testdata/adler32.c-compressed");
  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = IConstSlice.init(compressedData);
  var source_in_stream = source.inStream();

  var inflater = Inflater.init(allocator, -15);
  defer inflater.deinit();
  var inflaterBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream(IConstSlice.ReadError).init(&inflater, source_in_stream, inflaterBuf[0..]);
  defer inflateStream.deinit();

  var buffer: [256]u8 = undefined;
  var index: usize = 0;

  while (true) {
    const n = try inflateStream.read(buffer[0..]);
    if (n == 0) {
      break;
    }
    std.debug.assert(std.mem.eql(u8, buffer[0..n], uncompressedData[index..index + n]));
    index += n;
  }

  std.debug.assert(index == uncompressedData.len);
}

test "InflateInStream: fails with InvalidStream on bad input" {
  const IConstSlice = @import("streams/IConstSlice.zig").IConstSlice;
  const SingleStackAllocator = @import("SingleStackAllocator.zig").SingleStackAllocator;

  var memory: [100 * 1024]u8 = undefined;
  var ssa = SingleStackAllocator.init(memory[0..]);
  const allocator = &ssa.stack.allocator;
  const mark = ssa.stack.get_mark();
  defer ssa.stack.free_to_mark(mark);

  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = IConstSlice.init(uncompressedData);
  var source_in_stream = source.inStream();

  var inflater = Inflater.init(allocator, -15);
  defer inflater.deinit();
  var inflateBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream(IConstSlice.ReadError).init(&inflater, source_in_stream, inflateBuf[0..]);
  defer inflateStream.deinit();

  var buffer: [256]u8 = undefined;

  std.debug.assertError(
    inflateStream.read(buffer[0..]),
    InflateInStream(IConstSlice.ReadError).Error.InvalidStream,
  );
}
