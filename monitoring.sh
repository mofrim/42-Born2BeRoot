#!/usr/bin/env bash
# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    monitor_vm.sh                                      :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: fmaurer <fmaurer42@posteo.de>              +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/07/03 23:54:35 by fmaurer           #+#    #+#              #
#    Updated: 2024/07/08 15:11:14 by fmaurer          ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

# just to make date output stable
export LC_ALL=en_US.UTF-8

### all the colors! stolen from:
### https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
## ...but actually of no use with `wall`
# check if stdout is a terminal...
if test -t 1; then
  # see if it supports colors...
  ncolors=$(tput colors)
  if test -n "$ncolors" && test $ncolors -ge 8; then
    # Reset
    reset='\033[0m'       # Text Reset
    # Regular Colors
    black='\033[0;30m'        # Black
    red='\033[0;31m'          # Red
    green='\033[0;32m'        # Green
    yellow='\033[0;33m'       # Yellow
    blue='\033[0;34m'         # Blue
    purple='\033[0;35m'       # Purple
    cyan='\033[0;36m'         # Cyan
    white='\033[0;37m'        # White
  fi
fi

### fancy header
echo "#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#"
echo -e "#                                                ${green}:::      ::::::::${reset}    #"
echo -e "#   ${yellow}monitoring.sh${reset}                              ${green}:+:      :+:    :+:${reset}    #"
echo -e "#                                            ${green}+:+ +:+         +:+${reset}      #"
echo -e "#   By: ${blue}fmaurer${reset} <fmaurer42@posteo.de>      ${green}+#+  +:+       +#+${reset}         #"
echo -e "#                                        ${green}+#+#+#+#+#+   +#+${reset}            #"
echo -e "#                                             ${green}#+#    #+#${reset}              #"
echo -e "#                                            ${green}###   ########.fr${reset}        #"
echo -e "#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#"
echo -e "#"

