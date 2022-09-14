local cjson = require "cjson.safe"
local producer = require "resty.rocketmq.producer"
local consumer = require "resty.rocketmq.consumer"
local split = require('ngx.re').split
local http = require('lib.resty.http')
local dump, logs, dump_class,dump_lua,dump_dict = require('klib.dump').locally()

local _M = {

}

local function resp(body, status)
    status = status or 200
    ngx.status = status
    ngx.header.content_type = 'text/plain'
    ngx.say(body)
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
    if obj.method ~= 'aria2.addUri' then
        return
    end
    obj = obj.params
    if not obj then
        return resp('aria2.addUri need params. ' .. err, 500)
    end
    local fname = obj.out
end

function _M.main()

end

return _M

--[[

curl "http://127.0.0.1:680/jsonrpc" -X POST -d '{"id": "CurlA", "method": "aria2.addUri", "params": ["token:Aria_315", ["https://jinja.wtvdev.com/t1.j2/?type=js"],
      {
        "out": "jinja8.txt",
        "dir": "/downloads/TME1",
        "max-download-limit": "10M",
        "min-split-size": "20M",
        "split": 5,
        "timeout": 10,
        "max-connection-per-server": 10
      }
    ]
}'

curl "http://127.0.0.1/_rocketmq/" -X POST -d '
{
    "topic": "topic1",
    "group": "group1",
    "nameservers": "http://127.0.0.1/mock/?type=js",
    "min-split-size": "20M",
    "secretKey": "secret:ssss",
    "accessKey": "access:key",
    "message": { "result": {}}
}
'


]]

