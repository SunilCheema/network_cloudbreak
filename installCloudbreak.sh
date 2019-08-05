#!/bin/bash

yum -y update
yum -y install net-tools ntp wget lsof unzip tar iptables-services
systemctl enable ntpd && systemctl start ntpd
systemctl disable firewalld && systemctl stop firewalld
iptables --flush INPUT && \
iptables --flush FORWARD && \
service iptables save
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
getenforce
yum install -y docker
systemctl start docker
systemctl enable docker
sed -i 's/journald/json-file/' /etc/sysconfig/docker
systemctl restart docker
systemctl status docker
yum -y install unzip tar
curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_2.8.0_$(uname)_x86_64.tgz | sudo tar -xz -C /bin cbd
cbd --version
mkdir cloudbreak-deployment
cd cloudbreak-deployment
curl https://ipinfo.io/ip > address.txt
ip=$(cat address.txt)
printf "export UAA_DEFAULT_SECRET=<secret>\nexport UAA_DEFAULT_USER_PW=<password>\nexport UAA_DEFAULT_USER_EMAIL=<email>\nexport PUBLIC_IP=$ip\n" > Profile
rm *.yml
cbd generate
cbd pull-parallel
sudo cbd start
