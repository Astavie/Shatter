const wl_server = @import("wayland").server;
const wl = wl_server.wl;
const wlr = @import("wlroots");

const kde = .{
    .DecorationManager = wl_server.org.KdeKwinServerDecorationManager,
    .Decoration = wl_server.org.KdeKwinServerDecoration,
};

const gpa = @import("main.zig").gpa;

const std = @import("std");

pub const KdeDecorationManager = struct {
    global: *wl.Global,
    server_destroy: wl.Listener(*wl.Server) = wl.Listener(*wl.Server).init(serverDestroy),

    pub fn init(manager: *KdeDecorationManager, server: *wl.Server) !void {
        manager.global = try wl.Global.create(
            server,
            kde.DecorationManager,
            1,
            *KdeDecorationManager,
            manager,
            bind,
        );

        server.addDestroyListener(&manager.server_destroy);
    }

    pub fn deinit(manager: *KdeDecorationManager) void {
        manager.server_destroy.link.remove();
        manager.global.destroy();
    }

    fn bind(client: *wl.Client, manager: *KdeDecorationManager, version: u32, id: u32) callconv(.C) void {
        const kde_manager = kde.DecorationManager.create(client, version, id) catch {
            std.log.err("failed to allocate kde decoration manager", .{});
            return;
        };
        kde_manager.setHandler(*KdeDecorationManager, request, null, manager);
        kde_manager.sendDefaultMode(@enumToInt(kde.Decoration.Mode.Server));
    }

    fn request(kde_manager: *kde.DecorationManager, req: kde.DecorationManager.Request, _: *KdeDecorationManager) void {
        switch (req) {
            .create => |value| {
                const surface = wlr.Surface.fromWlSurface(value.surface);
                const client = kde_manager.getClient();
                const version = kde_manager.getVersion();

                var decoration = gpa.create(KdeDecoration) catch {
                    std.log.err("failed to allocate kde decoration", .{});
                    return;
                };
                decoration.init(surface, client, version, value.id) catch {
                    gpa.destroy(decoration);

                    std.log.err("failed to allocate kde decoration", .{});
                    return;
                };
            },
        }
    }

    fn serverDestroy(listener: wl.Listener(*wl.Server), _: *wl.Server) void {
        const manager = @fieldParentPtr(KdeDecorationManager, "server_destroy", listener);
        manager.deinit();
    }
};

pub const KdeDecoration = struct {
    mode: kde.Decoration.Mode,

    surface_destroy: wl.Listener(*wlr.Surface) = wl.Listener(*wlr.Surface).init(surfaceDestroy),

    pub fn init(decoration: *KdeDecoration, surface: *wlr.Surface, client: *wl.Client, version: u32, id: u32) !void {
        decoration.mode = .Server;

        const kde_decoration = try kde.Decoration.create(client, version, id);
        kde_decoration.setHandler(*KdeDecoration, request, destroy, decoration);

        surface.events.destroy.add(&decoration.surface_destroy);

        kde_decoration.sendMode(@intCast(u32, @enumToInt(decoration.mode)));
    }

    pub fn deinit(decoration: *KdeDecoration) void {
        decoration.surface_destroy.link.remove();
    }

    fn request(kde_decoration: *kde.Decoration, req: kde.Decoration.Request, decoration: *KdeDecoration) void {
        switch (req) {
            .release => {
                kde_decoration.destroy();
            },
            .request_mode => |value| {
                const mode = @intToEnum(kde.Decoration.Mode, value.mode);
                if (decoration.mode == mode) return; // prevent feedback loop

                decoration.mode = mode;
                kde_decoration.sendMode(value.mode);
            },
        }
    }

    fn destroy(_: *kde.Decoration, decoration: *KdeDecoration) void {
        decoration.deinit();
        gpa.destroy(decoration);
    }

    fn surfaceDestroy(listener: *wl.Listener(*wlr.Surface), _: *wlr.Surface) void {
        const decoration = @fieldParentPtr(KdeDecoration, "surface_destroy", listener);
        decoration.deinit();
        gpa.destroy(decoration);
    }
};
