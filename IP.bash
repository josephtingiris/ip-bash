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

# constants

readonly IPV4_MAX_BITS=32
readonly IPV4_MAX_LONG=$((2**$IPV4_MAX_BITS-1))
readonly IPV6_MAX_BITS=128
readonly IPV6_MAX_LONG=$((2**$IPV6_MAX_BITS-1)) # grr; bash max is sint64

#############
# functions #
#############

#
# output the binary string representation of a valid integer or hexidecimal value and return true, or return nothing and false
#
function binary(){
    local number="$1"

    # convert hex to int
    if [[ ${number} =~ ^((0[Xx]{1}[0-9a-fA-F]{0,32}|[0-9a-fA-F]{0,32})($)) ]]; then
        if [[ ${number} =~ ^0[Xx] ]]; then
            local number=$(($number))
        else
            local number=$((16#$number))
        fi
    fi

    if [[ ${number} =~ ^[0-9]+$ ]]; then
        local integer bit=""
        printf -v integer '%d' "$number"
        if [ $integer -eq 0 ]; then
            local bit=0
        else
            for ((; integer>0; integer>>=1)); do
                local bit="$((integer&1))$bit"
            done
        fi

        if [ ${#bit} -gt 0 ]; then
            printf '%s' "$bit"
            return 0
        fi
    fi

    return 1
}

#
# output ipv4 compressed address (remove leading zeros, etc.)
#
function ipv4AddressCompress() {
    local address=$1

    printf $address

    return 0
}

#
# output ipv4 expanded address (add dots, etc.)
#
function ipv4AddressExpand() {
    local address=$1

    printf $address

    return 0
}

#
# output ipv4 formatted address consistently (compress first, then expand)
#
function ipv4AddressFormat() {
    local -l input=$1
    local -l output

    output=${input//[[:space:]]/} # strip all spaces

    if [[ $output == *"."* ]]; then
        # dot seperated

        # convert all segments to base 10 (i.e. strip leading zeros)
        if [[ ${output//\./} =~ ^[0-9]+$ ]] && [ ${#output} -le 15 ]; then
            local octet octets
            for octet in ${output//\./\ }; do
                octets+=".$((10#$octet))"
            done
            output=${octets#.*} # remove leading .
            unset -v octet octets
        fi

    else
        # not dot seperated

        # octal 16 characters; add dots
        if [[ ${output} =~ ^[0-9]+$ ]] && [[ ${#output} -eq 16 ]]; then
            output="${output:0:4}.${output:4:4}.${output:8:4}.${output:12:4}"
        fi

        # binary 32 characters; add dots
        if [[ ${output} =~ ^[0-1]+$ ]] && [[ ${#output} -eq 32 ]]; then
            output="${output:0:8}.${output:8:8}.${output:16:8}.${output:24:8}"
        fi

        # hex less than 8 chars; prefix with zeros
        if [[ ${output} =~ ^([a-fA-F]+)$ ]] && [ $((${#output}%2)) -eq 0 ]; then
            while [ ${#output} -lt 8 ]; do
                output="0${output}"
            done
        fi

    fi

    printf "%s" $output
}

#
# output ipv4 (cidr) bits or conversion of bits and return true or return false (if bits don't align & convert)
# optionally, with $input=="chart", output (to stderr) a chart of all bit representations (that are valid & supported)
#
# i.e.
# ipv4Bits 192.168.0.1 # false
# ipv4Bits 255.255.248.0 # 21
# ipv4Bits 21 decimal # 255.255.248.0
# ipv4Bits chart # displays all values of all bits >= 0 or <= $IPV4_MAX_BITS
# ipv4Bits chart 14 # displays all values of 14 bits
#
function ipv4Bits() {
    local -l input=$1
    local -l output=${2:0:3}

    local address bits chart sep while_bits while_bits_match

    # seperate input into address & bits
    if [[ "$input" == *"/"* ]]; then
        address=${input%%/*} # everything before /
        bits=${input##*/} # everything after /
    else
        bits=$input
    fi

    address=$(ipv4AddressFormat $address)
    bits=$(ipv4AddressFormat $bits) # necessary?

    if [ "$bits" == "chart" ]; then
        chart=0 # true
        printf -v sep -- "-%.0s" {1..109}
        # only match bits given as $2
        if [[ $output =~ ^[0-9]+$ ]]; then
            if [ $output -ge 0 ] || [ $output -le $IPV4_MAX_BITS ]; then
                while_bits_match=$output
            fi
        fi
    else
        chart=1 # false
        # if bits are given as $1 and $2 starts with one of the supported format names then output that representation
        if [[ $bits =~ ^[0-9]+$ ]]; then
            if [ $bits -ge 0 ] || [ $bits -le $IPV4_MAX_BITS ]; then
                if [ ${#output} -gt 0 ] && [ "${output}" != "bit" ]; then
                    if [ "${output}" == "bin" ] || [ "${output}" == "dec" ] || [ "${output}" == "hex" ] || [ "${output}" == "uin" ] || [ "${output}" == "oct" ]; then
                        while_bits_match=$bits
                    else
                        return 1 # unsupported output
                    fi
                else
                    if [ "${output}" == "" ] || [ "${output}" == "bit" ]; then
                        printf "%d" $bits
                        return 0 # special case; valid simply return $bits (faster)
                    fi
                fi
            fi
        fi
    fi

    # if chart, then print header row
    if [ $chart -eq 0 ]; then
        (>&2 printf "+%s+\n" "$sep")
        (>&2 printf "%-7s" "| bits")
        (>&2 printf "%-36s" "| binary")
        (>&2 printf "%-18s" "| decimal")
        (>&2 printf "%-14s" "| hexidecimal")
        (>&2 printf "%-13s" "| uint")
        (>&2 printf "%-22s" "| octal")
        (>&2 printf "|\n")
        (>&2 printf "+%s+\n" "$sep")
    fi

    while_bits=$IPV4_MAX_BITS

    # go backwards, it's faster
    while [ $while_bits -ge 0 ]; do

        #(>&2 echo "while_bits=$while_bits bits=$bits")

        if [ ${#while_bits_match} -gt 0 ]; then
            if [ ${while_bits_match} -ne ${while_bits} ]; then
                ((while_bits--))
                continue
            fi
        fi

        if [ $chart -eq 0 ]; then
            (>&2 printf "%-7s" "| $while_bits")
        fi

        local binary
        printf -v binary "%.$(($while_bits))s%.$((${IPV4_MAX_BITS}-$while_bits))s" "11111111111111111111111111111111" "00000000000000000000000000000000"
        if [ $chart -eq 0 ]; then
            (>&2 printf "%-36s" "| $binary")
        else
            if [ "${bits}" == "${binary}" ] || [ "${bits//\./}" == "${binary}" ]; then
                printf "%d" $while_bits
                return 0
            else
                # all conversions depend on the binary representation of $bits
                if [ ${#binary} -ne 32 ]; then
                    return 1 # invalid binary conversion
                fi

                if [ "${output}" == "bin" ]; then
                    printf "%s" $binary
                    return 0
                fi
            fi
        fi

        local decimal
        printf -v decimal "%d.%d.%d.%d" $((2#${binary:0:8})) $((2#${binary:8:8})) $((2#${binary:16:8})) $((2#${binary:24:8}))
        if [ $chart -eq 0 ]; then
            (>&2 printf "%-18s" "| $decimal")
        else
            if [ "${bits}" == "${decimal}" ]; then
                printf "%d" $while_bits
                return 0
            else
                if [ "${output}" == "dec" ]; then
                    printf "%s" $decimal
                    return 0
                fi
            fi
        fi

        local hexidecimal
        printf -v hexidecimal "%02x%02x%02x%02x" $((2#${binary:0:8})) $((2#${binary:8:8})) $((2#${binary:16:8})) $((2#${binary:24:8}))
        if [ $chart -eq 0 ]; then
            (>&2 printf "%-14s" "| $hexidecimal")
        else
            if [ "${bits}" == "${hexidecimal}" ] || [ "${bits}" == "0x${hexidecimal}" ]; then
                printf "%d" $while_bits
                return 0
            else
                if [ "${output}" == "hex" ]; then
                    printf "%s" $hexidecimal
                    return 0
                fi
            fi
        fi

        local uint
        printf -v uint "%u" 0x${hexidecimal}
        if [ $chart -eq 0 ]; then
            (>&2 printf "%-13s" "| $uint")
        else
            if [ "${bits}" == "${uint}" ]; then
                printf "%d" $while_bits
                return 0
            else
                if [ "${output}" == "uin" ]; then
                    printf "%s" $uint
                    return 0
                fi
            fi
        fi

        local octal
        printf -v octal "%04o.%04o.%04o.%04o" $((2#${binary:0:8})) $((2#${binary:8:8})) $((2#${binary:16:8})) $((2#${binary:24:8}))
        if [ $chart -eq 0 ]; then
            (>&2 printf "%-22s" "| $octal")
        else
            if [ "${bits}" == "${octal}" ] || [ "${bits}" == "${octal//\./}" ]; then
                printf "%d" $while_bits
                return 0
            else
                if [ "${output}" == "oct" ]; then
                    printf "%s" $octal
                    return 0
                fi
            fi
        fi

        if [ $chart -eq 0 ]; then
            (>&2 printf "|\n")
        fi

        unset -v binary
        ((while_bits--))
    done

    if [ $chart -eq 0 ]; then
        (>&2 printf "+%s+\n" "$sep")
        return 0
    else
        return 1
    fi
}

# check if two ipv4 addresses 'confict' with each other
function ipv4Conflict() {
    local first=$1
    local second=$2

    # setup first
    if [[ "$first" == *"/"* ]]; then
        local address_first=${first%%/*} # everything before /
        local bits_first=${first##*/} # everything after /
    else
        local address_first=$first
        local bits_first=$IPV4_MAX_BITS
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

    local -i mask_first=$((-1<<($IPV4_MAX_BITS - $bits_first)))

    local -i long_first=$(($long_first & $mask_first)) # bitwise and; in case the address wasn't correctly aligned

    # setup second
    if [[ "$second" == *"/"* ]]; then
        local address_second=${second%%/*}
        local bits_second=${second##*/}
    else
        local address_second=$second
        local bits_second=$IPV4_MAX_BITS
    fi

    # validate bits_second
    if [[ ! $bits_second =~ ^[0-9]+$ ]]; then
        return 1 # invalid positive integer
    else
        if [ $bits_second -gt $IPV4_MAX_BITS ]; then
            return 1 # invalid positive integer
        fi
    fi

    # validate address_second
    local long_second=$(ipv42Long $address_second)
    if [[ ! $long_second =~ ^[0-9]+$ ]]; then
        return 1 # invalid ip address
    fi

    local -i mask_second=$((-1<<($IPV4_MAX_BITS - $bits_second)))

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

#
# output ipv4 mixed input to binary (bin) and return true, or output nothing and return false
#
function ipv4ToBin() {
    local -l address=$1

    local return=""

    # 00000001.00000010.00000011.00000100 # 1.2.3.0

    printf "return=$return\n"
    printf "address=$address\n"
}

#
# output ipv4 mixed input to decimal (dec) and return true, or output nothing and return false
#
function ipv4ToDec() {
    local -l address=$1

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

        if [ ${#decimal_bits} -gt 0 ]; then
            if [[ $decimal_bits =~ ^[0-9]+$ ]]; then
                if [ $decimal_bits -ge 0 ] && [ $decimal_bits -le $IPV4_MAX_BITS ]; then
                    # append the bits to the address
                    local decimal_address+="/${decimal_bits}"
                else
                    # what comes after / is a positive integer, but has more or less bits in the cidr than is valid; bad address
                    return 1
                fi
            else
                # what comes after / is not a positive integer; bad address (maybe support hex?)
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

    if [[ $address =~ ^[0-1]{$IPV4_MAX_BITS}$ ]]; then
        local binary_bits="" # empty

        printf "binary $binary_address"

        if [ $binary -eq 0 ]; then
            printf "$binary_address"
            return 0
        fi

        # TODO; complete
        # 00000000000000000000000000000000
    fi

    # $address not in a valid binary format

    #
    # validate & convert hexidecimal format
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
            local hexidecimal_address=$(($hexidecimal_address))
            #local hexidecimal_address=${hexidecimal_address:2:${#hexidecimal_address}-2}
        fi

        local hexidecimal_address="0x${hexidecimal_address:0:2} 0x${hexidecimal_address:2:2} 0x${hexidecimal_address:4:2} 0x${hexidecimal_address:6:2}"
        printf -v hexidecimal_address "%d.%d.%d.%d" $hexidecimal_address # convert address from hexidecimal to decimal

        # re-validate decimal address?? shouldn't be necessary ...

        if [[ ${hexidecimal_bits} =~ ^((^0[Xx]{1}[0-9a-fA-F]{8}|[0-9a-fA-F]{8})($)) ]]; then
            # bits as hex

            if [[ ${hexidecimal_bits} =~ ^0[Xx] ]]; then
                local hexidecimal_address=$(($hexidecimal_address))
                #local hexidecimal_bits=${hexidecimal_bits:2:${#hexidecimal_bits}-2}
            fi

            if hexidecimal_bits=$(ipv4Bits $hexidecimal_bits); then
                local hexidecimal_address+="/${hexidecimal_bits}"
            else
                return 1 # invalid mask
            fi

        else
            # bits as an integer?
            if [[ $hexidecimal_bits =~ ^[0-9]+$ ]]; then
                if [ $hexidecimal_bits -ge 0 ] && [ $hexidecimal_bits -le $IPV4_MAX_BITS ]; then
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

#
# output ipv4 mixed input to hexidecimal (hex) and return true, or output nothing and return false
#
function ipv4ToHex() {
    local -l input=$1
    local -l output

    local address address_output address_valid bits bits_output bits_valid

    # seperate input into address & bits
    address_valid=1 # false
    if [[ "$input" == *"/"* ]]; then
        address=${input%%/*} # everything before /
        bits=${input##*/} # everything after /
        bits_valid=1 # false
    else
        address=$input
        bits=""
        bits_valid=0 # true
    fi

    address=$(ipv4AddressFormat $address)
    bits=$(ipv4AddressFormat $bits) # necessary?

    #
    # address
    #

    if [ ${#address} -eq 0 ]; then
        return 1 # invalid; address length is 0
    else
        # convert ipv4 hex address
        if [ $address_valid -eq 1 ]; then
            if [[ ${address} =~ ^((^0[Xx]{1}[0-9a-fA-F]{8}|[0-9a-fA-F]{8})$) ]]; then
                if [[ ${address} =~ ^0[Xx] ]]; then
                    address_output=${address:2:${#address}-2}
                else
                    address_output=$address
                fi
                address_valid=0 # true
            fi
        fi

        # convert ipv4 decimal address
        if [ $address_valid -eq 1 ]; then
            if [[ $address =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]){1}$ ]]; then
                printf -v address_output '%02x' ${address//\./\ }

                address_valid=0 # true
            fi
        fi

        # convert ipv4 long address
        if [ $address_valid -eq 1 ]; then
            if [[ $address =~ ^[0-9]+$ ]]; then
                if [ $address -ge 0 ] && [ $address -le $IPV4_MAX_LONG ]; then
                    printf -v address_output '%08x' $((10#$address))
                    address_valid=0 # true
                fi
            fi
        fi

        # convert ipv4 binary address
        if [ $address_valid -eq 1 ]; then
            if [[ ${address//\./} =~ ^[0-1]+$ ]] && [[ ${#address} -eq 35 ]]; then
                local octet octets
                for octets in ${address//\./\ }; do
                    printf -v octet '%02x' $((2#${octets}))
                    address_output+=$octet
                done
                unset -v octet octets
                address_valid=0 # true
            fi
        fi

        # convert ipv4 octal address
        if [ $address_valid -eq 1 ]; then
            if [[ ${address//\./} =~ ^[0-9]+$ ]] && [[ ${#address} -eq 19 ]]; then
                local octet octets
                for octets in ${address//\./\ }; do
                    printf -v octet '%02x' $((8#${octets}))
                    address_output+=$octet
                done
                unset -v octet octets
                address_valid=0 # true
            fi
        fi

        # validate address_output
        if [ $address_valid -eq 0 ] && [ ${#address_output} -eq 8 ]; then
            output=$address_output
            address_valid=0 # true
        else
            return 1 # invalid address; all regex or output failed
        fi
    fi

    #
    # bits
    #

    if [ ${#bits} -gt 0 ]; then

        # convert ipv4 hexidecmal bits
        if [ $bits_valid -eq 1 ]; then
            if [[ ${bits} =~ ^((^0[Xx]{1}[0-9a-fA-F]{8}|[0-9a-fA-F]{8})$) ]]; then
                if [[ ${bits} =~ ^0[Xx] ]]; then
                    local bits_output=${bits:2:${#bits}-2}
                else
                    local bits_output=$bits
                fi
                bits_valid=0
            fi
        fi

        # convert ipv4 decimal bits
        if [ $bits_valid -eq 1 ]; then
            # convert ipv4 decimal mask to bits
            if [[ $bits =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]){1}$ ]]; then
                # convert subnet mask to decimal bits
                if ! bits=$(ipv4Bits $bits); then
                    return 1 # invalid bits
                fi
            fi

            if [[ $bits =~ ^[0-9]+$ ]]; then
                if [ $bits -ge 0 ] && [ $bits -le $IPV4_MAX_BITS ]; then
                    # convert decimal bits to binary
                    local bit
                    for ((bit=0; bit<$IPV4_MAX_BITS; bit+=1)); do
                        if [ $bit -lt $bits ]; then
                            bits_binary+="1"
                        else
                            bits_binary+="0"
                        fi
                    done
                    unset -v bit

                    # convert binary bits to hexidecimal
                    printf -v bits_output "%08x" $((2#$bits_binary))
                    bits_valid=0
                fi
            fi
        fi

        # convert ipv4 binary bits
        if [ $bits_valid -eq 1 ]; then
            if [[ ${bits//\./} =~ ^[0-1]+$ ]] && [[ ${#bits} -eq 35 ]]; then
                local octet octets
                for octets in ${bits//\./\ }; do
                    printf -v octet '%02x' $((2#${octets}))
                    bits_output+=$octet
                done
                unset -v octet octets
                bits_valid=0 # true
            fi
        fi

        # convert ipv4 octal bits
        if [ $bits_valid -eq 1 ]; then
            if [[ ${bits//\./} =~ ^[0-9]+$ ]] && [[ ${#bits} -eq 19 ]]; then
                local octet octets
                for octets in ${bits//\./\ }; do
                    printf -v octet '%02x' $((8#${octets}))
                    bits_output+=$octet
                done
                unset -v octet octets
                bits_valid=0 # true
            fi
        fi

        # convert ipv4 long bits (caveat; if it's an integer from 0-32 then it will *not* match here
        if [ $bits_valid -eq 1 ]; then
            if [[ $bits =~ ^[0-9]+$ ]]; then
                if [ $bits -gt $IPV4_MAX_BITS ] && [ $bits -le $IPV4_MAX_LONG ]; then
                    printf -v bits_output '%08x' $((10#$bits))
                    bits_valid=0 # true
                fi
            fi
        fi

        # validate bits_output
        if [ $bits_valid -eq 0 ] && [ ${#bits_output} -eq 8 ]; then

            local bits_check=0 octal_mask
            printf -v octal_mask '%o' 0x${bits_output}
            octal_mask=0${octal_mask} # octal must have leading zero

            while [ $octal_mask -gt 0 ]; do
                # calculate octal_mask modulo 2 & right shift 1 position; add the result to decimal bits
                let local bits_check+=$((octal_mask%2)) 'octal_mask>>=1'
            done


            if [ $bits_check -ge 0 ] && [ $bits_check -le $IPV4_MAX_BITS ]; then
                local bits_valid=0 # valid bits
            else
                local bits_valid=1 # valid bits
            fi

            # append valid bits to output
            output+="/${bits_output}"
        else
            return 1 # invalid bits
        fi

    fi


    # out valid address[/bits] and return 0
    if [ $address_valid -eq 0 ] && [ $bits_valid -eq 0 ]; then
        printf $output
        return 0
    fi

    # invalid address, return 1
    return 1
}

#
# output ipv4 mixed input to unsigned integer (uin) and return true, or output nothing and return false
#
function ipv4Uint() {
    local address=$1
    local return=""

    printf "return=$return\n"
    printf "address=$address\n"
}

#
# output ipv4 mixed input to octal (oct) and return true, or output nothing and return false
#
function ipv4Oct() {
    local address=$1
    local return=""

    # 0377.0377.0001.0001 # 255.255.1.1

    printf "return=$return\n"
    printf "address=$address\n"
}

#
# old
#

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
