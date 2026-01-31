-- I am not yet building all these
-- TODO how to even require them all?
-- do I really want one file per class, even if all the files just have one line to them?
-- if I auto-gen the classes then I'll still need to require() a prelim file to setup the autogen, so there's always at least one require() going on
-- so why not put one file per type for ppl who just want to use one type and no more?

-- TODO `env` is is great and all
-- but
-- I'm still caching created classes in package.loaded
-- so .... it doesn't modular-ize anything.
return function(env)
	env = env or _G

	-- vec

	env.vec2b = require 'vec-ffi.vec2b'
	env.vec2ub = require 'vec-ffi.vec2ub'
	env.vec2s = require 'vec-ffi.vec2s'
	--vec2us
	env.vec2i = require 'vec-ffi.vec2i'
	--vec2ui
	env.vec2f = require 'vec-ffi.vec2f'
	env.vec2d = require 'vec-ffi.vec2d'
	env.vec2sz = require 'vec-ffi.vec2sz'

	env.vec3b = require 'vec-ffi.vec3b'
	env.vec3ub = require 'vec-ffi.vec3ub'
	env.vec3s = require 'vec-ffi.vec3s'
	--vec3us
	env.vec3i = require 'vec-ffi.vec3i'
	--vec3ui
	env.vec3f = require 'vec-ffi.vec3f'
	env.vec3d = require 'vec-ffi.vec3d'
	env.vec3sz = require 'vec-ffi.vec3sz'

	env.vec4b = require 'vec-ffi.vec4b'
	env.vec4ub = require 'vec-ffi.vec4ub'
	--vec4s
	env.vec4us = require 'vec-ffi.vec4us'
	env.vec4i = require 'vec-ffi.vec4i'
	env.vec4f = require 'vec-ffi.vec4f'
	env.vec4d = require 'vec-ffi.vec4d'

	-- matrix

	env.vec4x4f = require 'vec-ffi.vec4x4f'

	local createVecType = require 'vec-ffi.create_vec'
	local createVecNs = {
		[2] = require 'vec-ffi.create_vec2',
		[3] = require 'vec-ffi.create_vec3',
	}
	for _,suffix in ipairs{
		--'b', 's', 'i', 
		'f', 'd'
	} do
		for i=2,4 do
			local create = createVecNs[i] or createVecType
			for j=2,4 do
				local k = 'vec'..i..'x'..j..suffix
				env[k] = env[k] or create{
					dim = i,
					ctype = 'vec'..j..suffix..'_t',
				}
			end
		end
	end

	-- box

	env.box2f = require 'vec-ffi.box2f'
	env.box2i = require 'vec-ffi.box2i'
	env.box3d = require 'vec-ffi.box3d'
	env.box3f = require 'vec-ffi.box3f'
	env.box3i = require 'vec-ffi.box3i'

	-- plane

	env.plane2f = require 'vec-ffi.plane2f'
	env.plane3f = require 'vec-ffi.plane3f'

	-- quat

	env.quatd = require 'vec-ffi.quatd'
	env.quatf = require 'vec-ffi.quatf'
end
