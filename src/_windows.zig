// windows.zig: Windows-specific implementation without std

// Windows API constants and types
const INVALID_SOCKET = 0xFFFFFFFFFFFFFFFF;
const SOCKET_ERROR = -1;
const AF_INET = 2;
const SOCK_STREAM = 1;
const IPPROTO_TCP = 6;
const SD_SEND = 1;
const SOMAXCONN = 0x7fffffff;
const SOL_SOCKET = 0xFFFF;
const SO_RCVTIMEO = 0x1006;
const SO_SNDTIMEO = 0x1005;
const SO_REUSEADDR = 0x0004;
const GENERIC_READ = 0x80000000;
const FILE_SHARE_READ = 0x00000001;
const OPEN_EXISTING = 3;
const FILE_ATTRIBUTE_NORMAL = 0x80;
const INVALID_HANDLE_VALUE = @as(usize, 0xFFFFFFFFFFFFFFFF);
const FILE_ATTRIBUTE_DIRECTORY = 0x00000010;

pub const Socket = usize;

const sockaddr_in = extern struct {
    sin_family: i16,
    sin_port: u16,
    sin_addr: u32,
    sin_zero: [8]u8,
};

const TIMEVAL = extern struct {
    tv_sec: i32,
    tv_usec: i32,
};

const WSAData = extern struct {
    wVersion: u16,
    wHighVersion: u16,
    szDescription: [257]u8,
    szSystemStatus: [129]u8,
    iMaxSockets: u16,
    iMaxUdpDg: u16,
    lpVendorInfo: ?*u8,
};

const WIN32_FIND_DATA = extern struct {
    dwFileAttributes: u32,
    ftCreationTime: FILETIME,
    ftLastAccessTime: FILETIME,
    ftLastWriteTime: FILETIME,
    nFileSizeHigh: u32,
    nFileSizeLow: u32,
    dwReserved0: u32,
    dwReserved1: u32,
    cFileName: [260]u8,
    cAlternateFileName: [14]u8,
};

const FILETIME = extern struct {
    dwLowDateTime: u32,
    dwHighDateTime: u32,
};

const LARGE_INTEGER = extern struct {
    QuadPart: i64,
};

// Windows API functions
extern "ws2_32" fn WSAStartup(wVersionRequested: u16, lpWSAData: *WSAData) callconv(.C) i32;
extern "ws2_32" fn WSACleanup() callconv(.C) i32;
extern "ws2_32" fn socket(af: i32, type: i32, protocol: i32) callconv(.C) usize;
extern "ws2_32" fn bind(s: usize, name: *const sockaddr_in, namelen: i32) callconv(.C) i32;
extern "ws2_32" fn listen(s: usize, backlog: i32) callconv(.C) i32;
extern "ws2_32" fn accept(s: usize, addr: ?*sockaddr_in, addrlen: ?*i32) callconv(.C) usize;
extern "ws2_32" fn closesocket(s: usize) callconv(.C) i32;
extern "ws2_32" fn recv(s: usize, buf: [*]u8, len: i32, flags: i32) callconv(.C) i32;
pub extern "ws2_32" fn send(s: usize, buf: [*]const u8, len: i32, flags: i32) callconv(.C) i32;
extern "ws2_32" fn shutdown(s: usize, how: i32) callconv(.C) i32;
extern "ws2_32" fn htons(hostshort: u16) callconv(.C) u16;
extern "ws2_32" fn setsockopt(s: usize, level: i32, optname: i32, optval: [*]const u8, optlen: i32) callconv(.C) i32;

