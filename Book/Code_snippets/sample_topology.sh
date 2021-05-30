#!/bin/bash

if [ $EUID -ne 0 ]
then
    echo "Run me as root..."
    exit
fi

if [ $# -eq 1 ]
then
    echo "Tearing down the sample network..."
    echo -e "\t(If one didn't exist before this script will silently fail)."
    docker rm $(docker stop h-a-1 h-b-1 r-a-b 2>/dev/null) > /dev/null 2>&1
    ip link del subnet-a-brd 2>/dev/null
    ip link del subnet-b-brd 2>/dev/null
    exit
fi

echo "Setting up the topology seen on figure 3.1\n"
echo -e "\tDisabling bridge calls to iptables (section 2.7)"
echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables

echo -e "\tEnabling IP forwarding within the host\n"
echo 0 > /proc/sys/net/ipv4/ip_forward

echo -e "\tSetting up the bridges"
echo -e "\t\tSetting up subnet A's bridge"
ip link add subnet-a-brd type bridge
ip link set subnet-a-brd up

echo -e "\t\tSetting up subnet B's bridge\n"
ip link add subnet-b-brd type bridge
ip link set subnet-b-brd up

echo -e "\tSpawning the hosts"
echo -e "\t\tSpawning H-A-1"
docker run -d --name h-a-1 --network none --cap-add SYS_ADMIN ubuntu_node > /dev/null

echo -e "\t\t\tLinking its network namespace to /var/run/netns"
ln -sf /proc/$(docker inspect -f {{.State.Pid}} h-a-1)/ns/net /var/run/netns/h-a-1

echo -e "\t\t\tSetting the hostname"
docker exec h-a-1 hostname h-a-1

echo -e "\t\tSpawning H-B-1"
docker run -d --name h-b-1 --network none --cap-add SYS_ADMIN ubuntu_node > /dev/null

echo -e "\t\t\tLinking its network namespace to /var/run/netns"
ln -sf /proc/$(docker inspect -f {{.State.Pid}} h-b-1)/ns/net /var/run/netns/h-b-1

echo -e "\t\t\tSetting the hostname"
docker exec h-b-1 hostname h-b-1

echo -e "\t\tSpawning Router-A-B"
docker run -d --name r-a-b --network none --sysctl net.ipv4.ip_forward=1 --cap-add NET_ADMIN --cap-add SYS_ADMIN ubuntu_router > /dev/null

echo -e "\t\t\tLinking its network namespace to /var/run/netns\n"
ln -sf /proc/$(docker inspect -f {{.State.Pid}} r-a-b)/ns/net /var/run/netns/r-a-b

echo -e "\t\t\tSetting the hostname"
docker exec r-a-b hostname r-a-b

echo -e "\tSetting up necessary veths"
echo -e "\t\tSetting up veth H-A-1 <--> Subnet A Bridge"
ip link add veth-h-a-1 type veth peer name veth-brd-h-a-1
ip link set veth-h-a-1 netns h-a-1
ip link set veth-brd-h-a-1 master subnet-a-brd
ip -n h-a-1 link set veth-h-a-1 up
ip link set veth-brd-h-a-1 up

echo -e "\t\tSetting up veth Subnet A Bridge <--> Router-A-B"
ip link add veth-r-a-b-a type veth peer name brd-r-a-b-a
ip link set veth-r-a-b-a netns r-a-b
ip link set brd-r-a-b-a master subnet-a-brd
ip -n r-a-b link set veth-r-a-b-a up
ip link set brd-r-a-b-a up

echo -e "\t\tSetting up veth H-B-1 <--> Subnet B Bridge"
ip link add veth-h-b-1 type veth peer name veth-brd-h-b-1
ip link set veth-h-b-1 netns h-b-1
ip link set veth-brd-h-b-1 master subnet-b-brd
ip -n h-b-1 link set veth-h-b-1 up
ip link set veth-brd-h-b-1 up

echo -e "\t\tSetting up veth Subnet B Bridge <--> Router-A-B\n"
ip link add veth-r-a-b-b type veth peer name brd-r-a-b-b
ip link set veth-r-a-b-b netns r-a-b
ip link set brd-r-a-b-b master subnet-b-brd
ip -n r-a-b link set veth-r-a-b-b up
ip link set brd-r-a-b-b up

echo -e "\tAddressing the interfaces"
echo -e "\t\tAddressing H-A-1"
ip -n h-a-1 addr add 10.0.0.2/24 brd + dev veth-h-a-1

echo -e "\t\tAddressing Router-A-B's interface on subnet A"
ip -n r-a-b addr add 10.0.0.1/24 brd + dev veth-r-a-b-a

echo -e "\t\tAddressing H-B-1"
ip -n h-b-1 addr add 10.0.1.2/24 brd + dev veth-h-b-1

echo -e "\t\tAddressing Router-A-B's interface on subnet A\n"
ip -n r-a-b addr add 10.0.1.1/24 brd + dev veth-r-a-b-b

echo -e "\tAdding necessary routes to hosts"
echo -e "\t\tAdding default route to H-A-1 through Router-A-B"
ip -n h-a-1 route add default via 10.0.0.1

echo -e "\t\tAdding default route to H-B-1 through Router-A-B\n"
ip -n h-b-1 route add default via 10.0.1.1

echo "Done setting up the network!"
exit
