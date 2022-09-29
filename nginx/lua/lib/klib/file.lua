local nfind, nsub = ngx.re.find, ngx.re.gsub
local nmatch, gmatch, byte, char = ngx.re.match, ngx.re.gmatch, string.byte, string.char
local sfind, ssub, lower, floor, rep = string.find, string.sub, string.lower, math.floor, string.rep
local insert, new_tab, sort = table.insert, table.new, table.sort
local DIR_SEP = package.config:sub(1, 1)
local DIR_SEP_byte = byte(DIR_SEP, 1, 1)
local IS_WINDOWS = DIR_SEP == '\\'

local lfs = require("lfs_ffi")
local attrib = lfs.attributes

---@class klib.file
---@field chdir fun (path:string) @switch dir
---@field currentdir fun (path:string) @get current working dir
---@field dir fun (path:string)
---@field link fun (path:string)
---@field mkdir fun (path:string)
---@field rmdir fun (path:string)
---@field setmode fun (path:string)
---@field touch fun (path:string)
local _M = {
	DIR_SEP = DIR_SEP,
	DIR_SEP_byte = DIR_SEP_byte
}

local function check_dir_path(path)
	if path == nil or path == '' then
		return
	end
	if byte(path, #path, #path) ~= DIR_SEP_byte then
		return path .. DIR_SEP
	end
	return path
end

local default_ls_option = { recurse = false, skipdirs = false, skipdots = true, delay = true, skipfiles = false }

---ls list file names under this directory
---@param full_path string
---@param option klib.file.option @default ls all files on entry folder, add `with_info=true` to return full file/folder info instead of `full-path-string`
---@param regex string @ default no regex matching
---@param regex_option string @default with 'jio'
---@return string[] @sorted
function _M.ls(full_path,option, regex, regex_option)
	full_path = check_dir_path(full_path)
	if not full_path then
		return
	end
	local arr = new_tab(0, 10)
	local nc = 1
	_M.foreach(full_path, function(path, attr)
		if regex then
			if nfind(path, regex,regex_option or 'jio') then
				arr[nc] = path
				nc = nc + 1
			end
		else
			arr[nc] = path
			nc = nc + 1
		end
	end, option or default_ls_option)
    if nc > 0 then
        sort(arr)
    end
	return arr
end

function _M.change_time(fs_path)
	return attrib(fs_path, 'change')
end

function _M.access_time(fs_path)
	return attrib(fs_path, 'access')
end

function _M.mod_time(fs_path)
	return attrib(fs_path, 'modification')
end

function _M.size(fs_path)
	return attrib(fs_path, 'size')
end

function _M.exists(fs_path)
	return attrib(fs_path, 'mode') ~= nil and fs_path
end

function _M.isdir(fs_path)
	return attrib(fs_path, 'mode') == 'directory' and fs_path
end

function _M.isfile(fs_path)
	return attrib(fs_path, 'mode') == 'file' and fs_path
end

function _M.islink(fs_path)
	return attrib(fs_path, 'mode') == 'link' and fs_path
end

_M.currentdir = lfs.currentdir
_M.attributes = lfs.attributes
_M.mkdir = lfs.mkdir
_M.rmdir = lfs.rmdir
_M.chdir = lfs.chdir
_M.link = lfs.link
_M.setmode = lfs.setmode
_M.dir = lfs.dir
_M.touch = lfs.touch

---read
---@param filepath string  @filename The file path [Required]
---@param is_bin boolean  @open in binary mode
---@param max_length number @if set, read the last part max_length of the file, very useful in log tailing
---@return string, string @ the file content, error message
function _M.read(filepath, is_bin, max_length)
	local mode = is_bin and 'b' or ''
	if not filepath or type(filepath) ~= 'string' then
		return nil, 'bad file name'
	end
	local file, open_err = io.open(filepath, 'r' .. mode)
	if not file then
		return nil, open_err
	end
	local str, err
	if max_length and max_length > 1024 then
		local current = file:seek()
		local fileSize = file:seek("end")  --get file total size
		if fileSize > max_length then
			file:seek('set', fileSize - max_length) --move cusor to last part
			str, err = file:read(max_length)
		else
			file:seek('set', 0) --move cursor to head
			str, err = file:read(fileSize)
		end
	else
		str, err = file:read("*a")
	end
	file:close()
	if not str then
		-- Errors in io.open have "filename: " prefix,
		-- error in file:read don't, add it.
		return nil, 'bad file path ' .. filepath .. ": " .. err
	end
	return str
end

---write
---@param filepath string @ file path
---@param str string @ file content
---@param is_binary boolean @binary mode to write
function _M.write(filepath, str, is_binary)
	if not filepath or type(filepath) ~= 'string' then
		return nil, 'bad file name'
	end
	local file, err = io.open(filepath, is_binary and 'wb+' or 'w+')
	if not file then
		return err
	end
	file:write(str)
	file:close()
	return true
end

---lines return the contents of a file as a list of lines
---@param filepath string
---@return string[], string @result, err
function _M.lines(filepath)
	if not filepath or type(filepath) ~= 'string' then
		return nil, 'bad file name'
	end
	local f, err = io.open(filepath, 'r')
	if not f then
		return nil, err
	end
	local res = {}
	for line in f:lines() do
		insert(res, line)
	end
	f:close()
	return res
end

---copy
---@param src string
---@param dst string
---@param force boolean
function _M.copy(src, dst, force)
	if not IS_WINDOWS then
		if _M.isdir(src) or _M.isdir(dst) then
			return nil, 'can not copy directories'
		end
	end
	local f, err = io.open(src, 'rb')
	if not f then
		return nil, err
	end

	if not force then
		local t, err = io.open(dst, 'rb')
		if t then
			f:close()
			t:close()
			return nil, "file alredy exists"
		end
	end

	local t, err = io.open(dst, 'w+b')
	if not t then
		f:close()
		return nil, err
	end

	local CHUNK_SIZE = 4096
	while true do
		local chunk = f:read(CHUNK_SIZE)
		if not chunk then
			break
		end
		local ok, err = t:write(chunk)
		if not ok then
			t:close()
			f:close()
			return nil, err or "can not write"
		end
	end

	t:close()
	f:close()
	return true
end

---move
---@param src string
---@param dst string
---@param force boolean
function _M.move(src, dst, force)
	if force and _M.exists(dst) and _M.exists(src) then
		local ok, err = _M.remove(dst)
		-- do we have to remove dir?
		-- if not ok then ok, err = _M.rmdir(dst) end
		if not ok then
			return nil, err
		end
	end
	if (not IS_WINDOWS) and _M.exists(dst) then
		-- on windows os.rename return error when dst exists,
		-- but on linux its just replace existed file
		return nil, "destination alredy exists"
	end
	return os.rename(src, dst)
end

---remove
---@param file_or_dir_path string
function _M.remove(file_or_dir_path)
	-- on windows os.remove can not remove dir
	if (not IS_WINDOWS) and _M.isdir(file_or_dir_path) then
		return os.exec('rm -rf "' .. file_or_dir_path..'"')
		--return nil, "remove method can not remove dirs"
	end
	return os.remove(file_or_dir_path)
end

local function isdots(P)
	return P == '.' or P == '..'
end

local function splitpath(P)
	return string.match(P, "^(.-)[\\/]?([^\\/]*)$")
end

local foreach_impl

local function do_foreach_recurse(base, match, callback, option)
	local dir_next, dir = lfs.dir(base)
	for name in dir_next, dir do
		if not isdots(name) then
			local path = base .. DIR_SEP .. name
			if attrib(path, "mode") == "directory" then
				local ret, err = foreach_impl(path, match, callback, option)
				if ret or err then
					if dir then
						dir:close()
					end
					return ret, err
				end
			end
		end
	end
end

foreach_impl = function(base, match, callback, option)
	if not base then
		return nil, 'empty folder string'
	end
	local tmp, origin_cb
	if option.delay then
		tmp, origin_cb, callback = {}, callback, function(base, name, fd)
			insert(tmp, { base, name, fd })
		end;
	end

	if option.recurse and option.reverse == true then
		local ok, err = do_foreach_recurse(base, match, callback, option)
		if ok or err then
			return ok, err
		end
	end
	local dir_next, dir = lfs.dir(base)
	for name in dir_next, dir do
		if option.skipdots == false or not isdots(name) then
			local path = base .. DIR_SEP .. name
			local attr = attrib(path)
			if attr then
				if (option.skipdirs and attr.mode == "directory")
						or (option.skipfiles and attr.mode == "file")
				then
				else
					if match(name) then
						local ret, err = callback(base, name, attr)
						if ret or err then
							if dir then
								dir:close()
							end
							return ret, err
						end
					end
				end

				local can_recurse = (not option.delay) and option.recurse and (option.reverse == nil)
				if can_recurse and attr.mode == "directory" and not isdots(name) then
					local ret, err = foreach_impl(path, match, callback, option)
					if ret or err then
						if dir then
							dir:close()
						end
						return ret, err
					end
				end
			end
		end
	end

	if option.delay then
		for _, t in ipairs(tmp) do
			local ok, err = origin_cb(t[1], t[2], t[3])
			if ok or err then
				return ok, err
			end
		end
	end

	if option.recurse and (not option.reverse) then
		if option.delay or (option.reverse == false) then
			return do_foreach_recurse(base, match, origin_cb or callback, option)
		end
	end
end

local function filePat2rexPat(pat)
	if pat:find("[*?]") then
		local post = '$'
		if pat:find("*", 1, true) then
			if pat:find(".", 1, true) then
				post = '[^.]*$'
			else
				post = ''
			end
		end
		pat = "^" .. pat:gsub("%.", "%%."):gsub("%*", ".*"):gsub("%?", ".?") .. post
	else
		pat = "^" .. pat:gsub("%.", "%%.") .. "$"
	end
	if IS_WINDOWS then
		pat = pat:upper()
	end
	return pat
end

local function match_pat(pat)
	pat = filePat2rexPat(pat)
	return IS_WINDOWS
			and function(s)
		return nil ~= string.find(string.upper(s), pat)
	end
			or function(s)
		return nil ~= string.find(s, pat)
	end
end

---foreach
---@param base_dir string
---@param callback fun(path:string, attr:klib.file.attributes):boolean @callback function for each dir or file entry, return true to break the recurse
---@param option klib.file.option
function _M.foreach(base_dir, callback, option)
	local len, base, mask = #base_dir
	for i = len, 1, -1 do
		if byte(base_dir, i) == DIR_SEP_byte then
			base = ssub(base_dir, 1, i - 1)
			mask = ssub(base_dir, i + 1, len)
			break
		end
	end
	if mask and mask ~= '' then
		mask = match_pat(mask)
	else
		mask = function()
			return true
		end
	end

	return foreach_impl(base, mask, function(_base, name, fd)

		if _base == base_dir then
			return callback(_base .. name, fd)
		else
			return callback(_base .. DIR_SEP .. name, fd)
		end

	end, option or {})
end

return _M

---@class lfs
---@field _COPYRIGHT string @ 2003-2017 Kepler Project
---@field _DESCRIPTION string @"LuaFileSystem is a Lua library developed to complement the set of functions related to file systems offered by the standard Lua distribution
---@field _VERSION string @LuaFileSystem
---@field attributes fun (path:string)
---@field chdir fun (path:string)
---@field currentdir fun (path:string)
---@field dir fun (path:string)
---@field link fun (path:string)
---@field lock fun (path:string)
---@field lock_dir fun (path:string)
---@field mkdir fun (path:string)
---@field rmdir fun (path:string)
---@field setmode fun (path:string)
---@field symlinkattributes fun (path:string)
---@field touch fun (path:string)
---@field unlock fun (path:string)

---@class klib.file.option
---@field skipdots boolean @ignore dot path [@default false]
---@field recurse boolean @recurse all subdirectory
---@field skipfiles boolean @ Only list directories
---@field skipdirs boolean @ Only list files
---@field delay boolean @ True to do callback after current dir iteration
---@field reverse boolean @ leaves recurse first


---@class klib.file.attributes
---@field access number
---@field blksize number
---@field blocks number
---@field change number
---@field dev number
---@field gid number
---@field ino number
---@field mode string @ file or directory
---@field modification number
---@field nlink number
---@field permissions string
---@field rdev number
---@field size number
---@field uid number
--	access = 1524203253,
--	blksize = 4096,
--	blocks = 8,
--	change = 1535451095,
--	dev = 39,
--	gid = 994,
--	ino = 1088,
--	mode = "file",
--	modification = 1534403091,
--	nlink = 1,
--	permissions = "rwxrwx---",
--	rdev = 0,
--	size = 58,
--	uid = 0

--	access = 1539081721,
--	blksize = 4096,
--	blocks = 8,
--	change = 1539081721,
--	dev = 39,
--	gid = 994,
--	ino = 1102,
--	mode = "directory",
--	modification = 1539081721,
--	nlink = 1,
--	permissions = "rwxrwx---",
--	rdev = 0,
--	size = 4096,
--	uid = 0

---@class klib.file.info
---@field path string
---@field attr klib.file.attributes