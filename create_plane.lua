local table = require 'ext.table'
local template = require 'template'
local showcode = require 'template.showcode'
local suffixes = require 'vec-ffi.suffix'

return function(args)
	local dim = assert(args.dim)
	local ctype = assert(args.ctype)

	local suffix = suffixes[ctype]
	args.suffix = suffix
	local vecNType = require('vec-ffi.vec'..dim..suffix)
	args.vecNType = vecNType
	-- TODO cache these classes somewhere better, where you don't need a new file for each new ctype?
	-- how about within create_vec?
	-- TODO remove the _t ?
	args.planeType = 'plane'..dim..suffix..'_t'
	args.vecNPlusOneType = require('vec-ffi.vec'..(dim+1)..suffix)

	args.fields = table{'n', 'negDist'}

	local code = template([=[
local args = ...
local ffi = require 'ffi'
<?
local range = require 'ext.range'
local dim = vecNType.dim
?>

local dim = <?=dim?>

local typeCode = [[
typedef union <?=planeType?> {
	struct {
		<?=vecNType.type?> n;
		<?=ctype?> negDist;
	};
	<?=vecNPlusOneType.type?> v;
	<?=ctype?> s[<?=dim+1?>];
} <?=planeType?>;
]]

ffi.cdef(typeCode)
assert(ffi.sizeof'<?=planeType?>' == ffi.sizeof'<?=vecNPlusOneType.type?>')

local metatype
local cl = {
	sizeof = ffi.sizeof('<?=planeType?>'),
	type = '<?=planeType?>',	-- TODO 'name' ?
	elemType = '<?=ctype?>',

	-- this is the dimension the plane resides in
	-- so the plane is dim+1 elements
	dim = dim,

	typeCode = typeCode,

	-- matches behavior ext.class
	-- but ofc no inheritence
	-- duplicated from vec-ffi.create_vec
	isa = function(o)
		return type(o) == 'cdata'
		and ffi.typeof(o) == metatype
	end,

	-- duplicated from vec-ffi.create_vec
	unpack = function(self)
		return self.v:unpack()
	end,

	-- TODO between this and ffi.cpp.vector, one is toTable the other is totable ... which to use?
	-- duplicated from vec-ffi.create_vec
	toTable = function(self)
		return {self.v:unpack()}
	end,

	__eq = function(a,b)
		if not (type(a) == 'table' or type(a) == 'cdata')
		or not (type(b) == 'table' or type(b) == 'cdata')
		then
			return false
		end
		return <?=fields:mapi(function(x) return 'a.'..x..' == '..'b.'..x end):concat(' and ')?>
	end,

	__tostring = function(self)
		return '(' .. <?=
			fields:mapi(function(x)
				return 'tostring(self.'..x..')'
			end):concat(' .. ", " .. ')
		?> .. ')'
	end,

	__concat = function(a, b)
		return tostring(a) .. tostring(b)
	end,


-- from here on our, plane-specific functions:

	fromDirAndPt = function(self, dir, pt)
		-- normalize?
		self.n = dir:normalize()
		self:setPt(pt)
	end,

	setPt = function(self, pt)
		self.negDist = -pt:dot(self.n)
	end,

	dist = function(self, pt)
		return self.n:dot(pt) + self.negDist
	end,
}

cl.__index = cl
metatype = ffi.metatype('<?=planeType?>', cl)
return metatype
	]=], args)
	local func, msg = load(code)
	if not func then
		error('\n'..showcode(code)..'\n'..msg)
	end
	return func(args)
end

