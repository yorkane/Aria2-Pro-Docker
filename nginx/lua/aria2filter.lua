local cjson = require "cjson.safe"
local split = require('ngx.re').split
local http = require('lib.resty.http')
local file = require('lib.klib.file')
local util = require('lib.klib.util')
local nmatch, gmatch, gsub, md5, escape_uri = ngx.re.match, ngx.re.gmatch, ngx.re.gsub, ngx.md5, ngx.escape_uri
local find, sub, lower, reverse, char, byte, concat, floor, ins, tsort, concat = string.find, string.sub, string.lower, string.reverse, string.char, string.byte, table.concat, math.floor, table.insert, table.sort, table.concat
local dump, logs, dump_class, dump_lua, dump_dict = require('klib.dump').locally()
---@type ngx.shared.DICT
local config = ngx.shared["config"]

local _M = {

}
local root = '/downloads/'
local root_completed = '/downloads/completed/'
local job_lock_second = 60

local function resp(body, status)
    status = status or 200
    ngx.status = status
    ngx.header.content_type = 'application/json'
    if status == 200 then
        ngx.say('{ "result": { "status": "' .. status .. '", "message": ' .. body .. '}} }')
    else
        ngx.say('{ "result": { "status": "' .. status .. '", "errorMessage": ' .. body .. '}} }')
    end
    ngx.exit(status)
end
local function get_headers(str, headers)
    if not str or #str < 5 then
        return nil, "not a valid headers string must like 'key1:val1; key2: val2;key3:val3'"
    end
    headers = headers or {}
    local arr1 = split(str, '; *', 'jo')
    for i = 1, #arr1 do
        local arr = split(arr1[i], ': *', 'jo')
        if #arr == 1 then
            headers[arr[1]] = arr[2]
        end
    end
end

function _M.handle()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    if not data then
        return resp('json data required', 500)
    end
    local obj, err = cjson.decode(data)
    if not obj then
        ngx.log(ngx.ERR, "Failed to parse: ", data, err)
        return resp('json data decoded failed. ' .. err, 500)
    end
    if obj.method == 'aria2.addUri' and obj.params then
        local url_list = obj.params[2]
        if not url_list then
            return
        end
        local options = obj.params[3] or {}
        local dir, out, completed = options.dir or root, options.out
        local jsecond = options.job_lock_second or job_lock_second
        jsecond = tonumber(jsecond) or job_lock_second
        if dir and out then
            if dir == root then
                completed = root_completed .. '/' .. out
            else
                completed = gsub(dir, root, root_completed, 'jo') .. '/' .. out
            end
            if file.exists(dir .. '/' .. out) then
                return resp('File downloading', 412)
            elseif file.exists(completed) then
                return resp('File exist', 409)
            else
            end
        else
            local completed_path = gsub(dir, root, root_completed, 'jo')
            local actual_list
            local err, status
            for i = 1, #url_list do
                local url = url_list[i]
                local inx = util.find_last(url, '/')
                out = sub(url, inx + 1, -1)
                if config:get('Error:' .. url) == 4 then
                    err = 'Url 404'
                    status = 410
                elseif config:get("JobLock:" .. url) then
                    err = 'Job tried'
                    status = 423
                elseif file.exists(root .. out) then
                    err = 'File downloading'
                    status = 412
                elseif file.exists(completed_path .. '/' .. out) then
                    err = 'File exist'
                    status = 409
                else
                    if not actual_list then
                        actual_list = {}
                    end
                    ins(actual_list, url)
                    config:set('JobLock:' .. url, 1, jsecond)
                end
            end
            if #url_list == 1 and err then
                return resp(err, status)
            end
            -- found error inject the filtered uri
            if err then
                obj.params[2] = actual_list
                ngx.req.set_body_data(cjson.encode(obj))
            end
        end
        --logs('/downloads/completed/' .. out)

        --logs(obj)
    end
end

function _M.main()

end

return _M

--[[
curl "http://192.168.50.2:680/jsonrpc" -X POST -d '{"id": "CurlA", "method": "aria2.addUri", "params": ["token:Aria_314",
[
    "https://www.baidu.com/index2.htm"
],
      {
        "dir": "TME2",
        "max-download-limit": "10M",
        "min-split-size": "20M",
        "split": 5,
        "timeout": 10,
        "max-connection-per-server": 10
      }
    ]
}'

]]