extern "kernel32" fn CreateFileA(
    lpFileName: [*:0]const u8,
    dwDesiredAccess: u32,
    dwShareMode: u32,
    lpSecurityAttributes: ?*anyopaque,
    dwCreationDisposition: u32,
    dwFlagsAndAttributes: u32,
    hTemplateFile: ?*anyopaque,
) callconv(.C) usize;
extern "kernel32" fn ReadFile(
    hFile: usize,
    lpBuffer: [*]u8,
    nNumberOfBytesToRead: u32,
    lpNumberOfBytesRead: *u32,
    lpOverlapped: ?*anyopaque,
) callconv(.C) i32;
extern "kernel32" fn CloseHandle(hObject: usize) callconv(.C) i32;
extern "kernel32" fn GetFileSizeEx(
    hFile: usize,
    lpFileSize: *LARGE_INTEGER,
) callconv(.C) i32;
extern "kernel32" fn GetFileAttributesA(lpFileName: [*:0]const u8) callconv(.C) u32;
extern "kernel32" fn GetStdHandle(nStdHandle: u32) callconv(.C) usize;
extern "kernel32" fn WriteConsoleA(
    hConsoleOutput: usize,
    lpBuffer: [*]const u8,
    nNumberOfCharsToWrite: u32,
    lpNumberOfCharsWritten: *u32,
    lpReserved: ?*anyopaque,
) callconv(.C) i32;
extern "kernel32" fn FindFirstFileA(lpFileName: [*:0]const u8, lpFindFileData: *WIN32_FIND_DATA) callconv(.C) usize;
extern "kernel32" fn FindNextFileA(hFindFile: usize, lpFindFileData: *WIN32_FIND_DATA) callconv(.C) i32;
extern "kernel32" fn FindClose(hFindFile: usize) callconv(.C) i32;

pub fn initNetworking() !void {
    var wsa_data: WSAData = undefined;
    if (WSAStartup(0x0202, &wsa_data) != 0) {
        print("WSAStartup failed\n");
        return error.WSAStartupFailed;
    }
}

pub fn cleanupNetworking() void {
    _ = WSACleanup();
}

pub fn createServerSocket(port: u16) !Socket {
    const server_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (server_socket == INVALID_SOCKET) {
        print("Socket creation failed\n");
        return error.SocketCreationFailed;
    }

    var opt_val: i32 = 1;
    _ = setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, @ptrCast(&opt_val), @sizeOf(i32));

    var server_addr = sockaddr_in{
        .sin_family = AF_INET,
        .sin_port = htons(port),
        .sin_addr = 0, // INADDR_ANY
        .sin_zero = [_]u8{0} ** 8,
    };

    if (bind(server_socket, &server_addr, @sizeOf(sockaddr_in)) == SOCKET_ERROR) {
        print("Bind failed\n");
        return error.BindFailed;
    }

    if (listen(server_socket, SOMAXCONN) == SOCKET_ERROR) {
        print("Listen failed\n");
        return error.ListenFailed;
    }

    return server_socket;
}

pub fn acceptConnection(server_socket: Socket) !Socket {
    const client_socket = accept(server_socket, null, null);
    if (client_socket == INVALID_SOCKET) {
        return error.AcceptFailed;
    }

    var timeout = TIMEVAL{
        .tv_sec = 10,
        .tv_usec = 0,
    };
    _ = setsockopt(client_socket, SOL_SOCKET, SO_RCVTIMEO, @ptrCast(&timeout), @sizeOf(TIMEVAL));
    _ = setsockopt(client_socket, SOL_SOCKET, SO_SNDTIMEO, @ptrCast(&timeout), @sizeOf(TIMEVAL));

    return client_socket;
}

pub fn closeSocket(sock: Socket) void {
    _ = closesocket(sock);
}

pub fn closeConnection(sock: Socket) void {
    _ = shutdown(sock, SD_SEND);
    _ = closesocket(sock);
}

pub fn receive(sock: Socket, buffer: []u8) !usize {
    const bytes = recv(sock, buffer.ptr, @intCast(buffer.len), 0);
    if (bytes <= 0) return error.ReceiveFailed;
    return @intCast(bytes);
}

pub fn sendData(sock: Socket, data: []const u8) usize {
    return @intCast(send(sock, data.ptr, @intCast(data.len), 0));
}

pub fn print(message: []const u8) void {
    const stdout = GetStdHandle(0xFFFFFFF5); // STD_OUTPUT_HANDLE
    var written: u32 = 0;
    _ = WriteConsoleA(stdout, message.ptr, @intCast(message.len), &written, null);
}

pub fn printInt(n: u16) void {
    var buffer: [8]u8 = undefined;
    const len = intToBuffer(&buffer, n);
    print(buffer[0..len]);
}

