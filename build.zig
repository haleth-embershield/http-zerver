const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
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

    // Create a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Create a custom run step that:
    // 1. Deletes all files in /www
    // 2. Copies /assets to /www
    // 3. Copies the executable to /www
    // 4. Runs the server from /www on port 8000

    // Create a custom run step
    const custom_run_step = b.step("run", "Run the HTTP server from /www directory");

    // Platform-specific commands for directory operations
    const clear_www = if (target.result.os.tag == .windows) b.addSystemCommand(&[_][]const u8{
        "powershell",
        "-Command",
        "if (Test-Path www) { Remove-Item -Path www\\* -Recurse -Force }; if (-not (Test-Path www)) { New-Item -ItemType Directory -Path www }",
    }) else b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "rm -rf www/* && mkdir -p www",
    });

    // Copy assets
    const copy_assets = if (target.result.os.tag == .windows) b.addSystemCommand(&[_][]const u8{
        "powershell",
        "-Command",
        "if (Test-Path assets) { Copy-Item -Path assets\\* -Destination www\\ -Recurse -Force }",
    }) else b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "if [ -d assets ]; then cp -r assets/* www/ 2>/dev/null || true; fi",
    });
    copy_assets.step.dependOn(&clear_www.step);

    // Copy executable
    const copy_exe = if (target.result.os.tag == .windows) b.addSystemCommand(&[_][]const u8{
        "powershell",
        "-Command",
        "Copy-Item",
        b.fmt("{s}/bin/http-zerver.exe", .{b.install_path}),
        "www/http-zerver.exe",
    }) else b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        b.fmt("cp {s}/bin/http-zerver www/http-zerver", .{b.install_path}),
    });
    copy_exe.step.dependOn(b.getInstallStep());
    copy_exe.step.dependOn(&copy_assets.step);

    // Run server
    const run_server = if (target.result.os.tag == .windows) b.addSystemCommand(&[_][]const u8{
        "powershell",
        "-Command",
        "cd www; ./http-zerver.exe 8000 .",
    }) else b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "cd www && ./http-zerver 8000 .",
    });
    run_server.step.dependOn(&copy_exe.step);

    custom_run_step.dependOn(&run_server.step);
}
