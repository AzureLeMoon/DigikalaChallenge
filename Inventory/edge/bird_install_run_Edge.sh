#!/bin/bash

sudo apt-get update

sudo apt-get install -y bird

sudo cat << EOF > /etc/bird/bird.conf

log syslog { debug, trace, info, remote, warning, error, auth, fatal, bug };
debug protocols all;

router id 192.168.20.3;

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
}

protocol bgp {
  import all;
  export all;
  local as 65002; # your AS number
  neighbor 192.168.20.2 as 65001; # AS number of VM B
  source address 192.168.20.3; # IP address of VM C on network 2
}

EOF

sudo systemctl restart bird

sudo systemctl enable bird