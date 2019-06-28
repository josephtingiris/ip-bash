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
IP_Bash_Dirs+=($(dirname $(readlink -e ${BASH_SOURCE})))
for IP_Bash_Dir in ${IP_Bash_Dirs[@]}; do
    while [ "${IP_Bash_Dir}" != "" ] && [ "${IP_Bash_Dir}" != "/" ]; do # search backwards
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
        if [ "${IP_Bash_Source}" != "" ]; then break; fi
        IP_Bash_Dir=$(dirname "${IP_Bash_Dir}") # search backwards
    done
done
if [ "${IP_Bash_Source}" == "" ]; then echo "${IP_Bash} file not found"; abort 1; fi
unset IP_Bash_Dir IP_Bash

# end IP.bash.include

function abort() {
    if [ "$1" != "" ]; then
        echo
        echo $1
        echo
    fi
    printf "%s\n\n" "abort"
    times
    echo
    exit 1
}

#
# IP tests
#

# 0=true, 1=false
test_all=1
test_global=1
test_invalid=0
test_invalid_abort=1
test_ipv4_address=1
test_ipv4_prefix=1
test_ipv4_prefix_chart=1
test_ipv4_conflicts=1
test_ipv4_conversions=0
test_last=1

if [ ${test_last} -eq 0 ]; then
    test_invalid_abort=1 # don't abort
fi

if [ ${test_all} -eq 0 ] || [ ${test_global} -eq 0 ]; then
    ipv4_inputs=()
    ipv4_inputs+=(0.0.0.0)
    ipv4_inputs+=(0.0.0.0/4)
    ipv4_inputs+=(9.19.29.39)
    ipv4_inputs+=(199.199.199.199)
    ipv4_inputs+=(3.3.3.3)
    ipv4_inputs+=(33.33.33.33)
    ipv4_inputs+=(0377.0377.0376.0000)
    ipv4_inputs+=(ffffffff)
    ipv4_inputs+=(0xffffff00)
    ipv4_inputs+=(000.000.000.000)

    iterations=100
    iterations_max=1000
    iterations_counter=0
    for ((i=1; i<=${iterations}; i++)); do
        if [ ${iterations} -gt 1 ]; then clear; fi
        for ipv4_input in "${ipv4_inputs[@]}"; do
            invalid_abort=1
            ((iterations_counter++))

            # ~1.1 seconds on my machine (using subshell) (1000 iterations)
            #if ! ipv4_output=$(ipv4Address ${ipv4_input}); then
            #ipv4_output="INVALID"
            #fi

            # ~0.17 seconds on my machine (using global) (1000 iterations)
            if ipGlobal ${ipv4_input} global; then
                ipv4_output=${ipGlobal_output}
            else
                invalid_abort=0
                ipv4_output="INVALID"
            fi

            printf "[%s] %-40s = ipv4_output = %s\n" "${iterations_counter}" "${ipv4_input}" "${ipv4_output}"

            unset -v ipv4_output

            if [ ${test_invalid_abort} -eq 0 ] && [ ${invalid_abort} -eq 0 ]; then
                abort
            fi
        done
        printf "\n"

        if [ $iterations_counter -ge $iterations_max ]; then
            abort
        fi
    done
fi

