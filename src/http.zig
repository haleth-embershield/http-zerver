// http.zig: OS-agnostic HTTP server logic
const version = @import("version.zig");
const builtin = @import("builtin");

// Import OS-specific implementations
const os = if (builtin.os.tag == .windows)
    @import("_windows.zig")
else if (builtin.os.tag == .linux)
    @import("_linux.zig")
else
    @compileError("Unsupported operating system");

// Global configuration
var verbose_logging: bool = false;

// HTTP request structure
pub const HttpRequest = struct {
    method: []const u8,
    path: []const u8,
    version: []const u8,
};

// MIME type mapping
pub fn getMimeType(path: []const u8) []const u8 {
    if (endsWith(path, ".html") or endsWith(path, ".htm")) {
        return "text/html";
    } else if (endsWith(path, ".css")) {
        return "text/css";
    } else if (endsWith(path, ".js")) {
        return "application/javascript";
    } else if (endsWith(path, ".wasm")) {
        return "application/wasm";
    } else if (endsWith(path, ".png")) {
        return "image/png";
    } else if (endsWith(path, ".jpg") or endsWith(path, ".jpeg")) {
        return "image/jpeg";
    } else if (endsWith(path, ".gif")) {
        return "image/gif";
    } else if (endsWith(path, ".svg")) {
        return "image/svg+xml";
    } else if (endsWith(path, ".json")) {
        return "application/json";
    } else {
        return "application/octet-stream";
    }
}

// String utilities
pub fn endsWith(str: []const u8, suffix: []const u8) bool {
    if (str.len < suffix.len) return false;
    const start = str.len - suffix.len;
    var i: usize = 0;
    while (i < suffix.len) : (i += 1) {
        if (str[start + i] != suffix[i]) return false;
    }
    return true;
}

pub fn eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

pub fn startsWith(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    return eql(str[0..prefix.len], prefix);
}

// Parse HTTP request
pub fn parseRequest(buffer: []const u8) !HttpRequest {
    var method_end: usize = 0;
    while (method_end < buffer.len and buffer[method_end] != ' ') : (method_end += 1) {}
    if (method_end >= buffer.len) return error.InvalidRequest;

    const path_start = method_end + 1;
    var path_end = path_start;
    while (path_end < buffer.len and buffer[path_end] != ' ') : (path_end += 1) {}
    if (path_end >= buffer.len) return error.InvalidRequest;

    const version_start = path_end + 1;
    var version_end = version_start;
    while (version_end < buffer.len and buffer[version_end] != '\r') : (version_end += 1) {}
    if (version_end >= buffer.len) return error.InvalidRequest;

    return HttpRequest{
        .method = buffer[0..method_end],
        .path = buffer[path_start..path_end],
        .version = buffer[version_start..version_end],
    };
}

// Log request info
fn logRequest(method: []const u8, path: []const u8) void {
    if (!verbose_logging) return;
    os.print(method);
    os.print(" ");
    os.print(path);
    os.print("\n");
}

// Main server function
pub fn serve(port: u16, directory: []const u8, verbose: bool) !void {
    verbose_logging = verbose;

    // Initialize OS-specific networking
    try os.initNetworking();
    defer os.cleanupNetworking();

    // Create and configure server socket
    const server_socket = try os.createServerSocket(port);
    defer os.closeSocket(server_socket);

    // Accept and handle connections
    while (true) {
        const client_socket = os.acceptConnection(server_socket) catch continue;
        handleConnection(client_socket, directory);
    }
}

fn handleConnection(client_socket: os.Socket, directory: []const u8) void {
    defer os.closeConnection(client_socket);

    var buffer: [4096]u8 = undefined;
    const bytes_received = os.receive(client_socket, &buffer) catch return;
    if (bytes_received <= 0) return;

    const request = parseRequest(buffer[0..@intCast(bytes_received)]) catch {
        sendErrorResponse(client_socket, 400, "Bad Request", false);
        return;
    };

    logRequest(request.method, request.path);

    const send_body = eql(request.method, "GET");
    if (!eql(request.method, "GET") and !eql(request.method, "HEAD")) {
        sendErrorResponse(client_socket, 405, "Method Not Allowed", send_body);
        return;
    }

    // Special case for root path
    if (request.path.len == 0 or eql(request.path, "/")) {
        var index_path_buf: [260]u8 = undefined;
        const index_path = os.constructFilePath(&index_path_buf, directory, "/", "index.html");
        os.serveFile(client_socket, index_path, send_body);
        return;
    }

    // Construct directory path first (without index.html)
    var dir_path_buf: [260]u8 = undefined;
    const dir_path = os.constructFilePath(&dir_path_buf, directory, request.path, "");

    // Check if it's a directory first
    if (os.isDirectory(dir_path)) {
        // If it's a directory and doesn't end with '/', redirect
        if (request.path[request.path.len - 1] != '/') {
            sendRedirect(client_socket, request.path);
            return;
        }

        // Try to serve index.html in the directory
        var index_path_buf: [260]u8 = undefined;
        const index_path = os.constructFilePath(&index_path_buf, directory, request.path, "index.html");

        // Try to serve the index file first
        if (!os.isDirectory(index_path)) {
            os.serveFile(client_socket, index_path, send_body);
            return;
        }

        // Fall back to directory listing
        os.serveDirectory(client_socket, dir_path, request.path, send_body);
        return;
    }

    // Try to serve the file directly
    var file_path_buf: [260]u8 = undefined;
    const file_path = os.constructFilePath(&file_path_buf, directory, request.path, "");
    os.serveFile(client_socket, file_path, send_body);
}

