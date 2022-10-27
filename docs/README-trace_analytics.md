# Trace Analytics 사용 가이드
* 목적: Opentelemetry operator를 통해 application으로부터 trace 데이터를 수집하여 분석할 수 있다.

## Opentelemetry Operator
* 개요
   * Instrumentation을 통한 agent 및 Opentelemtry Collector 설정 관리
   * Trace data를 수집하고자 하는 pod에 inject annotation 추가를 통해 자동으로 agent 설치할 수 있도록 지원

## Prerequisites
* [Cert-Manager](https://github.com/tmax-cloud/install-cert-manager)

## 구성 요소
* Opentelemetry-Operator (ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator:0.56.0)
    * Opentelemetry-Collector (ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector:0.56.0)
    * AutoInstrumentation-java (ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:1.15.0)
* Kube-rbac-proxy (gcr.io/kubebuilder/kube-rbac-proxy:v0.11.0)
    * operator deployment의 sidecar container
* Data-prepper (opensearchproject/data-prepper:1.5.0)

## 폐쇄망 설치 가이드
* 설치를 진행하기 전 아래의 과정을 통해 필요한 이미지 및 yaml 파일을 준비한다.
* 그 후, Install Step을 진행하면 된다.
1. 사용하는 image repository에 trace_analytics 사용 시 필요한 이미지를 push한다. 

    * 작업 디렉토리 생성 및 환경 설정
    ```bash
    $ export OS_HOME=~/opensearch-install
    $ cd $OS_HOME
    $ export OTEL_OPERATOR_VERSION=0.56.0
    $ export OTEL_COLLECTOR_VERSION=0.56.0
    $ export AGENT_VERSION=1.15.0
    $ export DP_IMAGE_VERSION=1.5.0
    $ export REGISTRY={ImageRegistryIP:Port}
    ```
    * 외부 네트워크 통신이 가능한 환경에서 필요한 이미지를 다운받는다.
    ```bash
    $ sudo docker pull ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator:${OTEL_OPERATOR_VERSION}
    $ sudo docker save ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator:${OTEL_OPERATOR_VERSION} > opentelemetry-operator_${OTEL_OPERATOR_VERSION}.tar
    $ sudo docker pull ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector:${OTEL_COLLECTOR_VERSION}
    $ sudo docker save ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector:${OTEL_COLLECTOR_VERSION} > opentelemetry-collector_${OTEL_COLLECTOR_VERSION}.tar
    $ sudo docker pull ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:${AGENT_VERSION}
    $ sudo docker save ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:${AGENT_VERSION} > otel-javaagent_${AGENT_VERSION}.tar
    $ sudo docker pull gcr.io/kubebuilder/kube-rbac-proxy:${PROXY_VERSION}
    $ sudo docker save gcr.io/kubebuilder/kube-rbac-proxy:${PROXY_VERSION} > kube-rbac-proxy_${PROXY_VERSION}.tar
    $ sudo docker pull opensearchproject/data-prepper:${DP_IMAGE_VERSION}
    $ sudo docker save opensearchproject/data-prepper:${DP_IMAGE_VERSION} > data-prepper_${DP_IMAGE_VERSION}.tar
    ```
  
2. 위의 과정에서 생성한 tar 파일들을 폐쇄망 환경으로 이동시킨 뒤 사용하려는 registry에 이미지를 push한다.
    ```bash
    $ sudo docker load < opentelemetry-operator_${OTEL_OPERATOR_VERSION}.tar
    $ sudo docker load < opentelemetry-collector_${OTEL_COLLECTOR_VERSION}.tar
    $ sudo docker load < otel-javaagent_${AGENT_VERSION}.tar
    $ sudo docker load < kube-rbac-proxy_${PROXY_VERSION}.tar
    $ sudo docker load < data-prepper_${DP_IMAGE_VERSION}.tar
    
    $ sudo docker tag ghcr.io/open-telemetry/opentelemetry-operator/opentelemetry-operator:${OTEL_OPERATOR_VERSION} ${REGISTRY}/opentelemetry-operator/opentelemetry-operator:${OTEL_OPERATOR_VERSION}
    $ sudo docker tag ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector:${OTEL_COLLECTOR_VERSION} ${REGISTRY}/opentelemetry-collector-releases/opentelemetry-collector:${OTEL_COLLECTOR_VERSION} 
    $ sudo docker tag ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:${AGENT_VERSION} ${REGISTRY}/opentelemetry-operator/autoinstrumentation-java:${AGENT_VERSION}
    $ sudo docker tag gcr.io/kubebuilder/kube-rbac-proxy:${PROXY_VERSION} ${REGISTRY}/kube-rbac-proxy:${PROXY_VERSION}
    $ sudo docker tag opensearchproject/data-prepper:${DP_IMAGE_VERSION} ${REGISTRY}/data-prepper:${DP_IMAGE_VERSION}
    
    $ sudo docker push ${REGISTRY}/opentelemetry-operator/opentelemetry-operator:${OTEL_OPERATOR_VERSION}
    $ sudo docker push ${REGISTRY}/opentelemetry-collector-releases/opentelemetry-collector:${OTEL_COLLECTOR_VERSION} 
    $ sudo docker push ${REGISTRY}/opentelemetry-operator/autoinstrumentation-java:${AGENT_VERSION}
    $ sudo docker push ${REGISTRY}/kube-rbac-proxy:${PROXY_VERSION}
    $ sudo docker push ${REGISTRY}/data-prepper:${DP_IMAGE_VERSION}
    ```

3. registry 정보를 image에 수정하여 반영한다.
  
  ```bash
	$ sed -i 's/ghcr.io\/open-telemetry\/opentelemetry-operator\/opentelemetry-operator/'${REGISTRY}'\/opentelemetry-operator\/opentelemetry-operator/g' opentelemetry-operator.yaml
  $ sed -i 's/ghcr.io\/open-telemetry\/opentelemetry-collector-releases\/opentelemetry-collector/'${REGISTRY}'\/opentelemetry-collector-releases\/opentelemetry-collector/g' opentelemetry-collector.yaml
  $ sed -i 's/ghcr.io\/open-telemetry\/opentelemetry-operator\/autoinstrumentation-java/'${REGISTRY}'\/opentelemetry-operator\/autoinstrumentation-java/g' instrumentation.yaml
  $ sed -i 's/gcr.io\/kubebuilder\/kube-rbac-proxy/'${REGISTRY}'\/kube-rbac-proxy/g' opentelemetry-operator.yaml
  $ sed -i 's/opensearchproject\/data-prepper/'${REGISTRY}'\/data-prepper/g' data-prepper.yaml
```   

## Step 0. 이미지 버전 반영
* 아래의 command를 사용하여 사용하고자 하는 image 버전을 입력한다.

```bash
  $ sed -i 's/{OTEL_OPERATOR_VERSION}/'${OTEL_OPERATOR_VERSION}'/g' opentelemetry-operator.yaml
  $ sed -i 's/{PROXY_VERSION}/'${PROXY_VERSION}'/g' opentelemetry-operator.yaml
  $ sed -i 's/{OTEL_COLLECTOR_VERSION}/'${OTEL_COLLECTOR_VERSION}'/g' opentelemetry-collector.yaml
  $ sed -i 's/{AGENT_VERSION}/'${AGENT_VERSION}'/g' instrumentation.yaml
  $ sed -i 's/{DP_IMAGE_VERSION}/'${DP_IMAGE_VERSION}'/g' data-prepper.yaml
```   

## Step 1. Opentelemetry-Operator 설치
* 목적: Opentelemetry-Operator 설치
* 순서:

1. [opentelemetry-operator.yaml](../trace_analytics/opentelemetry-operator.yaml)에 이미지 버전 설정
2. kubectl apply -f opentelemetry-operator.yaml 로 설치

## Step 2. Instrumentation CR 생성
* 목적: Instrumentation CR 설정
* 순서:

1. kubectl apply -f instrumentation.yaml 로 생성

* 비고: [instrumentation.yaml](../trace_analytics/instrumentation.yaml) 에서 각 파드에 inject할 agent의 이미지를 임의로 변경할 수 있다.

## Step 3. Opentelemetry-Collector CR 생성
* 목적: Opentelemetry-Collector CR 설정
* 순서: 

1. kubectl apply -f opentelemetry-collector.yaml 로 생성

* 비고: [opentelemetry-collector.yaml](../trace_analytics/opentelemetry-collector.yaml)에서 deployment mode를 변경할 수 있다. ex) sidecar, daemonset, deployment 현재 default 설정은 deployment

