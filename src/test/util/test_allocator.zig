const DoubleStackAllocator = @import("../../DoubleStackAllocator.zig").DoubleStackAllocator;
const DoubleStackAllocatorFlat = @import("../../DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const SingleStackAllocator = @import("../../SingleStackAllocator.zig").SingleStackAllocator;
const SingleStackAllocatorFlat = @import("../../SingleStackAllocatorFlat.zig").SingleStackAllocatorFlat;

// crashes
var dsa_buffer: [100 * 1024]u8 = undefined;
var dsa_ = DoubleStackAllocator.init(dsa_buffer[0..]);
pub const dsa = &dsa_;

// crashes
var ssa_buffer: [100 * 1024]u8 = undefined;
var ssa_ = SingleStackAllocator.init(ssa_buffer[0..]);
pub const ssa = &ssa_;

// works
var dsaf_buffer: [100 * 1024]u8 = undefined;
var dsaf_ = DoubleStackAllocatorFlat.init(dsaf_buffer[0..]);
pub const dsaf = &dsaf_;

// works
var ssaf_buffer: [100 * 1024]u8 = undefined;
var ssaf_ = SingleStackAllocatorFlat.init(ssaf_buffer[0..]);
pub const ssaf = &ssaf_;
