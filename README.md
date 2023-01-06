## Opensearch 기능 가이드
* [Opensearch 기본 가이드](https://github.com/tmax-cloud/install-opensearch/blob/main/docs/README-basic.md)
* [Opensearch Plugin 가이드](https://github.com/tmax-cloud/install-opensearch/blob/main/docs/README-plugin.md)
* [EFK-OpenSearch Migration 및 Snapshot 가이드](https://github.com/tmax-cloud/install-opensearch/blob/main/docs/README-snapshot.md)
* [Opensearch Role 설정 가이드](https://github.com/tmax-cloud/install-opensearch/blob/main/docs/README-roles.md)
* [Opensearch Trace_Analytics 사용 가이드](https://github.com/tmax-cloud/install-opensearch/blob/main/docs/README-trace_analytics.md)

# Opensearch 설치 가이드

## 개요
* Opensearch Stack은 Opensearch, Opensearch-Dashboards, Fluentd로 구성된 플랫폼 조합이다.
* K8S 클러스터로부터 Fluentd가 수집한 로그를 Opensearch에 적재하면, Opensearch는 수집된 로그를 저장하고 요청에 따라 검색 기능을 제공한다. 그리고 Opensearch-Dashboards를 통해 Opensearch에 적재된 데이터를 시각화한다.

## 구성 요소 및 버전
* Opensearch ([opensearchproject/opensearch:1.3.7](https://hub.docker.com/r/opensearchproject/opensearch))
* Opensearch dashboard ([opensearchproject/opensearch-dashboards:1.3.7](https://hub.docker.com/r/opensearchproject/opensearch-dashboards))
* Busybox ([busybox:1.32.0](https://hub.docker.com/layers/busybox/library/busybox/1.32.0/images/sha256-414aeb860595d7078cbe87abaeed05157d6b44907fbd7db30e1cfba9b6902448?context=explore))
* Fluentd ([docker.io/tmaxcloudck/hypercloud:fluentd-v1.15.3-debian-elasticsearch-1.0](https://hub.docker.com/layers/tmaxcloudck/hypercloud/fluentd-v1.15.3-debian-elasticsearch-1.0/images/sha256-14539981f57cbac47ef53e38ac23419b9a0614803c120d9d38b3db50c0295c54?context=explore))
    * elasticsearch plugin이 적용된 최신 버전 fluentd와 동일한 이미지에 opensearch output plugin을 추가하여 생성한 이미지
* Rightsizing Plugin ([docker.io/tmaxcloudck/rightsizing-opensearch-plugin:demo](https://hub.docker.com/repository/docker/tmaxcloudck/rightsizing-opensearch-plugin))

## Prerequisites
* 필수 모듈
  * [RookCeph](https://github.com/tmax-cloud/hypersds-wiki/) 
  * [Hyperauth](https://github.com/tmax-cloud/hyperauth)
  * [Cert-manager](https://github.com/tmax-cloud/install-cert-manager)

## 폐쇄망 설치 가이드
* 설치를 진행하기 전 아래의 과정을 통해 필요한 이미지 및 yaml 파일을 준비한다.
* 그 후, Install Step을 진행하면 된다.
1. 사용하는 image repository에 Opensearch 설치 시 필요한 이미지를 push한다. 

    * 작업 디렉토리 생성 및 환경 설정
    ```bash
    $ mkdir -p ~/opensearch-install
    $ export OS_HOME=~/opensearch-install
    $ cd $OS_HOME
    $ export OS_VERSION=1.3.7
    $ export DASHBOARD_VERSION=1.3.7
    $ export PG_IMAGE_PATH=rightsizing-opensearch-plugin:demo
    $ export BUSYBOX_VERSION=1.32.0
    $ export FLUENTD_VERSION=fluentd-v1.15.3-debian-elasticsearch-1.0
    $ export REGISTRY={ImageRegistryIP:Port}
    ```
    * 외부 네트워크 통신이 가능한 환경에서 필요한 이미지를 다운받는다.
    ```bash
    $ sudo docker pull opensearchproject/opensearch:${OS_VERSION}
    $ sudo docker save opensearchproject/opensearch:${OS_VERSION} > opensearch_${OS_VERSION}.tar
    $ sudo docker pull opensearchproject/opensearch-dashboards:${DASHBOARD_VERSION}
    $ sudo docker save opensearchproject/opensearch-dashboards:${DASHBOARD_VERSION} > dashboard_${DASHBOARD_VERSION}.tar
    $ sudo docker pull busybox:${BUSYBOX_VERSION}
    $ sudo docker save busybox:${BUSYBOX_VERSION} > busybox_${BUSYBOX_VERSION}.tar
    $ sudo docker pull docker.io/tmaxcloudck/${PG_IMAGE_PATH}
    $ sudo docker save docker.io/tmaxcloudck/${PG_IMAGE_PATH} > ${PG_IMAGE_PATH}.tar
    $ sudo docker pull docker.io/tmaxcloudck/hypercloud:${FLUENTD_VERSION}
    $ sudo docker save docker.io/tmaxcloudck/hypercloud:${FLUENTD_VERSION} > fluentd_${FLUENTD_VERSION}.tar
    ```
  
2. 위의 과정에서 생성한 tar 파일들을 폐쇄망 환경으로 이동시킨 뒤 사용하려는 registry에 이미지를 push한다.
    ```bash
    $ sudo docker load < opensearch_${OS_VERSION}.tar
    $ sudo docker load < dashboard_${DASHBOARD_VERSION}.tar
    $ sudo docker load < busybox_${BUSYBOX_VERSION}.tar
    $ sudo docker load < ${PG_IMAGE_PATH}.tar
    $ sudo docker load < fluentd_${FLUENTD_VERSION}.tar
    
    $ sudo docker tag opensearchproject/opensearch:${OS_VERSION} ${REGISTRY}/opensearchproject/opensearch:${OS_VERSION}
    $ sudo docker tag opensearchproject/opensearch-dashboards:${DASHBOARD_VERSION} ${REGISTRY}/opensearchproject/opensearch-dashboards:${DASHBOARD_VERSION}
    $ sudo docker tag busybox:${BUSYBOX_VERSION} ${REGISTRY}/busybox:${BUSYBOX_VERSION}
    $ sudo docker tag docker.io/tmaxcloudck/${PG_IMAGE_PATH} ${REGISTRY}/${PG_IMAGE_PATH}
    $ sudo docker tag docker.io/tmaxcloudck/hypercloud:${FLUENTD_VERSION} ${REGISTRY}/hypercloud:${FLUENTD_VERSION}
    
    $ sudo docker push ${REGISTRY}/opensearchproject/opensearch:${OS_VERSION}
    $ sudo docker push ${REGISTRY}/opensearchproject/opensearch-dashboards:${DASHBOARD_VERSION}
    $ sudo docker push ${REGISTRY}/busybox:${BUSYBOX_VERSION}
    $ sudo docker push ${REGISTRY}/${PG_IMAGE_PATH}
    $ sudo docker push ${REGISTRY}/hypercloud:${FLUENTD_VERSION}
    ```

## Step 0. opensearch.config 설정
* 목적 : `yaml/opensearch.config 파일에 설치를 위한 정보 기입`
* 순서: 
	* 환경에 맞는 config 내용 작성
		* OS_VERSION
			* OpenSearch 의 버전
			* ex) 1.3.7
		* DASHBOARD_VERSION
			* Opensearch-Dashboards 의 버전
			* ex) 1.3.7
		* BUSYBOX_VERSION
			* Busybox 의 버전
			* ex) 1.32.0
        * HYPERAUTH_URL
            * Hyperauth 의 URL
            * ex) hyperauth.tmaxcloud.org
        * OPENSEARCH_CLIENT_SECRET
            * Hyperauth 에 생성된 opensearch client 의 secret
            * ex) 22a985f7-c12d-4812-bd4e-bd598e1df7e8
        * RS_PLUGIN
            * OpenSearch-Dashboards의 Rightsizing plugin 사용 유무, boolean
            * ex) true
        *  PG_IMAGE_PATH
            * OpenSearch-Dashboards Plugin 이미지 레포와 버전
            * ex) rightsizing-opensearch-plugin:demo
        *  CUSTOM_DOMAIN_NAME
            * Ingress로 접근 요청할 사용자 지정 도메인 이름
            * ex) tmaxcloud.org
		* FLUENTD_VERSION
			* FLUENTD_VERSION 의 버전
			* ex) fluentd-v1.15.3-debian-elasticsearch-1.0
		* BUSYBOX_VERSION
			* BUSYBOX_VERSION 의 버전
			* ex) 1.32.0
		* STORAGECLASS_NAME
			* OpenSearch가 사용할 StorageClass 의 이름
            * {STORAGECLASS_NAME} 그대로 유지시 default storageclass 사용
			* ex) csi-cephfs-sc
		* REGISTRY
			* 폐쇄망 사용시 image repository의 주소
			* 폐쇄망 아닐시 {REGISTRY} 그대로 유지
			* ex) 192.168.171:5000
## Hyperauth 연동
* 목적: `Opensearch-dashboards와 Hyperauth 연동`
* 순서:
    *  hyperauth에서 client 생성
    	* Client protocol = openid-connect
    	* Access type = confidential 
    	* Standard Flow Enabled = On 
    	* Direct Access Grants Enabled = On
    	* Valid Redirect URIs: '*'
    * Client > opensearch > Credentials > client_secret 복사 후 OPENSEARCH_CLIENT_SECRET을 채운다.
    * Client > opensearch > Mappers > add builtin 클릭 후 'client roles'에 체크하여 Add selected 클릭
    * Client > opensearch > Mappers > client roles 선택 후 설정 변경
        * Client ID = opensearch
    	* Token Claim Name = roles
    	* Add to ID token = On
    	* Add to access token = On
    	* Add to userinfo = On
    * Client > opensearch > roles > add role 클릭 후 'opensearch-admin' role 생성
    * Opensearch-Dashboards를 사용하고자 하는 사용자의 계정의 Role Mappings 설정에서 Client Roles에서 'opensearch' 선택 후 'opensearch-admin'을 적용한다.

    * client 생성
    ![image](figure/client-page.png)
    * mapper 생성
    ![image](figure/client-mapper.png)
    * role-mapping
    ![image](figure/mapping.png)

## Step 1. installer 실행
* 목적 : `설치를 위한 shell script 실행`
* 순서: 
	* 권한 부여 및 실행
	``` bash
	$ sudo chmod +x yaml/install.sh
	$ sudo chmod +x yaml/uninstall.sh
	$ ./yaml/install.sh
	```

## 비고
* Dashboard의 서비스 타입 변경을 원하는 경우
    * yaml/02_opensearch-dashboards.yaml 파일에서 Service의 spec.type 수정

## 삭제 가이드
* 목적 : `삭제를 위한 shell script 실행`
* 순서: 
	* 실행
	``` bash
	$ ./yaml/uninstall.sh
	```

## 수동 설치 가이드
## Prerequisites
1. Namespace 생성
    * Opensearch를 설치할 namespace를 생성한다.
    ```bash
    $ kubectl create ns kube-logging
    ```
2. 변수 export
    * 다운 받을 버전을 export한다. 
    ```bash
    $ export OS_VERSION=1.3.7
    $ export DASHBOARD_VERSION=1.3.7
    $ export FLUENTD_VERSION=fluentd-v1.15.3-debian-elasticsearch-1.0
    $ export BUSYBOX_VERSION=1.32.0
    $ export PG_IMAGE_PATH=rightsizing-opensearch-plugin:demo
    $ export STORAGECLASS_NAME=csi-cephfs-sc
    ```
    * Hyperauth 연동 관련 및 기타 스펙을 export 한다.
    ```bash
    $ export RS_PLUGIN=true #disable 시 false
    $ export HYPERAUTH_URL=hyperauth.tmaxcloud.org
    $ export OPENSEARCH_CLIENT_SECRET=22a985f7-c12d-4812-bd4e-bd598e1df7e8
    $ export CUSTOM_DOMAIN_NAME=tmaxcloud.org
    ```
3. Plugin 설정을 위한 plugin-setting.sh를 실행한다.
   ```bash
   $ sudo chmod +x yaml/plugin-setting.sh
   $ ./yaml/plugin-setting.sh
   ```
* 비고  
    * 이하 인스톨 가이드는 StorageClass 이름이 csi-cephfs-sc 라는 가정하에 진행한다.
    * 재설치 시 Rightsizing plugin 설정을 변경할 경우
        * ex) rightsizing plugin disable로 변경 시 
        * export RS_PLUGIN=false 로 변수를 새로 export 후 plugin-setting.sh을 실행한다.

## Install Steps
0. [Opensearch yaml 수정](https://github.com/chaejin-lee/install-opensearch/blob/master/README.md#step-0-opensearch-yaml-%EC%88%98%EC%A0%95)
1. [OpenSearch 설치](https://github.com/chaejin-lee/install-opensearch/blob/master/README.md#step-1-opensearch-%EC%84%A4%EC%B9%98)
2. [OpenSearch-Dashboards 설치](https://github.com/chaejin-lee/install-opensearch/blob/master/README.md#step-2-opensearch-dashboards-%EC%84%A4%EC%B9%98)
3. [Fluentd 설치](https://github.com/chaejin-lee/install-opensearch/blob/master/README.md#step-3-fluentd-%EC%84%A4%EC%B9%98)

## Step 0. opensearch-stack yaml 수정
* 목적 : `opensearch-stack yaml에 이미지 registry, 버전 및 노드 정보를 수정`
* 생성 순서 : 
    * 아래의 command를 사용하여 사용하고자 하는 image 버전을 입력한다.
	```bash
	$ sed -i 's/{BUSYBOX_VERSION}/'${BUSYBOX_VERSION}'/g' 01_opensearch.yaml
	$ sed -i 's/{OS_VERSION}/'${OS_VERSION}'/g' 01_opensearch.yaml
	$ sed -i 's/{HYPERAUTH_URL}/'${HYPERAUTH_URL}'/g' 01_opensearch.yaml
	$ sed -i 's/{STORAGECLASS_NAME}/'${STORAGECLASS_NAME}'/g' 01_opensearch.yaml
    $ sed -i 's/{DASHBOARD_VERSION}/'${DASHBOARD_VERSION}'/g' 02_opensearch-dashboards.yaml
    $ sed -i 's/{PG_IMAGE_PATH}/'${PG_IMAGE_PATH}'/g' 02_opensearch-dashboards.yaml
    $ sed -i 's/{HYPERAUTH_URL}/'${HYPERAUTH_URL}'/g' 02_opensearch-dashboards.yaml
    $ sed -i 's/{OPENSEARCH_CLIENT_SECRET}/'${OPENSEARCH_CLIENT_SECRET}'/g' 02_opensearch-dashboards.yaml
    $ sed -i 's/{CUSTOM_DOMAIN_NAME}/'${CUSTOM_DOMAIN_NAME}'/g' 02_opensearch-dashboards.yaml
	$ sed -i 's/{FLUENTD_VERSION}/'${FLUENTD_VERSION}'/g' 03_fluentd.yaml
  	$ sed -i 's/{FLUENTD_VERSION}/'${FLUENTD_VERSION}'/g' 03_fluentd_cri-o.yaml
	```
* 비고 :
    * `폐쇄망에서 설치를 진행하여 별도의 image registry를 사용하는 경우 registry 정보를 추가로 설정해준다.`
	```bash
	$ sed -i 's/docker.io\/opensearchproject\/opensearch/'${REGISTRY}'\/opensearchproject\/opensearch/g' 01_opensearch.yaml
	$ sed -i 's/busybox/'${REGISTRY}'\/busybox/g' 01_opensearch.yaml
	$ sed -i 's/docker.io\/opensearchproject\/opensearch-dashboards/'${REGISTRY}'\/opensearchproject\/opensearch-dashboards/g' 02_opensearch-dashboards.yaml
	$ sed -i 's/docker.io\/tmaxcloudck/'${REGISTRY}'/g' 02_opensearch-dashboards.yaml
	$ sed -i 's/docker.io\/tmaxcloudck/'${REGISTRY}'/g' 03_fluentd.yaml
	$ sed -i 's/docker.io\/tmaxcloudck/'${REGISTRY}'/g' 03_fluentd_cri-o.yaml
	```    
    
## Step 1. OpenSearch 설치
* 목적 : `OpenSearch 설치`
* 생성 순서 : 
    * [01_opensearch.yaml](yaml/01_opensearch.yaml) 실행
	```bash
	$ kubectl apply -f 01_opensearch.yaml
	```     
* 비고 :
    * StorageClass 이름이 csi-cephfs-sc가 아니라면 환경에 맞게 수정해야 한다.

## Step 2. OpenSearch-Dashboards 설치
* 목적 : `Opensearch의 UI 모듈인 Opensearch-Dashboards를 설치`
* 생성 순서 : [02_opensearch-dashboards.yaml](yaml/02_opensearch-dashboards.yaml) 실행 
    ```bash
    $ kubectl apply -f 02_opensearch-dashboards.yaml
    ```
![image](figure/dashboards.png)
* 비고 :
    * Dashboard pod 가 running 임을 확인한 뒤 https://opensearch-dashboards.${CUSTOM_DOMAIN_NAME}/ 에 접속한다.
    * Hyperauth에서 설정한 사용자 계정으로 로그인하여 정상 작동을 확인한다.

## Step 3. fluentd 설치
* 목적 : `EFK의 agent daemon 역할을 수행하는 fluentd를 설치`
* 생성 순서 : 03_fluentd~.yaml 실행  
  1. Container Runtime이 cri-o 인 경우  
    * [03_fluentd_cri-o.yaml](yaml/03_fluentd_cri-o.yaml) 실행
      ``` bash
      $ kubectl apply -f 03_fluentd_cri-o.yaml
      ```
  2. Container Runtime이 docker 인 경우  
    * [03_fluentd.yaml](yaml/03_fluentd.yaml) 실행 
      ```bash
      $ kubectl apply -f 03_fluentd.yaml
      ```
  3. Kubernetes pod 별로 index 생성하고자 할 경우
    * [03_fluentd_multiple_index.yaml](yaml/03_fluentd_multiple_index.yaml) 실행 
      ```bash
      $ kubectl apply -f 03_fluentd_multiple_index.yaml
      ```
      
    * 비고: Kubernetes namespace 별로 index 생성하고자 할 경우 [03_fluentd_multiple_index.yaml](yaml/03_fluentd_multiple_index.yaml)의 configmap인 fluentd-config에서 pod_name으로 설정된 부분을 namespace_name으로 변경하여 적용한다.
    
    ![image](figure/fluentd_module_index.png)
    
## Opensearch HA 구성 가이드
* 목적: Opensearch와 Opensearch-Dashboards 파드에 대하여 각각 Active-Active 방식으로 기동하기 위한 설정이다.
* Opensearch 구성
    * Opensearch의 경우 master node 후보를 3개 이상의 홀수 개를 생성하는 것을 권장한다.
    1. [01_opensearch.yaml](yaml/01_opensearch.yaml)의 statefulset에서 replicas와 env 설정을 변경한다.
     ```
    spec:
      serviceName: opensearch
      selector:
        matchLabels:
          app: opensearch
      replicas: 3 ## 1에서 3으로 변경
     
    ...
    
    - name: discovery.seed_hosts
      value: "os-cluster-0.opensearch, os-cluster-1.opensearch, os-cluster-2.opensearch" ## 증가된 만큼 수정
    - name: cluster.initial_master_nodes
      value: "os-cluster-0, os-cluster-1, os-cluster-2" ## 증가된 만큼 수정
    
    ```
    2. opensearch-config의 opensearch.yml에 설정을 변경 및 추가한다.
    ```
    data:
      opensearch.yml: |
        cluster.name: "os-cluster"
        network.host: "0.0.0.0"
        discovery.seed_hosts: [ "os-cluster-0.opensearch", "os-cluster-1.opensearch", "os-cluster-2.opensearch" ] ## 증가된 만큼 수정
        cluster.initial_master_nodes: os-cluster-0, os-cluster-1, os-cluster-2 ## 증가된 만큼 수정
    ```
* Opensearch-Dashboards 구성
    * Opensearch-Dashboards의 경우 Dashboards replicas: 2로 수정한다.
    ```
    spec:
      replicas: 2 ## 1에서 2로 변경
      selector:
        matchLabels:
          app: opensearch-dashboards
      template:
        metadata:
          labels:
            app: opensearch-dashboards
    ```

### Opensearch multi node 환경에서 single node 환경으로 변경하여 재기동 시 주의 사항
*  opensearch data(PVC)에 master node 관련 설정이 저장되기 때문에 지워지는 노드에 대하여 master node 후보에서 제외시킨 후에 opensearch 재기동 필요
* Dashboards UI Dev tools에서 설정
```
POST /_cluster/voting_config_exclusions/node_name={NODE_NAME} # os-cluster-1, os-cluster-2 각각 실행
```

## 비고
* Fluentd에서 수집하는 로그 필드 설정
    * fluentd.yaml 파일 Configmap의 kubernetes.conf에 filter 설정을 추가로 적용하여 로그 필드를 삭제할 수 있다.
    * 주의: 삭제된 로그 필드는 opensearch에 적재되지 않는다.
    * 예시) kubernetes.container_image_id에 대한 로그 필드를 삭제
    ```
    <filter kubernetes.**>
      @type record_transformer
      enable_ruby true
      remove_keys $.kubernetes.container_image_id
    </filter>

    ```
### Opensearch와 Opensearch-Dashboards, fluentd 모듈의 log level 설정
* Opensearch: Apache Log4j를 사용하며 TRACE, DEBUG, INFO, WARN, ERROR, FATAL 총 6단계로, default로 설정된 log level은 INFO이다.
     * log level 설정은 config를 수정하는 방법과 opensearch-dashboards ui에서 query를 보내어 설정하는 방법, log4j2.properties를 수정하는 방법이 있다.
     * 현재 opensearch-config를 수정하는 방법과 dashboards ui에서 접근하여 설정하는 방법이 제대로 적용되지 않는 것을 확인하여 log4j2.properties를 수정하는 방법을 안내한다.  
     * log4j2.properties를 수정하는 방법: [opensearch-log4j2-config](yaml/opensearch-log4j2-config.yaml) Configmap을 예시와 같이 원하는 로그 레벨로 입력하여 추가시킨 후, opensearch에 mount시켜 적용한다.

ex1) log4j-config (log4j2.properies) Configmap 예시
             
	     
	     ```
             log4j2.properties: |
               status = error

               appender.console.type = Console
               appender.console.name = console
               appender.console.layout.type = PatternLayout
               appender.console.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %m%n

               rootLogger.level = error  ### 원하는 로그 레벨로 변경
               rootLogger.appenderRef.console.ref = console
	       
	     ```
		
	
ex2) 01_opensearch.yaml opensearch-log4j-config 마운트 적용 예시
	
	  
	    ```
	     volumeMounts:
	     - name: log4j2
               mountPath: /usr/share/opensearch/config/log4j2.properties
               subPath: log4j2.properties
	       
	     ...
	     
	     volumes:
	     - name: log4j2
               configMap:
               name: opensearch-log4j2-config

	     ```
* Opensearch-Dashboards: opensearch와는 다르게 log level을 지정하여 설정하지 않고 config 설정에서 원하는 log 설정에 true/false를 적용한다.
        
	ex) opensearch-dashboards-config (opensearch-dashboards.yml) Configmap 예시
	
	```
	    # Set the value of this setting to true to suppress all logging output.
        #logging.silent: false

        # Set the value of this setting to true to suppress all logging output other than error messages.
        #logging.quiet: false  ## log_level: warn/error 에 유사한 output

        # Set the value of this setting to true to log all events, including system usage information
        # and all requests.
        #logging.verbose: false ## log_level: trace/debug에 유사한 output
	```

* Fluentd: logger class는 fatal, error, warn, info, debug, trace 총 6단계로 구성되며 default log level 은 info이다. fluentd cli를 사용하거나 config file 을 통해서 수정 가능
    * config를 통한 log level 설정에 오류가 있어 fluentd command에 옵션을 추가하여 변경하는 방법을 안내한다.
    * [03_fluentd_cri-o.yaml](yaml/03_fluentd_cri-o.yaml)의 Daemonset에서 command에 원하는 log level에 맞는 옵션을 추가한다.
    * log level 별 옵션 참조: https://docs.fluentd.org/deployment/logging#by-command-line-option
    
    ex) fluentd Daemonset command 수정 예시, log level error 설정 (-qq 옵션 추가)
    
             ```
	     containers:
             - name: fluentd
               image: docker.io/tmaxcloudck/hypercloud:{FLUENTD_VERSION}        
               command: ["/bin/bash", "-c", "fluentd -qq -c /fluentd/etc/fluent.conf -p /fluentd/plugins"]

	     ```


* Index management policy 설정
    * watch-history-ilm-policy는 생성된 지 7일이 지난 인덱스는 자동으로 삭제한다.
    * policy를 수정하고 싶다면, Opensearch-dashboards에서 아래와 같이 Index Management > Index Policies 메뉴를 들어가서 watch-history-ilm-policy를 클릭한다.
    * 해당 페이지에서 Edit 버튼을 클릭하여 policy를 커스터마이징 후, Update를 클릭한다.
    ![image](figure/policy.png)
    * 변경된 policy가 기존 index에 적용되지 않은 경우
        * Index Management > Managed Indices > Change Policy를 클릭
        * 변경된 policy를 적용하려는 indices를 설정
        * New Policy에 watch-history-ilm-policy 적용 후 Change 클릭

* OpenSearch에 HTTP 콜 하는 방법
    * Opensearch-dashboards Management 메뉴에서 Dev Tools를 클릭한다.
    * HTTP 콜 작성 후 ▶ 버튼 클릭
    ![image](figure/dev-tools.png)

* 에러 해결법
    * Limit of total fields [1000] in index 에러
        * 원인 : 저장하려는 field 갯수가 index의 field limit보다 큰 경우
        * 해결 : index.mapping.total_fields.limit 증가 HTTP 콜 실행
        ```
        PUT {index 이름}/_settings
        {
            "index.mapping.total_fields.limit": 2000
        }
        ```
    * index read-only 에러
        * 원인 : 디스크 사용량이 flood-stage watermark 수치를 넘어서면 OS가 자동적으로 저장을 막음 (default 값은 95%)
        * 해결 (택1)
            * 필요없는 인덱스를 삭제해서 용량 확보
            	* dev-tools에서 HTTP 콜을 통해 인덱스 삭제
            	* ex) DELETE logstash-2022.01.01

            * HTTP콜을 통해 read-only 해제하기
            ![image](figure/read-only.png)
            ```
            PUT /{index 이름}/_settings
            {
                "index.blocks.read_only_allow_delete": null
            }
            ```

## Hyperauth selfsigned CA 설정
* 목적: hyperauth의 nip.io가 아닌 도메인에 대한 selfsigned_CA를 볼륨 마운트를 통해 opensearch와 hyperauth 연동을 하기 위함.
   * 단, 공인인증서 사용시에는 별도의 마운트를 적용하지 않아도 된다.
* 순서: 
1. [hyperauth-ca.yaml](yaml/hyperauth-ca.yaml)의 내용을 api-gateway-system 네임스페이스의 selfsigned-crt-secret 시크릿의 ca.crt로 수정한다.
   * 비고: hypercloud console ui로 조회한 시크릿의 ca.crt를 참조할 것.
2. hyperauth-ca.yaml을 실행
``` bash
$ kubectl apply -f hyperauth-ca.yaml
```
3. opensearch Statefulset의 볼륨 마운트 설정 및 ConfigMap인 opensearch-securityconfig를 수정한다.

* ex) opensearch statefulset 볼륨 & 마운트 추가
```
volumeMounts:
- name: hyperauth-ca
  mountPath: /usr/share/opensearch/config/certificates/hyperauth
  readOnly: true
volumes:
- name: hyperauth-ca
  secret:
    secretName: hyperauth-ca
```
opensearch-securityconfig 설정 추가
```
openid_connect_url: https://{HYPERAUTH_URL}/auth/realms/tmax/.well-known/openid-configuration
openid_connect_idp:         # 해당 내용 추가 필요
  enable_ssl: true          # 해당 내용 추가 필요
  verify_hostnames: false   # 해당 내용 추가 필요
  pemtrustedcas_filepath: /usr/share/opensearch/config/certificates/hyperauth/ca.crt # 해당 내용 추가 필요

```

4. 이후 install 가이드와 동일한 순서로 설치를 진행

* 비고: selfsigned 설정/또는 공인인증서 교체 이후 대시보드 접속했을 때 hyperauth와의 redirect에러(error 302) 발생 시,
     * 'kubectl exec -it os-cluster-0 -n kube-logging /bin/bash' 로 opensearch pod 접속 
     * 아래의 명령어 실행을 통해 securityconfig를 재설정한다.
     ```bash
     ./plugins/opensearch-security/tools/securityadmin.sh -cd ./plugins/opensearch-security/securityconfig/ -icl -nhnv -cacert ./config/certificates/admin/ca.crt -cert ./config/certificates/admin/tls.crt -key ./config/certificates/admin/tls.key

     ```
