local table = require 'ext.table'

return function(args)
	return require 'vec-ffi.create_vec'(table(args, {
		dim = args.dim or 3,	-- allow override, for vec4 to inherit vec3's routines, etc

		classCode = [[

cl.determinant = function(a,b,c)
	return a.x * b.y * c.z
		+ a.y * b.z * c.x
		+ a.z * b.x * c.y
		- a.z * b.y * c.x
		- a.y * b.x * c.z
		- a.x * b.z * c.y
end

-- such that a:cross(b):dot(c) = metatype.determinant(a,b,c) = volume of parallelepiped with sides a,b,c
cl.cross = function(a,b)
	return metatype(
		a.y * b.z - a.z * b.y,
		a.z * b.x - a.x * b.z,
		a.x * b.y - a.y * b.x)
end

]],
	}))
end
