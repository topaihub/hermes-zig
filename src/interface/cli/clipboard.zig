const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub fn saveClipboardImage(allocator: Allocator, dest: []const u8) !bool {
    const argv: []const []const u8 = switch (builtin.os.tag) {
        .macos => &.{ "pngpaste", dest },
        .linux => &.{ "xclip", "-selection", "clipboard", "-t", "image/png", "-o" },
        .windows => &.{ "powershell", "-c", "Get-Clipboard -Format Image | ForEach-Object { $_.Save('" ++ dest ++ "') }" },
        else => return false,
    };

    var child = std.process.Child.init(argv, allocator);
    child.stderr_behavior = .Ignore;
    if (builtin.os.tag == .linux) {
        child.stdout_behavior = .Pipe;
    }
    _ = child.spawnAndWait() catch return false;

    if (builtin.os.tag == .linux) {
        // For linux, xclip outputs to stdout; write to dest file
        if (child.stdout) |out| {
            const data = out.reader().readAllAlloc(allocator, 10 * 1024 * 1024) catch return false;
            defer allocator.free(data);
            if (data.len == 0) return false;
            var f = std.fs.cwd().createFile(dest, .{}) catch return false;
            defer f.close();
            f.writeAll(data) catch return false;
        }
    }
    return true;
}

test "saveClipboardImage compiles" {
    _ = &saveClipboardImage;
}
