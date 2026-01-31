[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

# Vector Class for LuaJIT

2D, 3D, 4D vectors of primitive types.

2x2-4x4 matrices.

Quaternions.

Bounding Boxes.

Planes.

### Dependencies:

- https://github.com/thenumbernine/lua-ext
- https://github.com/thenumbernine/struct-lua
- https://github.com/thenumbernine/lua-template

### TODO's

- overhaul, change the typename to `<prim><n>` instead of `vec<n><suffix>`
- remove the `_t` from the C names, so the Lua and C names match
- making typenames optional would be nice, and using `ffi.typeof(typedef)`, but becomes a problem with caching types and with recreating duplicate types unnecessarily...
