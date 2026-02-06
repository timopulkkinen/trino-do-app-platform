#!/bin/bash
set -e

# Default config directory to /etc/trino, but allow override via TRINO_CONFIG_DIR environment variable
CONFIG_DIR="${TRINO_CONFIG_DIR:-/etc/trino}"

# Create necessary directories
mkdir -p "${CONFIG_DIR}/catalog"

# Create Trino config.properties
echo "Creating Trino config.properties..."
cat > "${CONFIG_DIR}/config.properties" <<EOF
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8080
http-server.process-forwarded=true
discovery.uri=http://localhost:8080
EOF

# Create JVM config
echo "Creating Trino jvm.config..."
echo "${TRINO_JVM_ARGS:--server -Xmx8G -XX:InitialRAMPercentage=80 -XX:MaxRAMPercentage=80 -XX:G1HeapRegionSize=32M -XX:+ExplicitGCInvokesConcurrent -XX:+ExitOnOutOfMemoryError -XX:+HeapDumpOnOutOfMemoryError -XX:-OmitStackTraceInFastThrow -XX:ReservedCodeCacheSize=512M -XX:PerMethodRecompilationCutoff=10000 -XX:PerBytecodeRecompilationCutoff=10000 -Djdk.attach.allowAttachSelf=true -Djdk.nio.maxCachedBufferSize=2000000 -Dfile.encoding=UTF-8 -XX:+EnableDynamicAgentLoading}" | tr ' ' '\n' > "${CONFIG_DIR}/jvm.config"

# Discover and configure catalogs from explicit environment variables
# Property name transformation: __ -> . (dot), _ -> - (hyphen)
echo "Discovering and configuring catalogs from explicit environment variables..."
for i in {1..20}; do
    catalog_name_var="DB${i}_CATALOG_NAME"

    # Skip if no catalog name is set
    [ -z "${!catalog_name_var}" ] && continue

    final_catalog_name="${!catalog_name_var}"
    catalog_file="${CONFIG_DIR}/catalog/${final_catalog_name}.properties"

    echo "--> Creating catalog '${final_catalog_name}'..."

    # Clear/create the catalog file
    > "$catalog_file"

    # Find all DB{i}_* environment variables and write as properties
    prefix="DB${i}_"
    env | grep "^${prefix}" | while IFS='=' read -r env_name env_value; do
        # Extract the property part after DB{i}_
        prop_name="${env_name#$prefix}"

        # Skip the CATALOG_NAME variable itself
        [ "$prop_name" = "CATALOG_NAME" ] && continue

        # Transform: lowercase, then __ -> . (dot), then _ -> - (hyphen)
        prop_name=$(echo "$prop_name" | tr '[:upper:]' '[:lower:]' | sed 's/__/./g' | sed 's/_/-/g')

        # Write property to catalog file
        echo "${prop_name}=${env_value}" >> "$catalog_file"
    done

    # Check if any properties were written
    if [ ! -s "$catalog_file" ]; then
        echo "    Warning: No properties found for catalog '${final_catalog_name}'"
        rm -f "$catalog_file"
    else
        # Auto-detect connector.name from connection-url if not explicitly set
        if ! grep -q "^connector\.name=" "$catalog_file"; then
            connection_url=$(grep "^connection-url=" "$catalog_file" | cut -d'=' -f2-)
            if [ -n "$connection_url" ]; then
                # Extract connector from jdbc:postgresql://... -> postgresql
                url_no_jdbc=${connection_url#jdbc:}
                connector_name=${url_no_jdbc%%:*}
                echo "connector.name=${connector_name}" >> "$catalog_file"
                echo "    Auto-detected connector: ${connector_name}"
            fi
        fi
        echo "    Properties written to ${catalog_file}"
    fi
done

echo "Configuration setup completed."