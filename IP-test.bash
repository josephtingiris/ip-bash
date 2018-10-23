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
if [ "$IP_Bash_Source" == "" ]; then echo "$IP_Bash file not found"; exit 1; fi
unset IP_Bash_Dir IP_Bash

# end IP.bash.include

#
# IP tests
#

# 0=true, 1=false
test_all=1
test_invalid_exit=0
test_ipv4_bits=1
test_ipv4_bits_chart=1
test_ipv4_conflicts=1
test_ipv4_conversions=0
test_last=1

if [ $test_last -eq 0 ]; then
    test_invalid_exit=1 # don't exit
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_bits_chart -eq 0 ]; then
    ipv4Bits chart
    ipv4Bits chart 14
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_bits -eq 0 ]; then
    ipv4_bits=()
    ipv4_bits+=(255.255.255.255/255.255.248.0)
    ipv4_bits+=(14)
    ipv4_bits+=("32 hex")
    ipv4_bits+=(255.255.255.255/32)
    ipv4_bits+=(255.255.255.255)
    ipv4_bits+=(10000000.00000000.00000000.00000000)
    ipv4_bits+=(1000000000000000.00000000.00000000)
    ipv4_bits+=(11111111111111111111111111100000)
    ipv4_bits+=(fff80000)
    ipv4_bits+=(0xffff0000)
    ipv4_bits+=(4294934528)
    ipv4_bits+=(0377.0377.0376.0000)
    ipv4_bits+=(0377037700000000)
    ipv4_bits+=(0)
    ipv4_bits+=("13 bit")
    ipv4_bits+=("13 binary")
    ipv4_bits+=("13 decimal")
    ipv4_bits+=("16 decimal")
    ipv4_bits+=("24 hexidecimal")
    ipv4_bits+=("25 uint")
    ipv4_bits+=("32 octal")
    ipv4_bits+=(192.168.0.1) # invalid
    ipv4_bits+=(00000001.00000010.00000011.00000100) # invalid
    for ipv4_bit in "${ipv4_bits[@]}"; do
        invalid_exit=1
        if ! this_ipv4_bits=$(ipv4Bits $ipv4_bit); then
            invalid_exit=0
            this_ipv4_bits="INVALID"
        fi
        printf "%-70s = %s\n" "$ipv4_bit" "$this_ipv4_bits"
        if [ $test_invalid_exit -eq 0 ] && [ $invalid_exit -eq 0 ]; then
            exit
        fi
        unset -v this_ipv4_bits
    done
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_conversions -eq 0 ]; then
    ipv4_conversions=()
    ipv4_conversions+=(255.255.255.255) # valid
    ipv4_conversions+=(000.000.000.000) # valid
    ipv4_conversions+=(127.000.000.001) # valid
    ipv4_conversions+=(127.0.0.0/0) # valid
    ipv4_conversions+=(127.0.0.0/1) # valid
    ipv4_conversions+=(127.0.0.0/2) # valid
    ipv4_conversions+=(127.0.0.0/8) # valid
    ipv4_conversions+=(127.0.0.0/18) # valid
    ipv4_conversions+=(127.0.0.0/25) # valid
    ipv4_conversions+=(127.0.0.0/31) # valid
    ipv4_conversions+=(127.0.0.0/32) # valid
    ipv4_conversions+=(ffff) # invalid
    ipv4_conversions+=(0x506416AC) # valid, albeit reversed
    ipv4_conversions+=(0xac166450) # valid
    ipv4_conversions+=(fefefefe/24) # valid
    ipv4_conversions+=(fefefefe/fff80000) # valid
    ipv4_conversions+=(0xfefefefe/0xfff80000) # valid
    ipv4_conversions+=(00000001.00000010.00000011.00000100)
    ipv4_conversions+=(00000001.00000010.00000011.00000100/24)
    ipv4_conversions+=(00000011000100100010001100100100)
    ipv4_conversions+=(00000011000100100010001100100100/11111111111111111111111111111111)
    ipv4_conversions+=(00000011000100100010001100100100/11111111.11111111.11111111.11111111)
    ipv4_conversions+=(00000011000100100010001100100100/28)
    ipv4_conversions+=($IPV4_MAX_LONG)
    ipv4_conversions+=(0/$IPV4_MAX_LONG)
    ipv4_conversions+=(0377.0377.0001.0001/0000.0000.0377.0377)
    ipv4_conversions+=(0377037700020002/0003000303770377)
    ipv4_conversions+=(255.255.255.255.255) # invalid

    for ipv4_conversion in ${ipv4_conversions[@]}; do
        invalid_exit=1
        if ! this_ipv4_hex=$(ipv4ToHex $ipv4_conversion); then
            invalid_exit=0
            this_ipv4_hex="INVALID"
        fi
        printf "%-70s = this_ipv4_hex = %s\n" "$ipv4_conversion" "$this_ipv4_hex"
        if [ $test_invalid_exit -eq 0 ] && [ $invalid_exit -eq 0 ]; then
            exit
        fi
        unset -v this_ipv4_hex
    done
fi

if [ $test_all -eq 0 ] || [ $test_ipv4_conflicts -eq 0 ]; then
    conficts=()
    conficts+=(10/8) # invalid
    conficts+=(10.0.0.0)
    conficts+=(10.0.0.0/4)
    conficts+=(10.0.0.0/8)
    conficts+=(10.0.0.0/12)
    conficts+=(10.0.0.0/16)
    conficts+=(10.0.0.0/24)
    conficts+=(10.1.0.0)
    conficts+=(10.1.2.0)
    conficts+=(10.1.2.1)
    conficts+=(10.1.2.2)
    conficts+=(10.1.2.3)
    conficts+=(10.1.2.0/1)
    conficts+=(10.1.2.0/2)
    conficts+=(10.1.2.0/24)
    conficts+=(10.1.2.0/27)
    conficts+=(10.1.2.224/27)
    conficts+=(10.1.2.225)
    conficts+=(10.1.2.254)
    conficts+=(10.1.2.253)
    conficts+=(10.1.2.255)
    conficts+=(10.1.2.32/31)

    for confict_first in "${conficts[@]}"; do
        for confict_second in "${conficts[@]}"; do
            if [ "$confict_first" == "$confict_second" ]; then
                continue
            fi

            #(>&2 printf "%-30s = %s\n" "confict_first" "${confict_first}")
            #(>&2 printf "%-30s = %s\n" "confict_second" "${confict_second}")

            if ipv4Conflict $confict_first $confict_second; then
                (>&2 printf "$confict_first conficts with $confict_second\n")
            else
                (>&2 printf "$confict_first does NOT confict with $confict_second\n")
            fi

            unset -v confict_second
        done

        (>&2 printf "\n")

        unset -v confict_first
    done
fi

if [ $test_all -eq 0 ] || [ $test_last -eq 0 ]; then
    printf "d=%d\n" "0xC0"
fi

