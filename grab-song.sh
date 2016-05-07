#!/bin/sh

tput civis
stty -echo

# cd "${0%/*}"

# Define some defaults.
TMP_DIR=`mktemp -d /tmp/$0.XXXXXXXXXXX`
CONFIG_DIR=${CONFIG_DIR-Config}
SETTINGS_FILE="$CONFIG_DIR/settings.conf"
ONELINER_FORMAT=' $a: $t - $i '
OUTPUT_DIR='Output'

mkdir -p $CONFIG_DIR
if [ ! -f $SETTINGS_FILE ]; then
    echo "verbose=false" >> $SETTINGS_FILE
    echo "last-used-player=" >> $SETTINGS_FILE
    echo "output-directory=$OUTPUT_DIR" >> $SETTINGS_FILE
    echo "oneline=false" >> $SETTINGS_FILE
    echo 'oneliner-format= $a: $t - $i ' >> $SETTINGS_FILE
    echo "rm-output=$RM_OUTPUT" >> $SETTINGS_FILE
fi

# Load stored settings.
VERBOSE=${VERBOSE-$(cat $SETTINGS_FILE | grep "verbose=" | sed 's/verbose=//')}

PLAYER_SELECTION=${1-$(cat $SETTINGS_FILE | grep "last-used-player=" | sed 's/last-used-player=//')}

OUTPUT_DIR=${OUTPUT_DIR-$(cat $SETTINGS_FILE | grep "output-directory=" | sed 's/output-directory=//')}

ONELINE=${ONELINE-$(cat $SETTINGS_FILE | grep "oneline=" | sed 's/oneline=//')}
ONELINER_FORMAT=${ONELINER_FORMAT-$(cat $SETTINGS_FILE | grep "oneliner-format=" | sed 's/oneliner-format=//')}

RM_OUTPUT=${RM_OUTPUT-$(cat $SETTINGS_FILE | grep "rm-output=" | sed 's/rm-output=//')}

echo $RM_OUTPUT

# Set up the locations of the output files.
SONG_METADATA="$TMP_DIR/SongMetaData.txt"
SONG_TITLE="$OUTPUT_DIR/SongTitle.txt"
SONG_ARTIST="$OUTPUT_DIR/SongArtist.txt"
SONG_ALBUM="$OUTPUT_DIR/SongAlbum.txt"
SONG_ONELINER="$OUTPUT_DIR/SongInfo.txt"

# Trust me.
SELECTION_MENU_ACTIVE="false"

# Make sure that subshells can understand the parent script.
export TMP_DIR
export VERBOSE
printf "$VERBOSE" > $TMP_DIR/temp_verbose
export PLAYER_SELECTION
export SELECTION_MENU_ACTIVE
printf "$PLAYER_SELECTION" > $TMP_DIR/temp_player_selection
printf "$SELECTION_MENU_ACTIVE" > $TMP_DIR/temp_selection_menu_active
export ONELINE
printf "$ONELINE" > $TMP_DIR/temp_oneline
export coreproc="$$"
export SONG_METADATA

# Set current player variable for the UI.
PLAYER_SELECTION_LONG="$(qdbus org.mpris.MediaPlayer2.$PLAYER_SELECTION /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Identity)"
export PLAYER_SELECTION_LONG
printf "$PLAYER_SELECTION_LONG" > $TMP_DIR/temp_player_selection_long

# Make sure that the files and folders actually exist.
mkdir -p $OUTPUT_DIR
touch $SONG_METADATA
touch $SONG_TITLE
touch $SONG_ARTIST
touch $SONG_ALBUM
touch $SONG_ONELINER

# Test to make sure everything is present in the settings file.
TEST_VERBOSE=$(cat $SETTINGS_FILE | grep "verbose=")
TEST_PLAYER_SELECTION=$(cat $SETTINGS_FILE | grep "last-used-player=")
TEST_OUTPUT_DIR=$(cat $SETTINGS_FILE | grep "output-directory=")
TEST_ONELINE=$(cat $SETTINGS_FILE | grep "oneline=")
TEST_ONELINER_FORMAT=$(cat $SETTINGS_FILE | grep "oneliner-format=")
TEST_RM_OUTPUT=$(cat $SETTINGS_FILE | grep "rm-output=")

if [ "$TEST_VERBOSE" = "" ]; then
echo "verbose=$VERBOSE" >> $SETTINGS_FILE
fi
if [ "$TEST_PLAYER_SELECTION" = "" ]; then
echo "last-used-player=$PLAYER_SELECTION" >> $SETTINGS_FILE
fi
if [ "$TEST_OUTPUT_DIR" = "" ]; then
echo "output-directory=$OUTPUT_DIR" >> $SETTINGS_FILE
fi
if [ "$TEST_ONELINE" = "" ]; then
echo "oneline=$ONELINE" >> $SETTINGS_FILE
fi
if [ "$TEST_ONELINER_FORMAT" = "" ]; then
echo "oneliner-format=$ONELINER_FORMAT" >> $SETTINGS_FILE
fi
if [ "$TEST_RM_OUTPUT" = "" ]; then
echo "rm-output=$RM_OUTPUT" >> $SETTINGS_FILE
fi

