#!/bin/bash
. /etc/hostbalancer/admin-openrc.sh
while true; do
############CPU############

        # MySQL connection parameters
        DB_HOST="cluster1"
        DB_NAME="hostbalancer"
        TABLE_NAME="hostbalancer"
        LOG_FILE="/var/log/hostbalancer/migrations.log"
        #loop 4 times
        for (( i=1; i<=4; i++ )); do
                # Get a list of active compute nodes in the availability zone
                COMPUTE_NODES=$(openstack compute service list --service nova-compute -f value -c Host)

                # Loop through instances and distribute them across compute nodes based on a load metric
                for NODE in $COMPUTE_NODES; do

                        # Check if the host exists in the DB and create if not
                        hostresult=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -D "$DB_NAME" -e "SELECT COUNT(*) FROM hostbalancer WHERE hostname = '$NODE';" -sN)

                        if [ "$hostresult" -eq "0" ]; then
                                mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -D "$DB_NAME" -e "INSERT INTO hostbalancer (hostname) VALUES ('$NODE');"
                        fi

                        # Get Node load
                        CPUTOTAL=$(openstack host show $NODE --format value | awk '$2 == "(total)" { print $3 }')
                        MEMTOTAL=$(openstack host show $NODE --format value | awk '$2 == "(total)" { print $4 }')
                        CPULOAD=$(openstack host show $NODE --format value | awk '$2 == "(used_now)" { print $3 }')
                        MEMLOAD=$(openstack host show $NODE --format value | awk '$2 == "(used_now)" { print $4 }')
                        CPU_USAGE_PERCENT=$(( CPULOAD * 100 / CPUTOTAL ))
                        MEM_USAGE_PERCENT=$(( MEMLOAD * 100 / MEMTOTAL ))

                        mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET cpu_load = '$CPU_USAGE_PERCENT' WHERE hostname = '$NODE';"
                        mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET mem_load = '$MEM_USAGE_PERCENT' WHERE hostname = '$NODE';"

                        # Check if host is on maintenance
                        MAINTCHK=$(nova service-list --host $NODE | grep enabled | grep up | awk {'print $2'})
                        if [ -z $MAINTCHK ]; then
                                mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET on_maintenance = 'yes' WHERE hostname = '$NODE';"
                        else
                                mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET on_maintenance = 'no' WHERE hostname = '$NODE';"
                        fi

                done

                # Get Usage of each compute node and check if one of them has 10% more load than the rest.
                # If so, migrate an instance away from that host

                highcpuhost=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT hostname FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY cpu_load DESC LIMIT 1;")
                highcpuvalue=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT cpu_load FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY cpu_load DESC LIMIT 1;")
                lowcpuhost=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT hostname FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY cpu_load ASC LIMIT 1;")
                lowcpuvalue=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT cpu_load FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY cpu_load ASC LIMIT 1;")
                highmemhost=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT hostname FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY mem_load DESC LIMIT 1;")
                highmemvalue=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT mem_load FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY mem_load DESC LIMIT 1;")
                lowmemhost=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT hostname FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY mem_load ASC LIMIT 1;")
                lowmemvalue=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT mem_load FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY mem_load ASC LIMIT 1;")

                # Calc 300%
                PERCENT_HOSTS_CPU=$(( $lowcpuvalue * 3 ))
                difference=$(( $highcpuvalue - $lowcpuvalue ))

                # If node with higher cpu load is greaten than 10% from the lowest node then one instance from that node will be migrated to the one with the lowest.
                if [ $difference -gt $PERCENT_HOSTS_CPU ]; then
                        time=$(date +'%d-%m-%H:%M:%S')
                        echo "$time Hypervisor $highcpuhost has too many CPU resources." >> $LOG_FILE
                        INSTANCES=$(openstack server list --host $highcpuhost --all-projects -c ID -f value)
                        FIRST_HOST_INSTANCE=$(echo $INSTANCES | awk {'print $1'})
                        echo "Instance $FIRST_HOST_INSTANCE will be migrated to $lowcpuhost" >> $LOG_FILE
                        openstack server migrate $FIRST_HOST_INSTANCE --live --host $lowcpuhost --os-compute-api-version 2.30
                fi


