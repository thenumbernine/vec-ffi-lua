require 'vec-ffi.vec4f'

-- TODO I'm going to need a create_mat next ...
return require 'vec-ffi.create_vec'{
	dim = 4,
	ctype = 'vec4f_t',

	classCode = [=[
<?
local ffi = require 'ffi'
local assert = require 'ext.assert'
local range = require 'ext.range'
local volume = dims:product()

-- shorthand
local function ofs(...)
	return matrixIndexOffset(args, ...)
end
?>

local assert = require 'ext.assert'

function cl:copy(src)
--DEBUG:assert.eq(ffi.typeof(self), ffi.typeof(src))	-- this will false fail if I'm comparing T& with T ...  TODO removecv<>
	ffi.copy(self.s, src.s, <?=
		-- ffi.sizeof(self)				-- this would be at runtime
		volume * ffi.sizeof(scalarType)	-- ... or we can inline the size
?>)
	return self
end

function cl:clone()
	-- notice that metatype doesn't exist yet at the global scope,
	-- just function scope after global is run
	return metatype(self)
end

-- optimized ... default mul of arbitrary-rank inner-product is verrrry slow
function cl:mul4x4(a,b)
	local aptr = a.ptr
	local bptr = b.ptr
	local selfptr = self.ptr
--DEBUG:assert.eq(self.rank, 2)
--DEBUG:assert.eq(self.dims[1], self.dims[2])
	-- with temp vars ... any performance diff?
	local <?=range(0,volume-1):mapi(function(i) return 'a'..i end):concat', '
		?> = <?=range(0,volume-1):mapi(function(i) return 'aptr['..i..']' end):concat', '?>
	local <?=range(0,volume-1):mapi(function(i) return 'b'..i end):concat', '
		?> = <?=range(0,volume-1):mapi(function(i) return 'bptr['..i..']' end):concat', '?>
<?
-- c_ij = a_ik b_kj

assert.len(dims, 2)
assert.eq(dims[1], dims[2])

for i=0,dims[1]-1 do
	for j=0,dims[2]-1 do
?>	selfptr[<?=ofs(i,j)?>] = <?
		for k=0,dims[1]-1 do		-- sum dims is dims[1] or dims[2] since this is for square mat mult
?><?= k==0 and '' or ' + '?>a<?=ofs(i,k)?> * b<?=ofs(k,j)?><?
		end
?>
<?	end
end
?>	return self
end

-- another optimized mul - this for vectors
function cl:mul4x4v4(x,y,z,w)
	local selfptr = self.ptr
	w = w or 1
	return
<?
local vars = {'x','y','z','w'}
for i=0,dims[1]-1 do
?>		<?
	for j=0,dims[2]-1 do
?><?=j==0 and '' or ' + '?>selfptr[<?=ofs(i,j)?>] * <?=vars[1+j]?><?
	end
?><?=i < dims[1]-1 and ',' or ''?>
<?
end
?>
end

function cl:setIdent()
	local selfptr = self.ptr
<?
assert.len(dims, 2)
for i=0,dims[1]-1 do
	for j=0,dims[2]-1 do
?>	selfptr[<?=ofs(i,j)?>] = <?=i==j and '1' or '0'?>
<?	end
end
?>	return self
end

function cl:setOrtho(l,r,b,t,n,f)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.ge(self.dims[1], 4)
--DEBUG:assert.ge(self.dims[2], 4)
	local selfptr = self.ptr
	n = n or -1000
	f = f or 1000
	local invdx = 1 / (r - l)
	local invdy = 1 / (t - b)
	local invdz = 1 / (f - n)
	selfptr[<?=ofs(0,0)?>] = 2 * invdx
	selfptr[<?=ofs(0,1)?>] = 0
	selfptr[<?=ofs(0,2)?>] = 0
	selfptr[<?=ofs(0,3)?>] = -(r + l) * invdx
	selfptr[<?=ofs(1,0)?>] = 0
	selfptr[<?=ofs(1,1)?>] = 2 * invdy
	selfptr[<?=ofs(1,2)?>] = 0
	selfptr[<?=ofs(1,3)?>] = -(t + b) * invdy
	selfptr[<?=ofs(2,0)?>] = 0
	selfptr[<?=ofs(2,1)?>] = 0
	selfptr[<?=ofs(2,2)?>] = -2 * invdz
	selfptr[<?=ofs(2,3)?>] = -(f + n) * invdz
	selfptr[<?=ofs(3,0)?>] = 0
	selfptr[<?=ofs(3,1)?>] = 0
	selfptr[<?=ofs(3,2)?>] = 0
	selfptr[<?=ofs(3,3)?>] = 1
	return self
end

function cl:applyOrtho(l,r,b,t,n,f)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.ge(self.dims[1], 4)
--DEBUG:assert.ge(self.dims[2], 4)
	local selfptr = self.ptr
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
	local n00 = selfptr[<?=ofs(0,0)?>] * rhs00
	local n01 = selfptr[<?=ofs(0,1)?>] * rhs11
	local n02 = selfptr[<?=ofs(0,2)?>] * rhs22
	local n03 =
		  selfptr[<?=ofs(0,0)?>] * rhs03
		+ selfptr[<?=ofs(0,1)?>] * rhs13
		+ selfptr[<?=ofs(0,2)?>] * rhs23
		+ selfptr[<?=ofs(0,3)?>]
	local n10 = selfptr[<?=ofs(1,0)?>] * rhs00
	local n11 = selfptr[<?=ofs(1,1)?>] * rhs11
	local n12 = selfptr[<?=ofs(1,2)?>] * rhs22
	local n13 =
		  selfptr[<?=ofs(1,0)?>] * rhs03
		+ selfptr[<?=ofs(1,1)?>] * rhs13
		+ selfptr[<?=ofs(1,2)?>] * rhs23
		+ selfptr[<?=ofs(1,3)?>]
	local n20 = selfptr[<?=ofs(2,0)?>] * rhs00
	local n21 = selfptr[<?=ofs(2,1)?>] * rhs11
	local n22 = selfptr[<?=ofs(2,2)?>] * rhs22
	local n23 =
		  selfptr[<?=ofs(2,0)?>] * rhs03
		+ selfptr[<?=ofs(2,1)?>] * rhs13
		+ selfptr[<?=ofs(2,2)?>] * rhs23
		+ selfptr[<?=ofs(2,3)?>]
	local n30 = selfptr[<?=ofs(3,0)?>] * rhs00
	local n31 = selfptr[<?=ofs(3,1)?>] * rhs11
	local n32 = selfptr[<?=ofs(3,2)?>] * rhs22
	local n33 =
		  selfptr[<?=ofs(3,0)?>] * rhs03
		+ selfptr[<?=ofs(3,1)?>] * rhs13
		+ selfptr[<?=ofs(3,2)?>] * rhs23
		+ selfptr[<?=ofs(3,3)?>]
<?
for i=0,dims[1]-1 do
	for j=0,dims[2]-1 do
?>	selfptr[<?=ofs(i,j)?>] = n<?=i?><?=j?>
<?	end
end
?>	return self
end

function cl:setFrustum(l,r,b,t,n,f)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
	n = n or .1
	f = f or 1000
	local invdx = 1 / (r - l)
	local invdy = 1 / (t - b)
	local invdz = 1 / (f - n)
	selfptr[<?=ofs(0,0)?>] = 2 * n * invdx
	selfptr[<?=ofs(0,1)?>] = 0
	selfptr[<?=ofs(0,2)?>] = (r + l) * invdx
	selfptr[<?=ofs(0,3)?>] = 0
	selfptr[<?=ofs(1,0)?>] = 0
	selfptr[<?=ofs(1,1)?>] = 2 * n * invdy
	selfptr[<?=ofs(1,2)?>] = (t + b) * invdy
	selfptr[<?=ofs(1,3)?>] = 0
	selfptr[<?=ofs(2,0)?>] = 0
	selfptr[<?=ofs(2,1)?>] = 0
	selfptr[<?=ofs(2,2)?>] = -(f + n) * invdz
	selfptr[<?=ofs(2,3)?>] = -2 * f * n * invdz
	selfptr[<?=ofs(3,0)?>] = 0
	selfptr[<?=ofs(3,1)?>] = 0
	selfptr[<?=ofs(3,2)?>] = -1
	selfptr[<?=ofs(3,3)?>] = 0
	return self
end
function cl:applyFrustum(l,r,b,t,n,f)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
	n = n or .1
	f = f or 1000
	local invdx = 1 / (r - l)
	local invdy = 1 / (t - b)
	local invdz = 1 / (f - n)

	local rhs00 = 2 * n * invdx
	local rhs02 = (r + l) * invdx
	local rhs11 = 2 * n * invdy
	local rhs12 = (t + b) * invdy
	local rhs22 = -(f + n) * invdz
	local rhs23 = -2 * f * n * invdz

	local n00 = selfptr[<?=ofs(0,0)?>] * rhs00
	local n01 = selfptr[<?=ofs(0,1)?>] * rhs11
	local n02 =
		  selfptr[<?=ofs(0,0)?>] * rhs02
		+ selfptr[<?=ofs(0,1)?>] * rhs12
		+ selfptr[<?=ofs(0,2)?>] * rhs22
		- selfptr[<?=ofs(0,3)?>]
	local n03 = selfptr[<?=ofs(0,2)?>] * rhs23
	local n10 = selfptr[<?=ofs(1,0)?>] * rhs00
	local n11 = selfptr[<?=ofs(1,1)?>] * rhs11
	local n12 =
		  selfptr[<?=ofs(1,0)?>] * rhs02
		+ selfptr[<?=ofs(1,1)?>] * rhs12
		+ selfptr[<?=ofs(1,2)?>] * rhs22
		- selfptr[<?=ofs(1,3)?>]
	local n13 = selfptr[<?=ofs(1,2)?>] * rhs23
	local n20 = selfptr[<?=ofs(2,0)?>] * rhs00
	local n21 = selfptr[<?=ofs(2,1)?>] * rhs11
	local n22 =
		  selfptr[<?=ofs(2,0)?>] * rhs02
		+ selfptr[<?=ofs(2,1)?>] * rhs12
		+ selfptr[<?=ofs(2,2)?>] * rhs22
		- selfptr[<?=ofs(2,3)?>]
	local n23 = selfptr[<?=ofs(2,2)?>] * rhs23
	local n30 = selfptr[<?=ofs(3,0)?>] * rhs00
	local n31 = selfptr[<?=ofs(3,1)?>] * rhs11
	local n32 =
		  selfptr[<?=ofs(3,0)?>] * rhs02
		+ selfptr[<?=ofs(3,1)?>] * rhs12
		+ selfptr[<?=ofs(3,2)?>] * rhs22
		- selfptr[<?=ofs(3,3)?>]
	local n33 = selfptr[<?=ofs(3,2)?>] * rhs23
<?
for i=0,dims[1]-1 do
	for j=0,dims[2]-1 do
?>	selfptr[<?=ofs(i,j)?>] = n<?=i?><?=j?>
<?	end
end
?>	return self
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
	local forwardx, forwardy, forwardz = normalize(cx-ex, cy-ey, cz-ez)
	local sidex, sidey, sidez = normalize(cross(forwardx, forwardy, forwardz, upx, upy, upz))
	upx, upy, upz = normalize(cross(sidex, sidey, sidez, forwardx, forwardy, forwardz))
	local selfptr = self.ptr
	selfptr[<?=ofs(0,0)?>] = sidex
	selfptr[<?=ofs(0,1)?>] = sidey
	selfptr[<?=ofs(0,2)?>] = sidez
	selfptr[<?=ofs(0,3)?>] = 0
	selfptr[<?=ofs(1,0)?>] = upx
	selfptr[<?=ofs(1,1)?>] = upy
	selfptr[<?=ofs(1,2)?>] = upz
	selfptr[<?=ofs(1,3)?>] = 0
	selfptr[<?=ofs(2,0)?>] = -forwardx
	selfptr[<?=ofs(2,1)?>] = -forwardy
	selfptr[<?=ofs(2,2)?>] = -forwardz
	selfptr[<?=ofs(2,3)?>] = 0
	selfptr[<?=ofs(3,0)?>] = 0
	selfptr[<?=ofs(3,1)?>] = 0
	selfptr[<?=ofs(3,2)?>] = 0
	selfptr[<?=ofs(3,3)?>] = 1
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
	local ic = 1 - c
	local selfptr = self.ptr
	selfptr[<?=ofs(0,0)?>] = c + x*x*ic
	selfptr[<?=ofs(0,1)?>] = x*y*ic - z*s
	selfptr[<?=ofs(0,2)?>] = x*z*ic + y*s
	selfptr[<?=ofs(0,3)?>] = 0
	selfptr[<?=ofs(1,0)?>] = x*y*ic + z*s
	selfptr[<?=ofs(1,1)?>] = c + y*y*ic
	selfptr[<?=ofs(1,2)?>] = y*z*ic - x*s
	selfptr[<?=ofs(1,3)?>] = 0
	selfptr[<?=ofs(2,0)?>] = x*z*ic - y*s
	selfptr[<?=ofs(2,1)?>] = y*z*ic + x*s
	selfptr[<?=ofs(2,2)?>] = c + z*z*ic
	selfptr[<?=ofs(2,3)?>] = 0
	selfptr[<?=ofs(3,0)?>] = 0
	selfptr[<?=ofs(3,1)?>] = 0
	selfptr[<?=ofs(3,2)?>] = 0
	selfptr[<?=ofs(3,3)?>] = 1
	return self
end
function cl:applyRotateCosSinUnit(c, s, x, y, z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr

<?
for i=0,3 do
	for j=0,2 do
?>	local a<?=i?><?=j?> = selfptr[<?=ofs(i,j)?>]
<?	end
end
?>

	local ic = 1 - c
	local b00 = c + x*x*ic
	local b01 = x*y*ic - z*s
	local b02 = x*z*ic + y*s
	local b10 = x*y*ic + z*s
	local b11 = c + y*y*ic
	local b12 = y*z*ic - x*s
	local b20 = x*z*ic - y*s
	local b21 = y*z*ic + x*s
	local b22 = c + z*z*ic

<?
for i=0,3 do
	for j=0,2 do
?>	selfptr[<?=ofs(i,j)?>] = <?
		for k=0,2 do
?><?= k==0 and '' or ' + '?>a<?=i..k?> * b<?=k..j?><?
		end
?>
<?	end
end
?>	return self
end

-- axis is optional
-- if axis is not provided or if it is near-zero length, defaults to 0,0,1
function cl:setRotateCosSin(c, s, x, y, z)
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
	return self:setRotateCosSinUnit(c, s, x, y, z)
end
function cl:applyRotateCosSin(c, s, x, y, z)
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
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
	x = x or 1
	y = y or 1
	z = z or 1
<?
local vars = {'x','y','z'}
for i=0,3 do
	for j=0,3 do
?>	selfptr[<?=ofs(i,j)?>] = <?=i ~= j and '0' or vars[i] or '1'?>
<?	end
end
?>	return self
end
function cl:applyScale(x,y,z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
<?
local vars = {'x','y','z'}
for j=0,2 do
	local var = vars[j+1]
?>	if <?=var?> then
<?	for i=0,3 do
?>		selfptr[<?=ofs(i,j)?>] = selfptr[<?=ofs(i,j)?>] * <?=var?>
<?	end
?>	end
<?
end
?>	return self
end

function cl:setTranslate(x,y,z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
	x = x or 0
	y = y or 0
	z = z or 0
<?
local vars = {'x', 'y', 'z'}
for i=0,3 do
	for j=0,3 do
?>	selfptr[<?=ofs(i,j)?>] = <?=i==j and 1 or j==3 and vars[i+1] or '0'?>
<?	end
end
?>	return self
end
function cl:applyTranslate(x,y,z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
<?
for i=0,3 do
	for j=0,3 do
?>	local a<?=i?><?=j?> = selfptr[<?=ofs(i,j)?>]
<?	end
end
?>
	x = x or 0
	y = y or 0
	z = z or 0
<? for i=0,3 do
?>	selfptr[<?=ofs(i,3)?>] = a<?=i..0?> * x + a<?=i..1?> * y + a<?=i..2?> * z + a<?=i..3?>
<? end
?>	return self
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
	local selfptr = self.ptr
	local radians = math.rad(.5 * fovy)
	local deltaZ = zFar - zNear
	local sine = math.sin(radians)
	if deltaZ == 0 or sine == 0 or aspectRatio == 0 then return self end
	local cotangent = math.cos(radians) / sine
<?
local mat = {
	{'cotangent / aspectRatio', '0', '0', '0'},
	{'0', 'cotangent', '0', '0'},
	{'0', '0', '-(zFar + zNear) / deltaZ', '-2 * zNear * zFar / deltaZ'},
	{'0', '0', '-1', '1'},
}
for i=0,3 do
	for j=0,3 do
?>	selfptr[<?=ofs(i,j)?>] = <?=mat[1+i][1+j]?>
<?	end
end
?>	return self
end
function cl:applyPerspective(...)
	return self:mul4x4(
		self,
		metatype():setPerspective(...)
	)
end

-- calculates the inverse of 'src' or 'self' and stores it in 'self'
-- https://stackoverflow.com/a/1148405
function cl:inv4x4(src)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
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
