local ffi = require 'ffi'
local table = require 'ext.table'
local template = require 'template'
local showcode = require 'template.showcode'
local suffixes = require 'vec-ffi.suffix'

return function(vectype)
	assert(vectype)

	local dim = vectype.dim
	local ctype = ffi.typeof(vectype.ctype)
	local ctypename = tostring(ctype):match'^ctype<(.*)>$'
	local suffix = suffixes[ctypename]

	local args = {
		dim = dim,
		suffix = suffix,
		ctype = ctype,
		vectype = vectype,
		-- TODO remove the _t ?
		boxtype = 'box'..dim..suffix..'_t',
		fields = table{'min', 'max'},
	}

	local code = template([=[
<?
local range = require 'ext.range'
?>
-- class to match 'vectype'
local args = ...
local vectype = args.vectype
local dim = args.dim
local ffi = require 'ffi'
local op = require 'ext.op'

local metatype

local function modifyMetatable(cl)

	cl.ctype = ffi.typeof'<?=vectype.name?>'
	cl.dim = dim
	cl.sizeof = ffi.sizeof(cl.name)

	-- from here on our, box-specific functions:

	cl.__mul = function(a,b)
		if metatype:isa(a) and type(b) == 'number' then
			return metatype(a.min * b, a.max * b)
		elseif type(a) == 'number' and metatype:isa(b) then
			return metatype(a * b.min, a * b.max)
		else
			error"don't know how to multiply bbox with this"
		end
	end

	-- static initializer for empty box
	cl.empty = function()
		return metatype(
			vectype(<?=range(dim):mapi(function() return 'math.huge' end):concat', '?>),
			vectype(<?=range(dim):mapi(function() return '-math.huge' end):concat', '?>)
		)
	end

	cl.size = function(self)
		return self.max - self.min
	end

	-- 'b' is a 'box3', clamps 'self' to be within 'b'
	cl.clamp = function(self, b)
		for i=0,dim-1 do
			if self.min.s[i] < b.min.s[i] then self.min.s[i] = b.min.s[i] end
			if self.max.s[i] > b.max.s[i] then self.max.s[i] = b.max.s[i] end
		end
		return self
	end

	-- 'v' is a vec3, stretches 'self' to contain 'v'
	-- TODO same could be done with a box, stretch self's min by b's min, stretch self's max by b's max
	cl.stretch = function(self, ...)
		local vmin, vmax
		local n = select('#', ...)
		if n == 0 then
			error("box.stretch needs an arg")
		elseif n == 1 then
			local varg = ...
			-- <?=boxtype?>:isa(varg) won't cast between boxtypes ...
			-- wish luajit behavior had stuck to Lua convention of returning nil (fast) over throwing errors (slow) for simple things like accessing fields or detecting types ...
			if type(varg) == 'cdata'
			and tostring(ffi.typeof(varg)):sub(1,15) == 'ctype<union box'
			then
				vmin, vmax = varg.min, varg.max
			else
				vmin, vmax = varg, varg
			end
		else
			vmin, vmax = ...
		end
		for i=0,dim-1 do
			self.min.s[i] = math.min(self.min.s[i], vmin.s[i])
			self.max.s[i] = math.max(self.max.s[i], vmax.s[i])
		end
	end

	-- get the i'th corner, i in [0, 2^dim)
	cl.corner = function(self, i)
		local v = vectype()
		for j=0,dim-1 do
			local side = bit.band(bit.rshift(i, j), 1) == 1
			v.s[j] = side and self.min.s[j] or self.max.s[j]
		end
		return v
	end

	cl.contains = function(self, ...)
		local vmin, vmax
		local n = select('#', ...)
		if n == 0 then
			error("box.stretch needs an arg")
		elseif n == 1 then
			local varg = ...
			-- <?=boxtype?>:isa(varg) won't cast between boxtypes ...
			if (type(varg) == 'cdata' or type(varg) == 'table')
			-- NOTICE if varg is cdata then the next test will error upon failure
			-- because luajit decided to error on invalid index instead of lua's just-return-nil behavior
			-- and NOTICE I can get around it by using op.safeindex
			-- BUT this is a xpcall and it is slow!
			and op.safeindex(varg, 'min')
			and op.safeindex(varg, 'max')
			then
				vmin, vmax = varg.min, varg.max
			else
				vmin, vmax = varg, varg
			end
		else
			vmin, vmax = ...
		end
		for i=0,dim-1 do
			if vmin.s[i] < self.min.s[i] or vmax.s[i] > self.max.s[i] then return false end
		end
		return true
	end

	cl.touches = function(self, ...)
		local vmin, vmax
		local n = select('#', ...)
		if n == 0 then
			error("box.stretch needs an arg")
		elseif n == 1 then
			local varg = ...
			-- <?=boxtype?>:isa(varg) won't cast between boxtypes ...
			if (type(varg) == 'cdata' or type(varg) == 'table') and varg.min and varg.max then
				vmin, vmax = varg.min, varg.max
			else
				vmin, vmax = varg, varg
			end
		else
			vmin, vmax = ...
		end
		for i=0,dim-1 do
			if vmin.s[i] > self.max.s[i] or vmax.s[i] < self.min.s[i] then return false end
		end
		return true
	end

	-- returns the coefficient of intersection of line segment from a to b
	cl.intersectLineSeg = function(self, a, b)
--print('self', self)
		if self:contains(a) then return 0 end
--print('a', a)
--print('b', b)
		local d = b - a
--print('d', d)
		local bestS
		for i=0,dim-1 do
--print('test side', i)
			-- a_i + s * (b_i - a_i) = min or max = m
			-- s = (m - a_i) / (b_i - a_i)
			local s
			if d.s[i] > 0 then	-- test for collision with min
--print('di', d.s[i], 'ai', a.s[i], 'min', self.min.s[i])
				s = (self.min.s[i] - a.s[i]) / d.s[i]
			elseif d.s[i] < 0 then -- test for collision with max
--print('di', d.s[i], 'ai', a.s[i], 'max', self.max.s[i])
				s = (self.max.s[i] - a.s[i]) / d.s[i]
			end
--print('s',s)
			if s and s >= 0 and s <= 1 then
				local p = a + d * s
--print('p', p)
				local oob
				for j=0,dim-2 do
					local k = (i+j+1)%dim
					if p.s[k] < self.min.s[k] or p.s[k] > self.max.s[k] then
						oob = true
						break
					end
				end
				if not oob then
					if not bestS or s < bestS then
						bestS = s
					end
				end
			end
		end
		return bestS
	end
end

local range = require 'ext.range'
local struct = require 'struct'
metatype = struct{
	name = args.boxtype,
	union = true,
	fields = {
		-- struct has to come first for the ffi api to allow component initialization
		{
			type = struct{
				anonymous = true,
				fields = args.fields:mapi(function(fieldname)
					return {name=fieldname, type=vectype.name}
				end),
			},
		},

		{
			name = 's',
			type = vectype.name..'[2]',
			no_iter = true,
		},
	},
	metatable = modifyMetatable,
}


local code = [[
typedef union <?=boxtype?> {
	struct {
		<?=vectype.name?> <?=fields:concat', '?>;
	};
	<?=vectype.name?> s[2];
} <?=boxtype?>;
]]

assert(ffi.sizeof'<?=boxtype?>' == 2 * ffi.sizeof'<?=vectype.name?>')

return metatype
	]=], args)
	local func, msg = load(code)
	if not func then
		error('\n'..showcode(code)..'\n'..msg)
	end
	return func(args)
end
