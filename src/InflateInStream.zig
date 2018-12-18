const std = @import("std");

const InStream = @import("streams/InStream.zig").InStream;
const Inflater = @import("Inflater.zig").Inflater;
const OwnerId = @import("OwnerId.zig").OwnerId;

// TODO - support custom dictionary
// TODO - add more tests

pub const InflateInStream = struct {
  inflater: *Inflater,
  source: InStream,
  compressed_buffer: []u8,

  owner_id: OwnerId,
  inflate_error: ?Inflater.Error,

  pub fn init(inflater: *Inflater, source: InStream, buffer: []u8) @This() {
    const owner_id = OwnerId.generate();

    inflater.attachOwner(owner_id);

    return @This(){
      .source = source,
      .inflater = inflater,
      .compressed_buffer = buffer,
      .owner_id = owner_id,
      .inflate_error = null,
    };
  }

  pub fn deinit(self: *@This()) void {
    self.inflater.detachOwner(self.owner_id);
  }

  // private
  fn maybeRefillInput(self: *@This()) InStream.Error!void {
    if (self.inflater.isInputExhausted()) {
      const num_bytes = try self.source.read(self.compressed_buffer);

      self.inflater.setInput(self.owner_id, self.compressed_buffer[0..num_bytes]);
    }
  }

  fn read(self: *@This(), buffer: []u8) (InStream.Error || Inflater.Error)!usize {
    // anticipate footgun (sometimes forget you need two buffers)
    std.debug.assert(buffer.ptr != self.compressed_buffer.ptr);

    if (buffer.len == 0) {
      return 0;
    }

    try self.maybeRefillInput(); // returns InStream.Error
    try self.inflater.prepare(self.owner_id, buffer); // returns Inflater.Error

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

  // InStream

  pub fn inStream(self: *@This()) InStream {
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
    const self = @ptrCast(*InflateInStream, @alignCast(@alignOf(InflateInStream), impl));
    return self.read(dest) catch |err| {
      if (err == InStream.Error.ReadError) {
        // upstream error. the error is already stored in the upstream object.
      } else {
        // else it's an Inflater.Error, although the compiler couldn't infer it
        self.inflate_error = @errSetCast(Inflater.Error, err);
      }
      return InStream.Error.ReadError;
    };
  }
};

test "InflateInStream: works on valid input" {
  const IConstSlice = @import("streams/IConstSlice.zig").IConstSlice;
  const IConstSliceInStreamAdapter = @import("streams/IConstSlice_InStream.zig").IConstSliceInStreamAdapter;
  const Hunk = @import("Hunk.zig").Hunk;

  var memory: [100 * 1024]u8 = undefined;
  var hunk = Hunk.init(memory[0..]);
  var hunk_side = hunk.low();
  var allocator = hunk_side.allocator();

  const mark = hunk_side.getMark();
  defer hunk_side.freeToMark(mark);

  const compressedData = @embedFile("testdata/adler32.c-compressed");
  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = IConstSlice.init(compressedData);
  var source_in_stream_adapter = IConstSliceInStreamAdapter.init(&source);
  var source_in_stream = source_in_stream_adapter.inStream();

  var inflater = Inflater.init(&allocator, -15);
  defer inflater.deinit();
  var inflaterBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream.init(&inflater, source_in_stream, inflaterBuf[0..]);
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
  const IConstSliceInStreamAdapter = @import("streams/IConstSlice_InStream.zig").IConstSliceInStreamAdapter;
  const Hunk = @import("Hunk.zig").Hunk;

  var memory: [100 * 1024]u8 = undefined;
  var hunk = Hunk.init(memory[0..]);
  var hunk_side = hunk.low();
  var allocator = hunk_side.allocator();

  const mark = hunk_side.getMark();
  defer hunk_side.freeToMark(mark);

  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = IConstSlice.init(uncompressedData);
  var source_in_stream_adapter = IConstSliceInStreamAdapter.init(&source);
  var source_in_stream = source_in_stream_adapter.inStream();

  var inflater = Inflater.init(&allocator, -15);
  defer inflater.deinit();
  var inflateBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream.init(&inflater, source_in_stream, inflateBuf[0..]);
  defer inflateStream.deinit();

  var buffer: [256]u8 = undefined;

  std.debug.assertError(
    inflateStream.read(buffer[0..]),
    Inflater.Error.InvalidStream,
  );
}

test "InflateInStream: fails with InvalidStream on bad input (but with dynamic dispatch)" {
  const IConstSlice = @import("streams/IConstSlice.zig").IConstSlice;
  const IConstSliceInStreamAdapter = @import("streams/IConstSlice_InStream.zig").IConstSliceInStreamAdapter;
  const Hunk = @import("Hunk.zig").Hunk;

  var memory: [100 * 1024]u8 = undefined;
  var hunk = Hunk.init(memory[0..]);
  var hunk_side = hunk.low();
  var allocator = hunk_side.allocator();

  const mark = hunk_side.getMark();
  defer hunk_side.freeToMark(mark);

  const uncompressedData = @embedFile("testdata/adler32.c");

  var source = IConstSlice.init(uncompressedData);
  var source_in_stream_adapter = IConstSliceInStreamAdapter.init(&source);
  var source_in_stream = source_in_stream_adapter.inStream();

  var inflater = Inflater.init(&allocator, -15);
  defer inflater.deinit();
  var inflateBuf: [256]u8 = undefined;
  var inflateStream = InflateInStream.init(&inflater, source_in_stream, inflateBuf[0..]);
  defer inflateStream.deinit();
  var inflate_in_stream = inflateStream.inStream();

  var buffer: [256]u8 = undefined;

  std.debug.assertError(
    inflate_in_stream.read(buffer[0..]),
    InStream.Error.ReadError,
  );
  std.debug.assert(inflateStream.inflate_error.? == Inflater.Error.InvalidStream);
}

// TODO - test if the error happens in IConstSlice. in that case, the check should be:
// except IConstSlice cannot fail. might have to come up with a contrived source InStream to test this.

  // std.debug.assertError(
  //   inflate_in_stream.read(buffer[0..]),
  //   InStream.Error.ReadError,
  // );
  // std.debug.assert(inflateStream.inflate_error == null);
  // std.debug.assert(source.read_error.? == IConstSlice.ReadError.SomeErrorThatExists);