# Clean up validation variables
unset TEST_VERBOSE
unset TEST_PLAYER_SELECTION
unset TEST_OUTPUT_DIR
unset TEST_ONELINE
unset TEST_ONELINER_FORMAT
unset TEST_RM_OUTPUT

# Define a function for cleaning up temporary files.
save_and_clean()
{

sed -i "/verbose=/ c\verbose=$VERBOSE" $SETTINGS_FILE
sed -i "/last-used-player=/ c\last-used-player=$PLAYER_SELECTION" $SETTINGS_FILE
sed -i "/output-directory=/ c\output-directory=$OUTPUT_DIR" $SETTINGS_FILE
sed -i "/oneline=/ c\oneline=$ONELINE" $SETTINGS_FILE
sed -i "/oneliner-format=/ c\oneliner-format=$ONELINER_FORMAT" $SETTINGS_FILE
sed -i "/rm-output=/ c\rm-output=$RM_OUTPUT" $SETTINGS_FILE

rm -r $TMP_DIR

if $RM_OUTPUT; then
rm -r $OUTPUT_DIR
fi
kill $(jobs -p)
stty echo
tput cnorm
reset
exit 
}

media_player_menu()
{
# BEGIN PLAYER SELECTION MENU
/bin/bash -c '

SELECTION_LINE="1"

arrowup="\[A"
arrowdown="\[B"
arrowright="\[C"

SUCCESS=0

# Get the list of available players.
while true; do

MENU_STRING="$(qdbus org.mpris.MediaPlayer2.* | grep "org.mpris.MediaPlayer2." | sed 's/org.mpris.MediaPlayer2.//')"

# Enumerate the menu entries.
ENUM_TIC="1"
ENUM_MAX="$(printf "$MENU_STRING" | wc -w)"

MENU_PROPER_NAME=$(

while [ "$ENUM_TIC" -le "$ENUM_MAX" ]; do

eval MENU_ENTRY$ENUM_TIC="$ENUM_TIC"

# Populate the menu.
printf "$(qdbus org.mpris.MediaPlayer2.$(printf "$MENU_STRING" | sed -n "$ENUM_TIC{p;q}")  /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Identity | sed "s#^#$(if [ "$SELECTION_LINE" = "$MENU_ENTRY${ENUM_TIC}" ]; then tput rev; else tput sgr0; fi)##")$(tput sgr0)\n"

ENUM_TIC=$(($ENUM_TIC +1))

done

)

# Display the menu.
tput cup 0 0
tput ed
printf "$(tput cup $(tput lines) 0)$(tput bold)$(tput rev) \u21E7 $(tput sgr0)$(tput bold) Move up. $(tput rev) \u21E9 $(tput sgr0)$(tput bold) Move down. $(tput rev) \u21E8 $(tput sgr0)$(tput bold) Make selection. $(tput sgr0)"
printf "$(tput cup 0 0)$(tput bold)Please select a media player: \n$(tput sgr0)$(eval "printf \"$MENU_PROPER_NAME\"")"

if [ "$SELECTION_LINE" -gt "$ENUM_MAX" ]; then
SELECTION_LINE="$ENUM_MAX"
fi

# Scan for input, and define some controls.    
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

tput cup 1 0
tput ed
tput sgr0

PLAYER_SELECTION="$(printf "$(printf "$MENU_STRING" | sed -n "$SELECTION_LINE{p;q}")\n")" 
printf "$PLAYER_SELECTION" > $TMP_DIR/temp_player_selection

PLAYER_SELECTION_LONG="$(qdbus org.mpris.MediaPlayer2.$PLAYER_SELECTION /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Identity)"
printf "$PLAYER_SELECTION_LONG" > $TMP_DIR/temp_player_selection_long

exit
'
# END PLAYER SELECTION MENU
}

# Prevent 'qdbus' overflows by employing a tic system.
UPDATE_TIC="10"
UPDATE_TIC_MAX="10"

# BEGIN MAIN LOOP
while true; do

# Clear the window.
tput cup 0 0
tput ed

# Display help key.
printf "$(tput cup 0 0)$(tput rev)$(tput bold) Q:$(tput sgr0)$(tput bold) Close. $(tput rev)$(tput bold) P:$(tput sgr0)$(tput bold) Select media player. $(tput rev)$(tput bold) V:$(tput sgr0)$(tput bold) Toggle verbosity. $(tput cup $(tput lines) 0)$(tput cuu1)Selected media player: $PLAYER_SELECTION_LONG\n$(tput rev)$(tput bold) M:$(tput sgr0)$(tput bold) Toggle oneliner mode. $(tput sgr0)"

