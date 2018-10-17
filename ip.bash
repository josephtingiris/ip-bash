#!/bin/bash

# 20181012, joseph.tingiris@gmail.com

# output the binary string representation of a valid integer and return true (0), or return nothing and false (0)
function intToBin(){
    local integer="$1"

    if [[ $integer =~ ^[0-9]+$ ]]; then
        local binary i

        if [ $integer -eq 0 ]; then
            local binary=0
        else
            for ((i=$integer; i>0; i>>=1)); do
                local binary="$((i&1))$binary"
            done
        fi

        if [ ${#binary} -gt 0 ]; then
            printf "%s" "$binary"
            return 0
        fi
    fi

    return 1
}

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
                unset -v debug_var
            done
            unset -v debug_prefix
            (>&2 printf "\n")
        done
        unset -v debug_postfix
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
# inputs binary, decimal, hexidecimal, or an integer
function ipv4Dec() {
    local -l address=$1

    local max_bits=32

    #
    # validate input exists
    #

    if [ ${#address} -eq 0 ]; then
        return 1
    fi

    #
    # validate decimal format
    #

    local decimal=1 # false
    local decimal_address=$address

    # validate ipv4 decimal address
    if [[ $decimal_address =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]){1}(/|$) ]]; then
        local decimal=0 # true
        local decimal_bits="" # empty

        if [[ "$decimal_address" == *"/"* ]]; then
            # order is important; cut bits before address
            local decimal_bits=${decimal_address##*/} # everything after /
            local decimal_address=${decimal_address%%/*} # everything before /
        fi

        if [[ $decimal_bits =~ ^[0-9]+$ ]]; then
            if [ $decimal_bits -ge 0 ] && [ $decimal_bits -le $max_bits ]; then
                # append the bit mask back to the address
                local decimal_address+="/${decimal_bits}"
            else
                # what comes after / is a positive integer, but has more or less bits in the cidr than is valid; bad address
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
    local binary_address=$address

    if [[ $address =~ ^[0-1]{32}$ ]]; then
        local binary_bits="" # empty

        printf "binary $address"

        if [ $decimal -eq 0 ]; then
            printf "$decimal_address"
            return 0
        fi

        # TODO; complete
        # 00000000000000000000000000000000
    fi

    # $address not in a valid binary format

    #
    # validate hexidecimal format
    #

    local hexidecimal=1 # false
    local hexidecimal_address=$address

    if [[ ${hexidecimal_address} =~ ^((^0[Xx]{1}[0-9a-fA-F]{8}|[0-9a-fA-F]{8})(/|$)) ]]; then
        local hexidecimal=0 # true
        local hexidecimal_bits="" # empty

        if [[ "$hexidecimal_address" == *"/"* ]]; then
            # order is important; cut bits before address
            local hexidecimal_bits=${hexidecimal_address##*/} # everything after /
            local hexidecimal_address=${hexidecimal_address%%/*} # everything before /
        fi

        # these are unique to hexidecimal; support if the input is prefixed with 0x (strip first 2 characters)

        if [[ ${hexidecimal_address} =~ ^0[Xx] ]]; then
            local hexidecimal_address=${hexidecimal_address:2:${#hexidecimal_address}-2}
        fi

        local hexidecimal_address="0x${hexidecimal_address:0:2} 0x${hexidecimal_address:2:2} 0x${hexidecimal_address:4:2} 0x${hexidecimal_address:6:2}"
        printf -v hexidecimal_address "%d.%d.%d.%d" $hexidecimal_address # convert address from hexidecimal to decimal

        # re-validate decimal address?? shouldn't be necessary ...

        if [[ ${hexidecimal_bits} =~ ^((^0[Xx]{1}[0-9a-fA-F]{8}|[0-9a-fA-F]{8})($)) ]]; then
            # bits as hex

            if [[ ${hexidecimal_bits} =~ ^0[Xx] ]]; then
                local hexidecimal_bits=${hexidecimal_bits:2:${#hexidecimal_bits}-2}
            fi

            if hexidecimal_bits=$(ipv4Mask $hexidecimal_bits); then
                local hexidecimal_address+="/${hexidecimal_bits}"
            else
                return 1 # invalid mask
            fi

        else
            # bits as an integer?
            if [[ $hexidecimal_bits =~ ^[0-9]+$ ]]; then
                if [ $hexidecimal_bits -ge 0 ] && [ $hexidecimal_bits -le $max_bits ]; then
                    # append the bit mask back to the address
                    local hexidecimal_address+="/${hexidecimal_bits}"
                else
                    # what comes after / is a positive integer, but has more or less bits in the cidr than is valid; bad address
                    return 1
                fi
            fi
        fi

    fi

    if [ $hexidecimal -eq 0 ]; then
        if [ ${#hexidecimal_address} -eq 0 ]; then
            return 1 # invalid ipv4 hexidecimal address
        fi
    fi

    if [ $hexidecimal -eq 0 ]; then
        printf $hexidecimal_address
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

# convert decimal mask to bits and vice versa
function ipv4Mask() {
    local bits mask max_bits=32

    if mask=$(ipv4Dec $1); then # this will validate dec & convert bin/hex/int as needed
        # convert from decimal mask to cidr bits

        local bits=0

        # avoid subshell
        local octal_mask
        printf -v octal_mask '%o' ${mask//\./\ }
        local octal_mask=0${octal_mask} # must have leading zero

        while [ $octal_mask -gt 0 ]; do
            # calculate octal_mask modulo 2 & right shift 1 position; add the result to decimal bits
            let local bits+=$((octal_mask%2)) 'octal_mask>>=1'
        done

        if [ $bits -ge 0 ] && [ $bits -le $max_bits ]; then
            printf "%d" $bits
            return 0
        else
            return 1 # invalid number of bits
        fi

    else
        # convert from cidr bits to decimal subnet mask

        local mask=""

        local bits=$1

        if [[ $bits =~ ^[0-9]+$ ]]; then
            if [ $bits -ge 0 ] && [ $bits -le $max_bits ]; then
                local octet=0
                local octet_div=$(($bits/8)) # divide how many bits are full bytes, 0xFF, 255, etc.
                local octet_mod=$(($bits%8)) # modulo 8 how many bits are *not* full bytes, 0xFF, 255, etc.

                for ((octet=0;octet<4;octet+=1)); do
                    if [ $octet -lt $octet_div ]; then
                        mask+=255 # full byte octet
                    elif [ $octet -eq $octet_div ]; then
                        mask+=$((256-2**(8-$octet_mod))) # calculate the decimal version of the octet
                    else
                        mask+=0
                    fi

                    if [ $octet -lt 3 ]; then
                        mask+=. # append a period
                    fi
                done

                printf "%s" $mask
                return 0

            else
                return 1 # invalid number of bits
            fi
        else
            return 1 # invalid, bits is not a positive integer
        fi

    fi
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

    unset -v a b c d

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

ipv4_dec=$(ipv4Dec 0x506416AC)
echo "(hex) ipv4_dec=$ipv4_dec"

ipv4_dec=$(ipv4Dec ffffffff/24)
echo "(hex) ipv4_dec=$ipv4_dec"

ipv4_dec=$(ipv4Dec ffffffff/0xFFF80000)
echo "(hex) ipv4_dec=$ipv4_dec"

echo "hexidecimal_bits=$hexidecimal_bits"

echo $(ipv4Mask 25)
echo $(ipv4Mask 255.224.0.0)


if [ "$0" == "$BASH_SOURCE" ]; then
    exit
else
    return
fi

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

            unset -v confict_second
        done

        (>&2 printf "\n")

        unset -v confict_first
    done
fi