fn sendRedirect(client_socket: os.Socket, path: []const u8) void {
    var redirect_buf: [1024]u8 = undefined;
    var redirect_len: usize = 0;

    // HTTP/1.1 301 Moved Permanently
    const status = "HTTP/1.1 301 Moved Permanently\r\n";
    for (status) |c| {
        redirect_buf[redirect_len] = c;
        redirect_len += 1;
    }

    // Location header
    const location = "Location: ";
    for (location) |c| {
        redirect_buf[redirect_len] = c;
        redirect_len += 1;
    }

    // Add the request path
    for (path) |c| {
        redirect_buf[redirect_len] = c;
        redirect_len += 1;
    }

    // Add trailing slash and end of header
    redirect_buf[redirect_len] = '/';
    redirect_len += 1;
    redirect_buf[redirect_len] = '\r';
    redirect_len += 1;
    redirect_buf[redirect_len] = '\n';
    redirect_len += 1;

    // Content-Length: 0
    const content_length = "Content-Length: 0\r\n";
    for (content_length) |c| {
        redirect_buf[redirect_len] = c;
        redirect_len += 1;
    }

    // Connection: close
    const connection_close = "Connection: close\r\n\r\n";
    for (connection_close) |c| {
        redirect_buf[redirect_len] = c;
        redirect_len += 1;
    }

    _ = os.sendData(client_socket, redirect_buf[0..redirect_len]);
}

pub fn sendErrorResponse(client_socket: os.Socket, status_code: u32, status_text: []const u8, send_body: bool) void {
    var response_buf: [1024]u8 = undefined;
    var response_len: usize = 0;

    // Build status line
    const http_ver = "HTTP/1.1 ";
    for (http_ver) |c| {
        response_buf[response_len] = c;
        response_len += 1;
    }
    response_len += os.intToBuffer(response_buf[response_len..], status_code);
    response_buf[response_len] = ' ';
    response_len += 1;
    for (status_text) |c| {
        response_buf[response_len] = c;
        response_len += 1;
    }
    response_buf[response_len] = '\r';
    response_len += 1;
    response_buf[response_len] = '\n';
    response_len += 1;

    // Common headers
    const content_type = "Content-Type: text/html\r\n";
    for (content_type) |c| {
        response_buf[response_len] = c;
        response_len += 1;
    }

    // Error body
    var body_buf: [256]u8 = undefined;
    var body_len: usize = 0;
    const html_start = "<html><body><h1>";
    for (html_start) |c| {
        body_buf[body_len] = c;
        body_len += 1;
    }
    body_len += os.intToBuffer(body_buf[body_len..], status_code);
    body_buf[body_len] = ' ';
    body_len += 1;
    for (status_text) |c| {
        body_buf[body_len] = c;
        body_len += 1;
    }
    const html_end = "</h1></body></html>";
    for (html_end) |c| {
        body_buf[body_len] = c;
        body_len += 1;
    }

    // Content-Length
    const content_length = "Content-Length: ";
    for (content_length) |c| {
        response_buf[response_len] = c;
        response_len += 1;
    }
    response_len += os.intToBuffer(response_buf[response_len..], body_len);
    response_buf[response_len] = '\r';
    response_len += 1;
    response_buf[response_len] = '\n';
    response_len += 1;

    // Connection: close
    const connection_close = "Connection: close\r\n\r\n";
    for (connection_close) |c| {
        response_buf[response_len] = c;
        response_len += 1;
    }

    // Send headers
    _ = os.sendData(client_socket, response_buf[0..response_len]);

    // Send body only for GET requests
    if (send_body) {
        _ = os.sendData(client_socket, body_buf[0..body_len]);
    }
}
