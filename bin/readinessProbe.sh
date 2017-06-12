#!/bin/sh

. "$JBOSS_HOME/bin/probe_common.sh"

OUTPUT=/tmp/readiness-output
ERROR=/tmp/readiness-error
LOG=/tmp/readiness-log

COUNT=30
SLEEP=5
DEBUG=false

if [ $# -gt 0 ] ; then
    COUNT=$1
fi

if [ $# -gt 1 ] ; then
    SLEEP=$2
fi

if [ $# -gt 2 ] ; then
    DEBUG=$3
fi

if [ true = "${DEBUG}" ] ; then
    echo "Count: ${COUNT}, sleep: ${SLEEP}" > ${LOG}
fi

while : ; do
    run_cli_cmd ':read-attribute(name=server-state)' > ${OUTPUT} 2>${ERROR}
    CONNECT_RESULT=$?
    (grep -iq running "$OUTPUT") && ! deployments_failed
    GREP_RESULT=$?
    if [ true = "${DEBUG}" ] ; then
        (
            echo "$(date) Connect: ${CONNECT_RESULT}, Grep: ${GREP_RESULT}"
            echo "========================= OUTPUT ========================="
            cat ${OUTPUT}
            echo "========================= ERROR =========================="
            cat ${ERROR}
            echo "=========================================================="
        ) >> ${LOG}
    fi

    SERVER_STATUS=$(grep running "$OUTPUT" | sed -e 's+^.* : ++')
    FAILED_DEPLOYMENTS="$(list_failed_deployments)"

    rm -f ${OUTPUT} ${ERROR}

    if [ ${GREP_RESULT} -eq 0 ] ; then
        exit 0;
    fi

    COUNT=$(expr $COUNT - 1)
    if [ $COUNT -eq 0 ] ; then
        if [ -n "${FAILED_DEPLOYMENTS}" ] ; then
            FAILED_DEPLOYMENTS_MESSAGE=", failed deployments: ${FAILED_DEPLOYMENTS}"
        fi
        echo "Server status ${SERVER_STATUS}${FAILED_DEPLOYMENTS_MESSAGE}"
        exit 1;
    fi
    sleep ${SLEEP}
done
