const std = @import("std");

/// Maximum tool output length before truncation
const MAX_TOOL_OUTPUT_CHARS: usize = 100_000;

/// Check if character is valid in a secret token
fn isSecretChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == ':';
}

/// Find the end of a token starting from `from`
fn tokenEnd(input: []const u8, from: usize) usize {
    var end = from;
    for (input[from..]) |c| {
        if (isSecretChar(c)) {
            end += 1;
        } else {
            break;
        }
    }
    return end;
}

/// Scrub known secret-like token prefixes from text.
/// Redacts tokens with prefixes like `sk-`, `xoxb-`, `ghp_`, etc.
pub fn scrubSecretPatterns(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const prefixes = [_][]const u8{
        "sk-",    "xoxb-",  "xoxp-",  "ghp_",
        "gho_",   "ghs_",   "ghu_",   "glpat-",
        "AKIA",   "pypi-",  "npm_",   "shpat_",
        "AIza",   // Google API keys
    };
    const redacted = "[REDACTED]";

    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        // 1. Check key-value patterns: api_key=VALUE, token=VALUE, etc.
        if (matchKeyValueSecret(input, i)) |kv| {
            // Keep key + separator, redact the value (show first 4 chars)
            try result.appendSlice(allocator, input[i..kv.value_start]);
            const val = input[kv.value_start..kv.value_end];
            if (val.len > 4) {
                try result.appendSlice(allocator, val[0..4]);
            }
            try result.appendSlice(allocator, redacted);
            i = kv.value_end;
            continue;
        }

        // 2. Check "bearer TOKEN" (case-insensitive)
        if (matchBearerToken(input, i)) |bt| {
            try result.appendSlice(allocator, input[i .. i + bt.prefix_len]);
            const val = input[i + bt.prefix_len .. bt.end];
            if (val.len > 4) {
                try result.appendSlice(allocator, val[0..4]);
            }
            try result.appendSlice(allocator, redacted);
            i = bt.end;
            continue;
        }

        // 3. Check prefix-based tokens
        var matched = false;
        for (prefixes) |prefix| {
            if (i + prefix.len <= input.len and std.mem.eql(u8, input[i..][0..prefix.len], prefix)) {
                const content_start = i + prefix.len;
                const end = tokenEnd(input, content_start);
                if (end > content_start) {
                    try result.appendSlice(allocator, redacted);
                    i = end;
                    matched = true;
                    break;
                }
            }
        }
        if (!matched) {
            try result.append(allocator, input[i]);
            i += 1;
        }
    }

    return try result.toOwnedSlice(allocator);
}

const KeyValueMatch = struct { value_start: usize, value_end: usize };

/// Match patterns like `api_key=VALUE`, `token=VALUE`, `password: VALUE`, `secret=VALUE`.
fn matchKeyValueSecret(input: []const u8, pos: usize) ?KeyValueMatch {
    const keywords = [_][]const u8{
        "api_key",    "api-key",    "apikey",
        "token",      "password",   "passwd",
        "secret",     "api_secret", "access_key",
    };
    for (keywords) |kw| {
        if (pos + kw.len >= input.len) continue;
        if (!eqlLowercase(input[pos..][0..kw.len], kw)) continue;
        // Check separator after keyword: `=`, `:`, `= `, `: `
        var sep_end = pos + kw.len;
        if (sep_end < input.len and (input[sep_end] == '=' or input[sep_end] == ':')) {
            sep_end += 1;
            // Skip optional space after separator
            while (sep_end < input.len and input[sep_end] == ' ') sep_end += 1;
            // Skip optional quotes
            var quote: u8 = 0;
            if (sep_end < input.len and (input[sep_end] == '"' or input[sep_end] == '\'')) {
                quote = input[sep_end];
                sep_end += 1;
            }
            const value_start = sep_end;
            var value_end = value_start;
            if (quote != 0) {
                // Read until closing quote
                while (value_end < input.len and input[value_end] != quote) value_end += 1;
                if (value_end < input.len) value_end += 1; // skip closing quote
            } else {
                value_end = tokenEnd(input, value_start);
            }
            if (value_end > value_start) {
                return .{ .value_start = value_start, .value_end = value_end };
            }
        }
    }
    return null;
}

const BearerMatch = struct { prefix_len: usize, end: usize };

/// Match "Bearer TOKEN" or "bearer TOKEN" pattern.
fn matchBearerToken(input: []const u8, pos: usize) ?BearerMatch {
    const bearer_variants = [_][]const u8{ "Bearer ", "bearer ", "BEARER " };
    for (bearer_variants) |prefix| {
        if (pos + prefix.len <= input.len and std.mem.eql(u8, input[pos..][0..prefix.len], prefix)) {
            const token_start = pos + prefix.len;
            const end = tokenEnd(input, token_start);
            if (end > token_start) {
                return .{ .prefix_len = prefix.len, .end = end };
            }
        }
    }
    return null;
}

/// Case-insensitive comparison (input can be mixed case, kw is lowercase).
fn eqlLowercase(input: []const u8, kw: []const u8) bool {
    if (input.len != kw.len) return false;
    for (input, kw) |a, b| {
        if (std.ascii.toLower(a) != b) return false;
    }
    return true;
}

