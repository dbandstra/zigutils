pub fn Emitter(comptime T: type) type {
  return struct {
    const Self = this;

    pollFn: fn (emitter: *Emitter) ?T,

    fn poll(emitter: *Emitter) ?T {
      return emitter.pollFn(emitter);
    }
  };
}
