# HTTP-Zerver Performance Testing

This directory contains tools for testing the performance and stability of the HTTP-Zerver.

## Test Files

- `testfile.txt`: A small text file for basic download testing
- `generate-large-file.ps1`: PowerShell script to generate a large binary file for testing large file downloads

## Test Scripts

- `test-server.ps1`: PowerShell script to test server performance by making multiple requests

## How to Use

### Generating a Large Test File

To generate a large test file for download testing:

```powershell
# Generate a 10MB test file (default)
.\assets\generate-large-file.ps1

# Generate a 100MB test file
.\assets\generate-large-file.ps1 -SizeMB 100 -OutputFile "assets\largefile.bin"
```

### Running the Server

Start the HTTP server in one terminal:

```powershell
zig build run
```

### Running Performance Tests

In another terminal, run the test script:

```powershell
# Basic test - 1000 requests to the homepage
.\test-server.ps1

# Test with custom parameters
.\test-server.ps1 -RequestCount 500 -Url "http://localhost:8000/testfile.txt" -Concurrent 20 -DownloadFile

# Test downloading a large file
.\test-server.ps1 -RequestCount 100 -Url "http://localhost:8000/largefile.bin" -Concurrent 5 -DownloadFile
```

use this if necessary

```powershell
powershell -ExecutionPolicy Bypass -File .\test-server.ps1
```

## Test Parameters

The `test-server.ps1` script accepts the following parameters:

- `-RequestCount`: Number of requests to make (default: 1000)
- `-Url`: URL to request (default: "http://localhost:8000/")
- `-OutputFile`: File to save test results (default: "test-results.txt")
- `-Concurrent`: Number of concurrent requests (default: 10)
- `-DownloadFile`: Switch to download the file instead of just getting headers

## Interpreting Results

The script will output statistics to both the console and the specified output file, including:

- Total test duration
- Requests per second
- Success rate
- Average, minimum, and maximum response times

These metrics can help identify performance bottlenecks and stability issues in the server. 