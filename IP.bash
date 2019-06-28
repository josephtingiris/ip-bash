#!/bin/bash -r --noediting --noprofile --norc

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
readonly IPV4_MAX_LONG=$((2**${IPV4_MAX_BITS}-1))
readonly IPV6_MAX_BITS=128
readonly IPV6_MAX_LONG=$((2**${IPV6_MAX_BITS}-1)) # grr; bash max is sint64

#############
# functions #
#############

#
# input an integer or hexidecimal value
# output the binary string representation of input and return true, or output nothing and return false
#
function binary() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local output=${input} # preserve input

    # convert hex to base 10 int
    if [ "${output:0:2}" == "0x" ]; then
        printf -v output "%d" ${output}
    fi

    # convert base 10 int to binary
    if [[ ${output} =~ ^[0-9]+$ ]]; then
        local bits=""
        printf -v output '%u' "${output}"
        if [ ${output} -eq 0 ]; then
            bits=0
        else
            for ((; output>0; output>>=1)); do
                bits="$((output&1))${bits}"
            done
        fi

        if [ ${#bits} -gt 0 ]; then

            output=${bits}

            local -l argv=($@)
            if [ "${argv[-1]}" == "global" ]; then
                unset -v ${FUNCNAME}_output
                printf -v ${FUNCNAME}_output "%s" ${output}
            else
                printf '%s' "${output}"
            fi

            return 0
        fi
    fi

    return 1
}

#
# input anything
# output input, or unset/eval a global variable the same name as the function with the value of input
#
# note: This function is to test a bash performance hack; it's significantly faster to use globals than subshells.
function ipGlobal() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local output=${input} # preserve input

    # if this function was called via a subshell then printf to stdout else set a global the same name as the function

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address that's been 'formatted' and return true, or output nothing and return false
#
function ipv4Address() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l output=${2}

    local address prefix

    # get address from input
    if [[ "${input}" == *"/"* ]]; then
        address=${input%%/*} # everything before /
        prefix=${input##*/} # everything after /
    else
        address=${input}
    fi

    local -i address_type=0
    ipv4AddressType ${address} &> /dev/null
    address_type=$?

    if [ $address_type -gt 4 ]; then
        return 1 # invalid address
    fi

    if ipv4AddressCompress ${address} ${address_type} global; then
        address=${ipv4AddressCompress_output}
        if ipv4AddressExpand ${address} ${address_type} global; then
            address=${ipv4AddressExpand_output}
        else
            return 1 # failed to expand
        fi
    else
        return 1 # failed to compress
    fi

    if [ ${#prefix} -gt 0 ]; then
        if ipv4Prefix ${prefix} global; then
            prefix=${ipv4Prefix_output}
            output="${address}/${prefix}"
        else
            return 1 # invalid prefix
        fi
    else
        output="${address}"
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

    return 0
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address that's been 'compressed' and return true, or output nothing and return false
#
function ipv4AddressCompress() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l output=${2}

    local -i address_type=99
    if [[ ${output} =~ ^[0-9]+$ ]]; then
        address_type=${output}
        output=${input} # preserve input
    else
        if [ ${#output} -le 0 ] || [ "${output}" == "global" ]; then
            ipv4AddressType ${address} &> /dev/null
            address_type=$?
        else
            return 1 # invalid output
        fi
    fi

    if [ $address_type -gt 4 ]; then
        return 1
    fi

    output=${input}
    output=${output%%/*} # strip everything after /; (remove prefix)
    output=${output//[[:space:]]/} # strip all spaces

    # decimal
    if [ $address_type -eq 0 ]; then
        local octet octets
        octets=""
        for octet in ${output//\./\ }; do
            octets+=".$((10#${octet}))"
        done
        output=${octets#.*} # remove leading .
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

    return 0
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 that's been 'expanded' and return true, or output nothing and return false
#
function ipv4AddressExpand() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l output=${2}

    local -i address_type=99
    if [[ ${output} =~ ^[0-9]+$ ]]; then
        address_type=${output}
        output=${input} # preserve input
    else
        if [ ${#output} -le 0 ] || [ "${output}" == "global" ]; then
            ipv4AddressType ${address} &> /dev/null
            address_type=$?
        else
            return 1 # invalid output
        fi
    fi

    if [ $address_type -gt 4 ]; then
        return 1
    fi

    output=${input}
    output=${output%%/*} # strip everything after /; (remove prefix)
    output=${output//[[:space:]]/} # strip all spaces

    # dec
    # add zeros?

    # hex
    if [ $address_type -eq 1 ]; then
        if [ ${output:0:2} != "0x" ]; then
            output="0x${output}"
        fi
    else
        # bin
        if [ $address_type -eq 3 ]; then
            if [ ${#output} -eq 32 ]; then
                output="${output:0:8}.${output:8:8}.${output:16:8}.${output:24:8}"
            fi
        else
            # oct
            if [ $address_type -eq 4 ]; then
                if [ ${#output} -eq 16 ]; then
                    output="${output:0:4}.${output:4:4}.${output:8:4}.${output:12:4}"
                fi
            fi
        fi
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

    return 0
}

#
# input ipv4 address in binary, decimal, hexidecimal, octal, or uint
# output none
# return integer (0=decimal, 1=hexidecimal, 2=uint, 3=binary, 4=octal)
#
function ipv4AddressType() {
    local -l input=${1}

    # for performance this is ordered by 'most common' input

    # dec
    if [[ ${input} =~ ^((([0-9]{1,2}|[0-1][0-9]{1,2}|[0-2][0-5][0-5])(\.|$)){4}$) ]]; then
        return 0
    fi

    # hex
    if [[ ${input} =~ ^((^0x{1}[0-9a-f]{8}|[0-9a-f]{8})$) ]]; then
        return 1
    fi

    if [[ ${input} =~ ^[0-9]+$ ]]; then
        # uint
        if [ $input -ge 0 ] && [ $input -le ${IPV4_MAX_LONG} ]; then
            return 2
        fi
    fi

    # bin
    if [[ ${input} =~ ^(([0-1]{8}(|\.|$)){4}) ]]; then
        return 3
    fi

    # oct
    if [[ ${input} =~ ^((0[0-7][0-7][0-7](|\.|$)){4}$) ]]; then
        return 4
    fi

    return 99
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 that's been 'expanded' and return true, or output nothing and return false
# return integer (0=success/true, 1=failed/false)
#
function ipv4AddressValid() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

    return 0
}

#
# input two ipv4 address[/prefix|mask] values
# ouput nothing and return true if two address[/prefix|mask] inputs 'confict' with each other, or false if they don't
#
function ipv4Conflict() {
    local -l input1=${1}

    if [ ${#input1} -le 0 ] || [ "${input1}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l input2=${2}

    if [ ${#input2} -le 0 ] || [ "${input2}" == "global" ]; then
        return 1 # invalid input
    fi

    local address1 address2 prefix1 prefix2 output

    # seperate input1 into address1 & prefix1
    if ipv4ToHex ${input1} global; then
        address1=${ipv4ToHex_output}
        if [[ "${address1}" == *"/"* ]]; then
            prefix1=${address1##*/} # everything after /
            address1=${address1%%/*} # everything before /
            if ipv4Prefix ${prefix1} pre global; then
                prefix1=${ipv4Prefix_output}
            else
                return 1 # invalid prefix
            fi
        fi
    else
        return 1 # invalid address1
    fi
    if [ ${#prefix1} -eq 0 ]; then
        prefix1=${IPV4_MAX_BITS}
    fi

    local -i sint1=$((-1<<(${IPV4_MAX_BITS} - ${prefix1})))
    local -i aligned1=$((${address1} & ${sint1}))

    # seperate input2 into address2 & prefix2
    if ipv4ToHex ${input2} global; then
        address2=${ipv4ToHex_output}
        if [[ "${address2}" == *"/"* ]]; then
            prefix2=${address2##*/} # everything after /
            address2=${address2%%/*} # everything before /
            if ipv4Prefix ${prefix2} pre global; then
                prefix2=${ipv4Prefix_output}
            else
                return 1 # invalid prefix
            fi
        fi
    else
        return 1 # invalid address2
    fi
    if [ ${#prefix2} -eq 0 ]; then
        prefix2=${IPV4_MAX_BITS}
    fi

    local -i sint2=$((-1<<(${IPV4_MAX_BITS} - ${prefix2})))
    local -i aligned2=$((${address2} & ${sint2}))

    local -i conflict1=$((${aligned1} & ${sint2}))
    local -i conflict2=$((${aligned2} & ${sint1}))

    #(>&2 echo "address1=${address1} aligned1=${aligned1} prefix1=${prefix1} sint1=${sint1} conflict1=${conflict1}")
    #(>&2 echo "address2=${address2} aligned2=${aligned2} prefix2=${prefix2} sint2=${sint2} conflict2=${conflict2}")

    if [ ${conflict1} -eq ${conflict2} ]; then
        return 0 # the addresses conflict
    else
        return 1 # the addersses do not conflict
    fi
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/prefix|mask] in binary (bin) form and return true, or output nothing and return false
#
# note: This function first converts ${input} to ipv4ToHex ${output} and then uses printf to convert to the proper format.
#
function ipv4ToBin() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l address prefix output

    # seperate input into address & prefix
    if ipv4ToHex ${input} global; then
        address=${ipv4ToHex_output}
        if [[ "${address}" == *"/"* ]]; then
            prefix=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ipv4Prefix ${prefix} bin global; then
                prefix=${ipv4Prefix_output}
            else
                return 1 # invalid prefix
            fi
        fi
    else
        return 1 # invalid address
    fi

    local a b c d

    if binary $((16#${address:2:2})) global; then
        a=${binary_output}
    else
        return 1
    fi

    if binary $((16#${address:4:2})) global; then
        b=${binary_output}
    else
        return 1
    fi

    if binary $((16#${address:6:2})) global; then
        c=${binary_output}
    else
        return 1
    fi

    if binary $((16#${address:8:2})) global; then
        d=${binary_output}
    else
        return 1
    fi

    printf -v output "%08u.%08u.%08u.%08u" ${a} ${b} ${c} ${d}

    if [ ${#prefix} -gt 0 ]; then
        output+="/${prefix}"
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" ${output}
    fi

    return 0
}

#
# input ipv4 <subnet mask|prefix> in binary, decimal, hexidecimal, octal, or uint
# output ipv4 (cidr) prefix or conversion of prefix and return true, or output nothing and return
#
# optionally, with ${input}=="chart", output a chart (to stderr) of all representations (that are valid & supported)
#
# note: i.e.
# ipv4Prefix 192.168.0.1 # false
# ipv4Prefix 255.255.248.0 # 21
# ipv4Prefix 21 decimal # 255.255.248.0
# ipv4Prefix chart # displays all values of all prefix >= 0 or <= ${IPV4_MAX_BITS}
# ipv4Prefix chart 14 # displays all values of 14 prefix
#
function ipv4Prefix() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l output=${2}

    if [ "${output}" == "global" ]; then
        output=""
    else
        output=${output:0:3}
    fi

    local prefix chart sep while_prefix while_prefix_match

    input=${input//[[:space:]]/}

    # get prefix from input
    if [[ "${input}" == *"/"* ]]; then
        prefix=${input##*/} # everything after /
    else
        prefix=${input}
    fi

    if [ "${prefix}" == "chart" ]; then
        chart=0 # true
        printf -v sep -- "-%.0s" {1..113}
        # only match prefix given as ${2}
        if [[ ${output} =~ ^[0-9]+$ ]]; then
            if [ ${output} -ge 0 ] || [ ${output} -le ${IPV4_MAX_BITS} ]; then
                while_prefix_match=${output}
            fi
        fi
    else
        chart=1 # false
        # if prefix are given as ${1} and ${2} starts with one of the supported format names then output that representation
        if [[ ${prefix} =~ ^[0-9]+$ ]]; then
            if [ $((10#${prefix})) -ge 0 ] && [ $((10#${prefix})) -le ${IPV4_MAX_BITS} ]; then
                if [ ${#output} -gt 0 ] && [ "${output}" != "pre" ]; then
                    case ${output} in
                        bin|dec|hex|uin|oct)
                            while_prefix_match=${prefix}
                            ;;
                        *)
                            return 1 # unsupported output
                            ;;
                    esac
                else
                    if [ "${output}" == "" ] || [ "${output}" == "pre" ]; then
                        printf -v output "%u" $((10#${prefix}))

                        local -l argv=($@)
                        if [ "${argv[-1]}" == "global" ]; then
                            unset -v ${FUNCNAME}_output
                            printf -v ${FUNCNAME}_output "%s" ${output}
                        else
                            printf "%s" ${output}
                        fi

                        return 0 # special case; valid return ${prefix} (faster)
                    fi
                fi
            fi
        fi
    fi

    # if chart, then print header row
    if [ ${chart} -eq 0 ]; then
        (>&2 printf "+%s+\n" "${sep}")
        (>&2 printf "%-9s" "| prefix")
        (>&2 printf "%-38s" "| binary")
        (>&2 printf "%-18s" "| decimal")
        (>&2 printf "%-14s" "| hexidecimal")
        (>&2 printf "%-13s" "| uint")
        (>&2 printf "%-22s" "| octal")
        (>&2 printf "|\n")
        (>&2 printf "+%s+\n" "${sep}")
    fi

    while_prefix=${IPV4_MAX_BITS}

    local binary decimal hexidecimal uint octal

    # go backwards, it's typically faster because most prefixes are /32 not /0, /1, etc.
    while [ ${while_prefix} -ge 0 ]; do

        binary=""
        decimal=""
        hexidecimal=""
        uint=""
        octal=""

        if [ ${#while_prefix_match} -gt 0 ]; then
            if [ ${while_prefix_match} -ne ${while_prefix} ]; then
                ((while_prefix--))
                continue
            fi
        fi

        if [ ${chart} -eq 0 ]; then
            (>&2 printf "%-9s" "| ${while_prefix}")
        else
            if [ "${prefix}" == "${while_prefix}" ]; then
                while_prefix_match=0
                #(>&2 echo "input=${input} output=${output} while_prefix=${while_prefix} (${while_prefix_match}) prefix=${prefix}")
            fi
        fi

        if [ ${#while_prefix_match} -eq 0 ] || [ ${while_prefix_match} -ne 0 ] || [ ${#output} -ne 0 ]; then
            printf -v binary "%.$((${while_prefix}))s%.$((${IPV4_MAX_BITS}-${while_prefix}))s" "11111111111111111111111111111111" "00000000000000000000000000000000"
            binary="${binary:0:8}.${binary:8:8}.${binary:16:8}.${binary:24:8}" # add dots
            # all conversions depend on the binary representation of ${prefix}
            if [ ${#binary} -ne 35 ]; then
                return 1 # invalid binary conversion
            fi
            if [ ${chart} -eq 0 ]; then
                (>&2 printf "%-38s" "| ${binary}")
            else
                if [ "${prefix//\./}" == "${binary//\./}" ]; then
                    while_prefix_match=0
                fi
            fi
        fi

        if [ ${#while_prefix_match} -eq 0 ] || [ ${while_prefix_match} -ne 0 ] || [ "${output}" == "dec" ]; then
            printf -v decimal "%d.%d.%d.%d" $((2#${binary:0:8})) $((2#${binary:9:8})) $((2#${binary:18:8})) $((2#${binary:27:8}))
            if [ ${chart} -eq 0 ]; then
                (>&2 printf "%-18s" "| ${decimal}")
            else
                if [ "${prefix}" == "${decimal}" ]; then
                    while_prefix_match=0
                fi
            fi
        fi

        if [ ${#while_prefix_match} -eq 0 ] || [ ${while_prefix_match} -ne 0 ] || [ "${output}" == "hex" ]; then
            printf -v hexidecimal "0x%02x%02x%02x%02x" $((2#${binary:0:8})) $((2#${binary:9:8})) $((2#${binary:18:8})) $((2#${binary:27:8}))
            if [ ${chart} -eq 0 ]; then
                (>&2 printf "%-14s" "| ${hexidecimal}")
            else
                if [ "${prefix}" == "${hexidecimal}" ] || [ "${prefix}" == "${hexidecimal:2:8}" ]; then
                    while_prefix_match=0
                fi
            fi
        fi

        if [ ${#while_prefix_match} -eq 0 ] || [ ${while_prefix_match} -ne 0 ] || [ "${output}" == "uin" ]; then
            printf -v uint "%u" ${hexidecimal}
            if [ ${chart} -eq 0 ]; then
                (>&2 printf "%-13s" "| ${uint}")
            else
                if [ "${prefix}" == "${uint}" ]; then
                    while_prefix_match=0
                fi
            fi
        fi

        if [ ${#while_prefix_match} -eq 0 ] || [ ${while_prefix_match} -ne 0 ] || [ "${output}" == "oct" ]; then
            printf -v octal "%04o.%04o.%04o.%04o" $((2#${binary:0:8})) $((2#${binary:9:8})) $((2#${binary:18:8})) $((2#${binary:27:8}))
            if [ ${chart} -eq 0 ]; then
                (>&2 printf "%-22s" "| ${octal}")
            else
                if [ "${prefix//\./}" == "${octal//\./}" ]; then
                    while_prefix_match=0
                fi
            fi
        fi

        if [ ${chart} -eq 0 ]; then
            (>&2 printf "|\n")
        else

            if [[ "${while_prefix_match}" =~ ^[0-9]+$ ]] && [ ${while_prefix_match} -eq 0 ]; then
                case ""${output} in
                    bin)
                        printf -v output "%s" ${binary}
                        ;;
                    dec)
                        printf -v output "%s" ${decimal}
                        ;;
                    hex)
                        printf -v output "%s" ${hexidecimal}
                        ;;
                    uin)
                        printf -v output "%s" ${uint}
                        ;;
                    oct)
                        printf -v output "%s" ${octal}
                        ;;
                    *)
                        printf -v output "%d" ${while_prefix}
                        ;;
                esac

                local -l argv=($@)
                if [ "${argv[-1]}" == "global" ]; then
                    unset -v ${FUNCNAME}_output
                    printf -v ${FUNCNAME}_output "%s" ${output}
                else
                    printf "%s" ${output}
                fi

                return 0
            fi
        fi

        ((while_prefix--))
    done

    if [ ${chart} -eq 0 ]; then
        (>&2 printf "+%s+\n" "${sep}")

        return 0
    else
        return 1
    fi
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/prefix|mask] in binary (bin) form and return true, or output nothing and return false
#
# note: This function converts the input to native binary() strings, rather than converting ipv4ToHex ${output} to binary with printf
#       It's 33% slower, though I thought worth preserving. Ideally, all inputs would be converted to binary and from there
#       mathed quickly to other outputs.  Too bad bash doesn't support base 2 via builtins.
#
function ipv4ToBinary() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l address prefix output

    # seperate input into address & prefix
    if ipv4Address ${input} global; then
        address=${ipv4Address_output}
        if [[ "${address}" == *"/"* ]]; then
            prefix=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ipv4Prefix ${prefix} bin global; then
                prefix=${ipv4Prefix_output}
                if ipv4Address ${prefix} global; then
                    prefix=${ipv4Address_output}
                else
                    return 1 # failed to address format prefix
                fi
            else
                return 1 # invalid prefix
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
                            if [ $((8#${octet})) -ge 0 ] && [ $((8#${octet})) -le 255 ]; then
                                if binary $((8#${octet})) global; then
                                    printf -v octet "%08u" ${binary_output}
                                    octets+=".${octet}"
                                else
                                    return 1
                                fi
                            else
                                return 1 # invalid octal
                            fi
                        else
                            # decimal octet
                            if [ $((10#${octet})) -ge 0 ] && [ $((10#${octet})) -le 255 ]; then
                                if binary $((10#${octet})) global; then
                                    printf -v octet "%08u" ${binary_output}
                                    octets+=".${octet}"
                                else
                                    return 1
                                fi
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
        if [[ ${address} =~ ^0x ]]; then
            if [ ${#address} -eq 10 ]; then
                local a b c d

                if binary $((16#${address:2:2})) global; then
                    a=${binary_output}
                else
                    return 1
                fi

                if binary $((16#${address:4:2})) global; then
                    b=${binary_output}
                else
                    return 1
                fi

                if binary $((16#${address:6:2})) global; then
                    c=${binary_output}
                else
                    return 1
                fi

                if binary $((16#${address:8:2})) global; then
                    d=${binary_output}
                else
                    return 1
                fi

                printf -v output "%08u.%08u.%08u.%08u" ${a} ${b} ${c} ${d}
            else
                return 1 # invalid hex address (too long)
            fi

        fi
    fi

    if [ ${#output} -eq 0 ]; then
        if [[ ${address} =~ ^[0-9]+$ ]]; then
            if [ $((10#${address})) -ge 0 ] && [ $((10#${address})) -le ${IPV4_MAX_LONG} ]; then
                local a b c d

                if binary $((address>>24&255)) global; then
                    a=${binary_output}
                else
                    return 1
                fi

                if binary $((address>>16&255)) global; then
                    b=${binary_output}
                else
                    return 1
                fi

                if binary $((address>>8&255)) global; then
                    c=${binary_output}
                else
                    return 1
                fi

                if binary $((address&255)) global; then
                    d=${binary_output}
                else
                    return 1
                fi

                printf -v output "%08u.%08u.%08u.%08u" ${a} ${b} ${c} ${d}
            else
                return 1 # unknown address type; (uint out of range)
            fi
        fi
    fi

    if ipv4Address ${output} global; then
        output=${ipv4Address_output}
        if [ ${#prefix} -gt 0 ]; then
            output+="/${prefix}"
        fi

        local -l argv=($@)
        if [ "${argv[-1]}" == "global" ]; then
            unset -v ${FUNCNAME}_output
            printf -v ${FUNCNAME}_output "%s" ${output}
        else
            printf "%s" "${output}"
        fi

        return 0
    else
        return 1
    fi

}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/prefix|mask] in decimal (dec) form and return true, or output nothing and return false
#
# note: This function first converts ${input} to ipv4ToHex ${output} and then uses printf to convert to the proper format.
#       If [/prefix|mask] is valid then it will output cidr prefix *not* a decimal subnet mask.
#
function ipv4ToDec() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l address prefix output

    # seperate input into address & prefix
    if ipv4ToHex ${input} global; then
        address=${ipv4ToHex_output}
        if [[ "${address}" == *"/"* ]]; then
            prefix=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ipv4Prefix ${prefix} pre global; then
                prefix=${ipv4Prefix_output}
            else
                return 1 # invalid prefix
            fi
        fi
    else
        return 1 # invalid address
    fi

    printf -v output "%u.%u.%u.%u" $((16#${address:2:2})) $((16#${address:4:2})) $((16#${address:6:2})) $((16#${address:8:2})) # hex
    if [ ${#prefix} -gt 0 ]; then
        output+="/${prefix}"
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

    return 0
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/prefix|mask] in decimal (dec) form and return true, or output nothing and return false
#
# note: This function first converts ${input} to ipv4ToHex ${output} and then uses printf to convert to the proper format.
#       If [/prefix|mask] is valid then it will output a decimal subnet mask *not* cidr prefix.
#
function ipv4ToDecMask() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l address prefix output

    # seperate input into address & prefix
    if ipv4ToHex ${input} global; then
        address=${ipv4ToHex_output}
        if [[ "${address}" == *"/"* ]]; then
            prefix=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ipv4Prefix ${prefix} dec global; then
                prefix=${ipv4Prefix_output}
            else
                return 1 # invalid prefix
            fi
        fi
    else
        return 1 # invalid address
    fi

    printf -v output "%u.%u.%u.%u" $((16#${address:2:2})) $((16#${address:4:2})) $((16#${address:6:2})) $((16#${address:8:2})) # hex
    if [ ${#prefix} -gt 0 ]; then
        output+="/${prefix}"
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

    return 0
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/prefix|mask] in hexidecimal (hex) form and return true, or output nothing and return false
#
# note: Many of the other functions herein depdend on this function.  It's more comprehensive, faster, and is easier to reduce to
# hex & then convert to other formats via printf.
#
function ipv4ToHex() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l address prefix output

    # seperate input into address & prefix
    if ipv4Address ${input} global; then
        address=${ipv4Address_output}
        if [[ "${address}" == *"/"* ]]; then
            prefix=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ipv4Prefix ${prefix} hex global; then
                prefix=${ipv4Prefix_output}
                if ipv4Address ${prefix} global; then
                    prefix=${ipv4AddressExpand_output}
                else
                    return 1
                fi
            else
                return 1
            fi
        fi
    else
        return 1
    fi

    local -i address_type=99

    if [ ${#address} -eq 0 ]; then
        return 1 # invalid; address length is 0
    else
        # convert ipv4 hex address
        if [ ${#output} -eq 0 ]; then
            if [[ ${address} =~ ^((^0x{1}[0-9a-f]{8}|[0-9a-f]{8})$) ]]; then
                if [[ ${address} =~ ^0x ]]; then
                    output=${address:2:${#address}-2}
                else
                    output=${address}
                fi
            fi
        fi

        # convert ipv4 decimal address
        if [ ${#output} -eq 0 ]; then
            if [[ ${address} =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]){1}$ ]]; then
                printf -v output '%02x' ${address//\./\ }

            fi
        fi

        # convert ipv4 uint address
        if [ ${#output} -eq 0 ]; then
            if [[ ${address} =~ ^[0-9]+$ ]]; then
                if [ ${address} -ge 0 ] && [ ${address} -le ${IPV4_MAX_LONG} ]; then
                    printf -v output '%08x' $((10#${address}))
                fi
            fi
        fi

        # convert ipv4 binary address
        if [ ${#output} -eq 0 ]; then
            if [[ ${address//\./} =~ ^[0-1]+$ ]] && [[ ${#address} -eq 35 ]]; then
                local octet octets
                for octets in ${address//\./\ }; do
                    printf -v octet '%02x' $((2#${octets}))
                    output+=${octet}
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
                    output+=${octet}
                done
                unset -v octet octets
            fi
        fi

    fi

    # output valid address[/prefix] and return 0
    if [ ${#output} -eq 8 ]; then
        if [ ${#prefix} -gt 0 ]; then
            output+="/${prefix}"
        fi
        printf -v output "0x%s" ${output}

        local -l argv=($@)
        if [ "${argv[-1]}" == "global" ]; then
            unset -v ${FUNCNAME}_output
            printf -v ${FUNCNAME}_output "%s" ${output}
        else
            printf "%s" ${output}
        fi

        return 0
    else
        # invalid address, return 1
        return 1
    fi
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/prefix|mask] in octal (oct) form and return true, or output nothing and return false
#
# note: This function first converts ${input} to ipv4ToHex ${output} and then uses printf to convert to the proper format.
#
function ipv4ToOct() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l address prefix output

    # seperate input into address & prefix
    if ipv4ToHex ${input} global; then
        address=${ipv4ToHex_output}
        if [[ "${address}" == *"/"* ]]; then
            prefix=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ipv4Prefix ${prefix} oct global; then
                prefix=${ipv4Prefix_output}
            else
                return 1 # invalid prefix
            fi
        fi
    else
        return 1 # invalid address
    fi

    #printf -v output "%u.%u.%u.%u" $((2#${address:0:8})) $((2#${address:9:8})) $((2#${address:18:8})) $((2#${address:27:8})) # binary
    printf -v output "%04o.%04o.%04o.%04o" $((16#${address:2:2})) $((16#${address:4:2})) $((16#${address:6:2})) $((16#${address:8:2})) # hex
    if [ ${#prefix} -gt 0 ]; then
        output+="/${prefix}"
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

    return 0
}

#
# input ipv4 address[/prefix|mask] in binary, decimal, hexidecimal, octal, or uint
# output ipv4 address[/prefix|mask] in unsigned integer (uin) form and return true, or output nothing and return false
#
# note: This function first converts ${input} to ipv4ToHex ${output} and then uses printf to convert to the proper format.
#
function ipv4ToUint() {
    local -l input=${1}

    if [ ${#input} -le 0 ] || [ "${input}" == "global" ]; then
        return 1 # invalid input
    fi

    local -l address prefix output

    # seperate input into address & prefix
    if ipv4ToHex ${input} global; then
        address=${ipv4ToHex_output}
        if [[ "${address}" == *"/"* ]]; then
            prefix=${address##*/} # everything after /
            address=${address%%/*} # everything before /
            if ipv4Prefix ${prefix} uin global; then
                prefix=${ipv4Prefix_output}
            else
                return 1 # invalid prefix
            fi
        fi
    else
        return 1 # invalid address
    fi

    printf -v output "%u" ${address}
    if [ ${#prefix} -gt 0 ]; then
        output+="/${prefix}"
    fi

    local -l argv=($@)
    if [ "${argv[-1]}" == "global" ]; then
        unset -v ${FUNCNAME}_output
        printf -v ${FUNCNAME}_output "%s" ${output}
    else
        printf "%s" "${output}"
    fi

    return 0
}
