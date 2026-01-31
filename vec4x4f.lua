require 'vec-ffi.vec4f'

-- TODO I'm going to need a create_mat next ...
return require 'vec-ffi.create_vec'{
	dim = 4,
	ctype = 'vec4f_t',

	classCode = [=[

local assert = require 'ext.assert'

function cl:copy(src)
--DEBUG:assert.eq(ffi.typeof(self), ffi.typeof(src))	-- this will false fail if I'm comparing T& with T ...  TODO removecv<>
	ffi.copy(self.s, src.s, ffi.sizeof(self))
	return self
end

function cl:clone()
	return metatype(self)
end

-- optimized ... default mul of arbitrary-rank inner-product is verrrry slow
function cl:mul4x4(a,b)
	local aptr = a.ptr
	local bptr = b.ptr
	local selfptr = self.ptr

--DEBUG:assert.eq(self.rank, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--[[ no temp vars ... any perf diff?
	-- also assert self isn't the table a or b, or else this will mess up
	selfptr[0] = aptr[0] * bptr[0] + aptr[4] * bptr[1] + aptr[8] * bptr[2] + aptr[12] * bptr[3]
	selfptr[4] = aptr[0] * bptr[4] + aptr[4] * bptr[5] + aptr[8] * bptr[6] + aptr[12] * bptr[7]
	selfptr[8] = aptr[0] * bptr[8] + aptr[4] * bptr[9] + aptr[8] * bptr[10] + aptr[12] * bptr[11]
	selfptr[12] = aptr[0] * bptr[12] + aptr[4] * bptr[13] + aptr[8] * bptr[14] + aptr[12] * bptr[15]
	selfptr[1] = aptr[1] * bptr[0] + aptr[5] * bptr[1] + aptr[9] * bptr[2] + aptr[13] * bptr[3]
	selfptr[5] = aptr[1] * bptr[4] + aptr[5] * bptr[5] + aptr[9] * bptr[6] + aptr[13] * bptr[7]
	selfptr[9] = aptr[1] * bptr[8] + aptr[5] * bptr[9] + aptr[9] * bptr[10] + aptr[13] * bptr[11]
	selfptr[13] = aptr[1] * bptr[12] + aptr[5] * bptr[13] + aptr[9] * bptr[14] + aptr[13] * bptr[15]
	selfptr[2] = aptr[2] * bptr[0] + aptr[6] * bptr[1] + aptr[10] * bptr[2] + aptr[14] * bptr[3]
	selfptr[6] = aptr[2] * bptr[4] + aptr[6] * bptr[5] + aptr[10] * bptr[6] + aptr[14] * bptr[7]
	selfptr[10] = aptr[2] * bptr[8] + aptr[6] * bptr[9] + aptr[10] * bptr[10] + aptr[14] * bptr[11]
	selfptr[14] = aptr[2] * bptr[12] + aptr[6] * bptr[13] + aptr[10] * bptr[14] + aptr[14] * bptr[15]
	selfptr[3] = aptr[3] * bptr[0] + aptr[7] * bptr[1] + aptr[11] * bptr[2] + aptr[15] * bptr[3]
	selfptr[7] = aptr[3] * bptr[4] + aptr[7] * bptr[5] + aptr[11] * bptr[6] + aptr[15] * bptr[7]
	selfptr[11] = aptr[3] * bptr[8] + aptr[7] * bptr[9] + aptr[11] * bptr[10] + aptr[15] * bptr[11]
	selfptr[15] = aptr[3] * bptr[12] + aptr[7] * bptr[13] + aptr[11] * bptr[14] + aptr[15] * bptr[15]
--]]
-- [[
	local a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15 = aptr[0], aptr[1], aptr[2], aptr[3], aptr[4], aptr[5], aptr[6], aptr[7], aptr[8], aptr[9], aptr[10], aptr[11], aptr[12], aptr[13], aptr[14], aptr[15]
	local b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15 = bptr[0], bptr[1], bptr[2], bptr[3], bptr[4], bptr[5], bptr[6], bptr[7], bptr[8], bptr[9], bptr[10], bptr[11], bptr[12], bptr[13], bptr[14], bptr[15]
	selfptr[0]		=	a0  * b0  + a4  * b1  + a8  * b2  + a12 * b3
	selfptr[4]		=	a0  * b4  + a4  * b5  + a8  * b6  + a12 * b7
	selfptr[8]		=	a0  * b8  + a4  * b9  + a8  * b10 + a12 * b11
	selfptr[12]	=	a0  * b12 + a4  * b13 + a8  * b14 + a12 * b15
	selfptr[1]		=	a1  * b0  + a5  * b1  + a9  * b2  + a13 * b3
	selfptr[5]		=	a1  * b4  + a5  * b5  + a9  * b6  + a13 * b7
	selfptr[9]		=	a1  * b8  + a5  * b9  + a9  * b10 + a13 * b11
	selfptr[13]	=	a1  * b12 + a5  * b13 + a9  * b14 + a13 * b15
	selfptr[2]		=	a2  * b0  + a6  * b1  + a10 * b2  + a14 * b3
	selfptr[6]		=	a2  * b4  + a6  * b5  + a10 * b6  + a14 * b7
	selfptr[10]	=	a2  * b8  + a6  * b9  + a10 * b10 + a14 * b11
	selfptr[14]	=	a2  * b12 + a6  * b13 + a10 * b14 + a14 * b15
	selfptr[3]		=	a3  * b0  + a7  * b1  + a11 * b2  + a15 * b3
	selfptr[7]		=	a3  * b4  + a7  * b5  + a11 * b6  + a15 * b7
	selfptr[11]	=	a3  * b8  + a7  * b9  + a11 * b10 + a15 * b11
	selfptr[15]	=	a3  * b12 + a7  * b13 + a11 * b14 + a15 * b15
--]]
	return self
end

-- another optimized mul - this for vectors
function cl:mul4x4v4(x,y,z,w)
	local selfptr = self.ptr
	w = w or 1
	return
		selfptr[0] * x + selfptr[4] * y + selfptr[8] * z + selfptr[12] * w,
		selfptr[1] * x + selfptr[5] * y + selfptr[9] * z + selfptr[13] * w,
		selfptr[2] * x + selfptr[6] * y + selfptr[10] * z + selfptr[14] * w,
		selfptr[3] * x + selfptr[7] * y + selfptr[11] * z + selfptr[15] * w
end

function cl:setIdent()
	local selfptr = self.ptr
	if self.ctype == float then
		return self:copy(ident)
	end
	selfptr[0],  selfptr[1],  selfptr[2],  selfptr[3]  = 1, 0, 0, 0
	selfptr[4],  selfptr[5],  selfptr[6],  selfptr[7]  = 0, 1, 0, 0
	selfptr[8],  selfptr[9],  selfptr[10], selfptr[11] = 0, 0, 1, 0
	selfptr[12], selfptr[13], selfptr[14], selfptr[15] = 0, 0, 0, 1
	return self
end

function cl:setOrtho(l,r,b,t,n,f)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	n = n or -1000
	f = f or 1000
	local invdx = 1 / (r - l)
	local invdy = 1 / (t - b)
	local invdz = 1 / (f - n)
	self.ptr[0] = 2 * invdx
	self.ptr[4] = 0
	self.ptr[8] = 0
	self.ptr[12] = -(r + l) * invdx
	self.ptr[1] = 0
	self.ptr[5] = 2 * invdy
	self.ptr[9] = 0
	self.ptr[13] = -(t + b) * invdy
	self.ptr[2] = 0
	self.ptr[6] = 0
	self.ptr[10] = -2 * invdz
	self.ptr[14] = -(f + n) * invdz
	self.ptr[3] = 0
	self.ptr[7] = 0
	self.ptr[11] = 0
	self.ptr[15] = 1
	return self
end

function cl:applyOrtho(l,r,b,t,n,f)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	n = n or -1000
	f = f or 1000
	local invdx = 1 / (r - l)
	local invdy = 1 / (t - b)
	local invdz = 1 / (f - n)
	local rhs00 = 2 * invdx
	local rhs03 = -(r + l) * invdx
	local rhs11 = 2 * invdy
	local rhs13 = -(t + b) * invdy
	local rhs22 = -2 * invdz
	local rhs23 = -(f + n) * invdz
	local n00 = self.ptr[0] * rhs00
	local n01 = self.ptr[4] * rhs11
	local n02 = self.ptr[8] * rhs22
	local n03 = self.ptr[0] * rhs03 + self.ptr[4] * rhs13 + self.ptr[8] * rhs23 + self.ptr[12]
	local n10 = self.ptr[1] * rhs00
	local n11 = self.ptr[5] * rhs11
	local n12 = self.ptr[9] * rhs22
	local n13 = self.ptr[1] * rhs03 + self.ptr[5] * rhs13 + self.ptr[9] * rhs23 + self.ptr[13]
	local n20 = self.ptr[2] * rhs00
	local n21 = self.ptr[6] * rhs11
	local n22 = self.ptr[10] * rhs22
	local n23 = self.ptr[2] * rhs03 + self.ptr[6] * rhs13 + self.ptr[10] * rhs23 + self.ptr[14]
	local n30 = self.ptr[3] * rhs00
	local n31 = self.ptr[7] * rhs11
	local n32 = self.ptr[11] * rhs22
	local n33 = self.ptr[3] * rhs03 + self.ptr[7] * rhs13 + self.ptr[11] * rhs23 + self.ptr[15]
	self.ptr[0] = n00
	self.ptr[4] = n01
	self.ptr[8] = n02
	self.ptr[12] = n03
	self.ptr[1] = n10
	self.ptr[5] = n11
	self.ptr[9] = n12
	self.ptr[13] = n13
	self.ptr[2] = n20
	self.ptr[6] = n21
	self.ptr[10] = n22
	self.ptr[14] = n23
	self.ptr[3] = n30
	self.ptr[7] = n31
	self.ptr[11] = n32
	self.ptr[15] = n33
end

function cl:setFrustum(l,r,b,t,n,f)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	n = n or .1
	f = f or 1000
	local invdx = 1 / (r - l)
	local invdy = 1 / (t - b)
	local invdz = 1 / (f - n)
	self.ptr[0] = 2 * n * invdx
	self.ptr[4] = 0
	self.ptr[8] = (r + l) * invdx
	self.ptr[12] = 0
	self.ptr[1] = 0
	self.ptr[5] = 2 * n * invdy
	self.ptr[9] = (t + b) * invdy
	self.ptr[13] = 0
	self.ptr[2] = 0
	self.ptr[6] = 0
	self.ptr[10] = -(f + n) * invdz
	self.ptr[14] = -2 * f * n * invdz
	self.ptr[3] = 0
	self.ptr[7] = 0
	self.ptr[11] = -1
	self.ptr[15] = 0
	return self
end
function cl:applyFrustum(l,r,b,t,n,f)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	n = n or .1
	f = f or 1000
	local invdx = 1 / (r - l)
	local invdy = 1 / (t - b)
	local invdz = 1 / (f - n)

	local rhs0 = 2 * n * invdx
	local rhs8 = (r + l) * invdx
	local rhs5 = 2 * n * invdy
	local rhs9 = (t + b) * invdy
	local rhs10 = -(f + n) * invdz
	local rhs14 = -2 * f * n * invdz

	local new0 = self.ptr[0] * rhs0
	local new4 = self.ptr[4] * rhs5
	local new8 = self.ptr[0] * rhs8 + self.ptr[4] * rhs9 + self.ptr[8] * rhs10 - self.ptr[12]
	local new12 = self.ptr[8] * rhs14
	local new1 = self.ptr[1] * rhs0
	local new5 = self.ptr[5] * rhs5
	local new9 = self.ptr[1] * rhs8 + self.ptr[5] * rhs9 + self.ptr[9] * rhs10 - self.ptr[13]
	local new13 = self.ptr[9] * rhs14
	local new2 = self.ptr[2] * rhs0
	local new6 = self.ptr[6] * rhs5
	local new10 = self.ptr[2] * rhs8 + self.ptr[6] * rhs9 + self.ptr[10] * rhs10 - self.ptr[14]
	local new14 = self.ptr[10] * rhs14
	local new3 = self.ptr[3] * rhs0
	local new7 = self.ptr[7] * rhs5
	local new11 = self.ptr[3] * rhs8 + self.ptr[7] * rhs9 + self.ptr[11] * rhs10 - self.ptr[15]
	local new15 = self.ptr[11] * rhs14

	self.ptr[0] = new0
	self.ptr[4] = new4
	self.ptr[8] = new8
	self.ptr[12] = new12
	self.ptr[1] = new1
	self.ptr[5] = new5
	self.ptr[9] = new9
	self.ptr[13] = new13
	self.ptr[2] = new2
	self.ptr[6] = new6
	self.ptr[10] = new10
	self.ptr[14] = new14
	self.ptr[3] = new3
	self.ptr[7] = new7
	self.ptr[11] = new11
	self.ptr[15] = new15
end

-- http://iphonedevelopment.blogspot.com/2008/12/glulookat.html?m=1
local function cross(ax,ay,az,bx,by,bz)
	local cx = ay * bz - az * by
	local cy = az * bx - ax * bz
	local cz = ax * by - ay * bx
	return cx,cy,cz
end
local function normalize(x,y,z)
	local m = math.sqrt(x*x + y*y + z*z)
	if m > 1e-20 then
		return x/m, y/m, z/m
	end
	return 1,0,0
end
-- https://www.khronos.org/opengl/wiki/GluLookAt_code
-- ex ey ez is where the view is centered (lol not 'center')
-- cx cy cz is where the view is looking at
-- upx upy upz is the up vector
function cl:setLookAt(ex,ey,ez,cx,cy,cz,upx,upy,upz)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	local forwardx, forwardy, forwardz = normalize(cx-ex, cy-ey, cz-ez)
	local sidex, sidey, sidez = normalize(cross(forwardx, forwardy, forwardz, upx, upy, upz))
	upx, upy, upz = normalize(cross(sidex, sidey, sidez, forwardx, forwardy, forwardz))
	self.ptr[0] = sidex
	self.ptr[4] = sidey
	self.ptr[8] = sidez
	self.ptr[12] = 0
	self.ptr[1] = upx
	self.ptr[5] = upy
	self.ptr[9] = upz
	self.ptr[13] = 0
	self.ptr[2] = -forwardx
	self.ptr[6] = -forwardy
	self.ptr[10] = -forwardz
	self.ptr[14] = 0
	self.ptr[3] = 0
	self.ptr[7] = 0
	self.ptr[11] = 0
	self.ptr[15] = 1
	return self:applyTranslate(-ex, -ey, -ez)
end
-- TODO optimize the in-place apply instead of this slow crap:
function cl:applyLookAt(...)
	local tmp = metatype()
	return self:mul4x4(self, tmp:setLookAt(...))
end

-- axis is expected to be unit
function cl:setRotateCosSinUnit(c, s, x, y, z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	local ic = 1 - c
	self.ptr[0] = c + x*x*ic
	self.ptr[4] = x*y*ic - z*s
	self.ptr[8] = x*z*ic + y*s
	self.ptr[12] = 0
	self.ptr[1] = x*y*ic + z*s
	self.ptr[5] = c + y*y*ic
	self.ptr[9] = y*z*ic - x*s
	self.ptr[13] = 0
	self.ptr[2] = x*z*ic - y*s
	self.ptr[6] = y*z*ic + x*s
	self.ptr[10] = c + z*z*ic
	self.ptr[14] = 0
	self.ptr[3] = 0
	self.ptr[7] = 0
	self.ptr[11] = 0
	self.ptr[15] = 1
	return self
end
function cl:applyRotateCosSinUnit(c, s, x, y, z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	local ic = 1 - c
	local a0 = self.ptr[0]
	local a1 = self.ptr[1]
	local a2 = self.ptr[2]
	local a3 = self.ptr[3]
	local a4 = self.ptr[4]
	local a5 = self.ptr[5]
	local a6 = self.ptr[6]
	local a7 = self.ptr[7]
	local a8 = self.ptr[8]
	local a9 = self.ptr[9]
	local a10 = self.ptr[10]
	local a11 = self.ptr[11]

	local b0 = c + x*x*ic
	local b4 = x*y*ic - z*s
	local b8 = x*z*ic + y*s
	local b1 = x*y*ic + z*s
	local b5 = c + y*y*ic
	local b9 = y*z*ic - x*s
	local b2 = x*z*ic - y*s
	local b6 = y*z*ic + x*s
	local b10 = c + z*z*ic

	self.ptr[0] = a0 * b0 + a4 * b1 + a8 * b2
	self.ptr[1] = a1 * b0 + a5 * b1 + a9 * b2
	self.ptr[2] = a2 * b0 + a6 * b1 + a10 * b2
	self.ptr[3] = a3 * b0 + a7 * b1 + a11 * b2
	self.ptr[4] = a0 * b4 + a4 * b5 + a8 * b6
	self.ptr[5] = a1 * b4 + a5 * b5 + a9 * b6
	self.ptr[6] = a2 * b4 + a6 * b5 + a10 * b6
	self.ptr[7] = a3 * b4 + a7 * b5 + a11 * b6
	self.ptr[8] = a0 * b8 + a4 * b9 + a8 * b10
	self.ptr[9] = a1 * b8 + a5 * b9 + a9 * b10
	self.ptr[10] = a2 * b8 + a6 * b9 + a10 * b10
	self.ptr[11] = a3 * b8 + a7 * b9 + a11 * b10

	return self
end

-- axis is optional
-- if axis is not provided or if it is near-zero length, defaults to 0,0,1
function cl:setRotateCosSin(c, s, x, y, z)
	if not x then x,y,z = 0,0,1 end
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	local l = math.sqrt(x*x + y*y + z*z)
	if l < 1e-20 then
		x=1
		y=0
		z=0
	else
		local il = 1/l
		x=x*il
		y=y*il
		z=z*il
	end
	return self:setRotateCosSinUnit(c, s, x, y, z)
end
function cl:applyRotateCosSin(c, s, x, y, z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	if not x then x,y,z = 0,0,1 end
	local l = math.sqrt(x*x + y*y + z*z)
	if l < 1e-20 then
		x=1
		y=0
		z=0
	else
		local il = 1/l
		x=x*il
		y=y*il
		z=z*il
	end
	return self:applyRotateCosSinUnit(c, s, x, y, z)
end

function cl:setRotate(radians, ...)
	return self:setRotateCosSin(math.cos(radians), math.sin(radians), ...)
end
function cl:applyRotate(radians, ...)
	return self:applyRotateCosSin(math.cos(radians), math.sin(radians), ...)
end

function cl:setScale(x,y,z)
	x = x or 1
	y = y or 1
	z = z or 1
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	self.ptr[0] = x
	self.ptr[1] = 0
	self.ptr[2] = 0
	self.ptr[3] = 0
	self.ptr[4] = 0
	self.ptr[5] = y
	self.ptr[6] = 0
	self.ptr[7] = 0
	self.ptr[8] = 0
	self.ptr[9] = 0
	self.ptr[10] = z
	self.ptr[11] = 0
	self.ptr[12] = 0
	self.ptr[13] = 0
	self.ptr[14] = 0
	self.ptr[15] = 1
	return self
end
function cl:applyScale(x,y,z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	if x then
		self.ptr[0] = self.ptr[0] * x
		self.ptr[1] = self.ptr[1] * x
		self.ptr[2] = self.ptr[2] * x
		self.ptr[3] = self.ptr[3] * x
	end
	if y then
		self.ptr[4] = self.ptr[4] * y
		self.ptr[5] = self.ptr[5] * y
		self.ptr[6] = self.ptr[6] * y
		self.ptr[7] = self.ptr[7] * y
	end
	if z then
		self.ptr[8] = self.ptr[8] * z
		self.ptr[9] = self.ptr[9] * z
		self.ptr[10] = self.ptr[10] * z
		self.ptr[11] = self.ptr[11] * z
	end
	return self
end

function cl:setTranslate(x,y,z)
	x = x or 0
	y = y or 0
	z = z or 0
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	self.ptr[0] = 1
	self.ptr[1] = 0
	self.ptr[2] = 0
	self.ptr[3] = 0
	self.ptr[4] = 0
	self.ptr[5] = 1
	self.ptr[6] = 0
	self.ptr[7] = 0
	self.ptr[8] = 0
	self.ptr[9] = 0
	self.ptr[10] = 1
	self.ptr[11] = 0
	self.ptr[12] = x
	self.ptr[13] = y
	self.ptr[14] = z
	self.ptr[15] = 1
	return self
end
function cl:applyTranslate(x,y,z)
	x = x or 0
	y = y or 0
	z = z or 0
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	self.ptr[12] = x * self.ptr[0] + y * self.ptr[4] + z * self.ptr[8] + self.ptr[12]
	self.ptr[13] = x * self.ptr[1] + y * self.ptr[5] + z * self.ptr[9] + self.ptr[13]
	self.ptr[14] = x * self.ptr[2] + y * self.ptr[6] + z * self.ptr[10] + self.ptr[14]
	self.ptr[15] = x * self.ptr[3] + y * self.ptr[7] + z * self.ptr[11] + self.ptr[15]
	return self
end

-- based on the mesa impl: https://community.khronos.org/t/glupickmatrix-implementation/72008/2
-- except that I'm going to assume x, y, dx, dy are normalized to [0,1] instead of [0,viewport-1] so that you don't have to also get and pass the viewport
function cl:setPickMatrix(...)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	return self:setIdent():applyPickMatrix(...)
end
function cl:applyPickMatrix(x, y, dx, dy)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	if dx <= 0 or dy <= 0 then return self end
	return self
		:applyTranslate(
			(1 - 2 * x) / dx,
			(1 - 2 * y) / dy,
			0)
		:applyScale(
			1 / dx,
			1 / dy,
			1)
end

-- based on mesa: https://github.com/Starlink/mesa/blob/master/src/glu/sgi/libutil/project.c
function cl:setPerspective(fovy, aspectRatio, zNear, zFar)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local radians = math.rad(.5 * fovy)
	local deltaZ = zFar - zNear
	local sine = math.sin(radians)
	if deltaZ == 0 or sine == 0 or aspectRatio == 0 then return self end
	local cotangent = math.cos(radians) / sine
	self:setIdent()
	self.ptr[0 + 4 * 0] = cotangent / aspectRatio
	self.ptr[1 + 4 * 1] = cotangent
	self.ptr[2 + 4 * 2] = -(zFar + zNear) / deltaZ
	self.ptr[2 + 4 * 3] = -1
	self.ptr[3 + 4 * 2] = -2 * zNear * zFar / deltaZ
	self.ptr[3 + 4 * 3] = 0
	return self
end
function cl:applyPerspective(...)
	return self:mul4x4(
		self,
		cl({4, 4}, float):zeros():setPerspective(...)
	)
end

-- calculates the inverse of 'src' or 'self' and stores it in 'self'
-- https://stackoverflow.com/a/1148405
function cl:inv4x4(src)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
--DEBUG:assert(not self.rowmajor)
	src = src or self
	local srcp = src.ptr
	local a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15
		= srcp[0], srcp[1], srcp[2], srcp[3], srcp[4], srcp[5], srcp[6], srcp[7], srcp[8], srcp[9], srcp[10], srcp[11], srcp[12], srcp[13], srcp[14], srcp[15]

	local dstp = self.ptr
	dstp[0]  =  a5 * a10 * a15 - a5 * a11 * a14 - a9 * a6 * a15 + a9 * a7 * a14 + a13 * a6 * a11 - a13 * a7 * a10
	dstp[1]  = -a1 * a10 * a15 + a1 * a11 * a14 + a9 * a2 * a15 - a9 * a3 * a14 - a13 * a2 * a11 + a13 * a3 * a10
	dstp[2]  =  a1 * a6 * a15 - a1 * a7 * a14 - a5 * a2 * a15 + a5 * a3 * a14 + a13 * a2 * a7 - a13 * a3 * a6
	dstp[3]  = -a1 * a6 * a11 + a1 * a7 * a10 + a5 * a2 * a11 - a5 * a3 * a10 - a9 * a2 * a7 + a9 * a3 * a6
	dstp[4]  = -a4 * a10 * a15 + a4 * a11 * a14 + a8 * a6 * a15 - a8 * a7 * a14 - a12 * a6 * a11 + a12 * a7 * a10
	dstp[5]  =  a0 * a10 * a15 - a0 * a11 * a14 - a8 * a2 * a15 + a8 * a3 * a14 + a12 * a2 * a11 - a12 * a3 * a10
	dstp[6]  = -a0 * a6 * a15 + a0 * a7 * a14 + a4 * a2 * a15 - a4 * a3 * a14 - a12 * a2 * a7 + a12 * a3 * a6
	dstp[7]  =  a0 * a6 * a11 - a0 * a7 * a10 - a4 * a2 * a11 + a4 * a3 * a10 + a8 * a2 * a7 - a8 * a3 * a6
	dstp[8]  =  a4 * a9 * a15 - a4 * a11 * a13 - a8 * a5 * a15 + a8 * a7 * a13 + a12 * a5 * a11 - a12 * a7 * a9
	dstp[9]  = -a0 * a9 * a15 + a0 * a11 * a13 + a8 * a1 * a15 - a8 * a3 * a13 - a12 * a1 * a11 + a12 * a3 * a9
	dstp[10] =  a0 * a5 * a15 - a0 * a7 * a13 - a4 * a1 * a15 + a4 * a3 * a13 + a12 * a1 * a7 - a12 * a3 * a5
	dstp[11] = -a0 * a5 * a11 + a0 * a7 * a9 + a4 * a1 * a11 - a4 * a3 * a9 - a8 * a1 * a7 + a8 * a3 * a5
	dstp[12] = -a4 * a9 * a14 + a4 * a10 * a13 + a8 * a5 * a14 - a8 * a6 * a13 - a12 * a5 * a10 + a12 * a6 * a9
	dstp[13] =  a0 * a9 * a14 - a0 * a10 * a13 - a8 * a1 * a14 + a8 * a2 * a13 + a12 * a1 * a10 - a12 * a2 * a9
	dstp[14] = -a0 * a5 * a14 + a0 * a6 * a13 + a4 * a1 * a14 - a4 * a2 * a13 - a12 * a1 * a6 + a12 * a2 * a5
	dstp[15] =  a0 * a5 * a10 - a0 * a6 * a9 - a4 * a1 * a10 + a4 * a2 * a9 + a8 * a1 * a6 - a8 * a2 * a5

	local det = a0 * dstp[0] + a1 * dstp[4] + a2 * dstp[8] + a3 * dstp[12]
	if det == 0 then
		-- if this is in-place then do we error or return an extra flag or something?
		for i=0,15 do
			dstp[i] = 0/0
		end
		return self, 'singular'
	end

	local invdet = 1 / det
	for i=0,15 do
		dstp[i] = dstp[i] * invdet
	end

	return self
end

function cl.determinant(m)
	local mp = m.ptr
	local a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15
		= mp[0], mp[1], mp[2], mp[3], mp[4], mp[5], mp[6], mp[7], mp[8], mp[9], mp[10], mp[11], mp[12], mp[13], mp[14], mp[15]

	local dstp0  =  a5 * a10 * a15 - a5 * a11 * a14 - a9 * a6 * a15 + a9 * a7 * a14 + a13 * a6 * a11 - a13 * a7 * a10
	local dstp4  = -a4 * a10 * a15 + a4 * a11 * a14 + a8 * a6 * a15 - a8 * a7 * a14 - a12 * a6 * a11 + a12 * a7 * a10
	local dstp8  =  a4 * a9 * a15 - a4 * a11 * a13 - a8 * a5 * a15 + a8 * a7 * a13 + a12 * a5 * a11 - a12 * a7 * a9
	local dstp12 = -a4 * a9 * a14 + a4 * a10 * a13 + a8 * a5 * a14 - a8 * a6 * a13 - a12 * a5 * a10 + a12 * a6 * a9
	return a0 * dstp0 + a1 * dstp4 + a2 * dstp8 + a3 * dstp12
end

function cl:transpose4x4(src)
	src = src or self
	local srcp = src.ptr
	local dstp = self.ptr
	dstp[0], dstp[4], dstp[8], dstp[12], dstp[1], dstp[5], dstp[9], dstp[13], dstp[2], dstp[6], dstp[10], dstp[14], dstp[3], dstp[7], dstp[11], dstp[15]
	= srcp[0], srcp[1], srcp[2], srcp[3], srcp[4], srcp[5], srcp[6], srcp[7], srcp[8], srcp[9], srcp[10], srcp[11], srcp[12], srcp[13], srcp[14], srcp[15]
	return self
end


]=],
}
