# HTTP-Zerver TODO List

## High Priority (Core Functionality)

### Directory Listing
- Implement `list_directory` functionality
  - When a request targets a directory without an index.html (or index.htm), the server should generate and return an HTML page listing the directory contents
  - This is crucial for browsing directories
  - The Python code's `list_directory` method provides the logic:
    - Check if the requested path is a directory using `GetFileAttributesA` and checking for the `FILE_ATTRIBUTE_DIRECTORY` flag
    - Use `FindFirstFileA` and `FindNextFileA` to iterate through the directory's contents
    - Generate HTML output similar to the Python version, including links to files and subdirectories
    - Handle potential OSError if the directory can't be listed (e.g., permissions)

### Handle Trailing Slashes Correctly
- If a URL ends with a `/`, and that path doesn't correspond to a directory, return a 404 error
- This is important for consistent behavior
- The Python code explicitly checks for this: `if path.endswith("/")`
- Your Zig code needs an equivalent check using `GetFileAttributesA`

### Handle HTTP/0.9
- Detect and handle HTTP/0.9 requests
- Do not send response headers for HTTP/0.9
- Only respond with the file contents
- Do not support directory listing

### Refactor Error Handling
- Instead of just calling `sendErrorResponse`, consider returning error values from functions like `handleConnection` and `parseRequest`
- This will allow for more granular error handling and potentially cleaner logging

### Improve parseRequest
- The current `parseRequest` is very basic and could be made more robust
- Consider using a state machine or a more structured approach to parsing to better handle edge cases and malformed requests
- Handle requests that are missing parts (e.g., just "GET")
- The Python code has checks like `if len(words) < 2`
- Remove double slashes from requests

### Date and Time Formatting
- Implement `date_time_string` and/or use a pre-existing Zig library to add correctly formatted Date headers

### Proper HTTP Status Codes
- Use symbolic constants for HTTP status codes, rather than just the numeric values
- Create a Zig enum for this: 
  ```zig
  pub const HttpStatusCode = enum(u16) { 
      OK = 200, 
      NotFound = 404, 
      // ... 
  };
  ```
- This improves readability and maintainability

### HEAD Request
- Implement a function for handling HEAD requests similar to Python's `do_HEAD()` function

### If-Modified-Since
- Implement conditional requests based on the `If-Modified-Since` header

## Medium Priority (Enhancements)

### Logging
- Improve logging. Instead of just printing to the console, consider implementing a basic logging function that includes:
  - Client IP address
  - Timestamp
  - Request line (method, path, version)
  - Response code
  - Response size (in bytes)
- The Python code has detailed logging which would be beneficial to follow

### Command Line Arguments
- Add command-line argument parsing (like Python's argparse) to allow the user to specify the port and directory to serve
- This makes the server much more usable
- Zig has libraries for this, or you can implement a basic version yourself

### Security Considerations (Basic)
- **Path Traversal Prevention**: The current path normalization is a good start, but it's essential to ensure that requests cannot access files outside of the served directory
  - Python's `translate_path` method and `_url_collapse_path` in `CGIHTTPRequestHandler` provide critical protection against path traversal attacks (e.g., `GET /../../etc/passwd`)
  - You MUST implement robust checks to prevent this
- **Explicitly handle ".."**: Make very sure that `..` in paths is handled safely and cannot be used to escape the root directory

### Content-Length for Error Responses
- Add the `Content-Length` header to error responses for greater HTTP compliance

### Connection: close // i think we got this working 2025-02-25
- Set `Connection: close` header
- Close connection after request served

## Low Priority (Nice-to-Haves)

### HTTP/1.1 Keep-Alive
- Basic support for persistent connections (Keep-Alive) could be added, but it's significantly more complex
- This involves managing multiple requests on a single connection
- This is not necessary for a simple development server
- If you implement this, you'll need to handle the `Connection: keep-alive` header and manage socket timeouts

### More MIME Types
- Expand the `getMimeType` function with a more comprehensive list of MIME types, or use a dedicated MIME type library
- The Python version uses `mimetypes.guess_type`
- For simple development, the current list is likely sufficient

### Configurable Index Files
- Allow the user to specify a list of index files (like Python's `index_pages`), not just index.html

### More Robust Header Parsing (Long Term)
- For a production-quality server (which this is not), you'd want a full HTTP header parser
- But for a simple server, the current approach is adequate

## Key Differences and Simplifications (compared to Python)

- **No CGI Support**: You are explicitly not implementing CGI support. This simplifies the server considerably.
- **No Threading**: Your Zig server is single-threaded. Python's `ThreadingHTTPServer` is not being replicated. This is acceptable for a local development server.
- **Windows-Specific**: Your current implementation is Windows-specific due to the use of the Windows API. Porting to other platforms would require using different system calls.
- **No socketserver Abstraction**: You're directly using the Windows socket API, whereas Python uses the `socketserver` module, which provides a higher-level abstraction.

## General Zig Improvements

- **Error Handling**: Use Zig's error handling features (`try`, `catch`, error sets) consistently.
- **Memory Management**: Be mindful of memory allocation. Since you're not using Zig's standard library allocator, you need to be very careful to avoid memory leaks. For a simple server, static buffers (like your `buffer: [4096]u8`) are generally sufficient, but be aware of their limitations (e.g., buffer overflows).
- **Code Style**: Use consistent naming conventions (e.g., snake_case for function names).
- **Use of Pointers**: You are using raw pointers (`[*]u8`). Ensure you have a good understanding of Zig's pointer types and their safety implications. Consider using slices (`[]u8`) where appropriate, as they provide bounds checking.
- **Type Safety**: Use comptime checks, and Zig type system to maximum advantage.