#!/bin/sh
# common routines for readiness and liveness probes

# jboss-cli.sh sometimes hangs indefinitely. Send SIGTERM after CLI_TIMEOUT has passed
# and failing that SIGKILL after CLI_KILLTIME, to ensure that it exits
CLI_TIMEOUT=10s
CLI_KILLTIME=30s

run_cli_cmd() {
    cmd="$1"
    timeout --foreground -k "$CLI_KILLTIME" "$CLI_TIMEOUT" java -jar $JBOSS_HOME/bin/client/jboss-cli-client.jar --connect "$cmd"
}

is_eap7() {
    run_cli_cmd "version" | grep -q "^JBoss AS product: JBoss EAP 7"
}

# Additional check necessary for EAP7, see CLOUD-615
deployments_failed() {
    ls -- /deployments/*failed >/dev/null 2>&1 || (is_eap7 && run_cli_cmd "deployment-info" | grep -q FAILED)
}

list_failed_deployments() {
    ls -- /deployments/*failed >/dev/null 2>&1 && \
        echo /deployments/*.failed | sed "s+^/deployments/\(.*\)\.failed$+\1+"
}
