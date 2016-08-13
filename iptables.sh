iptver=$1
rulefile=/etc/iptables/${iptver}.rules
cat ${rulefile}

tableliste="filter nat mangle raw security"
tableliste="nat"
tableliste="filter"


function show_config ()
{
    # Show current config
    echo "========================================================================"
    #    ${iptver} -nvL --line-numbers
    for i in $tableliste
    do
	${iptver} -t $i -nvL --line-numbers
    done
    echo "========================================================================"
}

function clean_config ()
{
    # Clean current config
    ${iptver} -F
    ${iptver} -X

    for i in $tableliste
    do
	${iptver} -t $i -F
	${iptver} -t $i -X
    done
    echo "========================================================================"
}

init_config ()
{
    # keep established
    ${iptver} -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    ${iptver} -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

    # drop invalid
    ${iptver} -A INPUT   -m state --state INVALID -j DROP
    ${iptver} -A FORWARD -m state --state INVALID -j DROP
    ${iptver} -A OUTPUT  -m state --state INVALID -j DROP

    # Allow loopback
    ${iptver} -t filter -A INPUT -i lo -j ACCEPT
    ${iptver} -t filter -A OUTPUT -o lo -j ACCEPT

    # ICMP (Ping)
    ${iptver} -t filter -A INPUT -p icmp  -m limit --limit 1/second -j ACCEPT
    ${iptver} -t filter -A OUTPUT -p icmp -j ACCEPT

    # DNS In/Out
    ${iptver} -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
    ${iptver} -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
    ${iptver} -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
    ${iptver} -t filter -A INPUT -p udp --dport 53 -j ACCEPT

    # NTP Out
    ${iptver} -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT

}

web_config ()
{
    # HTTP + HTTPS Out
    ${iptver} -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
    ${iptver} -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT

    # HTTP + HTTPS In
    ${iptver} -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
    ${iptver} -t filter -A INPUT -p tcp --dport 443 -j ACCEPT

    # ddos limit to 10/minutes if 100/minutes reached
    ${iptver} -A INPUT -p tcp --dport 80 -m limit --limit 10/minute --limit-burst 100 -j ACCEPT
    ${iptver} -A INPUT -p tcp --dport 443 -m limit --limit 10/minute --limit-burst 100 -j ACCEPT
}

drop_all_other ()
{
    # drop all
    ${iptver} -t filter -P INPUT DROP
    ${iptver} -t filter -P FORWARD DROP
    ${iptver} -t filter -P OUTPUT DROP
}

one_port_out ()
{
    ${iptver} -t filter -A OUTPUT -p tcp --dport $1 -j ACCEPT
}

one_port_in ()
{
    ${iptver} -t filter -A INPUT -p tcp --dport $1 -j ACCEPT
}

one_port ()
{
    one_port_in $1
    one_port_out $1
}

clean_config
show_config

init_config
web_config


# 22 for ssh
for i in 22
do
    one_port_in $i
done

# for ftp and ssh
for i in 21 22
do
    one_port_out $i
done



drop_all_other
show_config


# Save
${iptver}-save > ${rulefile}

