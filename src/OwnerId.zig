var next_owner_id: usize = 1; // FIXME - "manager" per thread
pub const OwnerId = struct{
  pub id: usize,

  pub fn generate() OwnerId {
    const id = next_owner_id;
    next_owner_id += 1;
    return OwnerId{ .id = id };
  }
};
