const std = @import("std");
const deps = @import("./deps.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("iter-zig", "src/lib.zig");
    lib.setTarget(target);
    lib.setBuildMode(mode);
    deps.addAllTo(lib);
    lib.install();

    const exe = b.addExecutable("iter-zig-example", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    deps.addAllTo(exe);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("example", "Run the example app using library");
    run_step.dependOn(&run_cmd.step);

    const main_tests = b.addTest("src/lib.zig");
    main_tests.setBuildMode(mode);
    deps.addAllTo(main_tests);

    const docs = b.addTest("src/lib.zig");
    docs.setBuildMode(mode);
    deps.addAllTo(docs);
    docs.emit_docs = .emit;

    const lib_step = b.step("lib", "Build static library");
    lib_step.dependOn(&lib.step);

    const docs_step = b.step("docs", "Generate library docs");
    docs_step.dependOn(&docs.step);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
