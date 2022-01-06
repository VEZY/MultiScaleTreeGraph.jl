"""
    cache_name(vars...)

Make a unique name based on the vars names.

# Examples

```julia
cache_name("test","var")
```
"""
function cache_name(vars...)
    "_cache_" * bytes2hex(sha1(join([vars...])))
end
