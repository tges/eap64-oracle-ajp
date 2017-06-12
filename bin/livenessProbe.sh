#!/bin/sh

. "$JBOSS_HOME/bin/probe_common.sh"

if [ true = "${DEBUG}" ] ; then
    # short circuit liveness check in dev mode
    exit 0
fi

OUTPUT=/tmp/liveness-output
ERROR=/tmp/liveness-error
LOG=/tmp/liveness-log

# liveness failure before management interface is up will cause the probe to fail
COUNT=30
SLEEP=5
DEBUG_SCRIPT=false

if [ $# -gt 0 ] ; then
    COUNT=$1
fi

if [ $# -gt 1 ] ; then
    SLEEP=$2
fi

if [ $# -gt 2 ] ; then
    DEBUG_SCRIPT=$3
fi

# Sleep for 5 seconds to avoid launching readiness and liveness probes
# at the same time
sleep 5

if [ true = "${DEBUG_SCRIPT}" ] ; then
    echo "Count: ${COUNT}, sleep: ${SLEEP}" > ${LOG}
fi

while : ; do
    run_cli_cmd ':read-attribute(name=server-state)' > ${OUTPUT} 2>${ERROR}
    CONNECT_RESULT=$?
    grep -iq success "$OUTPUT" && (!(grep -iq running "$OUTPUT") || ! deployments_failed)
    GREP_RESULT=$?
    if [ true = "${DEBUG_SCRIPT}" ] ; then
        (
            echo "$(date) Connect: ${CONNECT_RESULT}, Grep: ${GREP_RESULT}"
            echo "========================= OUTPUT ========================="
            cat ${OUTPUT}
            echo "========================= ERROR =========================="
            cat ${ERROR}
            echo "=========================================================="
        ) >> ${LOG}
    fi

    rm -f ${OUTPUT} ${ERROR}

    if [ ${GREP_RESULT} -eq 0 ] ; then
        exit 0;
    fi

    COUNT=$(expr $COUNT - 1)
    if [ $COUNT -eq 0 ] ; then
        exit 1;
    fi
    sleep ${SLEEP}
done
