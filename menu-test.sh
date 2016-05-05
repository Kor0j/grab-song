#!/bin/sh

tput civis
stty -echo

/bin/bash -c '

SELECTION_LINE="1"
SELECTION_LENGTH=""

arrowup="\[A"
arrowdown="\[B"
arrowright="\[C"

SUCCESS=0

while true; do

MENU_STRING="$(qdbus org.mpris.MediaPlayer2.* | grep "org.mpris.MediaPlayer2." | sed 's/org.mpris.MediaPlayer2.//')"

ENUM_TIC="1"
ENUM_MAX="$(printf "$MENU_STRING" | wc -w)"

MENU_PROPER_NAME=$(

while [ "$ENUM_TIC" -le "$ENUM_MAX" ]; do

eval MENU_ENTRY$ENUM_TIC="$ENUM_TIC"

printf "$(qdbus org.mpris.MediaPlayer2.$(printf "$MENU_STRING" | sed -n "$ENUM_TIC{p;q}")  /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Identity | sed "s#^#$(if [ "$SELECTION_LINE" = "$MENU_ENTRY${ENUM_TIC}" ]; then tput rev; else tput sgr0; fi)##")\n"

ENUM_TIC=$(($ENUM_TIC +1))

done

)

printf "$(tput cup 0 0)$(tput ed)$(eval "printf \"$MENU_PROPER_NAME\"")"

if [ "$SELECTION_LINE" -gt "$ENUM_MAX" ]; then
SELECTION_LINE="$ENUM_MAX"
fi
    
read -rsn3 -t 0.25 input

printf "$input" | grep "$arrowup"
if [ "$?" -eq $SUCCESS ]; then
    if [ "$SELECTION_LINE" -gt "1" ]; then
        ((SELECTION_LINE--))
    fi
fi

printf "$input" | grep "$arrowdown"
if [ "$?" -eq $SUCCESS ]; then
    if [ "$SELECTION_LINE" -lt "$ENUM_MAX" ]; then
        ((SELECTION_LINE++))
    fi
fi

printf "$input" | grep "$arrowright"
if [ "$?" -eq $SUCCESS ]; then
    break
fi

done

tput cup 0 0
tput ed
tput sgr0

printf "$(printf "$MENU_STRING" | sed -n "$SELECTION_LINE{p;q}")\n" | tee > test.txt

'
TESTVAR=$(eval "cat \"test.txt\"")
printf "$TESTVAR\n"

stty echo
tput cnorm
