#!/bin/bash

# Copyright (C) 2018 Joseph Tingiris (joseph.tingiris@gmail.com)

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# begin IP.bash.include

IP_Bash="IP.bash"
IP_Bash_Dirs=()
IP_Bash_Dirs+=($(dirname $(readlink -e $BASH_SOURCE)))
for IP_Bash_Dir in ${IP_Bash_Dirs[@]}; do
    while [ "$IP_Bash_Dir" != "" ] && [ "$IP_Bash_Dir" != "/" ]; do # search backwards
        IP_Bash_Source_Dirs=()
        IP_Bash_Source_Dirs+=("${IP_Bash_Dir}")
        IP_Bash_Source_Dirs+=("${IP_Bash_Dir}/include")
        IP_Bash_Source_Dirs+=("${IP_Bash_Dir}/include/debug-bash")
        for IP_Bash_Source_Dir in ${IP_Bash_Source_Dirs[@]}; do
            IP_Bash_Source=${IP_Bash_Source_Dir}/${IP_Bash}
            if [ -r "${IP_Bash_Source}" ]; then
                source "${IP_Bash_Source}"
                break
            else
                unset IP_Bash_Source
            fi
        done
        if [ "$IP_Bash_Source" != "" ]; then break; fi
        IP_Bash_Dir=$(dirname "$IP_Bash_Dir") # search backwards
    done
done
if [ "$IP_Bash_Source" == "" ]; then echo "$IP_Bash file not found"; abort 1; fi
unset IP_Bash_Dir IP_Bash

# end IP.bash.include

function abort() {
    if [ "$1" != "" ]; then
        echo
        echo $1
        echo
    fi
    echo
    times
    echo
    exit 1
}

#
# IP tests
#

# 0=true, 1=false
test_all=1
test_invalid=0
test_invalid_abort=1
test_ipv4_address=1
test_ipv4_bits=1
test_ipv4_bits_chart=1
test_ipv4_conflicts=1
test_ipv4_conversions=0
test_last=1

