#!/bin/sh

tput civis
stty -echo

export COREPROC="$$"

generate_settings()
{
printf "verbose=$VERBOSE\n" >> $SETTINGS_FILE
if [ -z "$PLAYER_SELECTION" ]; then break; else printf "last-used-player=$PLAYER_SELECTION\n" >> $SETTINGS_FILE; fi
printf "output-directory=$OUTPUT_DIR\n" >> $SETTINGS_FILE
printf "oneline=$ONELINE\n" >> $SETTINGS_FILE
printf 'oneliner-format= $a: $t - $i \n' >> $SETTINGS_FILE
printf "logging=$LOGGING\n" >> $SETTINGS_FILE
printf "log-directory=$LOG_DIR\n" >> $SETTINGS_FILE
printf "rm-output=$RM_OUTPUT\n" >> $SETTINGS_FILE
}

# Define a function for cleaning up temporary files.
save()
{
sed -i "/verbose=/ c\verbose=$VERBOSE" $SETTINGS_FILE
sed -i "/last-used-player=/ c\last-used-player=$PLAYER_SELECTION" $SETTINGS_FILE
sed -i "/output-directory=/ c\output-directory=$OUTPUT_DIR" $SETTINGS_FILE
sed -i "/oneline=/ c\oneline=$ONELINE" $SETTINGS_FILE
sed -i "/oneliner-format=/ c\oneliner-format=$ONELINER_FORMAT" $SETTINGS_FILE
sed -i "/logging=/ c\logging=$LOGGING" $SETTINGS_FILE
sed -i "/log-directory=/ c\log-directory=$LOG_DIR" $SETTINGS_FILE
sed -i "/rm-output=/ c\rm-output=$RM_OUTPUT" $SETTINGS_FILE
}

