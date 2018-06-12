# Zig utils

Some [Zig](https://github.com/ziglang/zig) functions, nothing finished or polished.

## Usage

* To build: `zig build`
* To run tests: `zig build test`

## Contents

### FileInStream
Like the FileInStream from std, but also implements `Seekable`.

### InflateInStream
Decompresses data from a source `InStream`, using an `Inflater`. Implements `InStream`.

### Inflater
Wrapper around zlib's inflate routines. Requires zlib.

### LineReader
Replacement for `read_line` from std. The line is written to an `OutStream`. If writing fails partway (e.g. OutStream is full), it will still consume and discard the rest of the line.

### ScanZip
Locates a file in a zip archive (provided via source `InStream`+`Seekable`). Returns offset and size of the file. See also ZipTest.zig, which uses ScanZip to find a file in an archive, then InflateInStream to load it.

### Seekable
Trait interface with the following methods: seekForward, seekTo, getPos, getEndPos.

### MemoryInStream
Reads data from an in-memory byte slice. Implements `InStream` and `Seekable`.

### MemoryOutStream
Writes data to a provided byte slice. Implements `OutStream`.
