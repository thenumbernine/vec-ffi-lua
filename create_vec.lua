-- TODO match with cpp/Tensor and call these int2/3/4 float2/3/4 double2/3/4 instead of vec2/3/4i/f/d ...

--[[
TODO find who uses this
rename .typeCode to .code
rename .type to .name
get rid of sizeof ?
get rid of name, just use a ffi.typeof object
add degree
add rest of Tensor library functions
make everything inlined/unrolled
--]]


local ffi = require 'ffi'
local table = require 'ext.table'
local range = require 'ext.range'
local op = require 'ext.op'
local assert = require 'ext.assert'
local template = require 'template'
local showcode = require 'template.showcode'
local suffixes = require 'vec-ffi.suffix'

local function getCachedType(dims, scalarType)
	local scalarFFIType = assert(ffi.typeof(scalarType))
	local scalarFFIName = assert(tostring(scalarFFIType):match'^ctype<(.*)>$')
	local suffix = assert.index(suffixes, scalarFFIName)
	local luaname = 'vec'..dims:concat'x'..suffix
--DEBUG:print('getCachedType', luaname)

	return package.loaded['vec-ffi.'..luaname]
end

local function setCachedType(dims, scalarType, mt)
	assert.type(mt, 'cdata')
	local mtname = op.safeindex(mt, 'name')
	if not mtname then error("failed to find name for "..tostring(mt)) end
	local vecname = assert(mtname:match'^(.*)$' , "expected vec*")

	local scalarFFIType = assert(ffi.typeof(scalarType))
	local scalarFFIName = assert(tostring(scalarFFIType):match'^ctype<(.*)>$')
	local suffix = assert.index(suffixes, scalarFFIName)
	local luaname = 'vec'..dims:concat'x'..suffix

	assert.eq(mtname, luaname)

--DEBUG:print('setCachedType', luaname)
	package.loaded['vec-ffi.'..luaname] = mt
end

local createVecType