save_and_quit()
{
save
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

if [ -z "$CONFIG_DIR" ]; then CONFIG_DIR=${CONFIG_DIR-Config}; fi
if [ -z "$LOG_DIR" ]; then LOG_DIR=${LOG_DIR-Logs}; fi
if [ -z "$TMP_DIR" ]; then TMP_DIR=`mktemp -d /tmp/grab-song.XXXXXXXXXXX`; fi
if [ "$OUTPUT_DIR" = "" ]; then OUTPUT_DIR='Output'; fi
if [ "$SETTINGS_FILE" = "" ]; then SETTINGS_FILE="$CONFIG_DIR/settings.conf"; fi

# Make sure config directory is present
mkdir -p $CONFIG_DIR

# Generate a default config if not present
if [ ! -f $SETTINGS_FILE ]; then
    generate_settings
    save
fi

# Load stored settings, if any.
VERBOSE=${VERBOSE-$(cat $SETTINGS_FILE | grep "verbose=" | sed 's/verbose=//')}

PLAYER_SELECTION=${1-$(cat $SETTINGS_FILE | grep "last-used-player=" | sed 's/last-used-player=//')}

# Check if there's no player selection
if [ -z "$PLAYER_SELECTION" ]; then
    stty echo
    tput cnorm
    printf "Please specify a player and try again\n\n"
    sh check-media-players.sh
    printf "\n"
    exit
else break; fi

OUTPUT_DIR=${OUTPUT_DIR-$(cat $SETTINGS_FILE | grep "output-directory=" | sed 's/output-directory=//')}

ONELINE=${ONELINE-$(cat $SETTINGS_FILE | grep "oneline=" | sed 's/oneline=//')}
ONELINER_FORMAT=${ONELINER_FORMAT-$(cat $SETTINGS_FILE | grep "oneliner-format=" | sed 's/oneliner-format=//')}

LOGGING=${LOGGING-$(cat $SETTINGS_FILE | grep "logging=" | sed 's/logging=//')}
LOG_DIR=${LOG_DIR-$(cat $SETTINGS_FILE | grep "log-directory=" | sed 's/log-directory=//')}

RM_OUTPUT=${RM_OUTPUT-$(cat $SETTINGS_FILE | grep "rm-output=" | sed 's/rm-output=//')}

# Test to make sure everything is present in the settings file.
TEST_VERBOSE=$(cat $SETTINGS_FILE | grep "verbose=")
TEST_PLAYER_SELECTION=$(cat $SETTINGS_FILE | grep "last-used-player=")
TEST_OUTPUT_DIR=$(cat $SETTINGS_FILE | grep "output-directory=")
TEST_ONELINE=$(cat $SETTINGS_FILE | grep "oneline=")
TEST_ONELINER_FORMAT=$(cat $SETTINGS_FILE | grep "oneliner-format=")
TEST_LOGGING=$(cat $SETTINGS_FILE | grep "logging=")
TEST_LOG_DIR=$(cat $SETTINGS_FILE | grep "log-directory=")
TEST_RM_OUTPUT=$(cat $SETTINGS_FILE | grep "rm-output=")

if [ "$TEST_VERBOSE" = "" ]; then
printf "verbose=$VERBOSE\n" >> $SETTINGS_FILE
fi
if [ "$TEST_PLAYER_SELECTION" = "" ]; then
printf "last-used-player=$PLAYER_SELECTION\n\n" >> $SETTINGS_FILE
fi
if [ "$TEST_OUTPUT_DIR" = "" ]; then
printf "output-directory=$OUTPUT_DIR\n" >> $SETTINGS_FILE
fi
if [ "$TEST_ONELINE" = "" ]; then
printf "oneline=$ONELINE\n" >> $SETTINGS_FILE
fi
if [ "$TEST_ONELINER_FORMAT" = "" ]; then
printf "oneliner-format=$ONELINER_FORMAT\n" >> $SETTINGS_FILE
fi
if [ "$TEST_LOGGING" = "" ]; then
printf "logging=$LOGGING\n" >> $SETTINGS_FILE
fi
if [ "$TEST_LOG_DIR" = "" ]; then
printf "log-directory=$LOG_DIR\n" >> $SETTINGS_FILE
fi
if [ "$TEST_RM_OUTPUT" = "" ]; then
printf "rm-output=$RM_OUTPUT\n" >> $SETTINGS_FILE
fi

# Clean up validation variables
unset TEST_VERBOSE
unset TEST_PLAYER_SELECTION
unset TEST_OUTPUT_DIR
unset TEST_ONELINE
unset TEST_ONELINER_FORMAT
unset TEST_LOGGING
unset TEST_RM_OUTPUT

# Set defaults if settings aren't present.
if [ "$ONELINER_FORMAT" = "" ]; then ONELINER_FORMAT=' $a: $t - $i '; fi
if [ "$FIRSTRUN" = "" ]; then FIRSTRUN='true'; fi
if [ "$VERBOSE" = "" ]; then VERBOSE='true'; fi
if [ "$ONELINE" = "" ]; then ONELINE='false'; fi
if [ "$PLAYER_SELECTION" = "" ]; then PLAYER_SELECTION=''; fi
if [ "$LOGGING" = "" ]; then LOGGING='false'; fi
if [ "$RM_OUTPUT" = "" ]; then RM_OUTPUT='false'; fi

SONG_METADATA="$TMP_DIR/SongMetaData.txt"
SONG_TITLE="$OUTPUT_DIR/SongTitle.txt"
SONG_ARTIST="$OUTPUT_DIR/SongArtist.txt"
SONG_ALBUM="$OUTPUT_DIR/SongAlbum.txt"
SONG_ONELINER="$OUTPUT_DIR/SongInfo.txt"

LOG_DIR="Logs"
LOG_FILE="$LOG_DIR/$(date +'%F_%H-%M-%S.log')"
# Set up log directory.
if [ "$LOGGING" = "true" ]; then mkdir -p $LOG_DIR; fi

# Set up the locations of the output files.
mkdir -p $OUTPUT_DIR
touch $SONG_METADATA
touch $SONG_TITLE
touch $SONG_ARTIST
touch $SONG_ALBUM
touch $SONG_ONELINER

# Define some named pipes for the CUI.
export PLAYER_SELECTION_PIPE="$TMP_DIR/player-selection-pipe"
if [ ! -p $PLAYER_SELECTION_PIPE ]; then
mkfifo $PLAYER_SELECTION_PIPE
fi

export PLAYER_SELECTION_LONG_PIPE="$TMP_DIR/player-selection-long-pipe"
if [ ! -p $PLAYER_SELECTION_LONG_PIPE ]; then
mkfifo $PLAYER_SELECTION_LONG_PIPE
fi

export VERBOSE_PIPE="$TMP_DIR/verbose-pipe"
if [ ! -p $VERBOSE_PIPE ]; then
mkfifo $VERBOSE_PIPE
fi

export ONELINE_PIPE="$TMP_DIR/oneline-pipe"
if [ ! -p $ONELINE_PIPE ]; then
mkfifo $ONELINE_PIPE
fi

export LOGGING_PIPE="$TMP_DIR/logging-pipe"
if [ ! -p $LOGGING_PIPE ]; then
mkfifo $LOGGING_PIPE
fi

draw_contents()
{
# Help key.
printf "$(tput cup 0 0)$(tput ed)$(tput rev)$(tput bold) Q:$(tput sgr0)$(tput bold) Close. $(tput rev)$(tput bold) P:$(tput sgr0)$(tput bold) Select media player. $(tput rev)$(tput bold) V:$(tput sgr0)$(tput bold) Toggle verbosity. $(tput cup $(tput lines) 0)$(tput cuu1)Selected media player: $PLAYER_SELECTION_LONG\n$(tput rev)$(tput bold) M:$(tput sgr0)$(tput bold) Toggle oneliner mode. $(tput sgr0)$(tput rev)$(tput bold) L:$(tput sgr0)$(tput bold) Toggle track logging. $(tput sgr0)"

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
}

# Set current player variable for the UI.
PLAYER_SELECTION_LONG="$(qdbus org.mpris.MediaPlayer2.$PLAYER_SELECTION /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Identity)"

WINDOW_LINES_PREV="0"
WINDOW_COLS_PREV="0"
SONG_TITLE_VAR_PREV=""
SONG_ARTIST_VAR_PREV=""
SONG_ALBUM_VAR_PREV=""

# BEGIN MAIN LOOP
while true; do

# Check for MPRIS data update.
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
if [ "$SONG_TITLE_VAR" != "" ]; then
printf "$SONG_TITLE_VAR" > $SONG_TITLE
printf "$SONG_ARTIST_VAR" > $SONG_ARTIST
printf "$SONG_ALBUM_VAR" > $SONG_ALBUM
fi
else
# Same as above, except for oneline mode.
if [ "$SONG_TITLE_VAR" != "" ]; then
printf "$(eval "printf \"$ONELINER_FORMAT\"")" > $SONG_ONELINER
fi
fi

