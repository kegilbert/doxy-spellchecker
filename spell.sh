#!/bin/bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ERRORS=0

# Loops use here strings to allow them to run in the main shell and modify the correct version of
# the error counter global variable
while read file; do
    echo "$file"
    res=$(awk '/\/\*\*/,/\*\//' "$file" | cut -d '/' -f2 | sed 's/0x[^ ]*//' | sed 's/[0-9]*//g')

    start_tokens=(  "/@code"
                    "/addtogroup"
                    "defgroup"
                    "<"
                    "()"
                 )

    end_tokens=(    "/@endcode"
                    "/\*"
                    ""
                    ">"
                    ""
               )

    formats=(   'strip_between'
                'strip_between'
                'strip_line'
                'strip_between_sameline'
                'strip_token'
            )

    # Stripping strings between tokens P1-P2 and P3-P4 inclusively ran into issues depending
    # on if the tokens were on the same line or not.
    #_________________________________________
    # Don't remove this P1 remove me P2
    # Keep me
    # P3
    #   Remove me too please
    # P4
    # Keep me too
    # Still here P1 But this shouldn't be P2
    #_________________________________________
    #
    # Opted for having two separate formats. In particular this formatting issue came up when
    # trying to strip the code segments and template type arguments between '<, >' as the multiline
    # sed command would strip the entire line, causing the removal string to span across the entire file
    # when trying to match the next end token (above format when stripping everything between P1 and P2
    # would end up with just "Don't remove this" and the rest of the file stripped).

    for ((i=0;i<${#start_tokens[@]};++i)); do
        filter=""
        if [[ "${formats[i]}" == 'strip_between' ]]; then
            filter=$(echo "$res" | sed ""${start_tokens[i]}"/,"${end_tokens[i]}"/d")
        elif [[ "${formats[i]}" == 'strip_between_sameline' ]]; then
            filter=$(echo "$res" | sed -e "s/"${start_tokens[i]}".*"${end_tokens[i]}"//")
        elif [[ "${formats[i]}" == 'strip_line' ]]; then
            filter=$(echo "$res" | sed "/"${start_tokens[i]}"/ d")
        elif [[ "${formats[i]}" == 'strip_token' ]]; then
            filter=$(echo "$res" | sed "s/"${start_tokens[i]}"//g")
        fi

        if [ "$filter" != "" ]; then
            res=$filter
        fi
    done

    if [ "${2:-}" == "-vv" ]; then
        echo "$res"
    fi

    prev_err=("")
    while read err; do
        if [ $(echo "$res" | grep "$err" | wc -l) -eq $(grep "$err" "$file" | wc -l) ]; then
            # Do not count all caps words as errors (RTOS, WTI, etc) or plural versions (APNs/MTD's)
            if ! [[ $err =~ ^[A-Z]+$ || $err =~ ^[A-Z]+s$ || $err =~ ^[A-Z]+\'s$ ]]; then

                # Disregard camelcase/underscored words. Hex was stripped at the beginning
                if ! echo "$err" | grep --quiet -E '[a-z]{1,}[A-Z]|_'; then

                    # The grep command to fetch the line numbers will report all instances, do not
                    # list repeated error words found from aspell in each file
                    if ! [[ ${prev_err[*]} =~ "$err" ]]; then
                        prev_err+=("$err")

                        if [ ${#prev_err[@]} -eq 2 ]; then
                            echo "================================="
                            echo "Errors: "
                        fi

                        while read ln; do
                            echo "$ln $err"
                            ERRORS=$((ERRORS + 1))
                        done <<< "$(grep -n "$err" "$file" | cut -d ' ' -f1)"
                    fi
                fi
            fi
        fi
    done <<< "$(echo "$res" | aspell list -C --ignore-case -p "$DIR"/ignore.en.pws --local-data-dir "$DIR")"

    if [ ${#prev_err[@]} -ne 1 ]; then
        echo "_________________________________"
    fi

done <<< "$(find "$1" -type d -iname "*target*" -prune -o -name '*.h' -print)"

echo "----------------------------------------------------------------------------------"
echo "Total Errors Found: $ERRORS"

if [ $ERRORS -ne 0 ]; then
    echo "If any of the failed words should be considered valid please add them to the ignore.en.pws file"\
         "found in tools/test/scripts/doxy-spellchecker between the _code_ and _doxy_ tags."
    exit 1
else
    exit 0
fi
