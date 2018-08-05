// this is a "trait".
// too bad these are function pointers. i don't need that...
// or does the compiler actually prune them out somehow?
pub const Seekable = struct {
  pub const Error = error{SeekError};

  pub const Whence = enum {
    Start,
    End,
    Current,
  };

  seekFn: fn (seekable: *Seekable, ofs: i64, whence: Whence) Error!i64,

  // this boilerplate seems to be necessary for the self.func syntax to work...
  pub fn seek(seekable: *Seekable, ofs: i64, whence: Whence) Error!i64 {
    return seekable.seekFn(seekable, ofs, whence);
  }
};
