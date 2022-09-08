#     _         _       ____    ____
#    / \   _ __(_) __ _|___ \  |  _ \ _ __ ___
#   / _ \ | '__| |/ _` | __) | | |_) | '__/ _ \
#  / ___ \| |  | | (_| |/ __/  |  __/| | | (_) |
# /_/   \_\_|  |_|\__,_|_____| |_|   |_|  \___/
#
# https://github.com/P3TERX/Aria2-Pro-Docker
#
# Copyright (c) 2020-2021 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.

FROM p3terx/s6-alpine:3.15

RUN echo 'ls -la "$@"' > /usr/bin/ll && chmod 755 /usr/bin/ll && \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    wget 'https://openresty.org/package/admin@openresty.com-5ea678a6.rsa.pub' -P /etc/apk/keys/ && \
    echo "https://openresty.org/package/alpine/v3.15/main" | tee -a /etc/apk/repositories && \
    apk --no-cache add openresty zlib zziplib curl jq findutils luarocks5.1 && \
    sed -i "1iexport PERL5LIB=/usr/local/openresty/nginx/"  /etc/profile && \
    sed -i "1iexport LUA_PATH='/usr/local/openresty/nginx/lua/?.lua;/usr/local/openresty/nginx/lua/?/init.lua;/usr/local/openresty/site/lualib/?.ljbc;/usr/local/openresty/site/lualib/?/init.ljbc;/usr/local/openresty/lualib/?.ljbc;/usr/local/openresty/lualib/?/init.ljbc;/usr/local/openresty/site/lualib/?.lua;/usr/local/openresty/site/lualib/?/init.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;./?.lua;	/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua;'" /etc/profile && \
    sed -i "1iexport LUA_CPATH='/usr/local/openresty/site/lualib/?.so;/usr/local/openresty/lualib/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;'"  /etc/profile && \
    apk add libarchive-tools --repository=http://mirrors.ustc.edu.cn/alpine/edge/main/ && \
    rm -rf site/pod site/manifest site/resty.index resty.index && \
    mv /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/ && \
    rm -rf /usr/local/openresty/nginx/ && \
    curl -fsSL git.io/aria2c.sh | bash && \
    rm -rf /var/cache/apk/* /tmp/* && \
    mkdir /logs/ && \
    echo "Base cleared"

COPY rootfs /
COPY ./nginx /usr/local/openresty/nginx
COPY ./data/config /config

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=1 \
    RCLONE_CONFIG=/config/rclone.conf \
    UPDATE_TRACKERS=false \
    CUSTOM_TRACKER_URL= \
    LISTEN_PORT=6888 \
    RPC_PORT=6800 \
    TZ=Asia/Shanghai \
    RPC_SECRET="Aria_314" \
    PUID=1000 \
    PGID=1000 \
    DISK_CACHE=\
    IPV6_MODE=\
    UMASK_SET=010\
    RMQ_NAMESERVERS=127.0.0.1:9876 \
    RMQ_TOPIC=topic1 \
    RMQ_GROUP=group1 \
    RMQ_KEY=\
    RMQ_SECRET=\
    SPECIAL_MODE=move

EXPOSE \
    80 \
    6800 \
    6888 \
    6888/udp


# docker build ./ -t aria2pro:1
# docker rm -f aria2
# docker rm -f aria2 & docker run -p 680:80 -e RPC_SECRET=Aria_315 --rm --name aria2 -v /code:/code -v /data:/data -v /data/downloads:/downloads -d aria2pro:1


# curl 127.0.0.1/jsonrpc -d ''