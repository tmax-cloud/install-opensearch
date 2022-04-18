#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $SCRIPTDIR

# Apply configuration
source ./opensearch.config

echo "RS_PLUGIN = $RS_PLUGIN"
echo "PG_IMAGE_PATH = $PG_IMAGE_PATH"
echo "OS_VERSION = $OS_VERSION"
echo "DASHBOARD_VERSION = $DASHBOARD_VERSION"
echo "HYPERAUTH_URL = $HYPERAUTH_URL"
echo "DASHBOARD_CLIENT_SECRET = $DASHBOARD_CLIENT_SECRET"
echo "CUSTOM_DOMAIN_NAME = $CUSTOM_DOMAIN_NAME"
echo "FLUENTD_VERSION = $FLUENTD_VERSION"
echo "BUSYBOX_VERSION = $BUSYBOX_VERSION"

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
if [ $STORAGECLASS_NAME != "{STORAGECLASS_NAME}" ]; then
  sed -i 's/{STORAGECLASS_NAME}/'${STORAGECLASS_NAME}'/g' 01_opensearch.yaml
  echo "STORAGECLASS_NAME = $STORAGECLASS_NAME"
else
  sed -i 's/storageClassName: {STORAGECLASS_NAME}//g' 01_opensearch.yaml
  echo "STORAGECLASS_NAME = default-storage-class"
fi
if [ $REGISTRY != "{REGISTRY}" ]; then
  echo "REGISTRY = $REGISTRY"
fi

sed -i 's/{BUSYBOX_VERSION}/'${BUSYBOX_VERSION}'/g' 01_opensearch.yaml
sed -i 's/{OS_VERSION}/'${OS_VERSION}'/g' 01_opensearch.yaml
sed -i 's/{HYPERAUTH_URL}/'${HYPERAUTH_URL}'/g' 01_opensearch.yaml
sed -i 's/{DASHBOARD_VERSION}/'${DASHBOARD_VERSION}'/g' 02_opensearch-dashboards.yaml
sed -i 's/{PG_IMAGE_PATH}/'${PG_IMAGE_PATH}'/g' 02_opensearch-dashboards.yaml
sed -i 's/{HYPERAUTH_URL}/'${HYPERAUTH_URL}'/g' 02_opensearch-dashboards.yaml
sed -i 's/{DASHBOARD_CLIENT_SECRET}/'${DASHBOARD_CLIENT_SECRET}'/g' 02_opensearch-dashboards.yaml
sed -i 's/{CUSTOM_DOMAIN_NAME}/'${CUSTOM_DOMAIN_NAME}'/g' 02_opensearch-dashboards.yaml
sed -i 's/{FLUENTD_VERSION}/'${FLUENTD_VERSION}'/g' 03_fluentd.yaml
sed -i 's/{FLUENTD_VERSION}/'${FLUENTD_VERSION}'/g' 03_fluentd_cri-o.yaml

if [ $REGISTRY != "{REGISTRY}" ]; then
  sed -i 's/docker.io\/opensearchproject\/opensearch/'${REGISTRY}'\/opensearchproject\/opensearch/g' 01_opensearch.yaml
  sed -i 's/busybox/'${REGISTRY}'\/busybox/g' 01_opensearch.yaml
  sed -i 's/docker.io\/opensearchproject\/opensearch-dashboards/'${REGISTRY}'\/opensearchproject\/opensearch-dashboards/g' 02_opensearch-dashboards.yaml
  sed -i 's/docker.io\/tmaxcloudck/'${REGISTRY}'/g' 02_opensearch-dashboards.yaml
  sed -i 's/fluent\/fluentd-kubernetes-daemonset/'${REGISTRY}'\/fluentd-kubernetes-daemonset/g' 03_fluentd.yaml
  sed -i 's/fluent\/fluentd-kubernetes-daemonset/'${REGISTRY}'\/fluentd-kubernetes-daemonset/g' 03_fluentd_cri-o.yaml
fi

# 1. Install OpenSearch
echo " "
echo "---Installation Start---"
kubectl create namespace kube-logging

echo " "
echo "---1. Install OpenSearch---"
kubectl apply -f 01_opensearch.yaml
timeout 5m kubectl -n kube-logging rollout status statefulset/os-cluster
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install OpenSearch"
  kubectl delete -f 01_opensearch.yaml
  exit 1
else
  echo "OpenSearch pod running success" 
fi

