// linux.zig: Linux-specific implementation using POSIX APIs without std

const builtin = @import("builtin");

// POSIX constants (architecture-independent)
const AF_INET = 2;
const SOCK_STREAM = 1;
const IPPROTO_TCP = 6;
const SOMAXCONN = 128;
const INVALID_SOCKET = -1;
const SOCKET_ERROR = -1;
const SOL_SOCKET = 1;
const SO_REUSEADDR = 2;
const SO_RCVTIMEO = 20;
const SO_SNDTIMEO = 21;
const SHUT_RDWR = 2;
const O_RDONLY = 0;
const SEEK_END = 2;
const SEEK_SET = 0;
const S_IFDIR = 16384;
const DT_DIR = 4;
const AT_FDCWD = -100; // For SYS_openat on aarch64

// Maximum buffer size for read/write operations (2GB)
const MAX_BUFFER_SIZE: i64 = 2147483647;

pub const Socket = i32;

// Architecture-specific syscall numbers
const SyscallNumbers = switch (builtin.cpu.arch) {
    .x86_64 => struct {
        const SYS_write = 1;
        const SYS_open = 2;
        const SYS_close = 3;
        const SYS_stat = 4;
        const SYS_fstat = 5;
        const SYS_lseek = 8;
        const SYS_read = 0;
        const SYS_socket = 41;
        const SYS_accept = 43;
        const SYS_bind = 49;
        const SYS_listen = 50;
        const SYS_setsockopt = 54;
        const SYS_shutdown = 48;
        const SYS_getdents64 = 217;
    },
    .aarch64 => struct {
        const SYS_write = 64;
        const SYS_openat = 56; // Use openat instead of open on aarch64
        const SYS_close = 57;
        const SYS_stat = 80;
        const SYS_fstat = 80;
        const SYS_lseek = 62;
        const SYS_read = 63;
        const SYS_socket = 198;
        const SYS_accept = 202;
        const SYS_bind = 200;
        const SYS_listen = 201;
        const SYS_setsockopt = 208;
        const SYS_shutdown = 210;
        const SYS_getdents64 = 61;
    },
    else => @compileError("Unsupported architecture"),
};

// Alias syscall numbers for cleaner usage
const SYS_write = SyscallNumbers.SYS_write;
const SYS_close = SyscallNumbers.SYS_close;
const SYS_stat = SyscallNumbers.SYS_stat;
const SYS_fstat = SyscallNumbers.SYS_fstat;
const SYS_lseek = SyscallNumbers.SYS_lseek;
const SYS_read = SyscallNumbers.SYS_read;
const SYS_socket = SyscallNumbers.SYS_socket;
const SYS_accept = SyscallNumbers.SYS_accept;
const SYS_bind = SyscallNumbers.SYS_bind;
const SYS_listen = SyscallNumbers.SYS_listen;
const SYS_setsockopt = SyscallNumbers.SYS_setsockopt;
const SYS_shutdown = SyscallNumbers.SYS_shutdown;
const SYS_getdents64 = SyscallNumbers.SYS_getdents64;

// Structure definitions
const sockaddr_in = extern struct {
    sin_family: i16,
    sin_port: u16,
    sin_addr: u32,
    sin_zero: [8]u8,
};

const timeval = extern struct {
    tv_sec: i64,
    tv_usec: i64,
};

const dirent = extern struct {
    d_ino: u64,
    d_off: i64,
    d_reclen: u16,
    d_type: u8,
    d_name: [256]u8,
};

const stat = extern struct {
    st_dev: u64,
    st_ino: u64,
    st_nlink: u64,
    st_mode: u32,
    st_uid: u32,
    st_gid: u32,
    __pad0: i32,
    st_rdev: u64,
    st_size: i64,
    st_blksize: i64,
    st_blocks: i64,
    st_atime: i64,
    st_atime_nsec: i64,
    st_mtime: i64,
    st_mtime_nsec: i64,
    st_ctime: i64,
    st_ctime_nsec: i64,
    __unused: [3]i64,
};

extern "c" fn syscall(number: i64, ...) i64;

// Initialize networking (no-op on Linux)
pub fn initNetworking() !void {
    // Nothing needed for Linux
}

pub fn cleanupNetworking() void {
    // Nothing needed for Linux
}

