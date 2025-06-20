#!/bin/bash
# -----------
# Description
# -----------
# This script has been designed to run on the Synology NAS server and be configured to run as a
#   scheduled task to look for and upload CSV files to an FTP server
# The configuration and project setup for this script is defined in the separate, config file that
#   needs to be placed besides this script. An example config file can be found in this repo, and
#   the one that contains the secrets is currently stored in 1Password.

# Load the configuration and projects setup
# -----------------------------------------
source ./config

# some files might not be available until a certain time of the day
CURRENT_HOUR=`date +%H`
# failures: will be storing information on the projects that failed processing
failures=()
# count: will help inform on the outcome of the script at the end of the processing
count=0


# Processing
# ----------
for project in "${FTP_PROJECTS[@]}"; do
    ((count++))

    # unpack the configuration variables
    config=(${project//;\ / })
    folder=${config[0]}
    id="${config[1]}"
    credentials="${config[2]}"

    # check if config specs have been parsed correctly or skip this config
    if [ -z "${folder}" ] || [ -z "${id}" ] || [ -z "${credentials}" ]; then
        failures+=("[${count}/${#FTP_PROJECTS[@]}] Bad config: ${config}")
        continue
    fi


    # Setup file paths
    # ----------------
    # IMPORTANT: to have the script work in PRODUCTION:
    # - make sure that the DEVELOPMENT_MODE flag is set to false (boolean)
    # - the script will automatically detect if it's running on Linux
    if [["$CURRENT_OS" == 'Linux' ]] && [ "$DEVELOPMENT_MODE" = false ]; then
        dayahead_template="/volume1/Teletrans/${folder}/%Y%m%d_DAYAHEAD_${id}_00.csv"
        dayahead_path=$(date --date="next day" +"$dayahead_template")

        intraday_template="/volume1/Teletrans/${folder}/%Y%m%d_INTRADAY_${id}_%H.csv"
        intraday_path=$(date --date="next hour" +"$intraday_template")
    elif [ "$DEVELOPMENT_MODE" = true ]; then
        dayahead_template="${DEVELOPMENT_FOLDER}/test-data/${folder}/%Y%m%d_DAYAHEAD_${id}_00.csv"
        [[ "$CURRENT_OS" == 'Darwin' ]] && dayahead_path=$(date -v+1d +"$dayahead_template")
        [[ "$CURRENT_OS" == 'Linux' ]] && dayahead_path=$(date --date="next day" +"$dayahead_template")
        cp "${DEVELOPMENT_FOLDER}/test-data/dayahead.csv" "$dayahead_path"

        intraday_template="${DEVELOPMENT_FOLDER}/test-data/${folder}/%Y%m%d_INTRADAY_${id}_%H.csv"
        [[ "$CURRENT_OS" == 'Darwin' ]] && intraday_path=$(date -v+1H +"$intraday_template")
        [[ "$CURRENT_OS" == 'Linux' ]] && intraday_path=$(date --date="next hour" +"$intraday_template")
        cp "${DEVELOPMENT_FOLDER}/test-data/intraday.csv" "$intraday_path"
    fi


    # Day Ahead
    # ---------
    # check if the file exists and keep track if it doesn't
    if ! test -f "$dayahead_path"; then
        # day ahead files are only available starting with 9:00 AM
        # there's no need to trigger notifications earlier, as this test is to be expected to fail
        if (( CURRENT_HOUR >= 9 )); then
            failures+=("[${count}/${#FTP_PROJECTS[@]}] Missing file for ${folder}: ${dayahead_path}")
        fi
    else
        # only move forward if the script is running on the server
        if [[ "$CURRENT_OS" != 'Darwin' ]]; then
            # attempt the file upload
            post=$(curl -u "$credentials" "$FTP_EXTERNAL_PATH" -T "$dayahead_path")

            # report back if it doesn't
            if [[ $post =~ "Error" ]] || [[ $post =~ "error" ]] || [[ $post =~ "cannot" ]] || [[ $post =~ "failed" ]]; then
                failures+=("[${count}/${#FTP_PROJECTS[@]}] Failed upload for ${folder}: ${dayahead_path}. Output: ${post}")
            fi
        fi
    fi

    # Intra Day
    # ---------
    # check if the file exists and keep track if it doesn't
    if ! test -f "$intraday_path"; then
        failures+=("[${count}/${#FTP_PROJECTS[@]}] Missing file for ${folder}: ${intraday_path}")
    else
        # only move forward if the script is running on the server
        if [[ "$CURRENT_OS" != 'Darwin' ]]; then
            # attempt the file upload
            post=$(curl -u "$credentials" "$FTP_EXTERNAL_PATH" -T "$intraday_path")

            # report back if it doesn't
            if [[ $post =~ "Error" ]] || [[ $post =~ "error" ]] || [[ $post =~ "cannot" ]] || [[ $post =~ "failed" ]]; then
                failures+=("[${count}/${#FTP_PROJECTS[@]}] Failed upload for ${folder}: ${intraday_path}. Output: ${post}")
            fi
        fi
    fi
done


# Report on issues
# ----------------
# assembling the notification payload
if (( ${#failures[@]} )); then
    priority="1"
    title="🔴 ${#failures[@]} failures for the ${count} registered projects."
    message="Here is a summary of the failure(s):\n\n"

    # compile a bulleted list of errors
    for failure in "${failures[@]}"; do
        message+="- ${failure}\n"
    done
else
    priority="0"
    title="🟢 All ${count} projects have been processed successfully."
    message="Nothing to see here, move along."
fi

# Fix for Pushover not supporting regular new line breaks
# - ref: https://support.pushover.net/i76-can-support-for-br-be-added
message=${message//'\n'/
}

for pushover_config in "${PUSHOVER_CONFIGS[@]}"; do
  credential=(${pushover_config//,/})
  user=${credential[0]}
  token="${credential[1]}"

  # check if config specs have been parsed correctly or skip this config
  if [ -n "${user}" ] && [ -n "${token}" ]; then
    # Trigger a normal priority notification
    curl -s \
      -F "token=${token}" \
      -F "user=${user}" \
      -F "priority=${priority}" \
      -F "title=${title}" \
      -F "message=${message}" \
      "$PUSHOVER_URL"
  fi
done

