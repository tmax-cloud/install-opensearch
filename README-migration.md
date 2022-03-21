# Elasticsearch-Opensearch 데이터 마이그레이션 가이드

### Step 1. ElasticSearch backup repo 생성
* [01_elasticsearch.yaml](migration/01_elasticsearch.yaml)(예시)에 snapshot repository 생성을 위한 설정을 추가한 후, es-cluster pod를 재기동한다.
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
* Snapshot으로 저장하고자 하는 index 설정
* [snapshot.sh](migration/snapshot.sh)에서 저장하고자 하는 index-pattern을 추가할 수 있다.
* 예시) fluentd-* index-pattern 추가 시,
```
{
  "indices": "logstash-*", "fluentd-*" # 
  "ignore_unavailable": true,
  "include_global_state": false
}

```

* 단, kibana의 system indices는 (ex) .kibana*) snapshot에 저장하지 않는다.
*  dashboards와 동일한 system indices 이름을 사용하기 때문에 충돌한다
