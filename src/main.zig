// http-zerver: Main entry point
// Handles command-line arguments and starts the HTTP server

const std = @import("std");
const http = @import("http.zig");
const version = @import("version.zig");
const builtin = @import("builtin");

// Import OS-specific implementations
const os = if (builtin.os.tag == .windows)
    @import("_windows.zig")
else if (builtin.os.tag == .linux)
    @import("_linux.zig")
else
    @compileError("Unsupported operating system");

// Print to console
fn print(message: []const u8) void {
    os.print(message);
}

// Parse command line arguments
fn parseArgs() !struct { port: u16, directory: []const u8 } {
    // Use a general purpose allocator instead of arena
    const gpa = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    // Default values
    var port: u16 = 8000;
    var dir_str: []const u8 = ".";

    // Parse arguments
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--port")) {
            if (args.next()) |port_str| {
                port = parsePort(port_str);
            }
        } else if (std.mem.eql(u8, arg, "--dir")) {
            if (args.next()) |dir| {
                dir_str = dir;
            }
        }
    }

    // Create a persistent copy of the directory string
    const dir_copy = try gpa.alloc(u8, dir_str.len);
    @memcpy(dir_copy, dir_str);

    return .{ .port = port, .directory = dir_copy };
}

// Parse port number from string
fn parsePort(str: []const u8) u16 {
    var result: u16 = 0;
    for (str) |c| {
        if (c >= '0' and c <= '9') {
            result = result * 10 + (c - '0');
        } else {
            break;
        }
    }
    return if (result > 0 and result < 65536) result else 8000;
}

// Entry point
pub fn main() !void {
    const args = try parseArgs();
    // Ensure cleanup of allocated memory
    defer std.heap.page_allocator.free(args.directory);

    // Initialize networking first
    try os.initNetworking();
    defer os.cleanupNetworking();

    print("\nStarting HTTP Zerver...\n");
    print(version.getVersionString());
    print("\nListening at http://localhost:");
    printInt(args.port);
    print("\nServing directory: ");
    print(args.directory);
    print("\n\n");

    try http.serve(args.port, args.directory);
}

// Print integer to console
fn printInt(n: u16) void {
    var buffer: [8]u8 = undefined;
    var i: usize = 0;
    var value = n;

    // Convert to digits
    if (value == 0) {
        buffer[0] = '0';
        i = 1;
    } else {
        while (value > 0) {
            buffer[i] = @intCast('0' + (value % 10));
            value /= 10;
            i += 1;
        }
    }

    // Reverse the digits
    var j: usize = 0;
    var k: usize = i - 1;
    while (j < k) {
        const temp = buffer[j];
        buffer[j] = buffer[k];
        buffer[k] = temp;
        j += 1;
        k -= 1;
    }

    print(buffer[0..i]);
}
