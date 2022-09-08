local cjson_safe = require("cjson.safe")
local acl_rpchook = require("resty.rocketmq.acl_rpchook")
local producer = require ("resty.rocketmq.producer")
local utils = require("resty.rocketmq.utils")

local ngx = ngx
local log = ngx.log
local WARN = ngx.WARN

local _M = {}
_M.__index = _M

function _M.new(config)
    local p, err = producer.new(config.nameservers)
    if not p then
        print("create producer err:", err)
        return
    end
    p:setUseTLS(config.use_tls)
    if config.access_key and config.secret_key then
        p:addRPCHook(acl_rpchook.new(config.access_key, config.secret_key))
    end
    return setmetatable({ p = p }, _M)
end

function _M:message()
    local method = ngx.req.get_method()
    log(WARN, method)
    local topic = ngx.var.topic
    if method == 'GET' then
        self:consume_message(topic)
    elseif method == 'POST' then
        self:produce_message(topic)
    end
end

local function error(status, message)
    ngx.status = status
    ngx.say(message)
    ngx.exit(0)
end

function _M:produce_message(topic)
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    local data_t, err = cjson_safe.decode(data)
    if err then
        error(400, "invalid json format")
    end
    local body = data_t.body
    if not body then
        error(400, "no message body")
    end
    local properties = data_t.properties or {}
    properties.UNIQ_KEY = utils.genUniqId()
    properties.waitStoreMsgOk = properties.waitStoreMsgOk or 'true'
    local msg = {
        producerGroup = "proxy_producer",
        topic = topic,
        defaultTopic = "TBW102",
        defaultTopicQueueNums = 4,
        sysFlag = 0,
        bornTimeStamp = ngx.now() * 1000,
        flag = 0,
        properties = properties,
        reconsumeTimes = 0,
        unitMode = false,
        maxReconsumeTimes = 0,
        batch = false,
        body = body,
    }
    local res, err = self.p:produce(msg)
    if not res then
        error(400, err)
    end
    ngx.say(cjson_safe.encode({
        msg_id = res.sendResult.msgId,
        offset_msg_id = res.sendResult.offsetMsgId,
        broker = res.sendResult.messageQueue.brokerName,
        queue_id = res.sendResult.messageQueue.queueId,
        queue_offset = res.sendResult.queueOffset,
    }))
end

function _M:consume_message()

end

return _M
