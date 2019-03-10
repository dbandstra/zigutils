const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
  const mode = b.standardReleaseOptions();

  var t = b.addTest("test.zig");

  // where to find zlib includes and libs on my system (ubuntu)
  t.addIncludeDir("/usr/include");
  t.addLibPath("/usr/lib/x86_64-linux-gnu");

  t.linkSystemLibrary("c");
  t.linkSystemLibrary("z");
  const test_step = b.step("test", "Run all tests");
  test_step.dependOn(&t.step);

  const build_lib = b.addStaticLibrary("zigutils", "src/index.zig");
  build_lib.setOutputDir("build");
  const build_lib_step = b.step("library", "Build static library");
  build_lib_step.dependOn(&build_lib.step);

  b.default_step.dependOn(build_lib_step);
}
