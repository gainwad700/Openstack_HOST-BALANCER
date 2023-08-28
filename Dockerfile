FROM docker.io/dokken/rockylinux-8
MAINTAINER sns.network
RUN dnf update -y
RUN dnf install python3 python3-pip -y
RUN pip3 install -U pip
RUN pip install python-openstackclient
RUN pip install python-novaclient
RUN dnf install mariadb -y
RUN mkdir /etc/hostbalancer
RUN mkdir /var/log/hostbalancer
COPY host-balancer.sh /etc/hostbalancer
COPY admin-openrc.sh /etc/hostbalancer
COPY myoptions.ini /etc/hostbalancer
CMD ["cat", "hosts", ">>", "/etc/hosts"]
CMD ["bash", "/etc/hostbalancer/host-balancer.sh"]
