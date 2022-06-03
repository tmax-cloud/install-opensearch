## Elasticsearch-Opensearch 데이터 마이그레이션 가이드
* 목적: 기존의 EFK stack으로 적재하고 저장한 index log data를 Opensearch에 데이터 손실 없이 옮긴다.

### Step 1. ElasticSearch backup repo 생성
* 기존에 사용한 [01_elasticsearch.yaml](migration/01_elasticsearch.yaml)(예시용)에 snapshot repository 생성을 위한 설정을 추가한 후, es-cluster pod를 재기동한다.
* 예시1) elasticsearch/statefulset 추가 설정
```
volumeMounts:
  - name: es-config
    mountPath: /usr/share/elasticsearch/config/elasticsearch.yml
    subPath: elasticsearch.yml
  - name: backups-vol
    mountPath: /backups
    
 volumes:
      - name: es-config
        configMap:
          name: es-config
      - name: backups-vol
        persistentVolumeClaim:
          claimName: backups-es-cluster-0
           
  volumeClaimTemplates:
  - metadata:
      name: backups
      labels:
        app: elasticsearch
    spec:
      accessModes: ["ReadWriteMany"]
      resources:
        requests:
          storage: 50Gi
          
```

* 예시2) elasticsearch.yml Configmap 추가
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: es-config
  namespace: kube-logging
data:
  elasticsearch.yml: |
    network.host: "0.0.0.0"
    path.repo: ["/backups"]

```

### Step 2. ES backup repo에 snapshot 생성
* ES snapshot 생성을 위한 shell script 실행

```bash
$ ./migration/snapshot.sh

```
### Step 3. OpenSearch에 backup repo 연동 및 restore
* [01_opensearch.yaml](yaml/01_opensearch.yaml)에 snapshot repository 생성을 위한 설정을 추가한 후, install 가이드에 따라 설치를 진행한다.
* 예시1) opensearch/statefulset 추가 설정
```
volumeMounts:
  - name: backups-vol
    mountPath: /backups
    
 volumes:
   - name: backups-vol
     persistentVolumeClaim:
       claimName: backups-es-cluster-0       
```

* 예시2) opensearch-config ConfigMap 추가 설정
```
network.host: "0.0.0.0"
path.repo: "/backups"
```
* 설치 완료 후, OS에서 Snapshot 데이터를 불러오기 위한 shell script 실행

```bash
$ ./migration/restore.sh

```


### 비고
* [snapshot.sh](migration/snapshot.sh)에서 저장하고자 하는 index-pattern을 추가할 수 있다.
* 예시) fluentd-* index-pattern 추가 시,
```
{
  "indices": "logstash-*", "fluentd-*" # 추가한 index-pattern
  "ignore_unavailable": true,
  "include_global_state": false
}

```

* 단, kibana의 system indices는 (ex) .kibana*) snapshot에 저장하지 않는다.
* dashboards와 동일한 system indices 이름을 사용하기 때문에 충돌하기 때문

## Opensearch Snapshot 가이드
* 목적: Opensearch에 적재한 index log data를 별도의 repository에 저장하여 관리한다.

### Step 1. OpenSearch backup repo PVC 마운트 설정
* [01_opensearch.yaml](yaml/01_opensearch.yaml)에 snapshot repository 생성을 위한 설정을 추가한 후, os-cluster pod를 재기동한다.
* 예시1) opensearch/statefulset 추가 설정
```
volumeMounts:
  - name: os-config
    mountPath: /usr/share/elasticsearch/config/opensearch.yml
    subPath: opensearch.yml
  - name: backups-vol
    mountPath: /usr/share/opensearch/backups
    
 volumes:
      - name: os-config
        configMap:
          name: os-config
      - name: backups-vol
        persistentVolumeClaim:
          claimName: backups-os-cluster-0
           
  volumeClaimTemplates:
  - metadata:
      name: backups
      labels:
        app: opensearch
    spec:
      accessModes: ["ReadWriteMany"]
      resources:
        requests:
          storage: 50Gi  # 임의로 설정한다.
          
```
* 예시2) opensearch-config ConfigMap 추가 설정
```
network.host: "0.0.0.0"
path.repo: "/usr/share/opensearch/backups"
```

### Step 2. OS backup repo 생성
* OPENSEARCH_SERVICE_IP = opensearch의 service ip를 기입한다.

ex) backups repository 생성
```
curl -u admin:admin -k -XPUT https://{OPENSEARCH_SERVICE_IP}:9200/_snapshot/backups -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/opensearch/backups"
  }
}
'
```

### Step 3. OS backup snapshot 생성
ex) snapshot_1을 생성하여 logstash-*에 해당하는 인덱스를 repository에 저장
```
curl -u admin:admin -k -XPUT "https://{OPENSEARCH_SERVICE_IP}:9200/_snapshot/backups/snapshot_1?wait_for_completion=true&pretty" -H 'Content-Type: application/json' -d'
{
  "indices": "logstash-*", # snapshot으로 저장하고자 하는 index pattern을 입력
  "ignore_unavailable": true,
  "include_global_state": false
}
'
```

### Step 3-1. Dashboards UI에서 Index Policy를 이용해 특정 index pattern을 가진 index를 주기적으로 저장