pub fn createServerSocket(port: u16) !Socket {
    const server_socket = syscall(SYS_socket, @as(i64, AF_INET), @as(i64, SOCK_STREAM), @as(i64, IPPROTO_TCP));
    if (server_socket < 0) return error.SocketCreationFailed;

    // Set SO_REUSEADDR
    var opt_val: i32 = 1;
    _ = syscall(SYS_setsockopt, server_socket, @as(i64, SOL_SOCKET), @as(i64, SO_REUSEADDR), &opt_val, @as(i64, @sizeOf(i32)));

    // Bind to address
    var addr = sockaddr_in{
        .sin_family = AF_INET,
        .sin_port = @byteSwap(port),
        .sin_addr = 0, // INADDR_ANY
        .sin_zero = [_]u8{0} ** 8,
    };

    if (syscall(SYS_bind, server_socket, &addr, @as(i64, @sizeOf(sockaddr_in))) < 0) {
        _ = syscall(SYS_close, server_socket);
        return error.BindFailed;
    }

    if (syscall(SYS_listen, server_socket, @as(i64, SOMAXCONN)) < 0) {
        _ = syscall(SYS_close, server_socket);
        return error.ListenFailed;
    }

    return @intCast(server_socket);
}

pub fn acceptConnection(server_socket: Socket) !Socket {
    var addr: sockaddr_in = undefined;
    var addr_len: u32 = @sizeOf(sockaddr_in);

    const client_socket = syscall(SYS_accept, server_socket, &addr, &addr_len);
    if (client_socket < 0) return error.AcceptFailed;

    // Set receive/send timeout (10 seconds)
    const timeout = timeval{
        .tv_sec = 10,
        .tv_usec = 0,
    };
    _ = syscall(SYS_setsockopt, client_socket, @as(i64, SOL_SOCKET), @as(i64, SO_RCVTIMEO), &timeout, @as(i64, @sizeOf(timeval)));
    _ = syscall(SYS_setsockopt, client_socket, @as(i64, SOL_SOCKET), @as(i64, SO_SNDTIMEO), &timeout, @as(i64, @sizeOf(timeval)));

    return @intCast(client_socket);
}

pub fn closeSocket(sock: Socket) void {
    _ = syscall(SYS_close, sock);
}

pub fn closeConnection(sock: Socket) void {
    _ = syscall(SYS_shutdown, sock, @as(i64, SHUT_RDWR));
    _ = syscall(SYS_close, sock);
}

pub fn receive(sock: Socket, buffer: []u8) !usize {
    const len: i64 = @min(@as(i64, @intCast(buffer.len)), MAX_BUFFER_SIZE);
    const bytes = syscall(SYS_read, sock, buffer.ptr, len);
    if (bytes <= 0) return error.ReceiveFailed;
    return @intCast(bytes);
}

pub fn sendData(sock: Socket, data: []const u8) usize {
    const len: i64 = @min(@as(i64, @intCast(data.len)), MAX_BUFFER_SIZE);
    const bytes = syscall(SYS_write, sock, data.ptr, len);
    return if (bytes < 0) 0 else @intCast(bytes);
}

pub fn print(message: []const u8) void {
    const len: i64 = @min(@as(i64, @intCast(message.len)), MAX_BUFFER_SIZE);
    _ = syscall(SYS_write, @as(i64, 1), message.ptr, len);
}

pub fn printInt(n: u16) void {
    var buf: [16]u8 = undefined;
    const str = intToBuffer(&buf, n);
    print(buf[0..str]);
}

pub fn intToBuffer(buffer: []u8, value: anytype) usize {
    var i: usize = 0;
    var val = value;

    if (val == 0) {
        buffer[0] = '0';
        return 1;
    }

    while (val > 0) {
        buffer[i] = @intCast('0' + @rem(val, 10));
        val = @divTrunc(val, 10);
        i += 1;
    }

    var j: usize = 0;
    var k: usize = i - 1;
    while (j < k) {
        const temp = buffer[j];
        buffer[j] = buffer[k];
        buffer[k] = temp;
        j += 1;
        k -= 1;
    }
    return i;
}

