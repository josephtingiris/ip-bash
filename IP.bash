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
# input an integer or hexidecimal value
# output the binary string representation of input and return true, or output nothing and return false
#
function binary() {
    local -l input=${1}

    # convert hex to base 10 int
    if [ "${input:0:2}" == "0x" ]; then
        local input=$((10#$input))
    fi

    # convert base 10 int to binary
    if [[ ${input} =~ ^[0-9]+$ ]]; then
        local uint bit=""
        printf -v uint '%u' "$input"
        if [ $uint -eq 0 ]; then
            local bit=0
        else
            for ((; uint>0; uint>>=1)); do
                local bit="$((uint&1))$bit"
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
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address that's been 'formatted' and return true, or output nothing and return false
#
# note: Some address validation is performed, but it's imperfect.  It is possible that certain outputs will be invalid addresses.
function ipv4Address() {
    local -l input=${1}

    if [ ${#input} -le 0 ]; then
        return 1 # input length invalid
    fi

    local -l output

    local address bits

    # get address from input
    if [[ "$input" == *"/"* ]]; then
        address=${input%%/*} # everything before /
        bits=${input##*/} # everything after /
    else
        address=${input}
    fi

    if address=$(ipv4AddressCompress $address); then
        if ! address=$(ipv4AddressExpand $address); then
            return 1 # failed to expand
        fi
    else
        return 1 # failed to compress
    fi

    if [ ${#bits} -gt 0 ]; then
        if bits=$(ipv4Bits $bits); then
            output="${address}/${bits}"
        else
            return 1
        fi
    else
        output="${address}"
    fi

    if [[ ! "${ouput}" == *"/"* ]]; then
        # ipv4 address without cidr bits
        if [[ ${ouput} =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]]; then
            printf "%s" "$output"
            return 0
        fi
    else
        # ipv4 address with cidr bits
        if [[ ${ouput} =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$ ]]; then
            printf "%s" "$output"
            return 0
        fi
    fi

    return 1
}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address that's been 'compressed' and return true, or output nothing and return false
#
function ipv4AddressCompress() {
    local -l input=$1

    if [ ${#input} -le 0 ]; then
        return 1 # input length invalid
    fi

    local -l output

    output=$input # preserve input
    output=${output%%/*} # strip everything after /; (remove bits)

    output=${output//:/} # strip all :
    output=${output//0x/} # strip all 0x

    # decimal
    if [[ $output == *"."* ]]; then
        if [ "${output//[^\.]}" == "..." ]; then
            if [ ${#output} -lt 16 ]; then
                if [[ ${output//\./} =~ ^[0-9]+$ ]]; then
                    local octet octets
                    for octet in ${output//\./\ }; do
                        octets+=".$((10#$octet))"
                    done
                    output=${octets#.*} # remove leading .
                    unset -v octet octets
                else
                    return 1 # invalid decimal
                fi
            fi
        else
            return 1 # too many dots
        fi
    fi

    output=${output//[[:space:]]/} # strip all spaces

    printf "%s" "$output"

    return 0
}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 that's been 'expanded' and return true, or output nothing and return false
#
function ipv4AddressExpand() {
    local -l input=$1
    local -l output

    if [ ${#input} -le 0 ]; then
        return 1
    fi

    output=$input

    if [[ ! $output == *"."* ]]; then
        # hexidecimal
        if [ ${#output} -eq 8 ]; then
            if [[ ${output} =~ ^([0-9a-fA-F]+)$ ]]; then
                output="0x${output}"
            else
                return 1 # invalid hex address
            fi
        else
            # octal
            if [ ${#output} -eq 16 ]; then
                if [[ ${output} =~ ^[0-9]+$ ]]; then
                    output="${output:0:4}.${output:4:4}.${output:8:4}.${output:12:4}"
                else
                    return 1 # invalid octal address
                fi
            else
                # binary
                if [ ${#output} -eq 32 ]; then
                    if [[ ${output} =~ ^[0-1]+$ ]]; then
                        output="${output:0:8}.${output:8:8}.${output:16:8}.${output:24:8}"
                    else
                        return 1 # invalid binary address
                    fi
                fi
            fi
        fi
    fi

    printf "%s" "$output"
    return 0
}

#
# input ipv4 <subnet mask|bits> in binary, decimal, hexidecimal, octal, or uint
# output ipv4 (cidr) bits or conversion of bits and return true, or output nothing and return
#
# optionally, with $input=="chart", output a chart (to stderr) of all bit representations (that are valid & supported)
#
# note: i.e.
# ipv4Bits 192.168.0.1 # false
# ipv4Bits 255.255.248.0 # 21
# ipv4Bits 21 decimal # 255.255.248.0
# ipv4Bits chart # displays all values of all bits >= 0 or <= $IPV4_MAX_BITS
# ipv4Bits chart 14 # displays all values of 14 bits
#
function ipv4Bits() {
    local -l input=${1}
    local -l output=${2:0:3}

    local bits chart sep while_bits while_bits_match

    input=${input//[[:space:]]/}

    # get bits from input
    if [[ "$input" == *"/"* ]]; then
        bits=${input##*/} # everything after /
    else
        bits=$input
    fi

    if [ "$bits" == "chart" ]; then
        chart=0 # true
        printf -v sep -- "-%.0s" {1..111}
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
            if [ $((10#$bits)) -ge 0 ] && [ $((10#$bits)) -le $IPV4_MAX_BITS ]; then
                if [ ${#output} -gt 0 ] && [ "${output}" != "bit" ]; then
                    case ${output} in
                        bin|dec|hex|uin|oct)
                            while_bits_match=$bits
                            ;;
                        *)
                            return 1 # unsupported output
                            ;;
                    esac
                else
                    if [ "${output}" == "" ] || [ "${output}" == "bit" ]; then
                        printf "%u" $((10#$bits))
                        return 0 # special case; valid return $bits (faster)
                    fi
                fi
            fi
        fi
    fi

    # if chart, then print header row
    if [ $chart -eq 0 ]; then
        (>&2 printf "+%s+\n" "$sep")
        (>&2 printf "%-7s" "| bits")
        (>&2 printf "%-38s" "| binary")
        (>&2 printf "%-18s" "| decimal")
        (>&2 printf "%-14s" "| hexidecimal")
        (>&2 printf "%-13s" "| uint")
        (>&2 printf "%-22s" "| octal")
        (>&2 printf "|\n")
        (>&2 printf "+%s+\n" "$sep")
    fi

    while_bits=$IPV4_MAX_BITS

    # go backwards, it's typically faster because most prefixes are /32 not /0, /1, etc.
    while [ $while_bits -ge 0 ]; do

        if [ ${#while_bits_match} -gt 0 ]; then
            if [ ${while_bits_match} -ne ${while_bits} ]; then
                ((while_bits--))
                continue
            fi
        fi

        if [ $chart -eq 0 ]; then
            (>&2 printf "%-7s" "| $while_bits")
        else
            if [ "${bits}" == "${while_bits}" ]; then
                while_bits_match=0
                #(>&2 echo "input=$input output=$output while_bits=$while_bits ($while_bits_match) bits=$bits")
            fi
        fi

        if [ ${#while_bits_match} -eq 0 ] || [ ${while_bits_match} -ne 0 ] || [ ${#output} -ne 0 ]; then
            local binary
            printf -v binary "%.$((${while_bits}))s%.$((${IPV4_MAX_BITS}-${while_bits}))s" "11111111111111111111111111111111" "00000000000000000000000000000000"
            binary="${binary:0:8}.${binary:8:8}.${binary:16:8}.${binary:24:8}" # add dots
            # all conversions depend on the binary representation of $bits
            if [ ${#binary} -ne 35 ]; then
                return 1 # invalid binary conversion
            fi
            if [ $chart -eq 0 ]; then
                (>&2 printf "%-38s" "| $binary")
            else
                if [ "${bits//\./}" == "${binary//\./}" ]; then
                    while_bits_match=0
                fi
            fi
        fi

        if [ ${#while_bits_match} -eq 0 ] || [ ${while_bits_match} -ne 0 ] || [ "${output}" == "dec" ]; then
            local decimal
            printf -v decimal "%d.%d.%d.%d" $((2#${binary:0:8})) $((2#${binary:9:8})) $((2#${binary:18:8})) $((2#${binary:27:8}))
            if [ $chart -eq 0 ]; then
                (>&2 printf "%-18s" "| $decimal")
            else
                if [ "${bits}" == "${decimal}" ]; then
                    while_bits_match=0
                fi
            fi
        fi

        if [ ${#while_bits_match} -eq 0 ] || [ ${while_bits_match} -ne 0 ] || [ "${output}" == "hex" ]; then
            local hexidecimal
            printf -v hexidecimal "0x%02x%02x%02x%02x" $((2#${binary:0:8})) $((2#${binary:9:8})) $((2#${binary:18:8})) $((2#${binary:27:8}))
            if [ $chart -eq 0 ]; then
                (>&2 printf "%-14s" "| $hexidecimal")
            else
                if [ "${bits}" == "${hexidecimal}" ] || [ "${bits}" == "${hexidecimal:2:8}" ]; then
                    while_bits_match=0
                fi
            fi
        fi

        if [ ${#while_bits_match} -eq 0 ] || [ ${while_bits_match} -ne 0 ] || [ "${output}" == "uin" ]; then
            local uint
            printf -v uint "%u" ${hexidecimal}
            if [ $chart -eq 0 ]; then
                (>&2 printf "%-13s" "| $uint")
            else
                if [ "${bits}" == "${uint}" ]; then
                    while_bits_match=0
                fi
            fi
        fi

        if [ ${#while_bits_match} -eq 0 ] || [ ${while_bits_match} -ne 0 ] || [ "${output}" == "oct" ]; then
            local octal
            printf -v octal "%04o.%04o.%04o.%04o" $((2#${binary:0:8})) $((2#${binary:9:8})) $((2#${binary:18:8})) $((2#${binary:27:8}))
            if [ $chart -eq 0 ]; then
                (>&2 printf "%-22s" "| $octal")
            else
                if [ "${bits//\./}" == "${octal//\./}" ]; then
                    while_bits_match=0
                fi
            fi
        fi

        if [ $chart -eq 0 ]; then
            (>&2 printf "|\n")
        else

            if [[ "$while_bits_match" =~ ^[0-9]+$ ]] && [ $while_bits_match -eq 0 ]; then
                case ""$output in
                    bin)
                        printf "%s" $binary
                        ;;
                    dec)
                        printf "%s" $decimal
                        ;;
                    hex)
                        printf "%s" $hexidecimal
                        ;;
                    uin)
                        printf "%s" $uint
                        ;;
                    oct)
                        printf "%s" $octal
                        ;;
                    *)
                        printf "%d" $while_bits
                        ;;
                esac
                return 0
            fi
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

#
# input two ipv4 address[/bits|mask] values
# ouput nothing and return true if two address[/bits|mask] inputs 'confict' with each other, or false if they don't
#
function ipv4Conflict() {
    local -l input1=$1
    local -l input2=$2

    local address1 address2 bits1 bits2 output

    # seperate input1 into address1 & bits1
    if address1=$(ipv4ToUint ${input1}); then
        if [[ "${address1}" == *"/"* ]]; then
            bits1=${address1##*/} # everything after /
            address1=${address1%%/*} # everything before /
            if ! bits1=$(ipv4Bits ${bits1} bit); then
                return 1 # invalid bits1
            fi
        else
            bits1=${IPV4_MAX_BITS}
        fi
    else
        return 1 # invalid address1
    fi

    local -i sint1=$((-1<<($IPV4_MAX_BITS - $bits1)))
    local -i aligned1=$(($address1 & $sint1))

    # seperate input2 into address2 & bits2
    if address2=$(ipv4ToUint ${input2}); then
        if [[ "${address2}" == *"/"* ]]; then
            bits2=${address2##*/} # everything after /
            address2=${address2%%/*} # everything before /
            if ! bits2=$(ipv4Bits ${bits2} bit); then
                return 1 # invalid bits2
            fi
        else
            bits2=${IPV4_MAX_BITS}
        fi
    else
        return 1 # invalid address2
    fi

    local -i sint2=$((-1<<($IPV4_MAX_BITS - $bits2)))
    local -i aligned2=$(($address2 & $sint2))

    local -i conflict1=$(($aligned1 & $sint2))
    local -i conflict2=$(($aligned2 & $sint1))

    #(>&2 echo "address1=$address1 aligned1=$aligned1 bits1=$bits1 sint1=$sint1 conflict1=$conflict1")
    #(>&2 echo "address2=$address2 aligned2=$aligned2 bits2=$bits2 sint2=$sint2 conflict2=$conflict2")

    if [ $conflict1 -eq $conflict2 ]; then
        return 0 # the addresses conflict
    else
        return 1 # the addersses do not conflict
    fi
}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/bits|mask] in binary (bin) form and return true, or output nothing and return false
#
# note: This function first converts $input to ipv4ToHex $output and then uses printf to convert to the proper format.
#
function ipv4ToBin() {
    local -l input=$1
    local -l address bits output

    # seperate input into address & bits
    if address=$(ipv4ToHex $input); then
        if [[ "${address}" == *"/"* ]]; then
            bits=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ! bits=$(ipv4Bits ${bits} bin); then
                return 1 # invalid bits
            fi
        fi
    else
        return 1 # invalid address
    fi

    printf -v output "%08d.%08d.%08d.%08d" $(binary $((16#${address:2:2}))) $(binary $((16#${address:4:2}))) $(binary $((16#${address:6:2}))) $(binary $((16#${address:8:2})))

    if [ ${#bits} -gt 0 ]; then
        output+="/${bits}"
    fi

    printf "%s" "$output"
    return 0
}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/bits|mask] in binary (bin) form and return true, or output nothing and return false
#
# note: This function converts the input to native binary() strings, rather than converting ipv4ToHex $output to binary with printf
#       It's 33% slower, though I thought worth preserving. Ideally, all inputs would be converted to binary and from there
#       mathed quickly to other outputs.  Too bad bash doesn't support base 2 via builtins.
#
function ipv4ToBinary() {
    local -l input=$1
    local -l address bits output

    # seperate input into address & bits
    if address=$(ipv4Address $input); then
        if [[ "${address}" == *"/"* ]]; then
            bits=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if bits=$(ipv4Bits ${bits} bin); then
                if ! bits=$(ipv4Address ${bits}); then
                    return 1 # failed to address format bits
                fi
            else
                return 1 # invalid bits
            fi
        fi
    else
        return 1 # invalid address
    fi

    if [ ${#output} -eq 0 ]; then
        if [[ ${address} == *"."* ]]; then
            if [ "${address//[^\.]}" == "..." ]; then
                local octet octets
                for octet in ${address//\./ }; do
                    #if [ ${#octet} -eq 8 ]; then
                    if [[ ${octet} =~ ^[0-1]{8}$ ]]; then
                        # binary octet
                        octets+=".${octet}"
                    else
                        if [ ${#octet} -eq 4 ]; then
                            # octal octet
                            if [ $((8#$octet)) -ge 0 ] && [ $((8#$octet)) -le 255 ]; then
                                printf -v octet "%08u" $(binary $((8#$octet)))
                                octets+=".${octet}"
                            else
                                return 1 # invalid octal
                            fi
                        else
                            # decimal octet
                            if [ $((10#$octet)) -ge 0 ] && [ $((10#$octet)) -le 255 ]; then
                                printf -v octet "%08u" $(binary $((10#$octet)))
                                octets+=".${octet}"
                            else
                                return 1 # invalid decimal
                            fi
                        fi
                    fi
                done
                output=${octets#.*}
                unset -v octet octets
            else
                return 1 # too many dots
            fi
        fi
    fi

    if [ ${#output} -eq 0 ]; then
        if [[ ${address} =~ ^0[Xx] ]]; then
            if [ ${#address} -eq 10 ]; then
                printf -v output "%08u.%08u.%08u.%08u" $(binary $((16#${address:2:2}))) $(binary $((16#${address:4:2}))) $(binary $((16#${address:6:2}))) $(binary $((16#${address:8:2})))
            else
                return 1 # invalid hex address (too long)
            fi

        fi
    fi

    if [ ${#output} -eq 0 ]; then
        if [[ ${address} =~ ^[0-9]+$ ]]; then
            if [ $((10#${address})) -ge 0 ] && [ $((10#${address})) -le ${IPV4_MAX_LONG} ]; then
                printf -v output "%08u.%08u.%08u.%08u" $(binary $((address>>24&255))) $(binary $((address>>16&255))) $(binary $((address>>8&255))) $(binary $((address&255)))
            else
                return 1 # unknown address type; (uint out of range)
            fi
        fi
    fi

    if output=$(ipv4Address ${output}); then
        if [ ${#bits} -gt 0 ]; then
            output+="/${bits}"
        fi
        printf "%s" "$output"
        return 0
    else
        # (>&2 echo "address=$address dec=$((16#${address:2:10}))")
        return 1
    fi

}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/bits|mask] in decimal (dec) form and return true, or output nothing and return false
#
# note: This function first converts $input to ipv4ToHex $output and then uses printf to convert to the proper format.
#       If [/bits|mask] is valid then it will output cidr bits *not* a decimal subnet mask.
#
function ipv4ToDec() {
    local -l input=$1
    local -l address bits output

    # seperate input into address & bits
    if address=$(ipv4ToHex $input); then
        if [[ "${address}" == *"/"* ]]; then
            bits=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ! bits=$(ipv4Bits ${bits} bit); then
                return 1 # invalid bits
            fi
        fi
    else
        return 1 # invalid address
    fi

    #printf -v output "%u.%u.%u.%u" $((2#${address:0:8})) $((2#${address:9:8})) $((2#${address:18:8})) $((2#${address:27:8})) # binary
    printf -v output "%u.%u.%u.%u" $((16#${address:2:2})) $((16#${address:4:2})) $((16#${address:6:2})) $((16#${address:8:2})) # hex
    if [ ${#bits} -gt 0 ]; then
        output+="/${bits}"
    fi

    printf "%s" "$output"
    return 0
}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/bits|mask] in decimal (dec) form and return true, or output nothing and return false
#
# note: This function first converts $input to ipv4ToHex $output and then uses printf to convert to the proper format.
#       If [/bits|mask] is valid then it will output a decimal subnet mask *not* cidr bits.
#
function ipv4ToDecMask() {
    local -l input=$1
    local -l address bits output

    # seperate input into address & bits
    if address=$(ipv4ToHex $input); then
        if [[ "${address}" == *"/"* ]]; then
            bits=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ! bits=$(ipv4Bits ${bits} dec); then
                return 1 # invalid bits
            fi
        fi
    else
        return 1 # invalid address
    fi

    #printf -v output "%u.%u.%u.%u" $((2#${address:0:8})) $((2#${address:9:8})) $((2#${address:18:8})) $((2#${address:27:8})) # binary
    printf -v output "%u.%u.%u.%u" $((16#${address:2:2})) $((16#${address:4:2})) $((16#${address:6:2})) $((16#${address:8:2})) # hex
    if [ ${#bits} -gt 0 ]; then
        output+="/${bits}"
    fi

    printf "%s" "$output"
    return 0
}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/bits|mask] in hexidecimal (hex) form and return true, or output nothing and return false
#
# note: Many of the other functions herein depdend on this function.  It's more comprehensive, faster, and is easier to reduce to
# hex & then convert to other formats via printf.
#
function ipv4ToHex() {
    local -l input=$1
    local -l address bits output

    # seperate input into address & bits
    if address=$(ipv4Address $input); then
        if [[ "${address}" == *"/"* ]]; then
            bits=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if bits=$(ipv4Bits ${bits} hex); then
                if ! bits=$(ipv4Address ${bits}); then
                    return 1
                fi
            else
                return 1
            fi
        fi
    else
        return 1
    fi

    if [ ${#address} -eq 0 ]; then
        return 1 # invalid; address length is 0
    else
        # convert ipv4 hex address
        if [ ${#output} -eq 0 ]; then
            if [[ ${address} =~ ^((^0[Xx]{1}[0-9a-fA-F]{8}|[0-9a-fA-F]{8})$) ]]; then
                if [[ ${address} =~ ^0[Xx] ]]; then
                    output=${address:2:${#address}-2}
                else
                    output=$address
                fi
            fi
        fi

        # convert ipv4 decimal address
        if [ ${#output} -eq 0 ]; then
            if [[ $address =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]){1}$ ]]; then
                printf -v output '%02x' ${address//\./\ }

            fi
        fi

        # convert ipv4 uint address
        if [ ${#output} -eq 0 ]; then
            if [[ $address =~ ^[0-9]+$ ]]; then
                if [ $address -ge 0 ] && [ $address -le $IPV4_MAX_LONG ]; then
                    printf -v output '%08x' $((10#$address))
                fi
            fi
        fi

        # convert ipv4 binary address
        if [ ${#output} -eq 0 ]; then
            if [[ ${address//\./} =~ ^[0-1]+$ ]] && [[ ${#address} -eq 35 ]]; then
                local octet octets
                for octets in ${address//\./\ }; do
                    printf -v octet '%02x' $((2#${octets}))
                    output+=$octet
                done
                unset -v octet octets
            fi
        fi

        # convert ipv4 octal address
        if [ ${#output} -eq 0 ]; then
            if [[ ${address//\./} =~ ^[0-9]+$ ]] && [[ ${#address} -eq 19 ]]; then
                local octet octets
                for octets in ${address//\./\ }; do
                    printf -v octet '%02x' $((8#${octets}))
                    output+=$octet
                done
                unset -v octet octets
            fi
        fi

    fi

    # output valid address[/bits] and return 0
    if [ ${#output} -eq 8 ]; then
        if [ ${#bits} -gt 0 ]; then
            output+="/${bits}"
        fi
        printf "0x%s" $output
        return 0
    else
        # invalid address, return 1
        return 1
    fi
}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/bits|mask] in octal (oct) form and return true, or output nothing and return false
#
# note: This function first converts $input to ipv4ToHex $output and then uses printf to convert to the proper format.
#
function ipv4ToOct() {
    local -l input=$1
    local -l address bits output

    # seperate input into address & bits
    if address=$(ipv4ToHex $input); then
        if [[ "${address}" == *"/"* ]]; then
            bits=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ! bits=$(ipv4Bits ${bits} oct); then
                return 1 # invalid bits
            fi
        fi
    else
        return 1 # invalid address
    fi

    #printf -v output "%u.%u.%u.%u" $((2#${address:0:8})) $((2#${address:9:8})) $((2#${address:18:8})) $((2#${address:27:8})) # binary
    printf -v output "%04o.%04o.%04o.%04o" $((16#${address:2:2})) $((16#${address:4:2})) $((16#${address:6:2})) $((16#${address:8:2})) # hex
    if [ ${#bits} -gt 0 ]; then
        output+="/${bits}"
    fi

    printf "%s" "$output"
    return 0
}

#
# input ipv4 address[/bits|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/bits|mask] in unsigned integer (uin) form and return true, or output nothing and return false
#
# note: This function first converts $input to ipv4ToHex $output and then uses printf to convert to the proper format.
#
function ipv4ToUint() {
    local -l input=$1
    local -l address bits output

    # seperate input into address & bits
    if address=$(ipv4ToHex $input); then
        if [[ "${address}" == *"/"* ]]; then
            bits=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ! bits=$(ipv4Bits ${bits} uin); then
                return 1 # invalid bits
            fi
        fi
    else
        return 1 # invalid address
    fi

    printf -v output "%u" ${address}
    if [ ${#bits} -gt 0 ]; then
        output+="/${bits}"
    fi

    printf "%s" "$output"
    return 0
}
