#!/bin/bash

sudo apt-get update

sudo apt-get install -y bird

sudo cat << EOF > /etc/bird/bird.conf


log syslog { debug, trace, info, remote, warning, error, auth, fatal, bug };
debug protocols all;

router id 192.168.10.3;

protocol kernel {
  learn;
  persist;
  scan time 20;
  import none;
  export none;
}

protocol device {
  scan time 10;
}

protocol direct {
  interface "enp0s8";
  interface "enp0s9";
}

protocol bgp {
  import all;
  export all;
  local as 65001; # your AS number
  neighbor 192.168.20.3 as 65002; # AS number of VM C
  source address 192.168.10.3; # IP address of VM B on network 1
}

EOF

sudo sysctl -w net.ipv4.ip_forward=1

sudo systemctl restart bird

sudo systemctl enable bird