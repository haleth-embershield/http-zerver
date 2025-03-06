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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    // Default values
    var port: u16 = 8000;
    var directory: []const u8 = ".";

    // Parse arguments
    while (args.next()) |arg| {
        // Handle positional arguments
        if (port == 8000) {
            // First positional arg is port
            port = parsePort(arg);
        } else {
            // Second positional arg is directory
            directory = arg;
        }
    }

    return .{ .port = port, .directory = directory };
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
    return if (result > 0) result else 8000;
}

// Entry point
pub fn main() !void {
    const args = try parseArgs();

    print("\nStarting HTTP Zerver...\n");
    print(version.getVersionString());
    print("\nListening at http://localhost:");
    os.printInt(args.port);
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
