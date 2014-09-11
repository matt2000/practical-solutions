#!/bin/bash

# Setting up Networked LXC Containers
# ===================================
# LXC Deprecated
#
# Continuing the theme of my old scripts that have been obsoleted by newer,
# better options, this is a script that I created first for ubuntu 10.04, and
# later updated for Ubuntu 12.04. The latest LTS (14.04) includes scripts with
# superior solutions, so I plan soon to strip out much of this.
#
# This was based on a script I found on github. Had the original author left a
# signature, I would know who to thank here. All the mistakes are mine alone.

# lxc-clone.sh
# ------------

# This script needs to be run as root. I had intended to add a check for that
# but never got around to it. I guess the consequences of running it without
# the necessary privleges were not painful enough.

# I use this on multiple servers, so machine-specific config goes in an 
# external file.

source lxc-clone.conf

# No set up some defaults, which might be replaced by CLI arguments.

# Snapshot is <sub-directory of a copy-on-write filesystem, and is the "base"
# container that is cloned (by default) to create new containers.

snapshot="webnode-default"

# These defaults from latest IP request.

netmask="255.255.255.224"
broadcast="aa.bb.cc.255"
gateway="aa.bb.cc.225"

local="0"

quota="20G"
memoryLimit="2G"
memswLimit="3G"

# Parse some Command-line agruments. "VE" is my acronym for Virtual Environment.

if [[ -z $2 ]]; then
  VEname="$1"
else
  while true; do
    [[ -z $1 ]] && break

    case "$1" in
        -h|-help|--help)
            #not yet implemented
            usage
            exit 0
            ;;
        -n|--name)
            VEname="$2"
            shift # remove name from remaining arguments
            ;;
        -s|--snapshot)
            snapshot="$2"
            shift
            ;;
        -a|--address|--internal) #ip address -- "internal" address for local VEs
            address="$2"
            shift
            ;;
        -e|--external)
            
            shift
            ;;
        -m|--mask)
            netmask="$2"
            shift
            ;;
        -g|--gateway)
            gateway="$2"
            shift
            ;;
        -b|--broadcast)
            broadcast="$2"
            shift
            ;;
        -l|--local) #used for no external IP
            local="1"
            ;;
        -q|--quota) #ZFS storage quota
            quota="$2"
            shift
            ;;
        -M|--memory) #LXC memory limit
            memoryLimit="$2""G"
            let "plusOne = $2 + 1"
            memswLimit="$plusOne""G"
            shift
            ;;
    esac

    shift
  done
fi

#@todo make sure name doesn't already exist.
if [[ -z $VEname ]]; then
  echo "Name is required."
  exit 0;
fi

echo "Settings up Ninjitsu Virtual Environment for $VEname"

# Check if an External IP is needed.

if [[ -z $address ]]; then

  # I used a SQLite Database for tracking IP address assignments.  Here we
  # claim the first unused internal IP

  echo "Acquiring an internal IP address..."
  sqlite3 $sqldb 'UPDATE internal_ips SET name="'$VEname'" WHERE ip=(SELECT ip FROM internal_ips WHERE name IS NULL LIMIT 1);'
  address=`sqlite3 $sqldb 'SELECT ip FROM internal_ips WHERE name="'$VEname'"'`
else
  #@todo check for conflicts

  # Record the internal address, if it came from the CLI options

  sqlite3 $sqldb 'INSERT INTO internal_ips (ip, name) VALUES ("'$address'","'$VEname'")';
fi


# Now we claim the first unused external IP.
# Internal address is specified because a VE might (in theory) have multiple
# internal addresses, but we want to map to one in particular.

#@todo is this stupid?
if [[ -z $external_ip ]] && [[ $local -eq "0" ]]; then
  sqlite3 $sqldb 'UPDATE external_ips SET name="'$VEname'", internal="'$address'" WHERE ip=(SELECT ip FROM external_ips WHERE name IS NULL LIMIT 1);'
  external_ip=`sqlite3 $sqldb 'SELECT ip FROM external_ips WHERE name="'$VEname'"'`
fi

rootfs="$VEpath/$VEname/rootfs"

# Clone the base CoW filesystem

cp $VEpath/$snapshot $VEpath/$VEname

# Secret sauce.

set-quota $quota $VEpath/$VEname

# Set up network interface on guest

cat <<EOF > $rootfs/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
	address $address
	netmask 255.255.255.0
	gateway $hostgateway
        post-up route add default gw $hostgateway
EOF

# Set the hostname for the container.

write_ubuntu_hostname() {
cat <<EOF > $rootfs/etc/hostname
$VEname
EOF
cat <<EOF > $rootfs/etc/hosts
127.0.0.1   $VEname localhost

#The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

echo "hello $VEname" > $rootfs/var/www/index.html
}
write_ubuntu_hostname

# Write LXC config file.

write_lxc_configuration() {
cat <<EOF > $VEpath/$VEname/config
lxc.utsname = $VEname
lxc.tty = 6
lxc.pts = 1024
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = lxcbr0
lxc.network.name = eth0
#lxc.network.mtu = 1500
lxc.network.ipv4 = $address/24
lxc.rootfs = $rootfs
lxc.cgroup.devices.deny = a
# /dev/null and zero
lxc.cgroup.devices.allow = c 1:3 rwm
lxc.cgroup.devices.allow = c 1:5 rwm
# consoles
lxc.cgroup.devices.allow = c 5:1 rwm
lxc.cgroup.devices.allow = c 5:0 rwm
lxc.cgroup.devices.allow = c 4:0 rwm
lxc.cgroup.devices.allow = c 4:1 rwm
# /dev/{,u}random
lxc.cgroup.devices.allow = c 1:9 rwm
lxc.cgroup.devices.allow = c 1:8 rwm
lxc.cgroup.devices.allow = c 136:* rwm
lxc.cgroup.devices.allow = c 5:2 rwm
# rtc
lxc.cgroup.devices.allow = c 254:0 rwm
#resource managment
lxc.cgroup.memory.limit_in_bytes = $memoryLimit
lxc.cgroup.memory.memsw.limit_in_bytes = $memswLimit
lxc.cgroup.memory.swappiness = 30
EOF
}
write_lxc_configuration

# Copy ssh keys.

cp /root/.ssh/id_rsa.pub $rootfs/root/.ssh/authorized_keys


do_external_networking() {

  # The SQLite look-ups should probably be here.

  interface=`echo $external_ip | grep -o "\w*$"`

  #Set-up network interface on host
  cat <<EOF >> /etc/network/interfaces

# $VEname
auto eth0:$ipset$interface
iface eth0:$ipset$interface inet static
  address $external_ip
  netmask $netmask
  broadcast $broadcast
  gateway $gateway
# end $VEname
EOF


# Port forwading with iptables.

  iptables -t nat -I PREROUTING -d $external_ip -j DNAT --to-destination $address
}

if [[ $local -eq "0" ]]; then
  do_external_networking
fi

# Add this VE to the host's hosts file.

cat <<EOF >> /etc/hosts
$address $VEname
EOF

lxc-create -n $VEname -f $VEpath/$VEname/config
lxc-start -n $VEname -d && ssh $VEname route add default gw $hostgateway

#@todo set-up lxc-monitor

echo "New Virtual Environment $VEname from $snapshot running at $address $external_ip"