## Step 4. Data-prepper 설치
* 목적: Opentelemetry-Collector를 통해 받은 trace data를 OpenSearch의 document 형식으로 변환하여 Opensearch에 적재
* 순서: 

1. [data-prepper.yaml](../trace_analytics/data-prepper.yaml)에 이미지 버전 설정
2. kubectl apply -f data-prepper.yaml 로 설치

## Step 4. Pod에 Annotation 추가
* 목적: pod에 annotation을 통해 해당 pod의 trace data를 수집하기 위한 agent를 설치
* 아래의 예시에서는 JavaAgent 사용을 전제로 함.
* 비고: operator에서 지원하는 agent의 종류는 java, python, nodejs 

ex) Pod일 경우

```
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  annotations:
    sidecar.opentelemetry.io/inject: "true"
    instrumentation.opentelemetry.io/inject-java: "kube-logging/java"
spec:
  containers:
  - name: myapp
```

ex) Deployment일 경우

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-deploy
spec:
  selector:
    matchLabels:
      app: my-app-deploy
  replicas: 1
  template:
    metadata:
      labels:
        app: my-app-deploy
      annotations:                                 ### annotation 추가를 spec > template > metadata 안에서 해야 함.
        sidecar.opentelemetry.io/inject: "true"
        instrumentation.opentelemetry.io/inject-java: "kube-logging/java"
