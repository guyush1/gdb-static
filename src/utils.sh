#!/bin/bash

GREEN="\033[0;32m"
BOLD="\033[1m"
RESET="\033[0m"

function print_centered() {
    # Print a string centered in the terminal.
    #
    # Parameters:
    # $1: string
    # $2: line width
    #
    # Returns:
    # 0: success

    local string="$1"
    local length=${#string}

    printf "%*s\n" $((($2 + length) / 2)) "$string"
}

function fancy_title() {
    # Print a fancy title.
    # The title is centered and surrounded by a line of dashes.
    #
    # Parameters:
    # $1: title
    #
    # Returns:
    # 0: success

    local title="$1"
    local length=80
    local maximum_title_length=60

    # Set color to green and bold
    tput setaf 2
    tput bold

    printf "%${length}s\n" | tr ' ' -

    # Split the title into words and print them centered
    IFS=' ' read -r -a words <<< "$title"

    line=""
    for word in "${words[@]}"; do
        if [[ ${#line} -eq 0 ]]; then
            line="$word"
        elif [[ $(( ${#line} + ${#word} + 1 )) -gt $maximum_title_length ]]; then
            print_centered "$line" "$length"
            line="$word"
        else
            line="$line $word"
        fi
    done

    # Print the last line
    if [[ ${#line} -gt 0 ]]; then
        print_centered "$line" "$length"
    fi

    printf "%${length}s\n" | tr ' ' -

    # Reset color and style
    tput sgr0
}