# 2. Wait until Opensearch starts up
echo " "
echo "---2. Wait until Opensearch starts up---"
echo "It will take a couple of minutes"
sleep 1m
set +e
export OS_IP=`kubectl get svc -n kube-logging | grep opensearch | tr -s ' ' | cut -d ' ' -f3`
for ((i=0; i<11; i++))
do
  curl -XGET -k -u admin:admin https://$OS_IP:9200/_cat/indices/
  is_success=`echo $?`
  if [ $is_success == 0 ]; then
    break
  elif [ $i == 10 ]; then
    echo "Timeout. Start uninstall"
    kubectl delete -f 01_opensearch.yaml
    exit 1
  else
    echo "try again..."
    sleep 1m
  fi
done
echo "OpenSearch starts up successfully"
set -e

# 3. Install Opensearch-Dashboards
echo " "
echo "---3. Install Opensearch-Dashboards---"
set +e
export IS_PG=`grep -r 'initContainer' ./02_opensearch-dashboards.yaml`
if [[ "$IS_PG" == *"initContainer"* ]]; then
  echo "OpenSearch-Dashboard Rightsizing Plugin Enabled"
else
  echo "OpenSearch-Dashboard Rightsizing Plugin Disabled"
fi
kubectl apply -f 02_opensearch-dashboards.yaml
timeout 5m kubectl -n kube-logging rollout status deployment/dashboard
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install opensearch-dashboards"
  kubectl delete -f 02_opensearch-dashboards.yaml
  exit 1
else
  echo "Dashboard pod running success"
  sleep 10s
fi

# 4. Install Fluentd
echo " "
echo "---4. Install Fluentd---"
kubectl apply -f 03_fluentd_cri-o.yaml
timeout 10m kubectl -n kube-logging rollout status daemonset/fluentd
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to install Fluentd"
  kubectl delete -f 03_fluentd_cri-o.yaml
  exit 1
else
  echo "Fluentd running success"
  sleep 10s
fi

# 5. Wait until Dashboard makes an index and alias normally
echo " "
echo "---5. Wait until Dashboard makes an index and alias normally---"
echo "It will take a couple of minutes"
sleep 10s
set +e
for ((i=0; i<11; i++))
do
  is_success=`curl -XGET -k -u admin:admin https://$OS_IP:9200/_cat/indices/`

  if [[ "$is_success" == *".kibana"* ]]; then
    break
  elif [ $i == 10 ]; then
    echo "Timeout. Failed to make an kibana index"
    exit 1
  else
    echo "try again..."
    sleep 1m
  fi
done
echo "Dashboard made an index on Opensearch successfully"

echo " "
echo "---Wait until Dashboard makes an alias normally---"
for ((i=0; i<11; i++))
do
  is_success=`curl -XGET -k -u admin:admin https://$OS_IP:9200/_alias`
  is_dashboard_normal=`kubectl get pod -n kube-logging | grep dashboard | tr -s ' ' | cut -d ' ' -f4`

  if [[ "$is_success" == *".kibana_1"* ]]; then
    break
  elif [ $is_dashboard_normal != 0 ]; then
    echo "make an index manually by curl command"
    curl -XPUT -k -u admin:admin https://$OS_IP:9200/.kibana_1/_alias/.kibana
  elif [ $i == 10 ]; then
    echo "Timeout. Failed to make a alias for kibana index"
    exit 1
  else
    echo "try again..."
    sleep 1m
  fi
done
echo "Dashboard made an alias on Opensearch successfully"
sleep 10s
set -e

# 6. Create default index 'logstash-*'
echo " "
echo "---6. Create default index 'logstash-*'---"
echo "It will take a couple of minutes"
set +e
export DASHBOARD_IP=`kubectl get svc -n kube-logging | grep dashboard | tr -s ' ' | cut -d ' ' -f3`

for ((i=0; i<11; i++))
do
  is_success=`curl -XGET -k -u admin:admin https://$OS_IP:9200/_cat/indices/`

  if [[ "$is_success" == *"logstash"* ]]; then
    break
  elif [ $i == 10 ]; then
    echo "Timeout. Failed to make a default index 'logstash-*'"
    exit 1
  else
    echo "try again..."
    sleep 1m
  fi
done
echo "logstash index was made in OpenSearch"

for ((i=0; i<11; i++))
do
  is_success=`curl -XGET -k -u admin:admin https://$DASHBOARD_IP:5601/api/status -I`

  if [[ "$is_success" == *"200 OK"* ]]; then
    break
  elif [ $i == 10 ]; then
    echo "Timeout. Dashboard status is not ready"
    exit 1
  else
    echo "waiting for Dashboard starts up..."
    sleep 1m
  fi
done
echo "Dashboard starts up successfully"
echo " "
echo "---Installation Done---"
popd
