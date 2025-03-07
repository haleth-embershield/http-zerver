const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options (defaults to host system unless overridden)
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Generate version date file based on platform
    const gen_date_cmd = if (target.result.os.tag == .windows) b.addSystemCommand(&[_][]const u8{
        "powershell",
        "-Command",
        "(Get-Date -Format 'yyyy-MM-dd').ToString() | Out-File -FilePath src/version_date.txt -NoNewline -Encoding ASCII",
    }) else b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "date +%Y-%m-%d > src/version_date.txt",
    });

    // Create executable
    const exe = b.addExecutable(.{
        .name = "http-zerver",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Make exe depend on date generation
    exe.step.dependOn(&gen_date_cmd.step);

    // Link with required platform-specific libraries
    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("ws2_32");
        exe.linkSystemLibrary("kernel32");
        exe.linkSystemLibrary("psapi");
    } else if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("c");
    } else if (target.result.os.tag == .macos) {
        exe.linkSystemLibrary("c");
    }

    // Install the executable
    b.installArtifact(exe);

    // Create a run step (basic run with arguments)
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create a custom run step that:
    // 1. Creates and cleans /www directory
    // 2. Copies /assets to /www
    // 3. Keeps executable in root
    // 4. Runs the server from root serving /www on port 8000
    const custom_run_step = b.step("run", "Run the HTTP server serving /www directory");

    // Platform-specific commands for directory operations
    const setup_www = if (target.result.os.tag == .windows) b.addSystemCommand(&[_][]const u8{
        "powershell",
        "-Command",
        "if (Test-Path www) { Remove-Item -Path www\\* -Recurse -Force }; if (-not (Test-Path www)) { New-Item -ItemType Directory -Path www }; if (Test-Path assets) { Copy-Item -Path assets\\* -Destination www\\ -Recurse -Force }",
    }) else b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "rm -rf www/* && mkdir -p www && if [ -d assets ]; then cp -r assets/* www/ 2>/dev/null || true; fi",
    });

    // Copy executable to root
    const exe_path = b.fmt("{s}/bin/http-zerver{s}", .{ b.install_path, if (target.result.os.tag == .windows) ".exe" else "" });
    const copy_exe = if (target.result.os.tag == .windows) b.addSystemCommand(&[_][]const u8{
        "powershell",
        "-Command",
        "Copy-Item",
        exe_path,
        "http-zerver.exe",
    }) else b.addSystemCommand(&[_][]const u8{
        "cp",
        exe_path,
        "http-zerver",
    });
    copy_exe.step.dependOn(b.getInstallStep());
    copy_exe.step.dependOn(&setup_www.step);

    // Run server from root directory serving www
    const run_server = if (target.result.os.tag == .windows) b.addSystemCommand(&[_][]const u8{
        "powershell",
        "-Command",
        "./http-zerver.exe",
    }) else b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
    });
    run_server.step.dependOn(&copy_exe.step);

    // Add arguments - either from command line or defaults
    if (b.args) |args| {
        if (target.result.os.tag == .windows) {
            run_server.addArgs(args);
        } else {
            // For Linux, construct the command with arguments
            var cmd_buf: [256]u8 = undefined;
            var cmd_len: usize = 0;

            // Start with the executable
            const base_cmd = "./http-zerver";
            @memcpy(cmd_buf[0..base_cmd.len], base_cmd);
            cmd_len = base_cmd.len;

            // Add each argument
            for (args) |arg| {
                cmd_buf[cmd_len] = ' ';
                cmd_len += 1;
                @memcpy(cmd_buf[cmd_len .. cmd_len + arg.len], arg);
                cmd_len += arg.len;
            }

            run_server.addArg(cmd_buf[0..cmd_len]);
        }
    } else {
        // Use default arguments
        if (target.result.os.tag == .windows) {
            run_server.addArg("--port");
            run_server.addArg("8000");
            run_server.addArg("--dir");
            run_server.addArg("www");
        } else {
            run_server.addArg("./http-zerver --port 8000 --dir www");
        }
    }

    custom_run_step.dependOn(&run_server.step);
}
