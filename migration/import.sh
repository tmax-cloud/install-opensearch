#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $SCRIPTDIR

# 1. Create Backup Repository
echo " "
echo "---Create Backup Repository---"
set +e
export OS_IP=`kubectl get svc -n kube-logging | grep opensearch | tr -s ' ' | cut -d ' ' -f3`

curl -u admin:admin -k -XPUT https://$OS_IP:9200/_snapshot/backups -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/backups"
  }
}
'

# 2. Import Snapshot Data
echo " "
echo "---Import Snapshot Data---"

curl -u admin:admin -k -XPOST https://$OS_IP:9200/_snapshot/backups/snapshot_1/_restore

echo " "
echo "---Import Snapshot Done---"

