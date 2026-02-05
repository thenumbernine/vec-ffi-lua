local table = require 'ext.table'
local createVec = require 'vec-ffi.create_vec'
-- matrix with 4x4 specialization functions
-- maybe I should put them in all matrix types?
return function(args)
	return createVec(table(args, {
		dim = args.dim or 4,
		classCode = [=[
<?
local ffi = require 'ffi'
local assert = require 'ext.assert'
local range = require 'ext.range'
local op = require 'ext.op'
local volume = dims:product()

-- most these routines assume it is a 4x4 vec-of-vec, or at least that it is square
assert.len(dims, 2)
assert.eq(dims[1], dims[2])

-- shorthand
local function ofs(...)
	return matrixIndexOffset(args, ...)
end

-- makes func(0,0) through func(m-1,n-1)
local function spanfunc(f, m, n)
	m = m or dims[1]
	n = n or dims[2]
	local s = table()
	for i=0,m-1 do
		for j=0,n-1 do
			s:insert((assert(f(i,j))))
		end
	end
	return s:concat', '
end

-- makes arrayname[ofs(0,0)] through arrayname[ofs(m-1,n-1)]
local function spanarray(arrayname, ...)
	return spanfunc(function(i,j)
		return arrayname..'['..ofs(i,j)..']'
	end, ...)
end

-- makes varname_0_0 through varname_(m-1)_(n-1)
local function spanvar(varname, ...)
	return spanfunc(function(i,j)
		return table{varname, i, j}:concat'_'
	end, ...)
end

local function spanmat(mat, ...)
	return spanfunc(function(i,j)
		return (assert(mat[i+1][j+1]))
	end, ...)
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

-- optimized ... default matrix-mul of arbitrary-rank inner-product is verrrry slow
-- TODO don't override the (slow) vec.mul since it will work on arbitrary rank tensors.
-- name this somethign else like "matmul"
function cl:mul4x4(a,b)
	local aptr = a.ptr
	local bptr = b.ptr
	local selfptr = self.ptr
--DEBUG:assert.eq(self.rank, 2)
--DEBUG:assert.eq(self.dims[1], self.dims[2])
	-- with temp vars ... any performance diff?
	local <?=spanvar'a'?> = <?=spanarray'aptr'?>
	local <?=spanvar'b'?> = <?=spanarray'bptr'?>

	-- c_ij = sum_k a_ik * b_kj
	<?=spanarray'selfptr'?> = <?=spanfunc(function(i,j)
		local s = table()
		for k=0,dims[1]-1 do
			s:insert('a_'..i..'_'..k..' * b_'..k..'_'..j)
		end
		return s:concat' + '
	end)?>
	return self
end

-- another optimized mul - this for vectors
function cl:mul4x4v4(x,y,z,w)
	local selfptr = self.ptr
	w = w or 1
	return
<?
local vars4 = {'x','y','z','w'}
for i=0,dims[1]-1 do
?>		<?=
	range(0,dims[2]-1):mapi(function(j)
		return 'selfptr['..ofs(i,j)..'] * '..vars4[1+j]
	end):concat' + '
?><?=i < dims[1]-1 and ',' or ''?>
<? end
?>
end

function cl:setIdent()
	local selfptr = self.ptr
	<?=spanarray'selfptr'?> = <?=spanfunc(function(i,j) return i==j and '1' or '0' end)?>
	return self
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
	<?=spanarray'selfptr'?> = <?=spanmat{
		{'2 * invdx', '0', '0', '-(r + l) * invdx'},
		{'0', '2 * invdy', '0', '-(t + b) * invdy'},
		{'0', '0', '-2 * invdz', '-(f + n) * invdz'},
		{'0', '0', '0', '1'},
	}?>
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
	local n_0_0 = selfptr[<?=ofs(0,0)?>] * rhs00
	local n_0_1 = selfptr[<?=ofs(0,1)?>] * rhs11
	local n_0_2 = selfptr[<?=ofs(0,2)?>] * rhs22
	local n_0_3 =
		  selfptr[<?=ofs(0,0)?>] * rhs03
		+ selfptr[<?=ofs(0,1)?>] * rhs13
		+ selfptr[<?=ofs(0,2)?>] * rhs23
		+ selfptr[<?=ofs(0,3)?>]
	local n_1_0 = selfptr[<?=ofs(1,0)?>] * rhs00
	local n_1_1 = selfptr[<?=ofs(1,1)?>] * rhs11
	local n_1_2 = selfptr[<?=ofs(1,2)?>] * rhs22
	local n_1_3 =
		  selfptr[<?=ofs(1,0)?>] * rhs03
		+ selfptr[<?=ofs(1,1)?>] * rhs13
		+ selfptr[<?=ofs(1,2)?>] * rhs23
		+ selfptr[<?=ofs(1,3)?>]
	local n_2_0 = selfptr[<?=ofs(2,0)?>] * rhs00
	local n_2_1 = selfptr[<?=ofs(2,1)?>] * rhs11
	local n_2_2 = selfptr[<?=ofs(2,2)?>] * rhs22
	local n_2_3 =
		  selfptr[<?=ofs(2,0)?>] * rhs03
		+ selfptr[<?=ofs(2,1)?>] * rhs13
		+ selfptr[<?=ofs(2,2)?>] * rhs23
		+ selfptr[<?=ofs(2,3)?>]
	local n_3_0 = selfptr[<?=ofs(3,0)?>] * rhs00
	local n_3_1 = selfptr[<?=ofs(3,1)?>] * rhs11
	local n_3_2 = selfptr[<?=ofs(3,2)?>] * rhs22
	local n_3_3 =
		  selfptr[<?=ofs(3,0)?>] * rhs03
		+ selfptr[<?=ofs(3,1)?>] * rhs13
		+ selfptr[<?=ofs(3,2)?>] * rhs23
		+ selfptr[<?=ofs(3,3)?>]
	<?=spanarray'selfptr'?> = <?=spanvar'n'?>
	return self
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
	<?=spanarray'selfptr'?> = <?=spanmat{
		{'2 * n * invdx', '0', '(r + l) * invdx', '0'},
		{'0', '2 * n * invdy', '(t + b) * invdy', '0'},
		{'0', '0', '-(f + n) * invdz', '-2 * f * n * invdz'},
		{'0', '0', '-1', '0'},
	}?>
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

	local n_0_0 = selfptr[<?=ofs(0,0)?>] * rhs00
	local n_0_1 = selfptr[<?=ofs(0,1)?>] * rhs11
	local n_0_2 =
		  selfptr[<?=ofs(0,0)?>] * rhs02
		+ selfptr[<?=ofs(0,1)?>] * rhs12
		+ selfptr[<?=ofs(0,2)?>] * rhs22
		- selfptr[<?=ofs(0,3)?>]
	local n_0_3 = selfptr[<?=ofs(0,2)?>] * rhs23
	local n_1_0 = selfptr[<?=ofs(1,0)?>] * rhs00
	local n_1_1 = selfptr[<?=ofs(1,1)?>] * rhs11
	local n_1_2 =
		  selfptr[<?=ofs(1,0)?>] * rhs02
		+ selfptr[<?=ofs(1,1)?>] * rhs12
		+ selfptr[<?=ofs(1,2)?>] * rhs22
		- selfptr[<?=ofs(1,3)?>]
	local n_1_3 = selfptr[<?=ofs(1,2)?>] * rhs23
	local n_2_0 = selfptr[<?=ofs(2,0)?>] * rhs00
	local n_2_1 = selfptr[<?=ofs(2,1)?>] * rhs11
	local n_2_2 =
		  selfptr[<?=ofs(2,0)?>] * rhs02
		+ selfptr[<?=ofs(2,1)?>] * rhs12
		+ selfptr[<?=ofs(2,2)?>] * rhs22
		- selfptr[<?=ofs(2,3)?>]
	local n_2_3 = selfptr[<?=ofs(2,2)?>] * rhs23
	local n_3_0 = selfptr[<?=ofs(3,0)?>] * rhs00
	local n_3_1 = selfptr[<?=ofs(3,1)?>] * rhs11
	local n_3_2 =
		  selfptr[<?=ofs(3,0)?>] * rhs02
		+ selfptr[<?=ofs(3,1)?>] * rhs12
		+ selfptr[<?=ofs(3,2)?>] * rhs22
		- selfptr[<?=ofs(3,3)?>]
	local n_3_3 = selfptr[<?=ofs(3,2)?>] * rhs23
	<?=spanarray'selfptr'?> = <?=spanvar'n'?>
	return self
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
	<?=spanarray'selfptr'?> = <?=spanmat{
		{'sidex', 'sidey', 'sidez', '0'},
		{'upx', 'upy', 'upz', '0'},
		{'-forwardx', '-forwardy', '-forwardz', '0'},
		{'0', '0', '0', '1'},
	}?>
	return self:applyTranslate(-ex, -ey, -ez)
end
-- TODO optimize the in-place apply instead of this slow crap:
function cl:applyLookAt(...)
	local tmp = metatype()
	return self:mul4x4(self, tmp:setLookAt(...))
end

<?
local rotmat = {
	{'c + x*x*ic', 'x*y*ic - z*s', 'x*z*ic + y*s'},
	{'x*y*ic + z*s', 'c + y*y*ic', 'y*z*ic - x*s'},
	{'x*z*ic - y*s', 'y*z*ic + x*s', 'c + z*z*ic'},
}
?>
-- axis is expected to be unit
function cl:setRotateCosSinUnit(c, s, x, y, z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local ic = 1 - c
	local selfptr = self.ptr
	<?=spanarray'selfptr'?> = <?=spanfunc(function(i,j)
		return op.safeindex(rotmat, 1+i, 1+j) or (i==j and '1' or '0')
	end)?>
	return self
end
function cl:applyRotateCosSinUnit(c, s, x, y, z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr

	local <?=spanvar'a'?> = <?=spanarray'selfptr'?>

	local ic = 1 - c
	local <?=spanvar('b',3,3)?> = <?=spanmat(rotmat,3,3)?>
	<?=spanarray('selfptr', dims[1], 3)?> = <?=spanfunc(function(i,j)
		return range(0,2):mapi(function(k)
			return 'a_'..i..'_'..k..' * b_'..k..'_'..j
		end):concat' + '
	end, dims[1], 3)?>
	return self
end

-- axis is optional
-- if axis is not provided or if it is near-zero length, defaults to 0,0,1
function cl:setRotateCosSin(c, s, x, y, z)
	local lensq
	if not x then
		x,y,z,lensq = 0,0,1,1
	else
		lensq = x*x + y*y + z*z
	end
	if lensq < 1e-10 then
		return self:setRotateCosSinUnit(c, s, 0, 0, 1)
	else
		local invlen = 1/math.sqrt(lensq)
		return self:setRotateCosSinUnit(c, s, x*invlen, y*invlen, z*invlen)
	end
end
function cl:applyRotateCosSin(c, s, x, y, z)
	local lensq
	if not x then
		x,y,z,lensq = 0,0,1,1
	else
		lensq = x*x + y*y + z*z
	end
	if lensq < 1e-10 then
		return self:applyRotateCosSinUnit(c, s, 0, 0, 1)
	else
		local invlen = 1/math.sqrt(lensq)
		return self:applyRotateCosSinUnit(c, s, x*invlen, y*invlen, z*invlen)
	end
end

function cl:setRotate(radians, ...)
	return self:setRotateCosSin(math.cos(radians), math.sin(radians), ...)
end
function cl:applyRotate(radians, ...)
	return self:applyRotateCosSin(math.cos(radians), math.sin(radians), ...)
end

<?
local vars3 = {'x', 'y', 'z'}
?>

function cl:setScale(x,y,z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
	x = x or 1
	y = y or 1
	z = z or 1
	<?=spanarray'selfptr'?> = <?=spanfunc(function(i,j)
		if i ~= j then return '0' end
		return vars3[i] or '1'
	end)?>
	return self
end
function cl:applyScale(x,y,z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
<?
for j=0,2 do
	local var = vars3[j+1]
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
	<?=spanarray'selfptr'?> = <?=spanfunc(function(i,j)
		if i==j then return '1' end
		if j==dims[2]-1 then return vars3[i+1] or '0' end
		return '0'
	end)?>
	return self
end
function cl:applyTranslate(x,y,z)
--DEBUG:assert.eq(#self.dims, 2)
--DEBUG:assert.eq(self.dims[1], 4)
--DEBUG:assert.eq(self.dims[2], 4)
	local selfptr = self.ptr
	local <?=spanvar'a'?> = <?=spanarray'selfptr'?>
	x = x or 0
	y = y or 0
	z = z or 0
<? for i=0,dims[1]-1 do
?>	selfptr[<?=ofs(i,dims[2]-1)?>] = <?=range(0,dims[2]-1):mapi(function(j,_,t)
		local avar = 'a_'..i..'_'..j
		if j == dims[2]-1 then return avar, #t+1 end	-- b_kj = 1, so return a_ik only
		local bvar = vars3[1+j]
		if not bvar then return end	-- b_kj = 0, so return nothing, no entry at all
		return avar..' * '..bvar, #t+1	-- a_ik * b_kj
	end):concat' + '?>
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
--TODO TODO TODO if I tab these over and run with langfix then mysterious 0009's pop up instead of \t's 
-- is it a limitation of %q string-escaping?
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
	<?=spanarray'selfptr'?> = <?=spanmat{
		{'cotangent / aspectRatio', '0', '0', '0'},
		{'0', 'cotangent', '0', '0'},
		{'0', '0', '-(zFar + zNear) / deltaZ', '-2 * zNear * zFar / deltaZ'},
		{'0', '0', '-1', '1'},
	}?>
	return self
end
function cl:applyPerspective(...)
	return self:mul4x4(
		self,
		metatype():setPerspective(...)
	)
end

-- calculates the inverse of 'src' or 'self' and stores it in 'self'
-- https://stackoverflow.com/a/1148405
-- inv(A^T) = inv(A)^T, so as long as src and dst have same major-ness it shouldn't matter
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

-- det(A) = det(A^T) so col vs row major doesn't matter
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
	local selfptr = self.ptr
	<?=spanarray'selfptr'?> = <?=spanfunc(function(i,j) return 'srcp['..ofs(j,i)..']' end)?>
	return self
end


]=],

	}):setmetatable(nil))
end
