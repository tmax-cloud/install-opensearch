#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $SCRIPTDIR

set +e
export IS_PG=`grep -r 'initContainer' ./02_opensearch-dashboards.yaml`

if [ $RS_PLUGIN == "true" ]; then
  sed -i 's/#{RS_PLUGIN_INITCONTAINER}/initContainers: \n      - name: install-plugins \n        image: docker.io\/tmaxcloudck\/{PG_IMAGE_PATH} \n        command: ["sh", "-c", "cp -r \/workspace\/* \/plugins"] \n        volumeMounts: \n        - name: install-plugin-volume \n          mountPath: \/plugins/g' 02_opensearch-dashboards.yaml
  sed -i 's/#{RS_PLUGIN_VOLUMEMOUNT}/- name: install-plugin-volume \n          mountPath: \/plugins/g' 02_opensearch-dashboards.yaml
  sed -i 's/#{RS_PLUGIN_VOLUME}/- name: install-plugin-volume\n        emptyDir: {}/g' 02_opensearch-dashboards.yaml
  sed -i 's/#{RS_PLUGIN_SETTING}/ls \/plugins\/*.zip | while read file; do \/usr\/share\/opensearch-dashboards\/bin\/opensearch-dashboards-plugin install file:\/\/$file; done/g' 02_opensearch-dashboards.yaml
  sed -i 's/#{RS_PLUGIN_INGRESS}/- host: rightsizing.{CUSTOM_DOMAIN_NAME} \n    http: \n      paths: \n      - backend: \n          service: \n            name: rightsizing-api-server-svc \n            port: \n              number: 8000 \n        path: \/ \n        pathType: Prefix/#{RS_PLUGIN_INITCONTAINER}/g' 02_opensearch-dashboards.yaml
elif [[ "$IS_PG" == *"initContainer"* ]]; then
  sed -i 's/initContainers:/#{RS_PLUGIN_INITCONTAINER}/g' 02_opensearch-dashboards.yaml
  sed -i '39,44d' 02_opensearch-dashboards.yaml
  sleep 1s
  sed -i 's/- name: install-plugin-volume /#{RS_PLUGIN_VOLUMEMOUNT}/g' 02_opensearch-dashboards.yaml
  sed -i '78d' 02_opensearch-dashboards.yaml
  sleep 1s
  sed -i '98s/.*/      #{RS_PLUGIN_VOLUME}/g' 02_opensearch-dashboards.yaml
  sed -i '99d' 02_opensearch-dashboards.yaml
  sleep 1s
  sed -i '144s/.*/    #{RS_PLUGIN_SETTING}/g' 02_opensearch-dashboards.yaml
  sed -i '204s/.*/  #{RS_PLUGIN_INGRESS}/g' 02_opensearch-dashboards.yaml
  sed -i '205,213d' 02_opensearch-dashboards.yaml
fi