if [ ${test_all} -eq 0 ] || [ ${test_ipv4_address} -eq 0 ]; then
    ipv4_inputs=()
    ipv4_inputs+=(0.0.0.0)
    ipv4_inputs+=(00.00.00.00)
    ipv4_inputs+=(000.000.000.000)
    ipv4_inputs+=(1.1.1.1)
    ipv4_inputs+=(11.11.11.11)
    ipv4_inputs+=(111.111.111.111)
    ipv4_inputs+=(9.9.9.9)
    ipv4_inputs+=(9.19.29.39)
    ipv4_inputs+=(199.199.199.199)
    ipv4_inputs+=(3.3.3.3)
    ipv4_inputs+=(33.33.33.33)
    ipv4_inputs+=(0.0.0.0/0)
    ipv4_inputs+=(0.0.0.0/4)
    ipv4_inputs+=(1.1.1.1/8)
    ipv4_inputs+=(1.1.1.1/16)
    ipv4_inputs+=(1.2.3.4/24)
    ipv4_inputs+=(255.255.255.255)
    ipv4_inputs+=(055.255.255.255)
    ipv4_inputs+=(055.05.255.225)
    ipv4_inputs+=(ffffffff)
    ipv4_inputs+=(0xffffff00)
    ipv4_inputs+=(0xffffff00/24)
    ipv4_inputs+=(0377.0377.0376.0000)
    ipv4_inputs+=(0377037703760000)
    ipv4_inputs+=(00000001.00000010.00000011.00000100)
    ipv4_inputs+=(00000001000000100000001100000100)

    if [ ${test_invalid} -eq 0 ]; then
        ipv4_inputs+=(0.0.0.0.0)
        ipv4_inputs+=(0379.0377.0376.0000)
        ipv4_inputs+=(ffffffzz)
        ipv4_inputs+=(256.256.256.256)
        ipv4_inputs+=(3.333.333.333)
        ipv4_inputs+=(3.33.333.333)
        ipv4_inputs+=(3.33.3.333)
        ipv4_inputs+=(333.333.333.333)
        ipv4_inputs+=(::1)
    fi

    iterations=100
    iterations_max=1000
    iterations_counter=0
    for ((i=1; i<=${iterations}; i++)); do
        if [ ${iterations} -gt 1 ]; then clear; fi
        for ipv4_input in "${ipv4_inputs[@]}"; do
            invalid_abort=1
            ((iterations_counter++))

            if ipv4Address ${ipv4_input} global; then
                ipv4_output=${ipv4Address_output}
            else
                invalid_abort=0
                ipv4_output="INVALID"
            fi
            printf "[%s] %-40s = ipv4_output = %s\n" "${iterations_counter}" "${ipv4_input}" "${ipv4_output}"
            unset -v ipv4_output

            if [ ${test_invalid_abort} -eq 0 ] && [ ${invalid_abort} -eq 0 ]; then
                abort
            fi

        done
        printf "\n"

        if [ $iterations_counter -ge $iterations_max ]; then
            abort
        fi
    done

    echo
    times
    echo
fi

if [ ${test_all} -eq 0 ] || [ ${test_ipv4_prefix_chart} -eq 0 ]; then
    ipv4Prefix chart
    ipv4Prefix chart 14
fi

if [ ${test_all} -eq 0 ] || [ ${test_ipv4_prefix} -eq 0 ]; then
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
    ipv4_inputs+=("13 prefix")
    ipv4_inputs+=("13 binary")
    ipv4_inputs+=("13 decimal")
    ipv4_inputs+=("16 decimal")
    ipv4_inputs+=("24 hexidecimal")
    ipv4_inputs+=("25 uint")
    ipv4_inputs+=("32 octal")

    if [ ${test_invalid} -eq 0 ]; then
        ipv4_inputs+=(00000001.00000010.00000011.00000100) # invalid
        ipv4_inputs+=(192.168.0.1) # invalid
    fi

    iterations=100
    iterations_max=1000
    iterations_counter=0
    for ((i=1; i<=${iterations}; i++)); do
        if [ ${iterations} -gt 1 ]; then clear; fi
        for ipv4_input in "${ipv4_inputs[@]}"; do
            invalid_abort=1
            ((iterations_counter++))

            if ipv4Prefix ${ipv4_input} global; then
                ipv4_output=${ipv4Prefix_output}
            else
                invalid_abort=0
                ipv4_output="INVALID"
            fi
            printf "[%s] %-70s = ipv4_output = %s\n" "${iterations_counter}" "${ipv4_input}" "${ipv4_output}"
            unset -v ipv4_output

            if [ ${test_invalid_abort} -eq 0 ] && [ ${invalid_abort} -eq 0 ]; then
                abort
            fi

        done
        printf "\n"

        if [ $iterations_counter -ge $iterations_max ]; then
            abort
        fi
    done
fi

