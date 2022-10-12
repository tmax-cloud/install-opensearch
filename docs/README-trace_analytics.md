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
    * AutoInstrumentation-java (ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:1.11.1)
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
    $ export AGENT_VERSION=1.11.1
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
