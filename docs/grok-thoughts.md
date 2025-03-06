# HTTP Server Architecture Options

Building a minimal HTTP server in Zig for Windows to serve your WASM files, with plans to adapt it for embedded systems like the ESP8266, is a solid plan. How you organize it—whether as a single repo with multiple targets or as a reusable module—depends on your workflow and long-term goals. Let's break down your options for structuring this, including how to handle the http.zig parser and integrate it into build/deploy scripts, so you can pick what feels right.

## Single Repo with Multiple Targets

**Approach:** Create one Git repo (e.g., `http-zerver`) with separate build targets for Windows and embedded systems.

### Structure:
```
http-zerver/
├── src/
│   ├── main.zig         # Entry point, switches on target
│   ├── http.zig         # Shared HTTP parser logic
│   ├── windows.zig      # Windows-specific socket code
│   └── esp8266.zig      # ESP8266-specific socket code
├── build.zig            # Build script with targets
└── README.md
```

### Build Script (build.zig):
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "http-zerver",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "Run the server").dependOn(&run_cmd.step);
}
```

### Build with:
```bash
# For Windows
zig build -Dtarget=x86_64-windows

# For ESP8266
zig build -Dtarget=xtensa-esp8266-none-elf -I/path/to/esp_sdk
```

### Pros:
- Everything's in one place—easy to maintain and version.
- Shared http.zig lives in the repo, no external fetching needed.
- Simple for now: tweak main.zig to import the right platform module based on `@import("builtin").target`.
- Scales naturally as you add your OS target later.

### Cons:
- Less modular if you want http.zig reused across unrelated projects.
- ESP8266-specific setup (e.g., SDK paths) might clutter the build script.

### How It Works:
- http.zig handles parsing (e.g., `parseRequest(buf: []const u8) !Request`) and response building.
- windows.zig uses Winsock (WS2_32.dll) for sockets.
- esp8266.zig uses lwIP via `@cImport`.
- main.zig glues it together with comptime target checks.

## Separate http.zig Module

**Approach:** Make http.zig a standalone library in its own public repo (e.g., github.com/yourname/zig-http), then pull it into your server projects.

### Structure:
```
zig-http/                # Public repo
├── http.zig            # Parser logic
├── build.zig           # Exports as library
└── README.md

wasm-server/            # Windows server repo
├── src/
│   ├── main.zig       # Imports http.zig
│   └── windows.zig
├── build.zig
└── zig.mod            # Dependency config

esp8266-server/         # Embedded server repo
├── src/
│   ├── main.zig
│   └── esp8266.zig
├── build.zig
└── zig.mod
```

### Build Script (wasm-server/build.zig):
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "wasm-server",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = b.standardTargetOptions(.{.default_target = .{ .os_tag = .windows }}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    const http_mod = b.dependency("http", .{}).module("http");
    exe.root_module.addImport("http", http_mod);

    b.installArtifact(exe);
    b.step("run", "Run the server").dependOn(&b.addRunArtifact(exe).step);
}
```

### zig.mod (or build.zig.zon for newer Zig):
```zig
.{
    .name = "wasm-server",
    .version = "0.1.0",
    .dependencies = .{
        .http = .{
            .url = "git+https://github.com/yourname/zig-http#commit-hash",
            .hash = "sha256-...",
        },
    },
}
```

**Build with:** `zig build` (fetches http.zig automatically).

### Pros:
- http.zig becomes a reusable library for any project, including your OS.
- Cleaner separation—each server focuses on platform specifics.
- Public repo lets others use/contribute to your parser.

### Cons:
- More repos to manage (versioning, updates).
- Dependency fetching adds complexity (git URLs, hashes).
- Overkill if this is just for you right now.

## Recommendation

Since you're starting with a Windows tool and planning for embedded (and eventually an OS), go with a single repo with multiple targets for now. It keeps things simple while you iterate, and you can refactor http.zig into a standalone library later if it grows into a general-purpose tool. Here's why:

- You're still prototyping—keeping http.zig local avoids premature modularization.
- One repo aligns with your "build my repertoire" goal—focus on coding, not repo juggling.
- Adding ESP8266 or OS targets is just a `zig build -Dtarget=...` away.
- Later, when your HTTP parser matures or you want it in other projects, spin it out into a public repo. For now, embed it in http-zerver/src/ and include it via `@import("http")`.

## Workflow

### Windows Tool First:
1. Write http.zig (parse GET, build 200 OK with application/wasm).
2. Use Winsock in windows.zig (load WS2_32.dll with @external).
3. Serve a WASM file from disk.
4. Test: `zig build run -Dtarget=x86_64-windows`.

### Adapt for ESP8266:
1. Add esp8266.zig with lwIP calls.
2. Swap file I/O for SPIFFS or OTA flash access.
3. Build: `zig build -Dtarget=xtensa-esp8266-none-elf`.

### Build Script:
- Keep it in build.zig—no external pulls needed yet.

## Future-Proofing

When your OS comes along, add a kernel.zig target in the same repo, reusing http.zig. If http.zig gets fancy (e.g., POST, chunked encoding), make it a public module then.

So, single repo to start—sound good? Want to sketch out http.zig's parser first, or dive into the Windows socket setup?