if [ $test_last -eq 0 ]; then
    test_invalid_abort=1 # don't abort
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_address -eq 0 ]; then
    ipv4_inputs=()
    ipv4_inputs+=(0.0.0.0)
    ipv4_inputs+=(0.0.0.0/0)
    ipv4_inputs+=(0.0.0.0/4)
    ipv4_inputs+=(1.1.1.1/8)
    ipv4_inputs+=(1.1.1.1/16)
    ipv4_inputs+=(1.2.3.4/24)
    ipv4_inputs+=(255.255.255.255/32)
    ipv4_inputs+=(255.255.255.255)
    ipv4_inputs+=(055.255.255.255)
    ipv4_inputs+=(055.255.255.255.225)
    ipv4_inputs+=(0377.0377.0376.0000)
    ipv4_inputs+=(ffffffff)
    ipv4_inputs+=(0xffffff00)

    if [ $test_invalid -eq 0 ]; then
        ipv4_inputs+=(ffffffzz)
    fi

    iterations=100
    iterations_counter=0
    for ((i=1; i<=$iterations; i++)); do
        if [ $iterations -gt 1 ]; then clear; fi
        for ipv4_input in "${ipv4_inputs[@]}"; do
            invalid_abort=1
            ((iterations_counter++))

            if ! ipv4_output=$(ipv4Address $ipv4_input); then
                ipv4_output="INVALID"
            fi
            printf "[%s] %-40s = ipv4_output = %s\n" "$iterations_counter" "$ipv4_input" "$ipv4_output"
            unset -v ipv4_output

            if [ $test_invalid_abort -eq 0 ] && [ $invalid_abort -eq 0 ]; then
                abort
            fi

        done
        printf "\n"
    done

    echo
    times
    echo
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_bits_chart -eq 0 ]; then
    ipv4Bits chart
    ipv4Bits chart 14
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_bits -eq 0 ]; then
    ipv4_inputs=()
    ipv4_inputs+=(255.255.255.255/255.255.248.0)
    ipv4_inputs+=(14)
    ipv4_inputs+=("32 hex")
    ipv4_inputs+=(255.255.255.255/32)
    ipv4_inputs+=(255.255.255.255)
    ipv4_inputs+=(10000000.00000000.00000000.00000000)
    ipv4_inputs+=(1000000000000000.00000000.00000000)
    ipv4_inputs+=(11111111111111111111111111100000)
    ipv4_inputs+=(fff80000)
    ipv4_inputs+=(0xffff0000)
    ipv4_inputs+=(4294934528)
    ipv4_inputs+=(0377.0377.0376.0000)
    ipv4_inputs+=(0377037700000000)
    ipv4_inputs+=(0)
    ipv4_inputs+=(0.0.0.0/0)
    ipv4_inputs+=("13 bit")
    ipv4_inputs+=("13 binary")
    ipv4_inputs+=("13 decimal")
    ipv4_inputs+=("16 decimal")
    ipv4_inputs+=("24 hexidecimal")
    ipv4_inputs+=("25 uint")
    ipv4_inputs+=("32 octal")

    if [ $test_invalid -eq 0 ]; then
        ipv4_inputs+=(00000001.00000010.00000011.00000100) # invalid
        ipv4_inputs+=(192.168.0.1) # invalid
    fi

    iterations=1
    iterations_counter=0
    for ((i=1; i<=$iterations; i++)); do
        if [ $iterations -gt 1 ]; then clear; fi
        for ipv4_input in "${ipv4_inputs[@]}"; do
            invalid_abort=1
            ((iterations_counter++))

            if ! ipv4_output=$(ipv4Bits $ipv4_input); then
                invalid_abort=0
                ipv4_output="INVALID"
            fi
            printf "[%s] %-70s = ipv4_output = %s\n" "$iterations_counter" "$ipv4_input" "$ipv4_output"
            unset -v ipv4_output

            if [ $test_invalid_abort -eq 0 ] && [ $invalid_abort -eq 0 ]; then
                abort
            fi

        done
        printf "\n"
    done
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_conversions -eq 0 ]; then
    ipv4_inputs=()
    ipv4_inputs+=(255.255.255.255) # valid
    ipv4_inputs+=(000.000.000.000) # valid
    ipv4_inputs+=(127.000.000.001) # valid
    ipv4_inputs+=(127.0.0.0/0) # valid
    ipv4_inputs+=(127.0.0.0/1) # valid
    ipv4_inputs+=(127.0.0.0/2) # valid
    ipv4_inputs+=(127.0.0.0/8) # valid
    ipv4_inputs+=(127.0.0.0/18) # valid
    ipv4_inputs+=(127.0.0.0/25) # valid
    ipv4_inputs+=(127.0.0.0/31) # valid
    ipv4_inputs+=(127.0.0.0/32) # valid
    ipv4_inputs+=(0x506416AC) # valid, albeit reversed
    ipv4_inputs+=(0xac166450) # valid
    ipv4_inputs+=(fefefefe/24) # valid
    ipv4_inputs+=(fefefefe/fff80000) # valid
    ipv4_inputs+=(0xfefefefe/0xfff80000) # valid
    ipv4_inputs+=(00000001.00000010.00000011.00000100)
    ipv4_inputs+=(00000001.00000010.00000011.00000100/24)
    ipv4_inputs+=(00000011000100100010001100100100)
    ipv4_inputs+=(00000011000100100010001100100100/11111111111111111111111111111111)
    ipv4_inputs+=(00000011000100100010001100100100/11111111.11111111.11111111.11111111)
    ipv4_inputs+=(00000011000100100010001100100100/28)
    ipv4_inputs+=($IPV4_MAX_LONG)
    ipv4_inputs+=(0/$IPV4_MAX_LONG)
    ipv4_inputs+=(0377.0377.0001.0001/0377.0377.0377.0377)
    ipv4_inputs+=(0377037700010001/0377037703770377)
    ipv4_inputs+=(10.0.0.0/8) # valid

    if [ $test_invalid -eq 0 ]; then
        ipv4_inputs+=(355.255.255.255) # invalid
        ipv4_inputs+=(0377.0377.0001.0001/0000.0000.0377.0377) # invalid bits
        ipv4_inputs+=(0377037700020002/0003000303770377) # invalid bits
        ipv4_inputs+=(255.255.255.255.255) # invalid
        ipv4_inputs+=(ffff) # invalid
    fi

    iterations=1
    iterations_counter=0
    for ((i=1; i<=$iterations; i++)); do
        if [ $iterations -gt 1 ]; then clear; fi
        for ipv4_input in ${ipv4_inputs[@]}; do
            invalid_abort=1
            ((iterations_counter++))

            if ! ipv4_output=$(ipv4ToDecMask $ipv4_input); then
                invalid_abort=0
                ipv4_output="INVALID"
            fi
            printf "[%s] %-70s = ipv4_output = %s\n" "$iterations_counter" "$ipv4_input" "$ipv4_output"
            unset -v ipv4_output

            if [ $test_invalid_abort -eq 0 ] && [ $invalid_abort -eq 0 ]; then
                abort
            fi

        done
        printf "\n"
    done
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_conflicts -eq 0 ]; then
    ipv4_inputs=()
    ipv4_inputs+=(10.0.0.0)
    ipv4_inputs+=(10.0.0.0/4)
    ipv4_inputs+=(10.0.0.0/8)
    ipv4_inputs+=(172.16.0.0/12)
    ipv4_inputs+=(10.0.0.0/16)
    #ipv4_inputs+=(10.0.0.0/24)
    #ipv4_inputs+=(10.1.0.0)
    #ipv4_inputs+=(10.1.2.0)
    #ipv4_inputs+=(10.1.2.1)
    ipv4_inputs+=(10.1.2.2)
    #ipv4_inputs+=(10.1.2.3)
    #ipv4_inputs+=(10.1.2.0/1)
    #ipv4_inputs+=(10.1.2.0/2)
    ipv4_inputs+=(10.1.2.0/24)
    #ipv4_inputs+=(10.1.2.0/27)
    #ipv4_inputs+=(10.1.2.224/27)
    #ipv4_inputs+=(10.1.2.225)
    #ipv4_inputs+=(10.1.2.254)
    #ipv4_inputs+=(10.1.2.253)
    ipv4_inputs+=(10.1.2.255)
    #ipv4_inputs+=(10.1.2.32/31)
    #ipv4_inputs+=(10.1.2.32/31)
    ipv4_inputs+=(0a0a0a0a/24)
    ipv4_inputs+=(0xac166450)

    if [ $test_invalid -eq 0 ]; then
        ipv4_inputs+=(10/8) # invalid
    fi

    for ipv4_input1 in "${ipv4_inputs[@]}"; do
        for ipv4_input2 in "${ipv4_inputs[@]}"; do
            if [ "$ipv4_input1" == "$ipv4_input2" ]; then
                continue
            fi

            #(>&2 printf "%-30s = %s\n" "ipv4_input1" "${ipv4_input1}")
            #(>&2 printf "%-30s = %s\n" "ipv4_input2" "${ipv4_input2}")

            if ipv4Conflict $ipv4_input1 $ipv4_input2; then
                (>&2 printf "$ipv4_input1 conflicts with $ipv4_input2\n")
            else
                (>&2 printf "$ipv4_input1 does NOT conflict with $ipv4_input2\n")
            fi

            unset -v ipv4_input2
        done

        (>&2 printf "\n")

        unset -v ipv4_input1
    done
fi

if [ $test_all -eq 0 ] || [ $test_last -eq 0 ]; then
    printf "d=%d\n" "0xC0"
fi

abort
