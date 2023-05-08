local table = require 'ext.table'
local template = require 'template'
local showcode = require 'template.showcode'
local suffix = require 'vec-ffi.suffix'

return function(vectype)
	assert(vectype)
	
	local dim = vectype.dim 
	local suffix = suffix[vectype.elemType]

	local code = template([=[
-- class to match 'vectype'
local vectorClass = ...
local ffi = require 'ffi'
<?
local range = require 'ext.range'
local dim = vectype.dim
?>

local dim = <?=dim?>

local typeCode = [[
typedef union {
	struct {
		<?=vectype.type?> <?=fields:concat', '?>;
	};
	<?=vectype.type?> s[2];
} <?=boxtype?>;
]]

ffi.cdef(typeCode)
assert(ffi.sizeof'<?=boxtype?>' == 2 * ffi.sizeof'<?=vectype.type?>')

local metatype
local cl = {
	sizeof = ffi.sizeof('<?=boxtype?>'),
	type = '<?=boxtype?>',	-- TODO 'name' ?
	elemType = '<?=vectype.type?>',
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
		return <?=fields:mapi(function(x) return 'self.'..x end):concat', '?>
	end,
	
	-- TODO between this and ffi.cpp.vector, one is toTable the other is totable ... which to use?
	-- duplicated from vec-ffi.create_vec
	toTable = function(self)
		return {self:unpack()}
	end,


	-- 'b' is a 'box3', clamps 'self' to be within 'b'
	clamp = function(self, b)
		for i=0,2 do
			if self.min.s[i] < b.min.s[i] then self.min.s[i] = b.min.s[i] end
			if self.max.s[i] > b.max.s[i] then self.max.s[i] = b.max.s[i] end
		end
		return self
	end,

	-- 'v' is a vec3, stretches 'self' to contain 'v'
	-- TODO same could be done with a box, stretch self's min by b's min, stretch self's max by b's max
	stretch = function(self, v)
		for i=0,2 do
			self.min.s[i] = math.min(self.min.s[i], v.s[i])
			self.max.s[i] = math.max(self.max.s[i], v.s[i])
		end
	end,

	-- static initializer for empty box
	empty = function()
		return metatype(
			vectorClass(<?=range(dim):mapi(function() return 'math.huge' end):concat', '?>),
			vectorClass(<?=range(dim):mapi(function() return '-math.huge' end):concat', '?>)
		)
	end,

	-- get the i'th corner, i in [0, 2^dim)
	corner = function(self, i)
		local v = vectorClass()
		for j=0,dim-1 do
			local side = bit.band(bit.rshift(i, j), 1) == 1
			v.s[j] = side and self.min.s[j] or self.max.s[j]
		end
		return v
	end,
}

cl.__index = cl
metatype = ffi.metatype('<?=boxtype?>', cl)
return metatype
	]=], {
		-- TODO remove the _t ?
		vectype = vectype,
		boxtype = 'box'..dim..suffix..'_t',
		fields = table{'min', 'max'},
	})
	local func, msg = load(code)
	if not func then
		error('\n'..showcode(code)..'\n'..msg)
	end
	return func(vectype)
end
