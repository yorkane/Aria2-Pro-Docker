local cjson = require "cjson.safe"
local producer = require "resty.rocketmq.producer"
local consumer = require "resty.rocketmq.consumer"
local split = require('ngx.re').split

local _M = {

}

local function resp(body, status)
    status = status or 200
    ngx.status = status
    ngx.header.content_type = 'text/plain'
    ngx.say(body)
    ngx.exit(status)
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
    nameservers = split(nameservers, [[(,|;)]], 'jo')

    local groupName = obj.group
    if not groupName or #groupName < 2 then
        return resp('json.group required at least 2 chars', 500)
    end

    local p = producer.new(nameservers, groupName)
    local accessKey, secretKey = obj.accessKey, obj.secretKey
    if accessKey then
        if not secretKey then
            return resp('josn.accessKey and json.secretKey must be paired', 500)
        end
        -- set acl
        local aclHook = require("resty.rocketmq.acl_rpchook").new(secretKey, secretKey)
        p:addRPCHook(aclHook)
    end
    if obj.useTLS then
        p:setUseTLS(true)
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
    if not result.files then
        return resp('json.message.result.files required', 500)
    end
    local files = result.files
    ngx.log(ngx.ERROR, cjson.encode(result))
    result.files = nil
    result.uri = files[1].uris[1].uri
    result.out = files[1].path
    local res, err = p:send(topic, result)
    if not res then
        return resp('Request RMQ Failed: ' .. err.. ' ====== '.. cjson.encode(result), 500)
    else
        ngx.log(ngx.NOTICE, '[RMQ]: ', cjson.encode(result))
    end
    --ngx.say("ok")
end

function _M.main()

end

--[[
curl 127.0.0.1/_rocketmq/ -X POST -d '{"nameservers": "127.0.0.1:9876", "topic": "topic1", "group": "group1", "message": "message1"}'
curl 127.0.0.1/_rocketmq/ -X POST -d '{"nameservers": "127.0.0.1:9876","accessKey":"accessKey", "topic": "topic1", "group": "group1", "message": "message1"}'
]]

return _M