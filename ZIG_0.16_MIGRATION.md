# Zig 0.16 API Migration Guide

## Key API Changes

### 1. std.io → std.Io
- **Old**: `std.io.fixedBufferStream(&buf)`
- **New**: Use `std.Io.Writer.Allocating` for dynamic buffers in tests
  ```zig
  var aw = std.Io.Writer.Allocating.init(allocator);
  defer aw.deinit();
  try aw.writer.writeAll("data");
  const result = aw.writer.buffered();
  ```

### 2. std.time.milliTimestamp() → Removed
- **Old**: `std.time.milliTimestamp()`
- **New**: Use `std.time.epoch` for epoch calculations, or pass `std.Io` for runtime timestamps
  ```zig
  // For tests with known timestamps:
  const secs = std.time.epoch.EpochSeconds{ .secs = unix_seconds };
  
  // For runtime (requires std.Io instance):
  const timestamp = io.vtable.now(io.userdata, .realtime);
  ```

### 3. std.process.getEnvVarOwned() → std.process.Environ
- **Old**: `std.process.getEnvVarOwned(allocator, "KEY")`
- **New**: 
  ```zig
  const env_block = std.process.Environ{ .block = .global };
  const value = try env_block.getAlloc(allocator, "KEY");
  ```

### 4. std.mem.trimLeft() → std.mem.trimStart()
- **Old**: `std.mem.trimLeft(u8, str, " ")`
- **New**: `std.mem.trimStart(u8, str, " ")`

### 5. std.crypto.random → std.Random
- **Old**: `std.crypto.random.bytes(&buf)`
- **New**: 
  ```zig
  var prng = std.Random.DefaultPrng.init(seed);
  const random = prng.random();
  random.bytes(&buf);
  ```

### 6. std.process.Child.init() → Direct struct initialization
- **Old**: `var child = std.process.Child.init(argv, allocator);`
- **New**: Use `std.process.spawn()` with `SpawnOptions`
  ```zig
  const child = try std.process.spawn(io, allocator, .{
      .argv = argv,
      .stdin = .inherit,
      .stdout = .pipe,
      .stderr = .ignore,
  });
  ```

### 7. std.fs.cwd() → std.Io.Dir.cwd()
- **Old**: `std.fs.cwd()`
- **New**: `std.Io.Dir.cwd()` (requires `std.Io` instance)

### 8. std.fs.File → std.Io.File
- **Old**: `std.fs.File`
- **New**: `std.Io.File`

### 9. std.ArrayList.init() → Direct initialization
- **Old**: `std.ArrayList(T).init(allocator)`
- **New**: Same, but check if context requires different pattern

## Migration Strategy

1. Replace all `std.io.fixedBufferStream` with `std.Io.Writer.Allocating`
2. Replace `std.time.milliTimestamp()` with epoch calculations
3. Replace `std.process.getEnvVarOwned` with `Environ.getAlloc`
4. Replace `std.mem.trimLeft` with `std.mem.trimStart`
5. Replace `std.crypto.random` with `std.Random`
6. Update `std.process.Child` usage to use `spawn()`
7. Replace `std.fs.cwd()` with `std.Io.Dir.cwd()`
8. Replace `std.fs.File` with `std.Io.File`
