# Shatter

| :exclamation: This wayland compositor is still in active development and will lack a lot of features expected from one.<br>Most importantly, keyboard/mouse input does not work yet. |
|-|

## Building

This repository ships with a few build dependencies that also need to be cloned. This can be done with e.g.

```
git submodule update --init
```

Before building, make sure the following dependencies are installed:

- zig 0.9
- wayland
- wayland-protocols
- wlroots 0.15
- xkbcommon
- pixman
- pkg-config

Shatter can then be compiled using, for example:

```
zig build -Drelease-safe
```

The output can then be found and run in `./zig-out/bin/`

## Usage

Shatter can be run directly from a tty or nested within an existing X11/Wayland session. Simply run the `shatter` executable.

A startup program can be specified by adding it as an argument. For example, `shatter "wlclock"` will run wlclock within the compositor. Any shell command can be put within the quotation marks.
