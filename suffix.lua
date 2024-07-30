local table = require 'ext.table'

local suffix = {
	int8_t = 'b',
	int16_t = 's',
	int32_t = 'i',
	int64_t = 'l',

	uint8_t = 'ub',
	uint16_t = 'us',
	uint32_t = 'ui',
	uint64_t = 'ul',

	char = 'b',		-- 'signed char' ?
	short = 's',
	int = 'i',
	long = 'l',

	['unsigned char'] = 'ub',
	['unsigned short'] = 'us',
	['unsigned int'] = 'ui',
	['unsigned long'] = 'ul',

	-- ssize_t ?
	size_t = 'sz',
	-- intptr_t ?
	-- uintptr_t ?

	float = 'f',
	double = 'd',
}

return suffix
