#!/usr/bin/env luajit
local ffi = require 'ffi'
require 'ext'
require 'vec-ffi'
assert.eq(ffi.sizeof'vec3b_t', 3)

local vec3x3f = require 'vec-ffi.create_vec3'{
	ctype = 'vec3f_t',
}

local x = vec3f(10,11,12)
print(x)
print(assert.eq(x * x, 10^2 + 11^2 + 12^2))

local A = vec3x3f({1,2,3}, {4,5,6}, {7,8,9})
print(A)

local y = A * x
print(y)
assert.eq(y.x, A.x.x*x.x + A.x.y*x.y + A.x.z*x.z)
assert.eq(y.y, A.y.x*x.x + A.y.y*x.y + A.y.z*x.z)
assert.eq(y.z, A.z.x*x.x + A.z.y*x.y + A.z.z*x.z)

local y = x * A
print(y)
assert.eq(y.x, A.x.x*x.x + A.y.x*x.y + A.z.x*x.z)
assert.eq(y.y, A.x.y*x.x + A.y.y*x.y + A.z.y*x.z)
assert.eq(y.z, A.x.z*x.x + A.y.z*x.y + A.z.z*x.z)

print'done'
