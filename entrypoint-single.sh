#!/bin/bash
set -e

cat > /etc/trino/config.properties <<EOF
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8080
discovery.uri=http://localhost:8080
EOF

echo "${TRINO_JVM_ARGS:--server -Xmx8G -XX:InitialRAMPercentage=80 -XX:MaxRAMPercentage=80 -XX:G1HeapRegionSize=32M -XX:+ExplicitGCInvokesConcurrent -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:-OmitStackTraceInFastThrow -XX:ReservedCodeCacheSize=512M -XX:PerMethodRecompilationCutoff=10000 -XX:PerBytecodeRecompilationCutoff=10000 -Djdk.attach.allowAttachSelf=true -Djdk.nio.maxCachedBufferSize=2000000 -Dfile.encoding=UTF-8 -XX:+EnableDynamicAgentLoading}" | tr ' ' '\n' > /etc/trino/jvm.config

echo "--- Discovering and configuring catalogs from explicit environment variables ---"
for i in {1..20}; do
    url_var="DB${i}_URL"
    catalog_name_var="DB${i}_CATALOG_NAME"
    user_var="DB${i}_USER"
    password_var="DB${i}_PASSWORD"

    if [ -n "${!url_var}" ] && [ -n "${!catalog_name_var}" ]; then
        db_url="${!url_var}"
        final_catalog_name="${!catalog_name_var}"

        url_no_jdbc=${db_url#jdbc:}
        connector_name=${url_no_jdbc%%:*}

        echo "--> Found DB${i}_URL. Creating catalog '${final_catalog_name}' for connector '${connector_name}'..."
        cat > "/etc/trino/catalog/${final_catalog_name}.properties" <<EOF
connector.name=${connector_name}
connection-url=${db_url}
connection-user=${!user_var}
connection-password=${!password_var}
EOF
    fi
done

exec /usr/lib/trino/bin/run-trino