# Logging.
if [ "$LOGGING" = "true" ]; then

if [ "$SONG_TITLE_VAR" != "" ]; then
date +"[%H:%M:%S] $(eval "printf \"$ONELINER_FORMAT\"")" >> $LOG_FILE
fi

fi

fi

# Input handling
/bin/bash -c '
while true; do
read -rsn1 -t 0.1 input
if [ "$input" = "q" ] || [ "$input" = "Q" ]; then
    kill $COREPROC
    exit
fi
break
done
'

# Display help key and/or verbose if the terminal window is resized.
if [ "$WINDOW_LINES_PREV" -ne "$(tput lines)" ] || [ "$WINDOW_COLS_PREV" -ne "$(tput cols)" ] || [ "$SONG_TITLE_VAR_PREV" != "$SONG_TITLE_VAR" ] || [ "$SONG_ARTIST_VAR_PREV" != "$SONG_ARTIST_VAR" ] || [ "$SONG_ALBUM_VAR_PREV" != "$SONG_ALBUM_VAR" ]; then

draw_contents

WINDOW_LINES_PREV="$(tput lines)"
WINDOW_COLS_PREV="$(tput cols)"
SONG_TITLE_VAR_PREV="$SONG_TITLE_VAR"
SONG_ARTIST_VAR_PREV="$SONG_TITLE_VAR"
SONG_ALBUM_VAR_PREV="$SONG_TITLE_VAR"

fi

sleep 1

# END MAIN LOOP

trap save_and_quit EXIT INT TERM

done
