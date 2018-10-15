#!/bin/bash

# 20181012, joseph.tingiris@gmail.com

# check if two ipv4 addresses 'confict' with each other
function ipv4Conflict() {
    local first=$1
    local second=$2

    local -i bits_max=32 # 32 is the largest number of bits for ipv4

    # setup first
    if [[ "$first" == *"/"* ]]; then
        local address_first=${first%%/*} # everything before /
        local bits_first=${first##*/} # everything after /
    else
        local address_first=$first
        local bits_first=$bits_max
    fi

    # validate address_first
    local long_first=$(ipv42Long $address_first)
    if [[ ! $long_first =~ ^[0-9]+$ ]]; then
        return 1 # invalid positive integer
    fi

    # validate bits_first
    if [[ ! $bits_first =~ ^[0-9]+$ ]]; then
        return 1 # invalid positive integer
    fi

    local -i mask_first=$((-1<<($bits_max - $bits_first)))

    local -i long_first=$(($long_first & $mask_first)) # bitwise and; in case the address wasn't correctly aligned

    # setup second
    if [[ "$second" == *"/"* ]]; then
        local address_second=${second%%/*}
        local bits_second=${second##*/}
    else
        local address_second=$second
        local bits_second=$bits_max
    fi

    # validate bits_second
    if [[ ! $bits_second =~ ^[0-9]+$ ]]; then
        return 1 # invalid positive integer
    else
        if [ $bits_second -gt $bits_max ]; then
            return 1 # invalid positive integer
        fi
    fi

    # validate address_second
    local long_second=$(ipv42Long $address_second)
    if [[ ! $long_second =~ ^[0-9]+$ ]]; then
        return 1 # invalid ip address
    fi

    local -i mask_second=$((-1<<($bits_max - $bits_second)))

    local -i long_second=$(($long_second & $mask_second)) # bitwise and; in case the address wasn't correctly aligned

    local -i confict_first=$(($long_first & $mask_second))
    local -i confict_second=$(($long_second & $mask_first))

    # debug to stderr
    if [ "$Debug" == "function" ]; then
        local debug_postfix
        for debug_postfix in first second; do
            (>&2 printf "%-30s = %s\n" "${debug_postfix}" "${!debug_postfix}")
            local debug_prefix
            for debug_prefix in address bits long mask confict; do
                local debug_var=${debug_prefix}_${debug_postfix}
                (>&2 printf "%-30s = %s\n" "${debug_var}" "${!debug_var}")
                unset debug_var
            done
            unset debug_prefix
            (>&2 printf "\n")
        done
        unset debug_postfix
    fi

    if [ $confict_first -eq $confict_second ]; then
        return 0
    else
        return 1
    fi

}

# binary (bin)
function ipv4Bin() {
    local address=$1

    local return=""

    printf "return=$return\n"
    printf "address=$address\n"
}

