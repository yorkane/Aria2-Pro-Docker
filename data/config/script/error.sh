#!/usr/bin/env bash


CHECK_CORE_FILE() {
    CORE_FILE="$(dirname $0)/core"
    if [[ -f "${CORE_FILE}" ]]; then
        . "${CORE_FILE}"
    else
        echo "!!! core file does not exist !!!"
        exit 1
    fi
}

CHECK_RPC_CONECTION() {
    READ_ARIA2_CONF
    if [[ "${RPC_SECRET}" ]]; then
        RPC_PAYLOAD='{"jsonrpc":"2.0","method":"aria2.getVersion","id":"P3TERX","params":["token:'${RPC_SECRET}'"]}'
    else
        RPC_PAYLOAD='{"jsonrpc":"2.0","method":"aria2.getVersion","id":"P3TERX"}'
    fi
    (curl "${RPC_ADDRESS}" -fsSd "${RPC_PAYLOAD}" || curl "https://${RPC_ADDRESS}" -kfsSd "${RPC_PAYLOAD}") >/dev/null
}

ERROR_ON_STOP() {
    if [[ "${TASK_STATUS}" = "error" ]] || [[ "${TASK_STATUS}" = "removed" ]]; then
        if [[ "${RMQ_KEY}" && "${RMQ_SECRET}"]]; then
          curl 127.0.0.1/_rocketmq/ -X POST -d '{"accessKey": '"$RMQ_KEY"', "secretKey": '"$RMQ_SECRET"', "nameservers": "'$RMQ_NAMESERVERS'", "topic": "'$RMQ_TOPIC'", "group": "'$RMG_GROUP'", "message": '$RPC_RESULT'}'
        else
          curl 127.0.0.1/_rocketmq/ -X POST -d '{"nameservers": "'$RMQ_NAMESERVERS'", "topic": "'$RMQ_TOPIC'", "group": "'$RMG_GROUP'", "message": '$RPC_RESULT'}'
        fi
    fi
}




CHECK_CORE_FILE "$@"
CHECK_PARAMETER "$@"
CHECK_FILE_NUM
CHECK_SCRIPT_CONF
GET_TASK_INFO
ERROR_ON_STOP
exit 0