pub fn constructFilePath(buf: []u8, dir: []const u8, path: []const u8, default_file: []const u8) []u8 {
    var len: usize = 0;

    // Handle directory path - remove leading ./ if present
    var clean_dir = dir;
    if (dir.len >= 2 and dir[0] == '.' and dir[1] == '/') {
        clean_dir = dir[2..];
    }

    // Copy directory path, but skip if it's just "."
    if (clean_dir.len > 0 and !(clean_dir.len == 1 and clean_dir[0] == '.')) {
        for (clean_dir) |c| {
            buf[len] = c;
            len += 1;
        }

        // Add separator if needed
        if (len > 0 and buf[len - 1] != '/') {
            buf[len] = '/';
            len += 1;
        }
    }

    // Handle request path
    var req_path = if (path.len > 0 and path[0] == '/') path[1..] else path;
    var query_pos: usize = 0;
    while (query_pos < req_path.len and req_path[query_pos] != '?') : (query_pos += 1) {}
    req_path = req_path[0..query_pos];

    // Add default file or request path
    if (req_path.len == 0 or (req_path.len == 1 and req_path[0] == '/')) {
        if (default_file.len > 0) {
            for (default_file) |c| {
                buf[len] = c;
                len += 1;
            }
        }
    } else {
        for (req_path) |c| {
            buf[len] = if (c == '\\') '/' else c;
            len += 1;
        }
    }

    // Remove trailing slash for directories
    if (len > 0 and buf[len - 1] == '/') {
        len -= 1;
    }

    // Always null terminate
    buf[len] = 0;

    return buf[0..len];
}

pub fn isDirectory(path: []const u8) bool {
    var clean_path = path;
    if (path.len >= 2 and path[0] == '.' and path[1] == '/') {
        clean_path = path[2..];
    }

    var st: stat = undefined;
    if (syscall(SYS_stat, clean_path.ptr, &st) < 0) return false;
    return (st.st_mode & S_IFDIR) != 0;
}

pub fn serveFile(client_socket: Socket, path: []const u8, send_body: bool, method: []const u8, request_path: []const u8) void {
    const http = @import("http.zig");
    var clean_path = path;
    if (path.len >= 2 and path[0] == '.' and path[1] == '/') {
        clean_path = path[2..];
    }

    // Use SYS_open for x86_64, SYS_openat for aarch64 with explicit casts
    const fd = switch (builtin.cpu.arch) {
        .x86_64 => syscall(SyscallNumbers.SYS_open, clean_path.ptr, @as(i64, O_RDONLY)),
        .aarch64 => syscall(SyscallNumbers.SYS_openat, @as(i64, AT_FDCWD), clean_path.ptr, @as(i64, O_RDONLY), @as(i64, 0)),
        else => unreachable,
    };
    if (fd < 0) {
        http.logResponse(method, request_path, "text/plain", 404, "Not Found");
        http.sendErrorResponse(client_socket, 404, "Not Found", send_body);
        return;
    }
    defer _ = syscall(SYS_close, fd);

    var st: stat = undefined;
    if (syscall(SYS_fstat, fd, &st) < 0) {
        http.logResponse(method, request_path, "text/plain", 500, "Internal Server Error");
        http.sendErrorResponse(client_socket, 500, "Internal Server Error", send_body);
        return;
    }

    const file_size = st.st_size;
    const mime_type = http.getMimeType(path);
    http.logResponse(method, request_path, mime_type, 200, "OK");

    var header_buf: [1024]u8 = undefined;
    var header_len: usize = 0;

    const status = "HTTP/1.1 200 OK\r\n";
    for (status) |c| {
        header_buf[header_len] = c;
        header_len += 1;
    }

    const content_type = "Content-Type: ";
    for (content_type) |c| {
        header_buf[header_len] = c;
        header_len += 1;
    }
    for (mime_type) |c| {
        header_buf[header_len] = c;
        header_len += 1;
    }
    header_buf[header_len] = '\r';
    header_len += 1;
    header_buf[header_len] = '\n';
    header_len += 1;

    const content_length = "Content-Length: ";
    for (content_length) |c| {
        header_buf[header_len] = c;
        header_len += 1;
    }
    header_len += intToBuffer(header_buf[header_len..], file_size);
    header_buf[header_len] = '\r';
    header_len += 1;
    header_buf[header_len] = '\n';
    header_len += 1;

    const connection_close = "Connection: close\r\n\r\n";
    for (connection_close) |c| {
        header_buf[header_len] = c;
        header_len += 1;
    }

    _ = sendData(client_socket, header_buf[0..header_len]);

    if (send_body) {
        var buffer: [8192]u8 = undefined;
        while (true) {
            const bytes_read = syscall(SYS_read, fd, &buffer, buffer.len);
            if (bytes_read <= 0) break;
            _ = sendData(client_socket, buffer[0..@intCast(bytes_read)]);
        }
    }
}

