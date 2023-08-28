# About
This script checks all the hypervisors / compute nodes and its load. The load stats are written into the DB.
Default the threshold is defined by 300%. That means if any CPU or MEMORY ressources on the compute node with the most has 300% more then the one with the least, it will take one instance via live-migration away from the higher to the lower.

If one compute node is down or in maintenance, this one will not be taken into consideration in the stats.

## Prereqs
I recomend to use this tool only if at least 3 instances per compute node are available. This, to prevent a ping-pong effect.
The container is built to run just on one control node.

By 4 compute nodes at 12 VMs.


# Installation
git clone https://github.com/gainwad700/Openstack_HOST-BALANCER.git

## Openstack User
openstack user create host-balancer --password *****************
openstack role add --user host-balancer --project service admin

## DB
create database hostbalancer;
use hostbalancer;
create table hostbalancer (id INT AUTO_INCREMENT PRIMARY KEY, hostname VARCHAR(255), cpu_load INT, mem_load INT, on_maintenance VARCHAR(255), timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
create user 'hostbalancer'@'%' identified by 'hostbalancer';
grant all privileges on hostbalancer.* to 'hostbalancer'@'%';
flush privileges;

## Logs
mkdir /var/log/hostbalancer

## Run!
docker run --name host-balancer -v /var/log/hostbalancer:/var/log/hostbalancer --network host registry1:5000/host-balancer:1

### Check Values
MariaDB [hostbalancer]> use hostbalancer; select * from hostbalancer;


