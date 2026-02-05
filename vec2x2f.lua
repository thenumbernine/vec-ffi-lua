require 'vec-ffi.vec2f'
return require 'vec-ffi.create_vec2'{
	ctype = 'vec2f',

	classCode = [[
function cl.det(m)
	return m.x.x * m.y.y - m.x.y * m.y.x
end
]],
}
