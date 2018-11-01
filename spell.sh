#!/bin/bash

find "$1" -type d -iname "*target*" -prune -o -name '*.h' -print | while read file; do
    echo "$file"
    res=$(awk '/\/\*\*/,/\*\//' "$file" | cut -d '/' -f2 | sed 's/[0-9]*//g')

    if [[ $2 == -v*  ]]; then
        echo "Classes: "
    fi

    # Handle variable class defition syntax:
    #   - class Test;
    #   - class Test {....
    #   - class Test : Inherit...
    #   - class Test:Inhereit...
    #   - class Test<....>
    cat "$file" | grep ^class |                                         \
    cut -d ' ' -f2 |cut -d ':' -f1 | cut -d ';' -f1 | cut -d '<' -f1 |  \
    sed 's/[0-9]*//g' | while read class; do

        if [[ $2 == -v*  ]]; then
            echo "$class"
        fi

        grep $class ignore.en.pws > /dev/null
        if [ $? -ne 0 ]; then
            echo $class >> ignore.en.pws
        fi
    done

    if [[ $2 == -v*  ]]; then
        echo "+++++++++++++++"
    fi

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
        if [[ "${formats[i]}" == 'strip_between' ]]; then
            filter=$(echo "$res" | sed ""${start_tokens[i]}"/,"${end_tokens[i]}"/d")

            if [ "$filter" != "" ]; then
                res=$filter
            fi
        elif [[ "${formats[i]}" == 'strip_between_sameline' ]]; then
            filter=$(echo "$res" | sed -e "s/"${start_tokens[i]}".*"${end_tokens[i]}"//")

            if [ "$filter" != "" ]; then
                res=$filter
            fi
        elif [[ "${formats[i]}" == 'strip_line' ]]; then
            filter=$(echo "$res" | sed "/"${start_tokens[i]}"/ d")

            if [ "$filter" != "" ]; then
                res=$filter
            fi
        elif [[ "${formats[i]}" == 'strip_token' ]]; then
            filter=$(echo "$res" | sed "s/"${start_tokens[i]}"//g")
            if [ "$filter" != "" ]; then
                res=$filter
            fi
        fi
    done

    if [ "$2" == "-vv" ]; then
        echo "$res"
    fi

    echo "================================="
    echo "Errors: "

    prev_err=()
    echo "$res" | aspell list -C -p ./ignore.en.pws --local-data-dir . | while read err; do
        if [ $(echo "$res" | grep "$err" | wc -l) -eq $(grep "$err" "$file" | wc -l) ]; then
            # Do not count all caps words as errors (RTOS, WTI, etc) or plural versions (APNs)
            if ! [[ $err =~ ^[A-Z]+$ || $err =~ ^[A-Z]+s$ ]]; then

                # Disregard camelcase/underscored words or hex values
                echo "$err" | grep -E '[a-z]{1,}[A-Z]|_|0x' > /dev/null
                if [ $? -ne 0 ]; then
                    # The grep command to fetch the line numbers will report all instances, do not
                    # list repeated error words found from aspell in each file
                    if ! [[ ${prev_err[*]} =~ "$err" ]]; then
                        prev_err+="$err"
                        grep -nw "$err" "$file" | cut -d ' ' -f1 | while read ln; do
                            echo "$ln $err"
                            let "total_err++"
                        done
                    fi
                fi
            fi
        fi
    done
    echo "_________________________________"
done
