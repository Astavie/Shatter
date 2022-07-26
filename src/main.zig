const std = @import("std");
const os = std.os;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");
const xkb = @import("xkbcommon");

const Server = @import("Server.zig");

pub const gpa = std.heap.c_allocator;
pub var server: Server = undefined;

pub fn main() anyerror!void {
    wlr.log.init(.debug);

    try server.init();
    defer server.deinit();

    var buf: [11]u8 = undefined;
    const socket = try server.wl_server.addSocketAuto(&buf);

    if (os.argv.len >= 2) {
        const cmd = std.mem.span(os.argv[1]);
        var child = try std.ChildProcess.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, gpa);
        defer child.deinit();
        var env_map = try std.process.getEnvMap(gpa);
        defer env_map.deinit();
        try env_map.put("WAYLAND_DISPLAY", socket);
        child.env_map = &env_map;
        try child.spawn();
    }

    try server.backend.start();

    std.log.info("Running compositor on WAYLAND_DISPLAY={s}", .{socket});
    server.wl_server.run();
}
