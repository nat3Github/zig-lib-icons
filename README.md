# TVG Icons Ready to use in Zig

- iconst are mostly in svg
- sometimes you need them in tvg (tiny vector graphics https://github.com/TinyVG/sdk)
- this lib provides the converted tvg files
- each tvg icon is embedded via @embedFile(...)
- use like: feather.@"icon-name"

# status of this library

- zig 0.14.0
- feather icon conversion looks horrible, unusable, waiting for better converter
- heroicons and lucid look quite ok

## icon libraries included:

- feather icons https://github.com/feathericons/feather
- lucide [https://github.com/feathericons/feather](https://github.com/lucide-icons/lucide)
- heroicons https://github.com/tailwindlabs/heroicons

# Licensing

- this library: MIT
- feather: MIT
- lucide: ISC
- heroicons: MIT

# Contribution

- there is a automated shell script to convert and generate zig code
- modify it to generate the new files, modify root.zig
- i will only accept icon libraries licensed similar to MIT