if [ ${test_all} -eq 0 ] || [ ${test_ipv4_conversions} -eq 0 ]; then
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
    ipv4_inputs+=(${IPV4_MAX_LONG})
    ipv4_inputs+=(0/${IPV4_MAX_LONG})
    ipv4_inputs+=(0377.0377.0001.0001/0377.0377.0377.0377)
    ipv4_inputs+=(0377037700010001/0377037703770377)
    ipv4_inputs+=(10.0.0.0/8) # valid

    if [ ${test_invalid} -eq 0 ]; then
        ipv4_inputs+=(355.255.255.255) # invalid
        ipv4_inputs+=(0377.0377.0001.0001/0000.0000.0377.0377) # invalid prefix
        ipv4_inputs+=(0377037700020002/0003000303770377) # invalid prefix
        ipv4_inputs+=(255.255.255.255.255) # invalid
        ipv4_inputs+=(ffff) # invalid
        ipv4_inputs+=(::1)
        ipv4_inputs+=(0)
    fi

    iterations=1
    iterations_counter=0
    for ((i=1; i<=${iterations}; i++)); do
        if [ ${iterations} -gt 1 ]; then clear; fi
        for ipv4_input in ${ipv4_inputs[@]}; do
            invalid_abort=1
            ((iterations_counter++))

            if ipv4ToHex ${ipv4_input} global; then
                ipv4_output=${ipv4ToHex_output}
            else
                invalid_abort=0
                ipv4_output="INVALID"
            fi
            printf "[%s] %-70s = ipv4_output = %s\n" "${iterations_counter}" "${ipv4_input}" "${ipv4_output}"
            unset -v ipv4_output

            if [ ${test_invalid_abort} -eq 0 ] && [ ${invalid_abort} -eq 0 ]; then
                abort
            fi

        done
        printf "\n"
    done
fi

if [ ${test_all} -eq 0 ] || [ ${test_ipv4_conflicts} -eq 0 ]; then
    ipv4_inputs=()
    ipv4_inputs+=(10.0.0.0)
    #ipv4_inputs+=(10.0.0.0/4)
    #ipv4_inputs+=(10.0.0.0/8)
    #ipv4_inputs+=(172.16.0.0/12)
    #ipv4_inputs+=(10.0.0.0/16)
    #ipv4_inputs+=(10.0.0.0/24)
    #ipv4_inputs+=(10.1.0.0)
    #ipv4_inputs+=(10.1.2.0)
    #ipv4_inputs+=(10.1.2.1)
    ipv4_inputs+=(10.1.2.2)
    ipv4_inputs+=(10.1.2.3)
    #ipv4_inputs+=(10.1.2.0/1)
    #ipv4_inputs+=(10.1.2.0/2)
    ipv4_inputs+=(10.1.2.0/24)
    #ipv4_inputs+=(10.1.2.0/27)
    #ipv4_inputs+=(10.1.2.224/27)
    #ipv4_inputs+=(10.1.2.225)
    #ipv4_inputs+=(10.1.2.254)
    #ipv4_inputs+=(10.1.2.253)
    #ipv4_inputs+=(10.1.2.255)
    #ipv4_inputs+=(10.1.2.32/31)
    #ipv4_inputs+=(10.1.2.32/31)
    #ipv4_inputs+=(0a0a0a0a/24)
    #ipv4_inputs+=(0xac166450)

    if [ ${test_invalid} -eq 0 ]; then
        ipv4_inputs+=(10/8) # invalid
    fi

    ipv4_conflict_counter=0
    for ipv4_input1 in "${ipv4_inputs[@]}"; do
        for ipv4_input2 in "${ipv4_inputs[@]}"; do
            if [ "${ipv4_input1}" == "${ipv4_input2}" ]; then
                continue
            fi

            ((ipv4_conflict_counter++))
            if ipv4Conflict ${ipv4_input1} ${ipv4_input2}; then
                printf "[%s] ${ipv4_input1} conflicts with ${ipv4_input2}\n" ${ipv4_conflict_counter}
            else
                printf "[%s] ${ipv4_input1} does NOT conflict with ${ipv4_input2}\n" ${ipv4_conflict_counter}
            fi

            unset -v ipv4_input2
        done

        printf "\n"

        unset -v ipv4_input1
    done
fi

if [ ${test_all} -eq 0 ] || [ ${test_last} -eq 0 ]; then
    printf "d=%d\n" "0xC0"
fi

abort


