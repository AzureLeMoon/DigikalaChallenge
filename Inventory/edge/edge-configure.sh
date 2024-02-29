#!/bin/bash

sudo apt-get install python3-pip -y

pip3 install flask

sudo cp /tmp/request-limiting-solution.py /home/vagrant/request-limiting-solution.py

nohup python3 script.py > script.out 2>&1 &

sudo ip route del default

sudo ip route add default via 192.168.20.2 dev enp0s8