```

ex) Multi-Container일 경우 (sidecar가 달려있는 container)

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment-with-multiple-containers
spec:
  selector:
    matchLabels:
      app: my-pod-with-multiple-containers
  replicas: 1
  template:
    metadata:
      labels:
        app: my-pod-with-multiple-containers
      annotations:
        sidecar.opentelemetry.io/inject: "true"
        instrumentation.opentelemetry.io/inject-java: "kube-logging/java"
        instrumentation.opentelemetry.io/container-names: "myapp,myapp2"
    spec:
      containers:
      - name: myapp
        image: myImage1
      - name: myapp2
        image: myImage2
      - name: myapp3
        image: myImage3
```

## Step 5. OpenSearch-Dashboards UI에서 확인
* Dashboards UI에서 Observability 메뉴에서 Trace Analytics를 클릭하여 확인
* 단, single service의 경우 service map이 뜨지 않는다.
![image](../figure/trace1.png)


## 비고
### Instrumentation의 Agent log level 설정
* java agent의 경우, env에서 OTEL_JAVAAGENT_DEBUG를 "false"로 수정 시 해당 agent가 설치되는 pod 내부에서 출력되는 log level이 info로 설정된다. 


## TroubleShooting
### Dropping data because sending_queue is full. Try increasing queue_size
* sending_queue full로 인하여 otel-collector pod에서 해당 로그 발생 시 collector queue size를 늘려준다.
* ex) [opentelemetry-collector.yaml](../trace_analytics/opentelemetry-collector.yaml) 의 exporter에서 sending queue 옵션 수정

```
exporters:
      logging:
      otlp/data-prepper:
        endpoint: data-prepper.kube-logging.svc:21890
        tls:
          insecure: true
        sending_queue:
          enabled: true
          num_consumers: 100
          queue_size: 10000  ### 해당 queue size를 늘려 준다. 
``` 

### OTelTraceGrpcService - Buffer is full, unable to write
* Data prepper pod에서 해당 로그 발생 시 ConfigMap에서 buffer_size와 batch_size를 조정한다.
* ex) [data-prepper.yaml](../trace_analytics/data-prepper.yaml)

```
data:
  pipelines.yaml: |
    entry-pipeline:
      delay: "100"
      source:
        otel_trace_source:
          ssl: false
          port: 21890
      buffer:
        bounded_blocking:
          buffer_size: 1024   ### buffer size를 늘린다
          batch_size: 256     ### batch_size를 늘린다
      sink:
      - pipeline:
          name: "raw-pipeline"
      - pipeline:
          name: "service-map-pipeline"
``` 

* Data prepper에서 java.lang.OutOfMemoryError: Java heap space 발생 시, data prepper Deployment의 container args에 jvm option 추가 및 resource를 조정한다.

```
spec:
  containers:
    - args:
        - java
        - -Xms2g             ### jvm heap size 설정 default 8m에서 2g로 변경
        - -Xmx2g
        - -jar
	- /usr/share/data-prepper/data-prepper.jar
        - /etc/data-prepper/pipelines.yaml
        - /etc/data-prepper/data-prepper-config.yaml
      image: opensearchproject/data-prepper:{DP_IMAGE_VERSION}
      imagePullPolicy: IfNotPresent
      name: data-prepper
      resources:
        limits:
          cpu: 500m
	  memory: 4000Mi     ### limits memory는 설정한 jvm heap size의 2배로 설정
        requests:
          cpu: 200m
          memory: 2000Mi     ### requests memory는 설정한 jvm heap size와 동일하게 설정
``` 
