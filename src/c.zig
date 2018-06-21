pub use @cImport({
  @cInclude("zlib.h");
});

// taken from tetris
// see https://github.com/ziglang/zig/issues/1059
pub fn ptr(p: var) t: {
  const T = @typeOf(p);
  const info = @typeInfo(@typeOf(p)).Pointer;
  break :t if (info.is_const) ?[*]const info.child else ?[*]info.child;
} {
  return @ptrCast(@typeInfo(@typeOf(this)).Fn.return_type.?, p);
}
