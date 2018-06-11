# Zig utils

Some [Zig](https://github.com/ziglang/zig) functions, nothing finished or polished.

## ArrayListOutStream
Writes data to a provided ArrayList(u8). Implements `OutStream`. Basically an inefficient example of an OutStream that doesn't have to worry about buffer sizes.

## FileInStream
Like the FileInStream from std, but also implements `Seekable`.

## InflateInStream
Decompresses data from a source `InStream`. Implements `InStream`. Requires zlib.

## LineReader
Replacement for `read_line` from std. The line is written to an `OutStream`. If writing fails partway (e.g. OutStream is full), it will still consume and discard the rest of the line.

## ScanZip
Locates a file in a zip archive (provided via source `InStream`). Returns offset and size of the file. See also ZipTest.zig, which uses ScanZip to find a file in an archive, then InflateInStream to load it.

## Seekable
Trait interface with the following methods: seekForward, seekTo, getPos, getEndPos.

## SimpleInStream
Reads data from an in-memory byte slice. Implements `InStream` and `Seekable`.

## SimpleOutStream
Writes data to a provided byte slice. Implements `OutStream`.
