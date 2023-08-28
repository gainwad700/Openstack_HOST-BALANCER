# Ansible managed

# Clear any old environment that may conflict.
for key in $( set | awk '{FS="="}  /^OS_/ {print $1}' ); do unset $key ; done
export OS_PROJECT_DOMAIN_NAME='Default'
export OS_USER_DOMAIN_NAME='Default'
export OS_PROJECT_NAME='service'
export OS_TENANT_NAME='admin'
export OS_USERNAME='host-balancer'
#echo "Please enter your OpenStack Password for project $OS_PROJECT_NAME as user $OS_USERNAME: "
#read -sr OS_PASSWORD_INPUT
export OS_PASSWORD='aaaaabbb*******'
export OS_AUTH_URL='http://cluster1:5000'
export OS_INTERFACE='internal'
export OS_ENDPOINT_TYPE='internalURL'
export OS_IDENTITY_API_VERSION='3'
export OS_REGION_NAME='RegionOne'
export OS_AUTH_PLUGIN='password'
