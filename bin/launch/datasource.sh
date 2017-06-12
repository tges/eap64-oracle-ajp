. $JBOSS_HOME/bin/launch/launch-common.sh
. $JBOSS_HOME/bin/launch/tx-datasource.sh

# Arguments:
# $1 - service name
# $2 - datasource jndi name
# $3 - datasource username
# $4 - datasource password
# $5 - datasource host
# $6 - datasource port
# $7 - datasource databasename
# $8 - connection checker class
# $9 - exception sorter class
# $10 - driver
# $11 - original service name
# $12 - datasource jta
# $13 - oracle connection string -- added by ora01000@time-gate.com
function generate_datasource() {
  pool_name="${1}"
  jndi_name="${2}"
  driver="${10}"
  service_name="${11}"
  
  
  if [ -n "$NON_XA_DATASOURCE" ] && [ "$NON_XA_DATASOURCE" = "true" ]; then
    ds="
              <datasource jta=\"${12}\" jndi-name=\"$2\" pool-name=\"$1\" use-java-context=\"true\" enabled=\"true\">
                  <connection-url>${13}</connection-url>
                  <driver>${10}</driver>"
  else
    ds="
              <xa-datasource jndi-name=\"$2\" pool-name=\"$1\" use-java-context=\"true\" enabled=\"true\">
                  <xa-datasource-property name=\"ServerName\">$5</xa-datasource-property>
                  <xa-datasource-property name=\"Port\">$6</xa-datasource-property>
                  <xa-datasource-property name=\"DatabaseName\">$7</xa-datasource-property>
                  <driver>${10}</driver>"
  fi

  if [ -n "$tx_isolation" ]; then
    ds="$ds 
                  <transaction-isolation>$tx_isolation</transaction-isolation>"
  fi
  if [ -n "$min_pool_size" ] || [ -n "$max_pool_size" ]; then
    if [ -n "$NON_XA_DATASOURCE" ] && [ "$NON_XA_DATASOURCE" = "true" ]; then
      ds="$ds
                    <pool>"
    else
      ds="$ds
                    <xa-pool>"
    fi
    if [ -n "$min_pool_size" ]; then
      ds="$ds
                      <min-pool-size>$min_pool_size</min-pool-size>"
    fi
    if [ -n "$max_pool_size" ]; then
      ds="$ds
                      <max-pool-size>$max_pool_size</max-pool-size>"
    fi
    if [ -n "$NON_XA_DATASOURCE" ] && [ "$NON_XA_DATASOURCE" = "true" ]; then
      ds="$ds
                    </pool>"
    else
      ds="$ds
                    </xa-pool>"
    fi
  fi     

  ds="$ds
                  <security>
                      <user-name>$3</user-name>
                      <password>$4</password>
                  </security>
                  <validation>
                      <validate-on-match>true</validate-on-match>
                      <valid-connection-checker class-name=\"$8\"></valid-connection-checker>
                      <exception-sorter class-name=\"$9\"></exception-sorter>
                  </validation>"

  if [ -n "$NON_XA_DATASOURCE" ] && [ "$NON_XA_DATASOURCE" = "true" ]; then
    ds="$ds
              </datasource>"
  else
    ds="$ds
              </xa-datasource>"
  fi
  
  if [ -n "$TIMER_SERVICE_DATA_STORE" -a "$TIMER_SERVICE_DATA_STORE" = "${service_name}" ]; then
    inject_timer_service ${pool_name}_ds
    inject_datastore $pool_name $jndi_name $driver
  fi

  echo $ds | sed ':a;N;$!ba;s|\n|\\n|g'
}

# Arguments:
# $1 - timer service datastore
function inject_timer_service() {
  timerservice="            <timer-service thread-pool-name=\"default\" default-data-store=\"${1}\">\
                <data-stores>\
                    <file-data-store name=\"default-file-store\" path=\"timer-service-data\" relative-to=\"jboss.server.data.dir\"/>\
                    <!-- ##DATASTORES## -->\
                </data-stores>\
            </timer-service>"
  sed -i "s|<!-- ##TIMER_SERVICE## -->|${timerservice%$'\n'}|" $CONFIG_FILE
}

# Arguments:
# $1 - service name
# $2 - datasource jndi name
# $3 - datasource databasename
function inject_datastore() {
  datastore="<database-data-store name=\"${1}_ds\" datasource-jndi-name=\"${2}\" database=\"${3}\" partition=\"${1}_part\"/>\
        <!-- ##DATASTORES## -->"
  sed -i "s|<!-- ##DATASTORES## -->|${datastore%$'\n'}|" $CONFIG_FILE
}

