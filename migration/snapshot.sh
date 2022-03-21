#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $SCRIPTDIR

# 1. Create Backup Repository
echo " "
echo "---Create Backup Repository---"
set +e
export ES_IP=`kubectl get svc -n kube-logging | grep elasticsearch | tr -s ' ' | cut -d ' ' -f3`

curl -XPUT "http://$ES_IP:9200/_snapshot/backups?pretty" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/backups"
  }
}
'

# 2. Create Snapshot Data
echo " "
echo "---Create Snapshot Data---"

curl -XPUT "http://$ES_IP:9200/_snapshot/backups/snapshot_1?wait_for_completion=true&pretty" -H 'Content-Type: application/json' -d'
{
  "indices": "logstash-*",
  "ignore_unavailable": true,
  "include_global_state": false
}
'

echo " "
echo "---Saving Snapshot Done---"

