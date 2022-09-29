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

    if [ "${TASK_STATUS}" == "error" ] || [ "${TASK_STATUS}" == "removed" ] || [ "${TASK_STATUS}" == "aborted" ]; then
      #echo "${TASK_STATUS} ------------------- ${RPC_RESULT} =============="
	        if [[ -z "${RMQ_KEY}" ]]; then
	          curl 127.0.0.1:680/_rocketmq/ -X POST -d '{"nameservers": "'$RMQ_NAMESERVERS'", "topic": "'$RMQ_TOPIC'", "group": "'$RMQ_GROUP'", "message": '$RPC_RESULT'}'
          else
#            echo " curl '127.0.0.1:680/_rocketmq/' -X POST -d '${RPC_RESULT}'"
#            curl '127.0.0.1:680/_rocketmq/' -X POST -d ''${RPC_RESULT}''
            sct='curl "http://127.0.0.1:680/_rocketmq/" -X POST -d '"'"'{"accessKey": "'$RMQ_KEY'", "secretKey": "'$RMQ_SECRET'", "nameservers": "'$RMQ_NAMESERVERS'", "topic": "'$RMQ_TOPIC'", "group": "'$RMQ_GROUP'", "message": '$RPC_RESULT}"'"
            echo $sct > /data/logs/e1.sh;
            bash /data/logs/e1.sh;
#            curl 127.0.0.1:680/_rocketmq/ -X POST -d '{"accessKey": "'$RMQ_KEY'", "secretKey": "'$RMQ_SECRET'", "nameservers": "'$RMQ_NAMESERVERS'", "topic": "'$RMQ_TOPIC'", "group": "'$RMQ_GROUP'", "message": '$RPC_RESULT'}'
          fi
    fi
}




CHECK_CORE_FILE "$@"
CHECK_PARAMETER "$@"
CHECK_FILE_NUM
CHECK_SCRIPT_CONF
GET_TASK_INFO
GET_TASK_STATUS
ERROR_ON_STOP
exit 0
