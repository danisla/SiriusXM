#!/usr/bin/env bash

if [[ ! $# -eq 4 ]]; then
  echo "USAGE: $0 <xm host> <channel ids> <es host> <es index>"
  exit 1
fi

XM_HOST=$1
CHAN_IDS=$2
ES_HOST=$3
ES_INDEX=$4

DEBUG=${DEBUG:-0}

function log {  
  if [[ $DEBUG -eq 1 ]]; then
    >&2 echo "`date`: ${1}"
  fi
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
  channel_number=$2
  for doc in $(jq -r -c .[] <<< ${DATA}); do
    ts=`jq -r -c ".timestamp" <<< $doc`
    id="${channel_number}_${ts}"
    doc=`jq -r -c ".channel_number=${channel_number}" <<< "${doc}"`
    req=`cat <<- EOF
{ "update" : { "_type": "events", "_id": "${id}", "doc_as_upsert": true }
EOF`
    echo $req
    echo `jq -r -c ".doc=${doc}|.doc_as_upsert=true" <<< {}`

  done
}

function process_meta() {
  DATA=$1
  for doc in $(jq -r -c ". | .[].cut" <<< ${DATA}); do
    artist=`jq -r -c ".artists[0].name" <<< ${doc}`
    title=`jq -r -c ".title" <<< ${doc}`
    album=`jq -r -c ".album.title" <<< ${doc}`
    album_details=`jq -r -c ".album" <<< ${doc}`
    album_details=`jq -r -c ".album_details=${album_details}" <<< {}`
    id=`echo "${artist} - ${title} - ${album}" | tr ' ' '_'`
    doc=`jq -r -c ".artist=\"${artist}\"|.title=\"${title}\"|.album=\"${album}\"" <<< {}`
    doc=`echo ${doc} ${album_details} | jq -r -c -s add`
    req=`cat <<- EOF
{ "update" : { "_type": "meta", "_id": "${id}", "doc_as_upsert": true }
EOF`
    echo $req
    echo `jq -r -c ".doc=${doc}|.doc_as_upsert=true" <<< {}`

  done
}

function bulk() {
  OUTPUT=`curl -s -XPOST ${ES_HOST}/${ES_INDEX}/_bulk --data-binary @- <<< "$1"`
  if [[ $? -ne 0 ]]; then
    log "Error running bulk insert"
    log "$1"
    log "$OUTPUT"
  fi
}

function rand_sleep() {
  sleep "0.$[ ( $RANDOM % 5 ) + 1 ]"
}

for channel_number in `tr , ' ' <<< $CHAN_IDS`; do
  OLD_IFS=${IFS}
  IFS=$'\n'

  url="${XM_HOST}/now_playing/${channel_number}"

  META=`get_url ${url}?t=detail`
  DATA=`get_url ${url}`

  if [[ ! -z "${DATA}" ]]; then
    bulk "`process \"${DATA}\" $channel_number`"
    bulk "`process_meta \"${META}\"`"
  else
    log "WARN: No data returned"
  fi
  IFS=${OLD_IFS}

  rand_sleep
done
