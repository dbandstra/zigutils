comptime {
  _ = @import("src/ArrayListOutStream.zig");
  // _ = @import("src/CrashingStackAllocator.zig");
  _ = @import("src/FileInStream.zig");
  _ = @import("src/InflateInStream.zig");
  _ = @import("src/LineReader.zig");
  _ = @import("src/MemoryInStream.zig");
  // _ = @import("src/SingleStackAllocator.zig");
  _ = @import("src/SingleStackAllocatorFlat.zig");
  _ = @import("src/image/tga_test.zig");
  // _ = @import("src/CrashingStackAllocatorTest.zig");
  _ = @import("src/test/ConsumeSeekableInStream.zig");
  _ = @import("src/test/ZipTest.zig");
}
