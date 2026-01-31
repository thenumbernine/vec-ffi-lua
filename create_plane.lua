local ffi = require 'ffi'
local assert = require 'ext.assert'
local table = require 'ext.table'
local template = require 'template'
local showcode = require 'template.showcode'
local suffixes = require 'vec-ffi.suffix'

return function(args)
	local dim = assert(args.dim)
	local ctype = ffi.typeof((assert.index(args, 'ctype')))
	local ctypename = tostring(ctype):match'^ctype<(.*)>$'

	local suffix = suffixes[ctypename]
	args.suffix = suffix
	local vecNType = require('vec-ffi.vec'..dim..suffix)
	args.vecNType = vecNType
	-- TODO cache these classes somewhere better, where you don't need a new file for each new ctype?
	-- how about within create_vec?
	-- (but if you use create_vec, be sure to let it know not to cache this as a vec-type to be used for matrix operations)
	-- TODO remove the _t ?
	args.planeType = 'plane'..dim..suffix..'_t'
	args.vecNPlusOneType = require('vec-ffi.vec'..(dim+1)..suffix)

	args.fields = table{'n', 'negDist'}

	local code = template([=[
local args = ...
local ffi = require 'ffi'
<?
local dim = vecNType.dim
?>

local dim = <?=dim?>

local metatype

local function modifyMetatable(cl)
	cl.ctype = ffi.typeof'<?=ctype?>'
	-- this is the dimension the plane resides in
	-- so the plane is dim+1 elements
	cl.dim = dim
	cl.sizeof = ffi.sizeof('<?=planeType?>')

	-- from here on our, plane-specific functions:

	cl.__unm = function(self)
		return metatype(-self.n, -self.negDist)
	end

	-- (x - pt) dot dir > 0
	-- x dot dir - pt dot dir > 0
	-- let p_i = dir_i
	-- and p_w = -pt dot dir
	-- x_i p_i + p_w > 0
	cl.fromDirPt = function(self, dir, pt)
		-- normalize?
		self.n = dir:normalize()
		self:setPt(pt)
		return self
	end

	cl.setPt = function(self, pt)
		self.negDist = -pt:dot(self.n)
	end

	-- get a point on the plane closest to origin
	-- plane eqn: v . n + negDist = 0
	-- let v = -n * negDist / (n . n)
	-- (-n * negDist / (n . n)) . n = -negDist
	-- -negDist = -negDist
	-- true
	cl.getPt = function(self)
		return -self.n * self.negDist / self.n:lenSq()
	end

	cl.dist = function(self, pt)
		return self.n:dot(pt) + self.negDist
	end

	cl.test = function(self, pt)
		return self:dist(pt) >= 0
	end

	-- project point x onto plane:
	-- x' = x - c n
	-- s.t. x' . n + negDist = 0
	-- (x - c n) . n + negDist = 0
	-- x . n - c n . n + negDist = 0
	-- c = (negDist + x.n) /  (n.n)
	-- c = dist(x) /  (n.n)
	-- x' = x - n * dist(x) / n.n
	-- x' = x - n * (x.n + negDist) / n.n
	-- x' = x - n * x.n / n.n - n * negDist / n.n
	-- x' = project(n,x) - n * negDist / n.n
	cl.project = function(self, x)
		return x - self.n * (self:dist(x) / self.n:lenSq())
	end

	-- project a vector v onto plane
	-- v' . n = 0
	-- v' = v - n (v . n) / (n . n)
	-- v . n - n . n (v . n) / (n.n) = 0
	-- 0 = 0
	-- but this is a vec3 function, not a plane3 function
	cl.projectVec = function(self, v)
		return self.n:project(v)
	end

	-- pt and dir are the ray's point and direction
	cl.intersectRay = function(self, pt, dir)
		-- ((rayPos + s * rayDir) - planePt) dot planeNormal = 0
		-- rayPos dot planeNormal + s * rayDir dot planeNormal - planePt dot planeNormal = 0
		-- s = ((planePt - rayPos) dot planeNormal) / (rayDir dot planeNormal)
		local s = (self:getPt() - pt):dot(self.n) / self.n:dot(dir)
		return pt + dir * s, s
	end

	-- transform a plane by a 4x4 matrix
	-- 3D plane test:
	-- p_i v_i + p_w > 0
	-- 3D transformed point / plane test:
	-- p_i M3_ij v_j + p_w > 0
	-- p'_i v_i + p_w > 0
	-- for p'_j = p_i M3_ij
	-- 3x4 transformed point / plane test:
	-- for M4_ij (v_j, 1) = M3_ij v_j + M4_i
	-- p_i (M3_ij v_j + M4_i) + p_w > 0
	-- (p_i M3_ij) v_j + (p_i M4_i + p_w) > 0
	-- so p'_j = p_i M3_ij
	-- and p'_w = p_i M4_i + p_w
	cl.transform = function(self, m3x3, m4)
		self.negDist = self.negDist + self.n:dot(m4)
		self.n = self.n * m3x3
	end
end

local range = require 'ext.range'
local struct = require 'struct'
metatype = struct{
	name = '<?=planeType?>',
	union = true,
	fields = {
		{type=struct{
			anonymous = true,
			fields = {
				{name='n', type='<?=vecNType.name?>'},
				{name='negDist', type='<?=ctype?>'},
			},
		}},
		{name='v', type='<?=vecNPlusOneType.name?>'},
		{name='s', type='<?=ctype?>[<?=dim+1?>]'},
	},
	metatable = modifyMetatable,
}

assert(ffi.sizeof'<?=planeType?>' == ffi.sizeof'<?=vecNPlusOneType.name?>')

return metatype
	]=], args)
	local func, msg = load(code)
	if not func then
		error('\n'..showcode(code)..'\n'..msg)
	end
	return func(args)
end

