        COMPUTE_NODES=$(openstack compute service list --service nova-compute -f value -c Host)
        #ZONES=$(openstack compute service list --service nova-compute -f value -c Zone)

         # MySQL connection parameters
         DB_HOST="opst-devcluster1.intra"
         DB_NAME="hostbalancer"
         TABLE_NAME="hostbalancer"

        # Loop through instances and distribute them across compute nodes based on a load metric
        for NODE in $COMPUTE_NODES; do

                # Check if the host exists in the DB and create if not
                hostresult=$(mysql --defaults-file="myoptions.ini" -h "$DB_HOST" -D "$DB_NAME" -e "SELECT COUNT(*) FROM hostbalancer WHERE hostname = '$NODE';" -sN)

                if [ "$hostresult" -eq "0" ]; then
                        mysql --defaults-file="myoptions.ini" -h "$DB_HOST" -D "$DB_NAME" -e "INSERT INTO hostbalancer (hostname) VALUES ('$NODE');"
                fi

                # Get Node load
                CPUTOTAL=$(openstack host show $NODE --format value | awk '$2 == "(total)" { print $3 }')
                MEMTOTAL=$(openstack host show $NODE --format value | awk '$2 == "(total)" { print $4 }')
                CPULOAD=$(openstack host show $NODE --format value | awk '$2 == "(used_now)" { print $3 }')
                MEMLOAD=$(openstack host show $NODE --format value | awk '$2 == "(used_now)" { print $4 }')
                CPU_USAGE_PERCENT=$(( CPULOAD * 100 / CPUTOTAL ))
                MEM_USAGE_PERCENT=$(( MEMLOAD * 100 / MEMTOTAL ))
                #THRESHOLD_MEM_PERCENT=$(75)
                #THRESHOLD_CPU_PERCENT=$(75)

                mysql --defaults-file="myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET cpu_load = '$CPU_USAGE_PERCENT' WHERE hostname = '$NODE';"
                mysql --defaults-file="myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET mem_load = '$MEM_USAGE_PERCENT' WHERE hostname = '$NODE';"
        done

