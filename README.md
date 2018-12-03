# Zig utils
[![Build Status](https://travis-ci.org/dbandstra/zigutils.svg?branch=master)](https://travis-ci.org/dbandstra/zigutils)

Some [Zig](https://github.com/ziglang/zig) functions, nothing finished or polished. (Things that become stable and useful will probably be moved out of this repo.)

## Usage

* To build: `zig build`
* To run tests: `zig build test`

## Contents

### ArrayListOutStream
Writes data to a provided ArrayList(u8). Implements `OutStream`. Basically an inefficient example of an OutStream that doesn't have to worry about buffer sizes.

### LoadTga
Load a TGA image from a source `InStream`. So far supports loading 16, 24 and 32 bit images, compressed or uncompressed. Not supported yet: greyscale and colormapped images.

### InflateInStream
Decompresses data from a source `InStream`, using an `Inflater`. Implements `InStream`.

### Inflater
Wrapper around zlib's inflate routines. Requires zlib.

### LineReader
Replacement for `read_line` from std. The line is written to an `OutStream`. If writing fails partway (e.g. OutStream is full), it will still consume and discard the rest of the line.

### ScanZip
Iterate through files in a zip archive (provided via source `InStream`+`Seekable`). Returns offset and size of files. See ZipTest.zig, which uses ScanZip to find a file in an archive, then InflateInStream to load it.

### WritePpm
Save an image in the very simple PPM format (useful for tests).

## Ideas
An instream method that reads, matching a provided byte slice. "If I read from the instream does it contain this exact string?"
