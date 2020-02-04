local suffix = require 'vec-ffi.suffix'

return function(ctype)
	return require 'vec-ffi.create_vec'{
		dim = 4,
		ctype = ctype,
		vectype = 'quat'..suffix[ctype]..'_t',
		
		-- create the 3type associated with our quat 4type
		vec3 = require('vec-ffi.vec3'..suffix[ctype]),
		
		classCode = [[
	mul = function(q, r, res)
		if not res then res = metatype() end
		
		local a = (q.w + q.x) * (r.w + r.x)
		local b = (q.z - q.y) * (r.y - r.z)
		local c = (q.x - q.w) * (r.y + r.z)
		local d = (q.y + q.z) * (r.x - r.w)
		local e = (q.x + q.z) * (r.x + r.y)
		local f = (q.x - q.z) * (r.x - r.y)
		local g = (q.w + q.y) * (r.w - r.z)
		local h = (q.w - q.y) * (r.w + r.z)

		res.x = a - .5 * ( e + f + g + h)
		res.y = -c + .5 * ( e - f + g - h)
		res.z = -d + .5 * ( e - f - g + h)
		res.w = b + .5 * (-e - f + g + h)
		
		return res
	end,
	__mul = cl.mul,

	__div = function(a,b)
		return a * b:conjugate() / b:lenSq()
	end,

	-- in degrees
	toAngleAxis = function(self, res)
		if not res then res = metatype() end

		local cosom = math.clamp(self.w, -1, 1)

		local halfangle = math.acos(cosom)
		local scale = math.sin(halfangle)

		if scale >= -.00001 and scale <= .00001 then
			res.x = 0
			res.y = 0
			res.z = 1
			res.w = 0
		else
			scale = 1 / scale
			res.x = self.x * scale
			res.y = self.y * scale
			res.z = self.z * scale
			res.w = halfangle * 360 / math.pi
		end
		
		return res
	end,

	fromAngleAxis = function(q, x, y, z, degrees)
		local vlen = math.sqrt(x*x + y*y + z*z)
		local radians = math.rad(degrees)
		local costh = math.cos(radians / 2)
		local sinth = math.sin(radians / 2)
		local vscale = sinth / vlen
		q.x = x * vscale
		q.y = y * vscale
		q.z = z * vscale
		q.w = costh
		
		return q
	end,

	xAxis = function(q, res)
		if not res then res = vec3() end
		res.x = 1 - 2 * (q.y * q.y + q.z * q.z)
		res.y = 2 * (q.x * q.y + q.z * q.w)
		res.z = 2 * (q.x * q.z - q.w * q.y)
		return res
	end,

	yAxis = function(q, res)
		if not res then res = vec3() end
		res.x = 2 * (q.x * q.y - q.w * q.z)
		res.y = 1 - 2 * (q.x * q.x + q.z * q.z)
		res.z = 2 * (q.y * q.z + q.w * q.x)
		return res
	end,

	zAxis = function(q, res)
		if not res then res = vec3() end
		res.x = 2 * (q.x * q.z + q.w * q.y)
		res.y = 2 * (q.y * q.z - q.w * q.x)
		res.z = 1 - 2 * (q.x * q.x + q.y * q.y)
		return res
	end,

	-- TODO instead of a table-of-vec3_t's, how about a matrix ffi type?
	toMatrix = function(q, mat)
		if not mat then mat = {} end
		mat[1] = metatype.xAxis(q, mat[1])
		mat[2] = metatype.yAxis(q, mat[2])
		mat[3] = metatype.zAxis(q, mat[3])
		return mat
	end,

	rotate = function(self, v)
		return vec3(
			table.unpack(
				self * metatype(v.x, v.y, v.z, 0) 
				* self:conjugate()
			), 1, 3)
	end,

	-- when using conj for quaternion orientations, you can get by just negative'ing the w
	-- ... since q == inv(q)
	-- makes a difference when you are using this for 3D rotations
	conjugate = function(self)
		return metatype(-self.x, -self.y, -self.z, self.w)
	end,

	-- in-place
	normalize = function(self)
		local len = self:length()
		if math.abs(len) < 1e-20 then
			self.x = 0
			self.y = 0
			self.z = 0
			self.w = 1
		else
			local invlen = 1 / len
			self.x = self.x * invlen
			self.y = self.y * invlen
			self.z = self.z * invlen
			self.w = self.w * invlen
		end
		return self
	end,
]],
	}
end