# output ipv4 decimal (dec) notation and return true (0), or output nothing and return false (1)
function ipv4Dec() {
    local -l address=$1

    local max_bits=32

    #
    # validate input
    #

    if [ "$address" == "" ]; then
        return 1
    fi

    #
    # validate decimal format
    #

    local decimal=1 # false
    local decimal_address=""
    local decimal_bits=""

    local decimal_address=$address

    # validate ipv4 decimal address
    if [[ $decimal_address =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]){1}(/|$) ]]; then
        local decimal=0 # true
        local decimal_address=${decimal_address%%/*} # everything before /
        if [[ "$decimal_address" == *"/"* ]]; then
            local decimal_bits=${decimal_address##*/} # everything after /
        fi
        if [[ $decimal_bits =~ ^[0-9]+$ ]]; then
            if [ $decimal_bits -ge 0 ] && [ $decimal_bits -le $max_bits ]; then
                # append the bit mask back to the address
                local decimal_address+="/${decimal_bits}"
            else
                # what comes after / is a positive integer, but has more or less bits in the cidr than is valid; bad address
                return 1
            fi
        else
            if [ ${#decimal_bits} -gt 0 ]; then
                # what comes after / is not a positive integer; bad address
                return 1
            fi
        fi
    fi

    if [ $decimal -eq 0 ]; then
        printf "$decimal_address"
        return 0
    fi

    # $address not in a valid decimal format

    #
    # validate binary format
    #

    local binary=1 # false
    local binary_address=""
    local binary_bits=""

    if [[ $address =~ ^[0-1]+$ ]]; then
        printf "binary $address"
    fi

    # TODO; complete

    # $address not in a valid binary format

    #
    # validate hexidecimal format
    #

    local hexidecimal=1 # false
    local hexidecimal_address=""
    local hexidecimal_bits=""

    # if they exist then strip 0x (first 2 characters)
    if [[ ${address} =~ ^0[Xx] ]]; then
        local hexidecimal_address=${address:2:${#address}-2}
        local hexidecimal=1 # true
    else
        local hexidecimal_address=${address}
    fi


    if [[ ${hexidecimal_address:0:8} =~ ^(([0-9a-FA-F]{8})(/|$)) ]]; then
        local hexidecimal=0 # true
        local hexidecimal_address="0x${hexidecimal_address:0:2} 0x${hexidecimal_address:2:2} 0x${hexidecimal_address:4:2} 0x${hexidecimal_address:6:2}"
            echo "hexidecimal_address=$hexidecimal_address"
    fi

    if [ $hexidecimal -eq 0 ]; then
        if [ ${#hexidecimal_address} -eq 0 ]; then
            return 1 # invalid ipv4 hexidecimal address
        fi
    fi

    if [ $hexidecimal -eq 0 ]; then
        printf "%d.%d.%d.%d" $hexidecimal_address
        return 0
    fi

    printf "unknown $address"

    return 1 # invalid ipv4 address
}

# hexidecimal (hex)
function ipv4Hex() {
    local address=$1
    local return=""

    printf "return=$return\n"
    printf "address=$address\n"
}

# (long) integer (int)
function ipv4Int() {
    local address=$1
    local return=""

    printf "return=$return\n"
    printf "address=$address\n"
}


function ipv42Long() {
    local address=$1

    if ! ipv4Valid $address; then
        return 1 # invalid ip address
    fi

    local -i a b c d

    read a b c d <<< "${address//\./ }"

    a=$((a<<24))
    b=$((b<<16))
    c=$((c<<8))
    d=$((d<<0))

    printf '%d' "$((a+b+c+d))"

    unset a b c d

    return 0
}

function ipv4Long2() {
    local address=$1

    local -i long_max=4294967295 # the largest long value for ipv4 address

    if [[ ! $address =~ ^[0-9]+$ ]]; then
        return 1 # invalid positive integer
    else
        if [ $address -gt $long_max ]; then
            return 1 # invalid long address
        fi
    fi

    local -i a=$((address>>24&255))
    local -i b=$((address>>16&255))
    local -i c=$((address>>8&255))
    local -i d=$((address&255))

    printf '%d.%d.%d.%d' $a $b $c $d

    return 0
}

# validate an ipv4 (decimal) address with or without cidr notation
function ipv4Valid() {
    local address=$1

    if [[ "$address" == *"/"* ]]; then

        if [[ $address =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$ ]]; then
            return 0 # valid ipv4 address and cidr notation
        fi

    else

        if [[ $address =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]]; then
            return 0 # valid ipv4 address
        fi

    fi

    return 1 # invalid ipv4 address
}

if [ "$0" == "$BASH_SOURCE" ]; then
    exit
else
    return
fi

# 
# tests; TODO remove
#

ipv4_dec=$(ipv4Dec 255.255.255.255.255)
echo "(dec) ipv4_dec=$ipv4_dec"

ipv4_dec=$(ipv4Dec 255.255.255.255)
echo "(dec) ipv4_dec=$ipv4_dec"

ipv4_dec=$(ipv4Dec 127.0.0.1/8)
echo "(dec) ipv4_dec=$ipv4_dec"

ipv4_dec=$(ipv4Dec 0xffff)
echo "(hex) ipv4_dec=$ipv4_dec"

ipv4_dec=$(ipv4Dec 0x006416AC)
echo "(hex) ipv4_dec=$ipv4_dec"

ipv4_dec=$(ipv4Dec ffffffff/24)
echo "(hex) ipv4_dec=$ipv4_dec"

printf "%d" "0xC0"

# global; tests to stderr
if [ "$Debug" != "" ]; then
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

            unset confict_second
        done

        (>&2 printf "\n")

        unset confict_first
    done
fi

