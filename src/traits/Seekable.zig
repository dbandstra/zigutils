// this is a "trait".
// too bad these are function pointers. i don't need that...
// or does the compiler actually prune them out somehow?
pub const Seekable = struct {
  pub const Error = error{SeekError};

  seekForwardFn: fn (seekable: *Seekable, amount: isize) Error!void,
  seekToFn: fn (seekable: *Seekable, pos: usize) Error!void,
  getPosFn: fn (seekable: *Seekable) Error!usize,
  getEndPosFn: fn (seekable: *Seekable) Error!usize,

  // this boilerplate seems to be necessary for the self.func syntax to work...
  fn seekForward(seekable: *Seekable, amount: isize) Error!void {
    return seekable.seekForwardFn(seekable, amount);
  }

  fn seekTo(seekable: *Seekable, pos: usize) Error!void {
    return seekable.seekToFn(seekable, pos);
  }

  fn getPos(seekable: *Seekable) Error!usize {
    return seekable.getPosFn(seekable);
  }

  fn getEndPos(seekable: *Seekable) Error!usize {
    return seekable.getEndPosFn(seekable);
  }
};
