# Zig utils

Some [Zig](https://github.com/ziglang/zig) functions, nothing finished or polished.

## Usage

* To build: `zig build`
* To run tests: `zig build test`

## Contents

### ArrayListOutStream
Writes data to a provided ArrayList(u8). Implements `OutStream`. Basically an inefficient example of an OutStream that doesn't have to worry about buffer sizes.

### FileInStream
Like the FileInStream from std, but also implements `Seekable`.

### LoadTga
Load a TGA image from a source `InStream`. So far supports loading 16, 24 and 32 bit images, compressed or uncompressed. Not supported yet: greyscale and colormapped images.

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

### WritePpm
Save an image in the very simple PPM format (useful for tests).

## Ideas
An instream method that reads, matching a provided byte slice. "If I read from the instream does it contain this exact string?"