### hostname
if [ -e `which uname` ]
then
        distro=$(cat /etc/*release | grep "PRETTY_NAME" | sed -e 's/^.*="//' -e 's/"$//' )
        echo -e "#  ${blue}Hostname${reset}: ${green}$(uname -n)${reset}"
        echo -e "#  ${blue}Architecture${reset}: $(uname -m) $(uname -o) "
        echo -e "#  ${blue}OS / Distro${reset}: $distro"
        echo -e "#  ${blue}Kernel${reset}: $(uname -r) $(uname -v)"
fi

### displays cpus and vcpus = (cores * threads)
threads=$(lscpu | grep "Thread(s)" | sed 's/[^[:digit:]]*//')
cores=$(lscpu | grep "Core(s)" | sed 's/[^[:digit:]]*//')
echo -e "#  ${blue}Physical CPUs aka Cores${reset}: $cores"
echo -e "#  ${blue}vCPUs = cores * threads${reset}: $((cores * threads))"

### mem stuff
# fake floating point div function, made possible by sed-voodoo-magic
function ff_div() {
        a=$1
        b=$2
        rem=$((10000*b/a))
        div=$(echo "$rem" | sed -e 's/..$/.&/;t' -e 's/.$/.0&/')
        if [ ${#rem} -eq 2 ]
        then
                echo -n "0"
        fi
        echo -n "$div"
}
memtotal=$(($(cat /proc/meminfo | grep "MemTotal" | sed 's/[^[:digit:]]*//g') / 1024))
memfree=$(($memtotal - $(cat /proc/meminfo | grep "MemAvailable" | sed 's/[^[:digit:]]*//g') / 1024))
echo -e "#  ${blue}Memory Usage${reset}: "$memfree "MiB / "$memtotal "MiB ($(ff_div memtotal memfree)%)"

## disk usage stuff
DR1=$(df -h --output=source,used | grep root | sed 's/ \+/ /g' | cut -d ' ' -f2)
DR2=$(df -h --output=source,size | grep root | sed 's/ \+/ /g' | cut -d ' ' -f2)
DR3=$(df -h --output=source,pcent | grep root | sed 's/ \+/ /g' | cut -d ' ' -f2)
disk_root="$(printf "%5s / %4s (%s)" "$DR1" "$DR2" "$DR3")"
DH1=$(df -h --output=source,used | grep home | sed 's/ \+/ /g' | cut -d ' ' -f2)
DH2=$(df -h --output=source,size | grep home | sed 's/ \+/ /g' | cut -d ' ' -f2)
DH3=$(df -h --output=source,pcent | grep home | sed 's/ \+/ /g' | cut -d ' ' -f2)
disk_home="$(printf "%5s / %4s (%s)" "$DH1" "$DH2" "$DH3")"
DS1=$(df -h --output=source,used | grep srv | sed 's/ \+/ /g' | cut -d ' ' -f2)
DS2=$(df -h --output=source,size | grep srv | sed 's/ \+/ /g' | cut -d ' ' -f2)
DS3=$(df -h --output=source,pcent | grep srv | sed 's/ \+/ /g' | cut -d ' ' -f2)
disk_srv="$(printf "%5s / %4s (%s)" "$DS1" "$DS2" "$DS3")"
echo -e "#  ${blue}Disk Usage${reset}:"
echo -e "#     ${blue}root${reset}: $disk_root"
echo -e "#     ${blue}home${reset}: $disk_home"
echo -e "#     ${blue} srv${reset}: $disk_srv"

### cpu load
##
## from the lovely man..
##
##   /proc/loadavg:
##        The first three fields in this file are load average figures
##        giving the number of jobs in the run queue (state  R)  or
##        waiting for disk I/O (state D) averaged over 1, 5, and 15
##        minutes.  They are the same as the load average numbers given by
##        uptime(1) and other programs.  The fourth field consists of two
##        num‐ bers  separated by a slash (/).  The first of these is the
##        number of currently runnable kernel schedul‐ ing entities
##        (processes, threads).  The value after the slash is the number
##        of kernel scheduling  enti‐ ties  that  currently  exist  on
##        the  system.  The fifth field is the PID of the process that was
##        most recently created on the system.
cpu_load_top="$(top -bn2 | grep '%Cpu' | tail -1 | sed 's/^\(.*ni,\)\( *[[:digit:]]\+.[[:digit:]]\)\( id.*\)/\2/')"
cpu_load_top=$(echo $cpu_load_top | awk '{print 100-$1 "%"}')
echo -e "#  ${blue}CPU Usage (top)${reset}: $cpu_load_top"
echo -e "#  ${blue}CPU load (/proc/loadavg)${reset}: $(cat /proc/loadavg | awk '{print "(1m) "$1 ", (5m) " $2 ", (15m) " $3}')"

### last boot - either `who -b` or `last reboot`
echo -e "#  ${blue}Last boot${reset}: $(who -b | sed 's/\s*system boot  //')"
echo -e "#  ${blue}Uptime${reset}: $(uptime | sed -e 's/\(^.*up \+\)\(.*:[[:digit:]]\+\),\(.*\)$/\2 hours/' -e 's/\(^.*up \)\([[:digit:]]\+ min\)\(.*\)/\2/')"

### LVM checkov
LVMDISK=`lvscan | grep "ACTIVE" | head -n1`
if [ -z "$LVMDISK" ]; then
  echo -e "${blue}#  LVM status${reset}: inactive"
else
  echo -e "${blue}#  LVM status${reset}: active"
fi

### TCP conns
tcpconns=$(netstat -tn | grep -c "ESTABLISHED")
echo -e "#  ${blue}TCP Connections${reset}: $tcpconns ESTABLISHED"

### users logged
userslogged=$(uptime | cut -d ',' -f2 | sed 's/\s*//')
echo -e "#  ${blue}Users logged in${reset}: $userslogged"

### ip and mac
iface="enp0s17"
ipaddr=$(ifconfig $iface | head -n2 | tail -1 | sed -e 's/^\s*inet //' -e 's/^\([[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\)\(.*\)/\1/')
macaddr=$(ifconfig $iface | grep "ether" | sed -e 's/^\s*ether //' | cut -d ' ' -f1)
echo -e "#  ${blue}Network${reset}: IP $ipaddr, MAC $macaddr"

### num of sudos
if [ -e /var/log/sudo/sudo.log ]; then
        echo -e "#  ${blue}SUDOs executed${reset}: $(cat /var/log/sudo/sudo.log | grep -c "COMMAND")"
else
        echo -e "#  ${blue}SUDOs executed${reset}:"
fi
