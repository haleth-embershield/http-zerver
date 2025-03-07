// Version information for http-zerver
pub const VERSION = "2025.03.06";
pub const BUILD_DATE = @embedFile("version_date.txt");

// Platform information
const builtin = @import("builtin");
pub const PLATFORM = switch (builtin.os.tag) {
    .windows => "Windows",
    .linux => "Linux",
    .macos => "macOS",
    else => "Unknown",
};

pub fn getVersionString() []const u8 {
    return "Version " ++ VERSION ++ " (" ++ PLATFORM ++ ", Built: " ++ BUILD_DATE ++ ")";
}
