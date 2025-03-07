# http-zerver

A minimal, cross-platform HTTP file server written in Zig, inspired by Python's `http.server` module.

## Features

- Simple HTTP/1.1 server for serving static files
- No dependencies on Zig's standard library
- OS-agnostic design (can be adapted for various platforms)
- Minimalist implementation
- Easy to use: `http-zerver 8000` to serve files on port 8000

## Getting Started

### Prerequisites

- Zig compiler (tested with version 0.11.0)

### Building

```bash
git clone https://github.com/yourusername/http-zerver.git
cd http-zerver
zig build
```

The build process will create an executable in the `zig-out/bin` directory.

### Usage

```bash
# Serve current directory on default port 8000
./http-zerver

# Serve current directory on specified port
./http-zerver 8000

# Serve specific directory on specified port
./http-zerver 8000 /path/to/directory
```

### Future Implementations


## Implementation Details

http-zerver is implemented in a single file (`src/http.zig`) without relying on Zig's standard library. It uses direct system calls for socket operations, file I/O, and memory management.

### Platform Support

Currently supported platforms:
<!-- - Linux -->
- Windows
<!-- - macOS -->

**Future plans include support for embedded systems like ESP8266.**
Zig’s killer feature is its built-in cross-compilation. You can target the ESP8266’s Xtensa architecture (xtensa-esp8266-none-elf)

### Code Structure

The code is organized into these main components:

1. Socket handling and networking primitives
2. HTTP request parsing
3. File system operations
4. MIME type determination
5. Response generation

## Customization

The server is designed to be easily customizable:

- Edit `http.zig` to modify server behavior
- Adjust MIME types in the `getMimeType` function
- Modify error responses in the `handleError` function

## Cross-Compiling

To build for different platforms:

```bash
# For Windows
zig build -Dtarget=x86_64-windows

# For macOS
# zig build -Dtarget=x86_64-macos

# For Linux
# zig build -Dtarget=x86_64-linux
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by Python's `http.server` module
- Designed with simplicity and portability in mind