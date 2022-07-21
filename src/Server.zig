const Server = @This();
const Output = @import("Output.zig");

const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");
// const xkb = @import("xkbcommon");

const gpa = @import("main.zig").gpa;

wl_server: *wl.Server,
backend: *wlr.Backend,
renderer: *wlr.Renderer,
allocator: *wlr.Allocator,
scene: *wlr.Scene,

output_layout: *wlr.OutputLayout,
new_output: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(newOutput),

xdg_shell: *wlr.XdgShell,
new_xdg_surface: wl.Listener(*wlr.XdgSurface) = wl.Listener(*wlr.XdgSurface).init(newXdgSurface),

xdg_decoration_manager: *wlr.XdgDecorationManagerV1,
new_toplevel_decoration: wl.Listener(*wlr.XdgToplevelDecorationV1) = wl.Listener(*wlr.XdgToplevelDecorationV1).init(newToplevelDecoration),

pub fn init(server: *Server) !void {
    const wl_server = try wl.Server.create();
    const backend = try wlr.Backend.autocreate(wl_server);
    const renderer = try wlr.Renderer.autocreate(backend);

    server.* = .{
        .wl_server = wl_server,
        .backend = backend,
        .renderer = renderer,
        .allocator = try wlr.Allocator.autocreate(backend, renderer),
        .scene = try wlr.Scene.create(),

        .output_layout = try wlr.OutputLayout.create(),
        .xdg_shell = try wlr.XdgShell.create(wl_server),

        .xdg_decoration_manager = try wlr.XdgDecorationManagerV1.create(wl_server),
    };

    const kde_manager = try wlr.KdeServerDecorationManager.create(wl_server);
    kde_manager.setDefaultMode(.server);

    try server.renderer.initServer(wl_server);
    try server.scene.attachOutputLayout(server.output_layout);

    _ = try wlr.Compositor.create(server.wl_server, server.renderer);
    _ = try wlr.DataDeviceManager.create(server.wl_server);

    server.backend.events.new_output.add(&server.new_output);
    server.xdg_shell.events.new_surface.add(&server.new_xdg_surface);
    server.xdg_decoration_manager.events.new_toplevel_decoration.add(&server.new_toplevel_decoration);
}

pub fn deinit(server: *Server) void {
    server.wl_server.destroyClients();
    server.wl_server.destroy();
}

fn newOutput(listener: *wl.Listener(*wlr.Output), wlr_output: *wlr.Output) void {
    const server = @fieldParentPtr(Server, "new_output", listener);

    const output = gpa.create(Output) catch {
        std.log.err("failed to allocate new output", .{});
        return;
    };

    output.init(wlr_output) catch {
        std.log.err("failed to initialize new output", .{});
        return;
    };

    if (wlr_output.enabled) server.output_layout.addAuto(wlr_output);
}

fn newXdgSurface(listener: *wl.Listener(*wlr.XdgSurface), surface: *wlr.XdgSurface) void {
    const server = @fieldParentPtr(Server, "new_xdg_surface", listener);

    switch (surface.role) {
        .toplevel => {
            const scene_node = server.scene.node.createSceneXdgSurface(surface) catch {
                std.log.err("failed to allocate xdg toplevel node", .{});
                return;
            };
            surface.data = @ptrToInt(scene_node);
        },
        .popup => {
            const parent = wlr.XdgSurface.fromWlrSurface(surface.role_data.popup.parent.?).?;
            const parent_node = @intToPtr(?*wlr.SceneNode, parent.data) orelse {
                return;
            };
            const scene_node = parent_node.createSceneXdgSurface(surface) catch {
                std.log.err("failed to allocate xdg popup node", .{});
                return;
            };
            surface.data = @ptrToInt(scene_node);
        },
        .none => unreachable,
    }
}

fn newToplevelDecoration(_: *wl.Listener(*wlr.XdgToplevelDecorationV1), decoration: *wlr.XdgToplevelDecorationV1) void {
    _ = decoration.setMode(.server_side);
}