############# MEMORY ##############
                sleep 1m
                # Loop through instances and distribute them across compute nodes based on a load metric
                for NODE in $COMPUTE_NODES; do

                        # Check if the host exists in the DB and create if not
                        hostresult=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -D "$DB_NAME" -e "SELECT COUNT(*) FROM hostbalancer WHERE hostname = '$NODE';" -sN)

                        if [ "$hostresult" -eq "0" ]; then
                                mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -D "$DB_NAME" -e "INSERT INTO hostbalancer (hostname) VALUES ('$NODE');"
                        fi

                        # Get Node load
                        CPUTOTAL=$(openstack host show $NODE --format value | awk '$2 == "(total)" { print $3 }')
                        MEMTOTAL=$(openstack host show $NODE --format value | awk '$2 == "(total)" { print $4 }')
                        CPULOAD=$(openstack host show $NODE --format value | awk '$2 == "(used_now)" { print $3 }')
                        MEMLOAD=$(openstack host show $NODE --format value | awk '$2 == "(used_now)" { print $4 }')
                        CPU_USAGE_PERCENT=$(( CPULOAD * 100 / CPUTOTAL ))
                        MEM_USAGE_PERCENT=$(( MEMLOAD * 100 / MEMTOTAL ))

                        mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET cpu_load = '$CPU_USAGE_PERCENT' WHERE hostname = '$NODE';"
                        mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET mem_load = '$MEM_USAGE_PERCENT' WHERE hostname = '$NODE';"
                done

                # Check if host is on maintenance
                MAINTCHK=$(nova service-list --host $NODE | grep enabled | grep up | awk {'print $2'})
                if [ -z $MAINTCHK ]; then
                        mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET on_maintenance = 'yes' WHERE hostname = '$NODE';"
                else
                        mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -e "UPDATE $DB_NAME.$TABLE_NAME SET on_maintenance = 'no' WHERE hostname = '$NODE';"
                fi

                # Get Usage of each compute node and check if one of them has 10% more load than the rest.
                # If so, migrate an instance away from that host

                highcpuhost=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT hostname FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY cpu_load DESC LIMIT 1;")
                highcpuvalue=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT cpu_load FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY cpu_load DESC LIMIT 1;")
                lowcpuhost=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT hostname FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY cpu_load ASC LIMIT 1;")
                lowcpuvalue=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT cpu_load FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY cpu_load ASC LIMIT 1;")
                highmemhost=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT hostname FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY mem_load DESC LIMIT 1;")
                highmemvalue=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT mem_load FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY mem_load DESC LIMIT 1;")
                lowmemhost=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT hostname FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY mem_load ASC LIMIT 1;")
                lowmemvalue=$(mysql --defaults-file="/etc/hostbalancer/myoptions.ini" -h "$DB_HOST" -N -B -e "SELECT mem_load FROM $DB_NAME.$TABLE_NAME WHERE on_maintenance != 'yes' ORDER BY mem_load ASC LIMIT 1;")

                # 300% more
                PERCENT_HOSTS_MEM=$(( $lowmemvalue * 3 ))
                difference=$(( $highmemvalue - $lowmemvalue ))

                if [ $difference -gt $PERCENT_HOSTS_MEM ]; then
                        time=$(date +'%d-%m-%H:%M:%S')
                        echo "$time Hypervisor $highmemhost has too many MEMORY resources." >> $LOG_FILE
                        INSTANCES=$(openstack server list --host $highmemhost --all-projects -c ID -f value)
                        FIRST_HOST_INSTANCE=$(echo $INSTANCES | awk {'print $1'})
                        echo "Instance $FIRST_HOST_INSTANCE will be migrated to $lowmemhost" >> $LOG_FILE
                        openstack server migrate $FIRST_HOST_INSTANCE --live --host $lowmemhost --os-compute-api-version 2.30
                fi
        done
        sleep 20m
done