# Finds the name of the database services and generates data sources
# based on this info
function inject_datasources() {
  # Find all databases in the $DB_SERVICE_PREFIX_MAPPING separated by ","
  IFS=',' read -a db_backends <<< $DB_SERVICE_PREFIX_MAPPING

  if [ -z "$TIMER_SERVICE_DATA_STORE" ]; then
    inject_timer_service default-file-store
  fi

  if [ "${#db_backends[@]}" -eq "0" ]; then
    datasources=$(generate_datasource)
  else
    for db_backend in ${db_backends[@]}; do

      service_name=${db_backend%=*}
      service=${service_name^^}
      service=${service//-/_}
      db=${service##*_}
      prefix=${db_backend#*=}
      
#      echo "------------"
#      echo "db_backend: $db_backend"
#      echo "service_name: $service_name"
#      echo "service_name^^: ${service_name^^}"
#      echo "service: $service"
#      echo "db: $db"
#      echo "prefix: $prefix"
#      echo "------------"

      if [[ "$service" != *"_"* ]]; then
          echo "There is a problem with the DB_SERVICE_PREFIX_MAPPING environment variable!"
          echo "You provided the following database mapping (via DB_SERVICE_PREFIX_MAPPING): $db_backend. The mapping does not contain the database type."
          echo
          echo "Please make sure the mapping is of the form <name>-<database_type>=PREFIX, where <database_type> is either MYSQL or POSTGRESQL."
          echo
          echo "WARNING! The datasource for $prefix service WILL NOT be configured."
          continue
      fi

#      host=$(find_env "${service}_SERVICE_HOST")
#      port=$(find_env "${service}_SERVICE_PORT")

#      if [ -z $host ] || [ -z $port ]; then
#        echo "There is a problem with your service configuration!"
#        echo "You provided following database mapping (via DB_SERVICE_PREFIX_MAPPING environment variable): $db_backend. To configure datasources we expect ${service}_SERVICE_HOST and ${service}_SERVICE_PORT to be set."
#        echo
#        echo "Current values:"
#        echo
#        echo "${service}_SERVICE_HOST: $host"
#        echo "${service}_SERVICE_PORT: $port"
#        echo
#        echo "Please make sure you provided correct service name and prefix in the mapping. Additionally please check that you do not set portalIP to None in the $service_name service. Headless services are not supported at this time."
#        echo
#        echo "WARNING! The ${db,,} datasource for $prefix service WILL NOT be configured."
#        continue
#      fi

      # Custom JNDI environment variable name format: [NAME]_[DATABASE_TYPE]_JNDI
      jndi=$(get_jndi_name "$prefix" "$service")

      # Database username environment variable name format: [NAME]_[DATABASE_TYPE]_USERNAME
      username=$(find_env "${prefix}_USERNAME")

      # Database password environment variable name format: [NAME]_[DATABASE_TYPE]_PASSWORD
      password=$(find_env "${prefix}_PASSWORD")

      # Database name environment variable name format: [NAME]_[DATABASE_TYPE]_DATABASE
      database=$(find_env "${prefix}_DATABASE")
      
      ## Added by ora01000@time-gate.com
      ## find oracle connection string
      oracle_connection_string=$(find_env "ORACLE_CONNECTION_STRING")
      
#      echo "-----------------"
#      echo "jndi: $jndi"
#      echo "username: $username"
#      echo "password: $password"
#      echo "database: $database"
#      echo "oracle_connection_string: $oracle_connection_string"
#      echo "-----------------"
      
      if [ -z $jndi ] || [ -z $username ] || [ -z $password ] || [ -z $database ]; then
        echo "Ooops, there is a problem with the ${db,,} datasource!"
        echo "In order to configure ${db,,} datasource for $prefix service you need to provide following environment variables: ${prefix}_USERNAME, ${prefix}_PASSWORD, ${prefix}_DATABASE."
        echo
        echo "Current values:"
        echo
        echo "${prefix}_USERNAME: $username"
        echo "${prefix}_PASSWORD: $password"
        echo "${prefix}_DATABASE: $database"
        echo
        echo "WARNING! The ${db,,} datasource for $prefix service WILL NOT be configured."
        continue
      fi

      # Transaction isolation level environment variable name format: [NAME]_[DATABASE_TYPE]_TX_ISOLATION
      tx_isolation=$(find_env "${prefix}_TX_ISOLATION")
    
      # min pool size environment variable name format: [NAME]_[DATABASE_TYPE]_MIN_POOL_SIZE
      min_pool_size=$(find_env "${prefix}_MIN_POOL_SIZE")
    
      # max pool size environment variable name format: [NAME]_[DATABASE_TYPE]_MAX_POOL_SIZE
      max_pool_size=$(find_env "${prefix}_MAX_POOL_SIZE")

      # jta environment variable name format: [NAME]_[DATABASE_TYPE]_JTA
      jta=$(find_env "${prefix}_JTA" true)

      # $NON_XA_DATASOURCE: [NAME]_[DATABASE_TYPE]_NONXA (DB_NONXA)
      NON_XA_DATASOURCE=$(find_env "${prefix}_NONXA" false)
      
#      echo "-----------------"
#      echo "tx_isolation: $tx_isolation"
#      echo "min_pool_size: $min_pool_size"
#      echo "max_pool_size: $max_pool_size"
#      echo "jta: $jta"
#      echo "NON_XA_DATASOURCE: $NON_XA_DATASOURCE"
#      echo "-----------------"      

      ## dummy $host and $port
      host="__"
      port="__"
      
      driver="oracle"
      checker="org.jboss.jca.adapters.jdbc.extensions.oracle.OracleValidConnectionChecker"
      sorter="org.jboss.jca.adapters.jdbc.extensions.oracle.OracleExceptionSorter"
      datasources="$datasources$(generate_datasource ${service,,}-${prefix} $jndi $username $password $host $port $database $checker $sorter $driver $service_name $jta $oracle_connection_string)\n"

#     echo "-----------------"
#     echo "datasources: $datasources"
#     echo "-----------------"      
    done
  fi

#  datasources="$datasources$(inject_tx_datasource)"
 
#  echo "-----------------"
#  echo "datasources: $datasources"
#  echo "-----------------"      
  
  sed -i "s|<!-- ##DATASOURCES## -->|${datasources%$'\n'}|" $CONFIG_FILE
}

function get_jndi_name() {
  prefix=$1
  echo $(find_env "${prefix}_JNDI" "java:jboss/datasources/${service,,}")
}
