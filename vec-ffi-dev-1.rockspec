package = "vec-ffi"
version = "dev-1"
source = {
	url = "git+https://github.com/thenumbernine/vec-ffi-lua.git"
}
description = {
	summary = "Vector class for LuaJIT",
	detailed = "Vector class for LuaJIT",
	homepage = "https://github.com/thenumbernine/vec-ffi-lua",
	license = "MIT"
}
dependencies = {
	"lua ~> 5.1"
}
build = {
	type = "builtin",
	modules = {
		["vec-ffi.create"] = "create.lua",
		["vec-ffi.vec2b"] = "vec2b.lua",
		["vec-ffi.vec2d"] = "vec2d.lua",
		["vec-ffi.vec2f"] = "vec2f.lua",
		["vec-ffi.vec2i"] = "vec2i.lua",
		["vec-ffi.vec2s"] = "vec2s.lua",
		["vec-ffi.vec2ub"] = "vec2ub.lua",
		["vec-ffi.vec3b"] = "vec3b.lua",
		["vec-ffi.vec3d"] = "vec3d.lua",
		["vec-ffi.vec3f"] = "vec3f.lua",
		["vec-ffi.vec3i"] = "vec3i.lua",
		["vec-ffi.vec3s"] = "vec3s.lua",
		["vec-ffi.vec3sz"] = "vec3sz.lua",
		["vec-ffi.vec3ub"] = "vec3ub.lua",
		["vec-ffi.vec4b"] = "vec4b.lua",
		["vec-ffi.vec4d"] = "vec4d.lua",
		["vec-ffi.vec4f"] = "vec4f.lua",
		["vec-ffi.vec4i"] = "vec4i.lua",
		["vec-ffi.vec4ub"] = "vec4ub.lua"
	}
}
