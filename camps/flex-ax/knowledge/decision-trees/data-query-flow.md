# 데이터 조회 흐름

```
flex-ax status 에 email/password 가 있는가? → 없으면 login 또는 env 설정 안내
DB(export)가 있는가? → 없으면 crawl + import 먼저 안내
export가 여러 개인가? → query 전에 OUTPUT_DIR 을 output/<customerIdHash> 로 지정
어떤 데이터? → 결재: instances/templates, 근태: attendance, 사용자: users
상세 필드? → field_values JOIN instances
```
