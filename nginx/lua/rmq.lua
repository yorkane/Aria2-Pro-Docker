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
    if not obj.nameservers or not obj.group or not obj.topic or not obj.message then
        ngx.status = 500
        ngx.say('RocketMQ json.nameservers: `127.0.0.1:9876,127.0.0.1:9875` required\n json.group, json.topic, json.message required')
        return
    end
    local nameservers = obj.nameservers
    if not nameservers or #nameservers < 5 then
        return resp('json.nameservers like: `127.0.0.1:9876,127.0.0.1:9875` required', 500)
    end
    local is_http_callback
    if string.find(nameservers, 'http', 1, true) == 1 then
        is_http_callback = true
    else
        nameservers = split(nameservers, [[(,|;)]], 'jo')
    end

    local groupName = obj.group
    if not groupName or #groupName < 2 then
        return resp('json.group required at least 2 chars', 500)
    end

    local topic = obj.topic
    if not topic or #topic < 2 then
        return resp('json.topic required at least 2 chars', 500)
    end
    local message = obj.message
    if not message.result then
        return resp('json.message.result required', 500)
    end
    local result = message.result
    local files = result.files
    if files then
        --ngx.log(ngx.ERROR, cjson.encode(result))
        result.files = nil
        result.uri = files[1].uris[1].uri
        result.out = files[1].path
    else
        --ngx.log(ngx.ERROR, cjson.encode(result))
        --return resp('json.message.result.files required', 500)
    end

    local res, err
    if is_http_callback then
        local client = http.new()
        local accessKey, secretKey = obj.accessKey, obj.secretKey
        local headers = {
            topic = topic,
            group = groupName
        }
        if accessKey then
            get_headers(accessKey, headers)
        end
        if accessKey then
            get_headers(secretKey, headers)
        end
        res, err = client:request_uri(nameservers, {
            method = "POST",
            headers = headers,
            body = cjson.encode(result)
        })
        logs(nameservers, result, res, err)
    else
        local client = producer.new(nameservers, groupName)
        local accessKey, secretKey = obj.accessKey, obj.secretKey
        if accessKey then
            if not secretKey then
                return resp('josn.accessKey and json.secretKey must be paired', 500)
            end
            -- set acl
            local aclHook = require("resty.rocketmq.acl_rpchook").new(secretKey, secretKey)
            client:addRPCHook(aclHook)
        end
        if obj.useTLS then
            client:setUseTLS(true)
        end
        res, err = client:send(topic, result)
        logs(nameservers, result, res, err)
    end
    if not res then
        return resp('Request RMQ Failed: ' .. err .. ' ====== ' .. cjson.encode(result), 500)
    else
        ngx.log(ngx.NOTICE, '[RMQ]: ', cjson.encode(result))
    end
    --ngx.say("ok")
end

function _M.main()

end

return _M

--[[
curl 127.0.0.1/_rocketmq/ -X POST -d '{"nameservers": "127.0.0.1:9876", "topic": "topic1", "group": "group1", "message": "message1"}'
curl 127.0.0.1/_rocketmq/ -X POST -d '{"nameservers": "127.0.0.1:9876","accessKey":"accessKey", "topic": "topic1", "group": "group1", "message": "message1"}'


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

