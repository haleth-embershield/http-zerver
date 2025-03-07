const std = @import("std");
const builtin = @import("builtin");

// This is the build script for our MP4 Parser WebAssembly project
pub fn build(b: *std.Build) void {
    // Standard target options for WebAssembly
    const wasm_target = std.Target.Query{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .abi = .none,
    };

    // Get native target for setup_zerver
    const native_target = b.standardTargetOptions(.{});

    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});

    // Create an executable that compiles to WebAssembly
    const exe = b.addExecutable(.{
        .name = "mp4_parser",
        .root_source_file = b.path("src/mp4_parser.zig"),
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
    });

    // Important WASM-specific settings
    exe.rdynamic = true;
    exe.entry = .disabled;

    // Install in the output directory
    b.installArtifact(exe);

    // Build setup_zerver executable first - using native target
    const setup_zerver = b.addExecutable(.{
        .name = "setup_zerver",
        .root_source_file = b.path("setup_zerver.zig"),
        .target = native_target,
        .optimize = optimize,
    });
    b.installArtifact(setup_zerver);

    // Run setup_zerver to create directories and get http-zerver
    const setup_path = b.getInstallPath(.bin, "setup_zerver");
    const make_www = b.addSystemCommand(&[_][]const u8{setup_path});
    make_www.step.dependOn(b.getInstallStep());

    // Create a step to copy the WASM file to the root www directory
    const copy_wasm = b.addInstallFile(exe.getEmittedBin(), "../www/mp4_parser.wasm");
    copy_wasm.step.dependOn(b.getInstallStep());
    copy_wasm.step.dependOn(&make_www.step);

    // Create a step to copy all files from the assets directory to the root www directory
    const copy_assets = b.addInstallDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .{ .custom = "../www" },
        .install_subdir = "",
    });
    copy_assets.step.dependOn(&make_www.step);

    // Add a run step to start http-zerver
    const server_path = if (builtin.os.tag == .windows)
        "http-zerver.exe"
    else
        "./http-zerver";

    const run_cmd = b.addSystemCommand(&[_][]const u8{
        server_path,
        "--port",
        "8000",
        "--dir",
        "www",
    });
    run_cmd.step.dependOn(&copy_wasm.step);
    run_cmd.step.dependOn(&copy_assets.step);

    const run_step = b.step("run", "Build, deploy, and start HTTP server");
    run_step.dependOn(&run_cmd.step);

    // Add a deploy step that only copies the files without starting the server
    const deploy_step = b.step("deploy", "Build and copy files to www directory");
    deploy_step.dependOn(&copy_wasm.step);
    deploy_step.dependOn(&copy_assets.step);
}
