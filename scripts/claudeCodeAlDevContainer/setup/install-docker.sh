#!/bin/bash
set -e

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh
sudo usermod -aG docker "$USER"
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

sudo rm -f /etc/sudoers.d/docker-autostart
sudo bash -lc 'echo "JWRvY2tlciBBTEw9KEFMTCkgTk9QQVNTV0Q6IC91c3Ivc2Jpbi9zZXJ2aWNlIGRvY2tlciBzdGFydAo=" | base64 -d > /etc/sudoers.d/docker-autostart'
sudo sed -i 's/\r$//' /etc/sudoers.d/docker-autostart
sudo chmod 440 /etc/sudoers.d/docker-autostart

if ! grep -qF '# Docker autostart' ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Docker autostart" >> ~/.bashrc
    echo 'if [ "$(service docker status 2>&1 | grep -c '"'"'not running'"'"')" -eq 1 ]; then' >> ~/.bashrc
    echo "    sudo service docker start > /dev/null 2>&1" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
fi

sudo service docker start
sudo docker run --rm hello-world
