#!/bin/sh

set -e -o pipefail

# config
NAME=dub-registry
HOST=root@kvm1.dawg.eu
DIR=/home/${NAME}
BUILD=${BUILD:=release}
COPY='dub-registry categories.json public'
USER=${NAME}
GROUP=${NAME}
CMD="${DIR}/${NAME} -v"

# build
dub build -b ${BUILD} -d DubRegistryStaging #--force

# systemd
cat > ${NAME}.service <<EOF
[Unit]
Description=${NAME}
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=simple
Group=${GROUP}
User=${USER}
ExecStart=${CMD}
WorkingDirectory=${DIR}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# upload
rsync() { command rsync -ravzL --delete --no-whole-file --usermap="*:${USER}" --groupmap="*:${GROUP}" "$@"; }
rsync ${COPY} ${HOST}:${DIR}/
rsync ${NAME}.service ${HOST}:/etc/systemd/system/
rm ${NAME}.service

# start
ssh ${HOST} "systemctl daemon-reload && systemctl restart ${NAME}.service && sleep 1 && systemctl status ${NAME}.service"
