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

CHECK_CORE_FILE "$@"
CHECK_PARAMETER "$@"
CHECK_FILE_NUM
CHECK_SCRIPT_CONF
GET_TASK_INFO
ERROR_ON_STOP
exit 0


curl "http://192.168.50.2:680/jsonrpc" -X POST -d '{"id": "CurlA", "method": "aria2.addUri", "params": ["token:Aria_314", ["https://www.baidu.com/index.htm"],
      {
        "out": "jinja.txt",
        "dir": "TME2",
        "max-download-limit": "10M",
        "min-split-size": "20M",
        "split": 5,
        "timeout": 10,
        "max-connection-per-server": 10
      }
    ]
}'


curl "http://192.168.50.2:680/jsonrpc" -X POST -d '{"id": "CurlA", "method": "aria2.addUri", "params": ["token:Aria_314", ["https://www.baidu.com/index.htm"],{"dir": "/downloads/TME1/"}]}'