-- NOTICE this will run createVecType on our newly cached type
-- it will skip specializations of create_vec2 and create_vec3
local function getOrCreateCachedType(dims, scalarType)
	assert.ge(#dims, 1)
--DEBUG:print('getOrCreateCachedType', require'ext.tolua'(dims), scalarType)
	local cl = getCachedType(dims, scalarType)
	if not cl then
		assert.gt(#dims, 1)
		cl = createVecType{
			dim = dims[1],
			ctype = getOrCreateCachedType(dims:sub(2), scalarType),
		}
		setCachedType(dims, scalarType, cl)
	end
	return cl
end

local function isScalar(a)
	return not op.safeindex(a, 'isVector')
end

local function matrixScaleRet(a,s)
	if isScalar(a) then return a * s end
	assert(isScalar(s))
	for i=0,a.dim-1 do
		a.s[i] = a.s[i] * s
	end
	return a
end

local function matrixScaleInto(y,a,s)
	if isScalar(a) then
		assert(not isScalar(s))
		return matrixScaleInto(y, s, a)
	end
	assert(isScalar(s))
	assert.eq(y.rank, a.rank)
	assert.eq(y.dim, a.dim)
	if y.rank == 1 then
		for i=0,a.dim-1 do
			y.s[i] = a.s[i] * s
		end
	else
		for i=0,a.dim-1 do
			matrixScaleInto(y.s[i], a.s[i], s)
		end
	end
	return y
end



-- aj and bj are 1-based indexes to contract
-- TODO make this an in-place operation
local function matrixInnerInto(y,a,b,aj,bj)
	-- now nested iter across all shared indexes
	-- and then contract the common indexes
	-- TODO code-gen this in resultType and it'll go much faster than at runtime
	-- but since the matching a's last and b's first dim can be arbitrary,
	--  we'll have to cache multiple multiplication/contraction functions...
	assert(not isScalar(y))
	if isScalar(a) then
		assert(not isScalar(b))
		return matrixScaleInto(y, b, a)
	elseif isScalar(b) then
		return matrixScaleInto(y, a, b)
	end

	local sa = table(a.dims)
	local sb = table(b.dims)
	local dega = #sa
	local degb = #sb
--DEBUG:print('dega', dega, 'degb', degb)
	if aj then
		assert.le(1, aj)
		assert.le(aj, dega)
	else
		aj = dega
	end
	if bj then
		assert.le(1, bj)
		assert.le(bj, degb)
	else
		bj = 1
	end
	local ssa = table(sa)
	local saj = ssa:remove(aj)
	local ssb = table(sb)
	local sbj = ssb:remove(bj)
	assert.eq(saj, sbj, "inner dimensions must be equal")
	local sc = table(ssa):append(ssb)

	assert(#sc > 0, "for result scalars, please use matrixInnerRet")
	local resultType = ffi.typeof(y)

	local n = #sc
	-- n == #resultType.dims == resultType.rank
	local i = table()
	for j=1,n do
		i[j] = 0
	end

	local done
	repeat
		local ia = table{table.unpack(i,1,#sa-1)}
		ia:insert(aj,0)
		local ib = table{table.unpack(i,#sa)}
		ib:insert(bj,0)

		local sum = 0
		for u=0,saj-1 do
			ia[aj] = u
			ib[bj] = u
			local ai = a:getIndex(ia:unpack())
			local bi = b:getIndex(ib:unpack())
--DEBUG:print('ia', require'ext.tolua'(ia), ai)
--DEBUG:print('ib', require'ext.tolua'(ib), bi)
			--assert.type(ai, 'number')
			--assert.type(bi, 'number')
			sum = sum + ai * bi
		end
--DEBUG:print('i', require'ext.tolua'(i), 'sum', sum)
		y:setIndex(sum, i:unpack())

		for j=n,1,-1 do
			i[j] = i[j] + 1
			if i[j] < sc[j] then break end
			i[j] = 0
			if j == 1 then done = true end
		end
	until done

	return y
end

local function matrixInnerRet(a,b,aj,bj)
	if isScalar(a) then
		if isScalar(b) then return a * b end
		return matrixScaleRet(b, a)
	elseif isScalar(b) then
		return matrixScaleRet(a,b)
	end

	local sa = table(a.dims)
	local sb = table(b.dims)
	local dega = #sa
	local degb = #sb
--DEBUG:print('dega', dega, 'degb', degb)
	if aj then
		assert.le(1, aj)
		assert.le(aj, dega)
	else
		aj = dega
	end
	if bj then
		assert.le(1, bj)
		assert.le(bj, degb)
	else
		bj = 1
	end
	local ssa = table(sa)
	local saj = ssa:remove(aj)
	local ssb = table(sb)
	local sbj = ssb:remove(bj)
	assert.eq(saj, sbj, "inner dimensions must be equal")
	local sc = table(ssa):append(ssb)

	local resultIsScalar = #sc == 0
	local resultType =
		resultIsScalar
		and a.scalarType
		or getOrCreateCachedType(sc, a.scalarType)

	local n = #sc
	-- n == #resultType.dims == resultType.rank
	local i = table()
	for j=1,n do
		i[j] = 0
	end

	local y = resultType()

	local done
	repeat
		local ia = table{table.unpack(i,1,#sa-1)}
		ia:insert(aj,0)
		local ib = table{table.unpack(i,#sa)}
		ib:insert(bj,0)

		local sum = 0
		for u=0,saj-1 do
			ia[aj] = u
			ib[bj] = u
			local ai = a:getIndex(ia:unpack())
			local bi = b:getIndex(ib:unpack())
--DEBUG:print('ia', require'ext.tolua'(ia), ai)
--DEBUG:print('ib', require'ext.tolua'(ib), bi)
			--assert.type(ai, 'number')
			--assert.type(bi, 'number')
			sum = sum + ai * bi
		end
--DEBUG:print('i', require'ext.tolua'(i), 'sum', sum)
		if resultIsScalar then
			y = sum
			break
		else
			y:setIndex(sum, i:unpack())
		end

		for j=n,1,-1 do
			i[j] = i[j] + 1
			if i[j] < sc[j] then break end
			i[j] = 0
			if j == 1 then done = true end
		end
	until done

	return y
end

-- row-major, zero-based
-- such that A.si.sj <=> A.ptr[index(i,j)]
-- such that C notation is math notation
-- from (i1,i2,...,in) 0-based
-- to the offset in ptr[] of the element within the matrix
local function matrixIndexOffset(a, ...)
	local dims = a.dims
	local n = select('#', ...)
	assert.eq(n, #dims)
	local j = 0
	for i,si in ipairs(a.storage) do
		local si1 = si + 1
		j = j * dims[si1]
		j = j + select(si1, ...)
	end
	return j
end

-- for-loop but single access
local function matrixGetIndex(a, ...)
	return a.ptr[a:indexOffset(...)]
end

-- for-loop but single access
local function matrixSetIndex(a, x, ...)
	a.ptr[a:indexOffset(...)] = x
end

local function matrixGetIndexR(a, ...)
	-- multiple access tail call / no for-loop
	-- TODO make this respect .storage (but how? using .storage? using .storageInv?)
	local n = select('#', ...)
	assert.gt(n, 0)
	if n == 1 then
		return a.s[...]
	else
		return matrixGetIndexR(a.s[...], select(2, ...))
	end
end

-- setter with recursive .s[] dereferencing
-- multiple access tail call / no for-loop
local function matrixSetIndexR(a, x, ...)
	local n = select('#', ...)
	assert.gt(n, 0)
	if n == 1 then
		a.s[...] = x
	else
		return matrixSetIndexR(a.s[...], x, select(2, ...))
	end
end

--[[
args:
	dim = vector dimension
	ctype = vector element type
	vectype = (optional) vector class name.	 default = vec<dim><suffix>
	fields = (optional) list of fields to use.  default = xyzw.
	suffix = (optional) suffix of classname.  defaults are above.  not used if vectype is provided.
	classCode = (optional) additional functions to put in the metatable
	storage = (optional) order of index offsetting.
		col major = n-1..0
		row major = 0..n-1
		NOTICE storage affects:
			- __mul
			- matrix-multiply
			- :indexOffset
			- :get/setIndex
			storage does not affect:
			- .x.y.z nested indexing (this is ofc hard-coded to C standard, which is row-major)
	rowMajor = shorthand for storage 0..n-1
	colMajor = shorthand for storage n-1..0
--]]
local createVecType = function(args)
--DEBUG:print'create_vec'
	assert(args)
	args = table(args)
	assert(args.dim)
--DEBUG:print('', 'dim='..args.dim)
	args.ctype = ffi.typeof((assert.index(args, 'ctype')))
--DEBUG:print('', 'ctype='..tostring(args.ctype))

	args.classCode = args.classCode or ''

	local ctypemt = op.safeindex(args.ctype, 'metatable')
	args.scalarType = op.safeindex(ctypemt, 'scalarType') or args.ctype
--DEBUG:print('', 'scalarType='..tostring(args.scalarType))
	args.scalarType = assert(ffi.typeof(args.scalarType))

	args.dims = table(op.safeindex(ctypemt, 'dims') or {}):append{args.dim}
--DEBUG:print('', 'dims='..args.dims:concat'x')

	args.rank = #args.dims

	--[[
	our new class is prepending an index on the left.
	i.e. vec3f is v_i, then vec3x3f is v_ji, where 'j' is the new index and 'i' maps to the inner storage's index
	setting colMajor means set the left-most index to rank-1
	setting rowMajor means set the left-most index to 0 and bump all subsequent indexes
	--]]
	local prevStorage = op.safeindex(args.ctype, 'storage') or table()
	if args.colMajor then
		assert(not args.rowMajor, "can't use rowMajor and colMajor")
		assert(not args.storage, "can't use rowMajor and storage")
		args.storage = table{args.rank-1}:append(prevStorage)
	elseif args.rowMajor
	or not args.storage	-- default to row-major to match C
	then
		assert(not args.storage, "can't use rowMajor and storage")
		args.storage = table{0}:append(prevStorage:mapi(function(i) return i+1 end))
	end
	assert.len(args.storage, args.rank)

	-- me thinking about caching types to prevent duplicate type-generation for when I need to create arbitrary-typed results in my math operations
	-- but I won't want to cache non-vec classes that use this, such as box, plane, quat ...
	local cacheThisAsAVectorClass
	if not args.vectype then
		cacheThisAsAVectorClass = true

		-- suffix is only needed for our cached-and-generated classes i.e. vec2x2f vec3x3f vec4x4f etc
		if not args.suffix then
			local scalarFFIName = assert(tostring(args.scalarType):match'^ctype<(.*)>$')
			args.suffix = assert.index(suffixes, scalarFFIName)
		end
--DEBUG:print('', 'suffix='..args.suffix)

		-- TODO should match the cache stuff above
		local nesting = args.dims:concat'x'..args.suffix
		args.vectype = 'vec'..nesting
--DEBUG:print('making vectype name', args.vectype)
	end

	args.fields = (args.fields or table{'x', 'y', 'z', 'w'}):sub(1, args.dim)

	-- handoff to code's env
	args.matrixInnerRet = matrixInnerRet
	args.matrixInnerInto = matrixInnerInto
	args.matrixIndexOffset = matrixIndexOffset
	args.args = args

	-- cuz I am tired of syntax highlighting being missing, and having to copy through scope so many times ...
	args.modifyMetatable = function(cl)
		cl.ctype = args.ctype
		cl.scalarType = args.scalarType
		cl.dim = args.dim
		cl.dims = args.dims
		cl.rank = args.rank
		cl.storage = args.storage
		cl.isVector = true
		cl.getIndex = matrixGetIndex
		cl.setIndex = matrixSetIndex
		cl.getIndexR = matrixGetIndexR
		cl.setIndexR = matrixSetIndexR
		cl.indexOffset = matrixIndexOffset
	end

	local code = template([=[
local ffi = require 'ffi'
local math = require 'ext.math'
local args = ...
local cl = args.cl
local matrixInnerRet = args.matrixInnerRet
local matrixInnerInto = args.matrixInnerInto
local matrixIndexOffset = args.matrixIndexOffset

local metatype

local function modifyMetatable(cl)
	args.modifyMetatable(cl)


	-- TODO get rid of this one? just use ffi.sizeof ?
	-- or move this back to struct?
	cl.sizeof = ffi.sizeof(cl.name)

	-- TODO no more :set on cdata or table, just on raw values
	-- use separate methods for the others
	-- prevent some if conditions
	cl.set = function(self, v, v2, ...)
		if type(v) == 'cdata' then
			<?=fields:mapi(function(x) return 'self.'..x..' = v.'..x end):concat(' ')?>
		elseif type(v) == 'table' then
			<?=fields:mapi(function(x,key) return 'self.'..x..' = v['..key..']' end):concat(' ')?>
		else
			if v2 == nil then
				<?=fields:mapi(function(x,key) return 'self.'..x..' = v' end):concat(' ')?>
			else
				local args = {v, v2, ...}
				assert(#args >= <?=dim?>)
				<?=fields:mapi(function(x,key) return 'self.'..x..' = args['..key..']' end):concat(' ')?>
			end
		end
		return self
	end


	-- from here on our, vec-specific functions:


	<? -- operations that are per-component or scalar
	local table = require 'ext.table'
	local op = require 'ext.op'

	local opnames = table{
		'add', 'sub', 'mul', 'div', 'mod', 'pow',
		-- >= 5.3
		'idiv', 'band', 'bor', 'bxnot', 'shl', 'shr',
	}

	local opinfos = opnames:mapi(function(name,_,t)
		local symbol = op.symbols[name]
		if symbol then
			return {name=name, symbol=symbol}, #t+1
		end
	end)

	-- TODO unary operators

	for _,info in ipairs(opinfos) do
?>	cl.__<?=info.name?> = function(a,b)
		if type(b) == 'cdata' then
			if type(a) == 'number' then
				return metatype(<?=fields:mapi(function(x)
					return 'a'..info.symbol..'b.'..x
				end):concat(', ')?>)
			end
<? if info.name == 'mul' then
-- just for mul of rank-n vectors, outer+contract the result
-- hmm that means mul only works with types available provided the ranks are 1 or 2 ...
-- (or depending on if the dims match)
-- ... otherwise, we would need access to types other than 'a' or 'b'
-- ... and that means i need some sort of type caching / namespace
?>
			return matrixInnerRet(a, b, #a.dims, 1)

<? else ?>
			return metatype(<?=fields:mapi(function(x)
				return 'a.'..x..info.symbol..'b.'..x
			end):concat(', ')?>)
<? end ?>
		end
		b = tonumber(b)
		if b == nil then
			error("can't handle "..tostring(b).." (type "..type(b)..")")
		end
		return metatype(<?=fields:mapi(function(x)
			return 'a.'..x..info.symbol..'b'
		end):concat(', ')?>)
	end
<? end
?>
	cl.__unm = function(v)
		return v * -1
	end

	cl.map = function(v, m)
		return metatype(<?=
			fields:mapi(function(x,i)
				return 'm(v.'..x..', '..(i-1)..')'
			end):concat', '
		?>)
	end

	cl.lenSq = function(a)
		return a:dot(a)
	end

	-- naming compat with Matlab/matrix
	cl.normSq = function(a)
		return a:dot(a)
	end

	cl.length = function(a)
		return math.sqrt(a:lenSq())
	end

	cl.norm = function(a)
		return math.sqrt(a:lenSq())
	end
	cl.distance = function(a, b)
		return (a - b):length()
	end

	cl.dot = function(a,b)
		return <?=
fields:mapi(function(x) return 'a.'..x..' * b.'..x end):concat(' + ')
?>	end

	cl.normalize = function(v)
		return v / v:length()
	end

	cl.unit = function(v)
		return v / v:length()
	end

	cl.unitOrZeroEpsilon = 1e-7

	-- useful for surface normal / quaternion angle/axis
	cl.unitOrZero = function(v, eps)
		eps = eps or metatype.unitOrZeroEpsilon
		local vlen = v:norm()
		if vlen <= eps or not math.isfinite(vlen) then
			return metatype(), vlen
		end
		return v / vlen, vlen
	end

	cl.lInfLength = function(v)	-- L-infinite length
		local fp = v.s
		local dist = math.abs(fp[0])
		for i=1,<?=dim?>-1 do
			dist = math.max(dist, math.abs(fp[i]))
		end
		return dist
	end

	cl.l1Length = function(v)	--L-1 length
		local fp = v.s
		local dist = math.abs(fp[0])
		for i=1,<?=dim?>-1 do
			dist = dist + math.abs(fp[i])
		end
		return dist
	end

	-- TODO call this 'product'
	cl.volume = function(v)
		return <?=fields:mapi(function(x) return 'v.'..x end):concat(' * ')?>
	end

	-- normal first so the function arguments can be 1:1 with plane project
	cl.project = function(n, v)
		return v - n * (n:dot(v) / n:dot(n))
	end

	cl.elemMul = function(a,b)
		local v = metatype()
		for i=0,<?=dim?>-1 do
			v.s[i] = a.s[i] * b.s[i]
		end
		return v
	end

--[[
	cl.outer = function(a,b)
		local A = ffi.typeof(a)
		local B = ffi.typeof(b)
		local result = A:replaceInner(B)()

		-- TODO now we need a scalar-most element iterator
		for i=0,<?=dim-1?> do

			result.s[i] = a.s[i] * b
		end

		return result
	end,
--]]

	-- in-place multiplication
	cl.mul = matrixInnerInto

-- allow the caller to override/add any functions

]=]
-- concat so the classCode can contain templated code
..args.classCode
..[=[

end

-- do this declartion inside the templated code
-- so that we can also use the same scope for storing `metatype`
-- and also reference that within the subclass-provided `classCode`
local range = require 'ext.range'
local struct = require 'struct'
metatype = struct{
	name = args.vectype,
	union = true,
	fields = {
		-- struct has to come first for the ffi api to allow component initialization
		{
			type = struct{
				anonymous = true,
				fields = args.fields:mapi(function(fieldname)
					return {name=fieldname, type=args.ctype}
				end),
			},
		},

		{
			type = struct{
				anonymous = true,
				fields = range(0, args.dim-1):mapi(function(i)
					return {name='s'..i, type=args.ctype}
				end),
			},
			no_iter = true,
		},

		{
			name = 's',
			type = ffi.typeof('$['..#args.fields..']', args.ctype),
			no_iter = true,
		},

		-- really I'm only calling this "ptr" for matrix.ffi compat ...
		{
			name = 'ptr',
			type = ffi.typeof('$['..args.dims:product()..']', args.scalarType),
			no_iter = true,
		},
	},
	metatable = modifyMetatable,
}

return metatype
]=], args)
--DEBUG:print()
--DEBUG:print(showcode(code))
--DEBUG:print()

	local func, msg = load(code)
	if not func then
		io.stderr:write(showcode(code), '\n')
		error(msg)
	end
	local metatype = func(args)
	do
		local vecsize = ffi.sizeof(args.vectype)
		local elemsize = ffi.sizeof(args.ctype)
		if vecsize ~= args.dim * elemsize then
			print(metatype.code)
			error("struct sizes mismatch, expected ffi.sizeof("..args.vectype..") = "..vecsize.." to equal args.dim = "..args.dim.." * ffi.sizeof("..args.ctype..") = "..elemsize)
		end
	end

	if cacheThisAsAVectorClass then
		setCachedType(args.dims, args.scalarType, metatype)
	end

	return metatype
end

return createVecType
