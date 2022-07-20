const Output = @This();
const Server = @import("Server.zig");

const std = @import("std");
const os = std.os;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const server = &@import("main.zig").server;
const gpa = @import("main.zig").gpa;

wlr_output: *wlr.Output,

frame: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(frame),
enable: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(enable),
destroy: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(destroy),

pub fn init(output: *Output, wlr_output: *wlr.Output) !void {
    if (!wlr_output.initRender(server.allocator, server.renderer)) return error.OutputCapabilitiesMismatch;

    if (wlr_output.preferredMode()) |preferred_mode| {
        wlr_output.setMode(preferred_mode);
        wlr_output.enable(true);
        wlr_output.commit() catch |err| {
            var it = wlr_output.modes.iterator(.forward);
            while (it.next()) |mode| {
                if (mode == preferred_mode) continue;
                wlr_output.setMode(mode);
                wlr_output.commit() catch continue;
                break;
            } else {
                return err;
            }
        };
    }

    output.* = .{
        .wlr_output = wlr_output,
    };

    wlr_output.events.enable.add(&output.enable);
    wlr_output.events.frame.add(&output.frame);
    wlr_output.events.destroy.add(&output.destroy);
}

pub fn deinit(output: *Output) void {
    output.frame.link.remove();
    output.enable.link.remove();
    output.destroy.link.remove();

    server.output_layout.remove(output.wlr_output);
}

fn frame(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
    const output = @fieldParentPtr(Output, "frame", listener);

    const scene_output = server.scene.getSceneOutput(output.wlr_output).?;
    _ = scene_output.commit();

    var now: os.timespec = undefined;
    os.clock_gettime(os.CLOCK.MONOTONIC, &now) catch @panic("CLOCK_MONOTONIC not supported");
    scene_output.sendFrameDone(&now);
}

fn enable(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
    const output = @fieldParentPtr(Output, "enable", listener);
    server.output_layout.addAuto(output.wlr_output);
}

fn destroy(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
    const output = @fieldParentPtr(Output, "destroy", listener);
    output.deinit();
    gpa.destroy(output);
}