pub fn intToBuffer(buffer: []u8, value: anytype) usize {
    var i: usize = 0;
    var val = value;

    if (val == 0) {
        buffer[0] = '0';
        return 1;
    }

    while (val > 0) {
        buffer[i] = @intCast('0' + (val % 10));
        val /= 10;
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
    for (dir) |c| {
        buf[len] = c;
        len += 1;
    }

    if (len > 0 and buf[len - 1] != '\\') {
        buf[len] = '\\';
        len += 1;
    }

    var req_path = if (path.len > 0 and path[0] == '/') path[1..] else path;
    var query_pos: usize = 0;
    while (query_pos < req_path.len and req_path[query_pos] != '?') : (query_pos += 1) {}
    req_path = req_path[0..query_pos];

    if (req_path.len == 0) {
        for (default_file) |c| {
            buf[len] = c;
            len += 1;
        }
    } else {
        for (req_path) |c| {
            buf[len] = if (c == '/') '\\' else c;
            len += 1;
        }
    }
    buf[len] = 0;
    return buf[0..len];
}

pub fn isDirectory(path: []const u8) bool {
    const attrs = GetFileAttributesA(@ptrCast(path.ptr));
    return attrs != 0xFFFFFFFF and (attrs & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

pub fn serveFile(client_socket: Socket, path: []const u8, send_body: bool) void {
    const file_handle = CreateFileA(@ptrCast(path.ptr), GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if (file_handle == INVALID_HANDLE_VALUE) {
        @import("http.zig").sendErrorResponse(client_socket, 404, "Not Found", send_body);
        return;
    }
    defer _ = CloseHandle(file_handle);

    var file_size: LARGE_INTEGER = undefined;
    if (GetFileSizeEx(file_handle, &file_size) == 0) {
        @import("http.zig").sendErrorResponse(client_socket, 500, "Internal Server Error", send_body);
        return;
    }

    const mime_type = @import("http.zig").getMimeType(path);
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
    header_len += intToBuffer(header_buf[header_len..], @as(u64, @intCast(file_size.QuadPart)));
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
        var read_buf: [8192]u8 = undefined;
        var bytes_read: u32 = 0;
        while (ReadFile(file_handle, &read_buf, read_buf.len, &bytes_read, null) != 0 and bytes_read > 0) {
            _ = sendData(client_socket, read_buf[0..bytes_read]);
        }
    }
}

pub fn serveDirectory(client_socket: Socket, path: []const u8, request_path: []const u8, send_body: bool) void {
    var search_pattern: [512]u8 = undefined;
    var pattern_len: usize = 0;
    for (path) |c| {
        search_pattern[pattern_len] = c;
        pattern_len += 1;
    }
    search_pattern[pattern_len] = '\\';
    pattern_len += 1;
    search_pattern[pattern_len] = '*';
    pattern_len += 1;
    search_pattern[pattern_len] = 0;

    var find_data: WIN32_FIND_DATA = undefined;
    const find_handle = FindFirstFileA(@ptrCast(&search_pattern), &find_data);
    if (find_handle == INVALID_HANDLE_VALUE) {
        @import("http.zig").sendErrorResponse(client_socket, 500, "Error listing directory", send_body);
        return;
    }
    defer _ = FindClose(find_handle);

    var html_buf: [8192]u8 = undefined;
    var html_len: usize = 0;
    var file_count: u32 = 0;

    if (send_body) {
        // HTML header
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

    var has_more_files = true;
    const http = @import("http.zig");
    while (has_more_files) {
        var filename_len: usize = 0;
        while (filename_len < find_data.cFileName.len and find_data.cFileName[filename_len] != 0) {
            filename_len += 1;
        }
        const filename = find_data.cFileName[0..filename_len];

        if (!http.eql(filename, ".") and !http.eql(filename, "..")) {
            file_count += 1;
            if (send_body) {
                const li_start = "<li><a href=\"";
                for (li_start) |c| {
                    html_buf[html_len] = c;
                    html_len += 1;
                }

                for (filename) |c| {
                    html_buf[html_len] = c;
                    html_len += 1;
                }

                if ((find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
                    html_buf[html_len] = '/';
                    html_len += 1;
                }

                html_buf[html_len] = '"';
                html_len += 1;
                html_buf[html_len] = '>';
                html_len += 1;

                for (filename) |c| {
                    html_buf[html_len] = c;
                    html_len += 1;
                }

                if ((find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
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
        has_more_files = FindNextFileA(find_handle, &find_data) != 0;
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

    // Send HTTP headers
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
