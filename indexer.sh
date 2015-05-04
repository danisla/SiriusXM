#!/usr/bin/env bash

if [[ ! $# -eq 4 ]]; then
  echo "USAGE: $0 <xm host> <channel ids> <es host> <es index>"
  exit 1
fi

XM_HOST=$1
CHAN_IDS=$2
ES_HOST=$3
ES_INDEX=$4

function log {
  >&2 echo "`date`: ${1}"
}

function get_url() {
  url=$1
  log "INFO: GET: ${url}"

  DATA=$(curl -sf ${url})
  if [[ ! $? -eq 0 ]]; then
    log "ERROR: Failed to GET: ${url}"
    echo ""
  else
    echo $DATA
  fi
}

function process() {
  DATA=$1
  DATA_DETAILS=$2
  channel_number=$3
  for doc in $(jq -r -c .[] <<< ${DATA}); do
    ts=`jq -r -c ".timestamp" <<< $doc`
    id="${channel_number}_${ts}"
    doc=`jq -r -c ".channel_number=${channel_number}|.details=${DATA_DETAILS}" <<< "${doc}"`
    req=`cat <<- EOF
{ "update" : { "_type": "events", "_id": "${id}", "doc_as_upsert": true }
EOF`
    echo $req
    echo `jq -r -c ".doc=${doc}|.doc_as_upsert=true" <<< {}`
  done
}

function bulk() {
  curl -sf -XPOST ${ES_HOST}/${ES_INDEX}/_bulk --data-binary @- <<< "$1" >/dev/null
}

function rand_sleep() {
  sleep "0.$[ ( $RANDOM % 5 ) + 1 ]"
}

for channel_number in `tr , ' ' <<< $CHAN_IDS`; do
  OLD_IFS=${IFS}
  IFS=$'\n'

  url="${XM_HOST}/now_playing/${channel_number}"

  DATA_DETAILS=`get_url ${url}?t=detail`
  DATA=`get_url ${url}`

  if [[ ! -z "${DATA}" ]]; then
    bulk "`process \"${DATA}\" \"${DATA_DETAILS}\" $channel_number`"
  fi
  IFS=${OLD_IFS}

  rand_sleep
done
