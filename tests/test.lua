#!/usr/bin/env luajit
local ffi = require 'ffi'
require 'ext'

--[[
do
	local vec3f = require 'vec-ffi.vec3f'
	assert.eq(ffi.sizeof'vec3x3f', 3*3*4)

	local x = vec3f(10,11,12)
	print(x)
	print(assert.eq(x * x, 10^2 + 11^2 + 12^2))

	local vec3x3f = require 'vec-ffi.vec3x3f'
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
end
--]]

do
	local vec4f = require 'vec-ffi.vec4f'
	local vec4x4f = require 'vec-ffi.vec4x4f'
	local A = vec4x4f()
	assert.eq(ffi.sizeof(vec4x4f), 4*4*ffi.sizeof'float')
	for i=0,3 do
		for j=0,3 do
			A.s[i].s[j] = j + 4 * i	-- row-major memory layout indexing
		end
	end
	print(A)
	-- assert row-major
	for i=0,15 do
		assert.eq(A.ptr[i], i)
	end

	-- make sure __mul matches mul matches mul4x4 matches mul4x4v4

	local x = vec4f(5,6,7,8)
	print(x)

	-- __mul
	local y = A * x
	assert.eq(y.x, A.x.x*x.x + A.x.y*x.y + A.x.z*x.z + A.x.w*x.w)
	assert.eq(y.y, A.y.x*x.x + A.y.y*x.y + A.y.z*x.z + A.y.w*x.w)
	assert.eq(y.z, A.z.x*x.x + A.z.y*x.y + A.z.z*x.z + A.z.w*x.w)
	assert.eq(y.w, A.w.x*x.x + A.w.y*x.y + A.w.z*x.z + A.w.w*x.w)

	-- mul4x4v4
	local y0,y1,y2,y3 = A:mul4x4v4(x:unpack())
	assert.eq(y0, A.x.x*x.x + A.x.y*x.y + A.x.z*x.z + A.x.w*x.w)
	assert.eq(y1, A.y.x*x.x + A.y.y*x.y + A.y.z*x.z + A.y.w*x.w)
	assert.eq(y2, A.z.x*x.x + A.z.y*x.y + A.z.z*x.z + A.z.w*x.w)
	assert.eq(y3, A.w.x*x.x + A.w.y*x.y + A.w.z*x.z + A.w.w*x.w)

	-- mul4x4
	local B = vec4x4f()
	-- set 1st col
	B.x.x = x.x
	B.y.x = x.y
	B.z.x = x.z
	B.w.x = x.w
	local C = vec4x4f():mul(A,B)
	-- verify 1st col is transformed
	assert.eq(C.x.x, A.x.x*x.x + A.x.y*x.y + A.x.z*x.z + A.x.w*x.w)
	assert.eq(C.y.x, A.y.x*x.x + A.y.y*x.y + A.y.z*x.z + A.y.w*x.w)
	assert.eq(C.z.x, A.z.x*x.x + A.z.y*x.y + A.z.z*x.z + A.z.w*x.w)
	assert.eq(C.w.x, A.w.x*x.x + A.w.y*x.y + A.w.z*x.z + A.w.w*x.w)
end


require 'vec-ffi'
assert.eq(ffi.sizeof'vec3b', 3)

print'done'
