require 'vec-ffi.vec3f'

-- TODO I'm going to need a create_mat next ...
return require 'vec-ffi.create_vec3'{
	ctype = 'vec3f',

	classCode = [[
function cl.det(m)
    return m.x.x * (m.y.y * m.z.z - m.y.z * m.z.y) -
           m.y.x * (m.x.y * m.z.z - m.x.z * m.z.y) +
           m.z.x * (m.x.y * m.y.z - m.x.z * m.y.y)
end
]],
}
