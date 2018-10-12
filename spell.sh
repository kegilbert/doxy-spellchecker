#!/bin/bash

find "$1" -name '*.h' | while read line; do
    echo "$line"
    echo "Classes: "

    cat "$line" | grep ^class | cut -d ' ' -f2 | while read class; do
        echo -e "\t- $class"
    done

    res=$(sed -n '\/\*\*/,/\*\// p' "$line")

    start_tokens=(  "/@code"
                    "/addtogroup"
                    "\@tparam"
                    "\@param"
                 )

    end_tokens=(    "/@endcode"
                    "/\*\/"
                    ""
                    ""
               )

    formats=(   'strip_between'
                'strip_between'
                'strip_token'
                'strip_token'
            )

    for ((i=0;i<${#start_tokens[@]};++i)); do
        if [[ "${formats[i]}" == 'strip_between' ]]; then
            filter=$(echo "$res" | sed ""${start_tokens[i]}"/,"${end_tokens[i]}"/d")

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

    if [ "$2" == "-v" ]; then
        echo "$res"
    fi

    echo "================================="
    echo "Errors: "
    echo "$res" | aspell list -C
    echo "_________________________________"

done
