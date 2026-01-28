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
local template = require 'template'
local showcode = require 'template.showcode'
local suffix = require 'vec-ffi.suffix'

--[[
args:
	dim = vector dimension
	ctype = vector element type
	vectype = (optional) vector class name.	 default = vec<dim><suffix>_t
	fields = (optional) list of fields to use.  default = xyzw.
	suffix = (optional) suffix of classname.  defaults are above.
	classCode = (optional) additional functions to put in the metatable
--]]
return function(args)
	assert(args)
	args = table(args)
	assert(args.dim)
	assert(args.ctype)
	args.suffix = args.suffix or suffix[args.ctype]
	args.classCode = args.classCode or ''
	args.vectype = args.vectype or 'vec'..args.dim..args.suffix..'_t'
	args.fields = (args.fields or table{'x', 'y', 'z', 'w'}):sub(1, args.dim)

	local code = template([=[
local ffi = require 'ffi'
local math = require 'ext.math'
local args = ...
local cl = args.cl
local dim = args.dim
local vectype = args.vectype
local ctype = args.ctype

local metatype

local function modifyMetatable(cl)

	cl.elemType = ctype
	cl.dim = <?=dim?>

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
			return metatype(<?=fields:mapi(function(x)
				return 'a.'..x..info.symbol..'b.'..x
			end):concat(', ')?>)
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
		local resultType = vec<b.type>
		local result = resultType()
		for i=0,<?=dim-1?> do
			result.s[i] = a.s[i] * b
		end
		return result
	end,
--]]

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
				fields = range(0, dim-1):mapi(function(i)
					return {name='s'..i, type=args.ctype}
				end),
			},
			no_iter = true,
		},

		{
			name = 's',
			type = args.ctype..'['..#args.fields..']',
			no_iter = true,
		},
	},
	metatable = modifyMetatable,
}

return metatype
]=], args)
	local func, msg = load(code)
	if not func then
		error('\n'..showcode(code)..'\n'..msg)
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
	return metatype
end
