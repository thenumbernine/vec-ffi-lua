local table = require 'ext.table'
local template = require 'template'


local allfields = table{'x', 'y', 'z', 'w'}


return function(dim, ctype, suffix, classCode)
	classCode = classCode or ''

	local vectorType = 'vec'..dim..suffix..'_t'
	local xs = allfields:sub(1,dim)

	local code = template([=[
local ffi = require 'ffi'

ffi.cdef[[
typedef union {
	//struct has to come first for the ffi api to allow component initialization
	struct {
		<?=ctype?> <?=xs:concat', '?>;
	};
	
	<?=ctype?> s[<?=dim?>];
} <?=vectorType?>;
]]
assert(ffi.sizeof'<?=vectorType?>' == <?=dim?> * ffi.sizeof'<?=ctype?>')

local vectorClass
vectorClass = ffi.metatype('<?=vectorType?>', {

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
?>	__<?=info.name?> = function(a,b)
		if type(b) == 'cdata' then
			return vectorClass( <?=xs:mapi(function(x) 
				return 'a.'..x..info.symbol..'b.'..x 
			end):concat(', ')?>)
		end
		b = tonumber(b)
		if b == nil then 
			error("can't handle "..tostring(b).." (type "..type(b)..")") 
		end
		return vectorClass(<?=xs:mapi(function(x) 
			return 'a.'..x..info.symbol..'b' 
		end):concat(', ')?>)
	end,
<? end
?>
	__unm = function(v) return v * -1 end,
	__eq = function(a,b) 
		return <?=xs:mapi(function(x) return 'a.'..x..' == '..'b.'..x end):concat(' and ')?>
	end,
	__len = function(a) return a:length() end,
	__tostring = function(v)
		return '(' .. <?=
			xs:mapi(function(x) return 'tostring(v.'..x..')' end):concat(' .. ", " .. ')
		?> .. ')'
	end,
	__concat = function(a,b) return tostring(a) .. tostring(b) end,
	__index = {	-- TODO make __index point to self?
		sizeof = ffi.sizeof('<?=vectorType?>'),	
		type = '<?=vectorType?>',
		elemType = '<?=ctype?>',
		dim = <?=dim?>,	-- # is for length, dim is for dimension
		length = function(a) return math.sqrt(a:lenSq()) end,
		lenSq = function(a) return a:dot(a) end,
		dot = function(a,b) return <?=
			xs:mapi(function(x) return 'a.'..x..' * b.'..x end):concat(' + ')
		?> end,
		normalize = function(v) return v / #v end,
		
		lInfLength = function(v)	-- L-infinite length
			local fp = v.s
			local dist = math.abs(fp[0])
			for i=1,<?=dim?>-1 do
				dist = math.max(dist, math.abs(fp[i]))
			end
			return dist
		end,
		l1Length = function(v)	--L-1 length
			local fp = v.s
			local dist = math.abs(fp[0])
			for i=1,<?=dim?>-1 do
				dist = dist + math.abs(fp[i])
			end
			return dist
		end,
		
		volume = function(v)
			return <?=xs:mapi(function(x) return 'v.'..x end):concat(' * ')?>
		end,
		
		set = function(self, v, v2, ...)
			if type(v) == 'cdata' then
				<?=xs:mapi(function(x) return 'self.'..x..' = v.'..x end):concat(' ')?>
			elseif type(v) == 'table' then
				<?=xs:mapi(function(x,key) return 'self.'..x..' = v['..key..']' end):concat(' ')?>
			else
				if v2 == nil then
					<?=xs:mapi(function(x,key) return 'self.'..x..' = v' end):concat(' ')?>
				else
					local args = {v, v2, ...}
					assert(#args == <?=dim?>)
					<?=xs:mapi(function(x,key) return 'self.'..x..' = args['..key..']' end):concat(' ')?>
				end
			end
			return self
		end,
		unpack = function(self) return <?=xs:mapi(function(x) return 'self.'..x end):concat(', ')?> end,
		toTable = function(self) return {self:unpack()} end,

		<?=classCode?>
	},
})
return vectorClass
]=],	{
			dim = dim,
			ctype = ctype,
			classCode = classCode,
			vectorType = vectorType,
			xs = xs,
		})
	local func, err = load(code)
	if not func then
		print(err, debug.traceback())
		print('code:')
		print(code)
	end
	return func()
end