/// Preview UTF-8 string up to max_chars, ensuring we don't cut in the middle of a multi-byte character
fn previewUtf8(input: []const u8, max_chars: usize) struct { slice: []const u8, truncated: bool } {
    if (input.len <= max_chars) {
        return .{ .slice = input, .truncated = false };
    }

    // Find the last valid UTF-8 boundary before max_chars
    var end = max_chars;
    while (end > 0 and end < input.len) {
        // Check if this is a valid UTF-8 start or ASCII
        if (input[end] & 0x80 == 0 or input[end] & 0xC0 == 0xC0) {
            break;
        }
        end -= 1;
    }

    return .{ .slice = input[0..end], .truncated = true };
}

/// Scrub credentials from tool execution output and truncate if too long.
/// Returns an owned slice. Caller must free.
pub fn scrubToolOutput(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    // First truncate if too long
    const preview = previewUtf8(input, MAX_TOOL_OUTPUT_CHARS);
    const truncated = if (preview.truncated) blk: {
        const suffix = "\n[output truncated]";
        var buf = try allocator.alloc(u8, preview.slice.len + suffix.len);
        @memcpy(buf[0..preview.slice.len], preview.slice);
        @memcpy(buf[preview.slice.len..], suffix);
        break :blk buf;
    } else try allocator.dupe(u8, input);
    defer allocator.free(truncated);

    // Then scrub secrets
    return scrubSecretPatterns(allocator, truncated);
}

// ════════════════════════════════════════════════════════════════════════════
// Tests
// ════════════════════════════════════════════════════════════════════════════

test "scrubSecretPatterns redacts sk- tokens" {
    const allocator = std.testing.allocator;
    const result = try scrubSecretPatterns(allocator, "request failed: sk-1234567890abcdef");
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "sk-1234567890abcdef") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "[REDACTED]") != null);
}

test "scrubSecretPatterns handles multiple prefixes" {
    const allocator = std.testing.allocator;
    const result = try scrubSecretPatterns(allocator, "keys sk-abcdef xoxb-12345 xoxp-67890");
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "sk-abcdef") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "xoxb-12345") == null);
    try std.testing.expect(std.mem.indexOf(u8, result, "xoxp-67890") == null);
}

test "scrubSecretPatterns keeps bare prefix" {
    const allocator = std.testing.allocator;
    const result = try scrubSecretPatterns(allocator, "only prefix sk- present");
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "sk-") != null);
}

test "scrubSecretPatterns redacts api_key=VALUE pattern" {
    const allocator = std.testing.allocator;
    const result = try scrubSecretPatterns(allocator, "config: api_key=sk_live_1234567890abcdef");
    defer allocator.free(result);
    // Should keep key name and first 4 chars of value
    try std.testing.expect(std.mem.indexOf(u8, result, "api_key=") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "sk_l") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "[REDACTED]") != null);
    // Full value should not be present
    try std.testing.expect(std.mem.indexOf(u8, result, "sk_live_1234567890abcdef") == null);
}

test "scrubSecretPatterns redacts Bearer TOKEN pattern" {
    const allocator = std.testing.allocator;
    const result = try scrubSecretPatterns(allocator, "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret");
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Bearer ") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "[REDACTED]") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret") == null);
}

test "scrubSecretPatterns no false positives on normal text" {
    const allocator = std.testing.allocator;
    const result = try scrubSecretPatterns(allocator, "the password policy requires 8 chars. See token docs.");
    defer allocator.free(result);
    // "password" and "token" without separator should not trigger redaction
    try std.testing.expect(std.mem.indexOf(u8, result, "[REDACTED]") == null);
}

test "scrubToolOutput truncates long output" {
    const allocator = std.testing.allocator;
    const long = try allocator.alloc(u8, 110_000);
    defer allocator.free(long);
    @memset(long, 'x');
    const result = try scrubToolOutput(allocator, long);
    defer allocator.free(result);
    try std.testing.expect(result.len < 110_000);
    try std.testing.expect(std.mem.endsWith(u8, result, "[output truncated]"));
}

test "scrubToolOutput keeps UTF-8 intact when truncating" {
    const allocator = std.testing.allocator;
    const prefix = "x" ** (MAX_TOOL_OUTPUT_CHARS - 1);
    const result = try scrubToolOutput(allocator, prefix ++ "\xd0\x99tail");
    defer allocator.free(result);

    try std.testing.expect(std.unicode.utf8ValidateSlice(result));
    try std.testing.expect(std.mem.endsWith(u8, result, "[output truncated]"));
    try std.testing.expect(std.mem.indexOf(u8, result, "\xd0\x99tail") == null);
}

test "scrubToolOutput passes through clean short output" {
    const allocator = std.testing.allocator;
    const result = try scrubToolOutput(allocator, "ls output: file1.txt file2.txt");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("ls output: file1.txt file2.txt", result);
}

test "eqlLowercase matches case-insensitively" {
    try std.testing.expect(eqlLowercase("API_KEY", "api_key"));
    try std.testing.expect(eqlLowercase("api_key", "api_key"));
    try std.testing.expect(eqlLowercase("Api_Key", "api_key"));
    try std.testing.expect(!eqlLowercase("api_keys", "api_key"));
}