pub fn serveDirectory(client_socket: Socket, path: []const u8, request_path: []const u8, send_body: bool) void {
    var clean_path = path;
    if (path.len >= 2 and path[0] == '.' and path[1] == '/') {
        clean_path = path[2..];
    }

    if (clean_path.len > 0 and clean_path[clean_path.len - 1] == '/') {
        clean_path = clean_path[0 .. clean_path.len - 1];
    }

    // Use SYS_open for x86_64, SYS_openat for aarch64 with explicit casts
    const dir_fd = switch (builtin.cpu.arch) {
        .x86_64 => syscall(SyscallNumbers.SYS_open, clean_path.ptr, @as(i64, O_RDONLY)),
        .aarch64 => syscall(SyscallNumbers.SYS_openat, @as(i64, AT_FDCWD), clean_path.ptr, @as(i64, O_RDONLY), @as(i64, 0)),
        else => unreachable,
    };
    if (dir_fd < 0) {
        @import("http.zig").sendErrorResponse(client_socket, 500, "Error listing directory", send_body);
        return;
    }
    defer _ = syscall(SYS_close, dir_fd);

    var html_buf: [8192]u8 = undefined;
    var html_len: usize = 0;
    var file_count: u32 = 0;

    if (send_body) {
        const html_header = "<!DOCTYPE HTML>\n<html>\n<head>\n<title>Directory listing for ";
        for (html_header) |c| {
            html_buf[html_len] = c;
            html_len += 1;
        }

        for (request_path) |c| {
            html_buf[html_len] = c;
            html_len += 1;
        }

        const html_header2 = "</title>\n</head>\n<body>\n<h1>Directory listing for ";
        for (html_header2) |c| {
            html_buf[html_len] = c;
            html_len += 1;
        }

        for (request_path) |c| {
            html_buf[html_len] = c;
            html_len += 1;
        }

        const html_list_start = "</h1>\n<hr>\n<ul>\n";
        for (html_list_start) |c| {
            html_buf[html_len] = c;
            html_len += 1;
        }

        if (request_path.len > 1) {
            const parent_link = "<li><a href=\"..\">..</a></li>\n";
            for (parent_link) |c| {
                html_buf[html_len] = c;
                html_len += 1;
            }
        }
    }

    const http = @import("http.zig");
    var dir_buf: [8192]u8 align(8) = undefined;

    while (true) {
        const bytes_read = syscall(SYS_getdents64, dir_fd, &dir_buf, dir_buf.len);
        if (bytes_read <= 0) break;

        var offset: usize = 0;
        while (offset < @as(usize, @intCast(bytes_read))) {
            const entry: *dirent = @ptrCast(@alignCast(&dir_buf[offset]));
            const name_len = strlen(&entry.d_name);
            const name = entry.d_name[0..name_len];

            if (!http.eql(name, ".") and !http.eql(name, "..")) {
                file_count += 1;
                if (send_body) {
                    const li_start = "<li><a href=\"";
                    for (li_start) |c| {
                        html_buf[html_len] = c;
                        html_len += 1;
                    }

                    for (name) |c| {
                        html_buf[html_len] = c;
                        html_len += 1;
                    }

                    if (entry.d_type == DT_DIR) {
                        html_buf[html_len] = '/';
                        html_len += 1;
                    }

                    html_buf[html_len] = '"';
                    html_len += 1;
                    html_buf[html_len] = '>';
                    html_len += 1;

                    for (name) |c| {
                        html_buf[html_len] = c;
                        html_len += 1;
                    }

                    if (entry.d_type == DT_DIR) {
                        html_buf[html_len] = '/';
                        html_len += 1;
                    }

                    const item_end = "</a></li>\n";
                    for (item_end) |c| {
                        html_buf[html_len] = c;
                        html_len += 1;
                    }
                }
            }
            offset += entry.d_reclen;
        }
    }

    if (send_body) {
        const html_footer = "</ul>\n<hr>\n</body>\n</html>\n";
        for (html_footer) |c| {
            html_buf[html_len] = c;
            html_len += 1;
        }
    } else {
        html_len = 500 + (file_count * 50);
    }

    var header_buf: [1024]u8 = undefined;
    var header_len: usize = 0;
    const status = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ";
    for (status) |c| {
        header_buf[header_len] = c;
        header_len += 1;
    }

    header_len += intToBuffer(header_buf[header_len..], html_len);

    const end_headers = "\r\nConnection: close\r\n\r\n";
    for (end_headers) |c| {
        header_buf[header_len] = c;
        header_len += 1;
    }

    _ = sendData(client_socket, header_buf[0..header_len]);
    if (send_body) {
        _ = sendData(client_socket, html_buf[0..html_len]);
    }
}

fn strlen(str: [*]const u8) usize {
    var len: usize = 0;
    while (str[len] != 0) : (len += 1) {}
    return len;
}