# Check for MPRIS data update.

if [ "$UPDATE_TIC" -ge "$UPDATE_TIC_MAX" ]; then
if [ "$(qdbus org.mpris.MediaPlayer2.$PLAYER_SELECTION /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Metadata)" != "$(cat $SONG_METADATA)" ]; then

qdbus org.mpris.MediaPlayer2.$PLAYER_SELECTION /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Metadata > $SONG_METADATA

# If no album art is found, use generic image instead.
if grep -q "mpris:artUrl:" $SONG_METADATA; then

SONG_ART="$(cat $SONG_METADATA | grep "mpris:artUrl:" | sed 's/mpris:artUrl: //' | sed "s/%20/ /g")"
convert "$SONG_ART" -resize 500x500! $OUTPUT_DIR/AlbumArt.jpg &>/dev/null

else

convert Images/NoArt.* -resize 500x500! $OUTPUT_DIR/AlbumArt.jpg &>/dev/null

fi
# Edit the junk out of the MPRIS data.
SONG_TITLE_VAR="$(cat $SONG_METADATA | grep "xesam:title:" | sed 's/xesam:title: //')"
SONG_ARTIST_VAR="$(cat $SONG_METADATA | grep "xesam:artist:" | sed 's/xesam:artist: //')"
SONG_ALBUM_VAR="$(cat $SONG_METADATA | grep "xesam:album:" | sed 's/xesam:album: //')"

t="$SONG_TITLE_VAR"
a="$SONG_ARTIST_VAR"
i="$SONG_ALBUM_VAR"

if [ "$ONELINE" = "false" ]; then
# Save the title, artist, and album data as individual text files.
printf "$SONG_TITLE_VAR" > $SONG_TITLE
printf "$SONG_ARTIST_VAR" > $SONG_ARTIST
printf "$SONG_ALBUM_VAR" > $SONG_ALBUM
else
# Same as above, except for oneline mode.
printf "$(eval "printf \"$ONELINER_FORMAT\"")" > $SONG_ONELINER
fi

fi

UPDATE_TIC="0"

fi

# Verbosity.
if [ "$VERBOSE" = "true" ]; then

tput cup 1 0

printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =

if [ "$ONELINE" = "false" ]; then

printf "Title: $SONG_TITLE_VAR\n\nArtist: $SONG_ARTIST_VAR\n\nAlbum: $SONG_ALBUM_VAR\n"

else

printf "$(eval "printf \"$ONELINER_FORMAT\"")\n"

fi

printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =

fi

# BEGIN INPUT LOOP
if [ "$SELECTION_MENU_ACTIVE" = "true" ]; then
    media_player_menu
    SELECTION_MENU_ACTIVE="false"
    printf "$SELECTION_MENU_ACTIVE" > $TMP_DIR/temp_selection_menu_active
fi


/bin/bash -c '

while true; do

read -rsn1 -t 0.1 input

if [ "$input" = "p" ] || [ "$input" = "P" ]; then
    SELECTION_MENU_ACTIVE="true"
    printf "$SELECTION_MENU_ACTIVE" > $TMP_DIR/temp_selection_menu_active
    sleep 0.1    
fi


if [ "$input" = "q" ] || [ "$input" = "Q" ]; then
    kill $coreproc
    exit
fi

if [ "$input" = "m" ] || [ "$input" = "M" ]; then
    if [ "$ONELINE" = "false" ]; then 
        ONELINE="true" ; 
    else 
        ONELINE="false" ; 
    fi 
    printf "" > $SONG_METADATA
    printf "$ONELINE" > $TMP_DIR/temp_oneline
    sleep 0.1    
fi

if [ "$input" = "v" ] || [ "$input" = "V" ]; then
    if [ "$VERBOSE" = "false" ]; then
        VERBOSE="true" ;
    else
        VERBOSE="false" ;
    fi
    printf "$VERBOSE" > $TMP_DIR/temp_verbose
    sleep 0.1
fi
break
done

exit
'

VERBOSE="$(cat $TMP_DIR/temp_verbose)" 
ONELINE="$(cat $TMP_DIR/temp_oneline)"
PLAYER_SELECTION="$(cat $TMP_DIR/temp_player_selection)"
PLAYER_SELECTION_LONG="$(cat $TMP_DIR/temp_player_selection_long)" 
SELECTION_MENU_ACTIVE="$(cat $TMP_DIR/temp_selection_menu_active)"
# END INPUT LOOP

UPDATE_TIC=$(($UPDATE_TIC +1))

# END MAIN LOOP

trap save_and_clean EXIT INT TERM

done
