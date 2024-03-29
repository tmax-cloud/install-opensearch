# Hyperauth-Opensearch 유저별 권한(role) 설정 가이드
* 목적: Opensearch Dashboards에서 Role을 생성 또는 수정하여 hyperauth 유저에게 매핑 적용을 통해 접근 권한을 설정한다.
* 유저 권한을 설정하기 위해서는 admin 권한을 가진 사용자로 접근해야한다.

## Hyperauth에 적용한 Opensearch Role 상세
* opensearch-admin : 전체 Plugin과 Index 관련 설정에 대한 Read, Write 권한 및 Security 설정을 통해 권한을 생성하고 매핑할 수 있는 Role
* opensearch-developer : Security 설정을 제외한 전체 Plugin과 Index에 대하여 Read, Write 권한을 가진 Role
* opensearch-guest : Security 설정을 제외한 전체 Plugin과 Index 관련 설정에 대하여 Read 권한을 가진 Role 

## Custom Role 생성 가이드 
### Step 1. Dashboards UI에서 Custom Role 생성
* Dashboards UI 메뉴에서 Security > Roles > Create Role을 클릭하여 Custom Role을 생성할 수 있다.
* 예시) Custom role "test" 생성
   * Name: 생성하고자 하는 Custom Role 이름
   * Cluster permissions: 클러스터 단위에서의 접근 권한
   * Index permissions: 인덱스 단위에서의 접근 권한, 특정 인덱스 패턴에 대한 접근 권한을 각각 지정할 수 있다.
   * Tenant permissions: 대시보드 내 스페이스(global 또는 private)에 대한 접근 권한
![image](../figure/create-role.png)

### Step 2. Custom Role을 Backend Role로 Mapping 적용
* Security > Roles> 생성한 Custom role을 클릭 > Mapped users > Manage mapping을 클릭한다.
* Backend roles에 Hyperauth에서 realm roles로 적용할 이름을 작성한 후 Map을 클릭한다.
* 예시) Backend roles "tmax"로 등록
![image](../figure/role-mapping.png)


### Step 3. Hyperauth 사용자에게 Role-Mapping 적용
* Hyperauth > Roles > Add Role로 Backend roles로 설정한 값과 동일한 이름으로 role을 생성한다.
* 해당 권한을 부여할 사용자의 Role Mappings 설정에서 Realm roles에 생성한 role을 적용한다.
![image](../figure/user-mapping.png)

* Dashboard에 새로 권한을 부여한 사용자 계정으로 로그인한다.
* 오른쪽 상단에 있는 계정 메뉴에서 "View roles and identities"를 클릭하여, 예시와 같이 새로 생성한 role이 적용되어 있는 것을 확인한다.
* 예시)
![image](../figure/check-roles.png)


## 비고
### Document Level 권한 설정
* 목적: Index Pattern을 지정하여 특정 log field에 대하여 원하는 값에 해당하는 로그 데이터만 확인하거나 그 값을 포함하지 않는 로그 데이터를 확인할 수 있는 권한을 준다.
* Dashboards UI를 통해 JSON 형태로 입력하여 설정한다.
* ex) metricbeat-* 의 인덱스에서 prometheus.labels.namespace의 값이 monitoring인 로그만 출력하도록 설정
![image](../figure/document-level.png)

### Field Level 권한 설정
* 목적: Index Pattern을 지정하여 특정 log field들을 지정하여 해당 log field만 출력하도록 하거나 해당 log field만 제외한 나머지만 확인할 수 있는 권한을 준다.
* Dashboards UI를 통해 include 또는 exclude 설정을 선택하여 적용하려는 log field를 입력하여 설정한다.
* ex) logstash-* 의 인덱스에서 @timestamp, kubernetes.host, kubernetes.container_name, kubernetes.pod_name, kubernetes.namespace_name, log, tag, stream, error log field만 출력하도록 설정
![image](../figure/field-level.png)
