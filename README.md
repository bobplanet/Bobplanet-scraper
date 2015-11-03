# 프로젝트 개요
- P넷의 10층식당 메뉴 페이지를 scrape하여 Google Cloud의 DataStore로 업로드
 - 따라서, P넷 접근이 가능한 위치에서 실행되어야 함
 - 현재 작성된 프로그램은 VDI의 Windows 머신에서 실행
 - 매주 금요일 정도에는 다음주 메뉴가 올라오므로 매주 토요일 새벽에 batch 실행
- 로컬환경에서의 용이한 데이터분석을 위해 데이터사본은 local의 SQLite에도 저장
 - 단, 하나의 컬럼이 여러개의 entity를 가질 수 없는 RDB의 한계상 child 테이블로 분리

# 파일 설명
- /
 - scraper.bat: 실제로 P넷 데이터를 긁어 DataStore까지 업로드. 관리자가 아닌 사람이 호출할 일은 없음
 - scraper.R: scraper.bat이 호출하는 R 스크립트
 - synchronize.R: DataStore에 업로드되어있는 데이터를 local SQLite로 다운로드
- lib/
 - daumSearch.R: 다음 이미지검색 API 구현
 - googleCloudMessage.R: GCM을 이용한 푸시메시지 발송. 해당 기능이 Bobplanet​ 서버에서 구현되어 deprecated
 - googleDataStore.R: Google DataStore에 데이터를 저장/조회
 - metadata.R: local SQLite DB에 메타데이터를 관리
 - naverSearch.R: 네이버 이미지검색 API 구현
 - pnetParser.R: P넷에서 받은 메뉴 HTML을 parse하여 data.frame으로 변환
- cache/
 - html/: P넷에서 다운로드받은 메뉴화면 HTML 원본
- curl/*: Windows에는 Curl이 기본제공되지 않으므로 별도 executable을 이용
- db/
 - menu_ddl.sql: SQLite DB의 schema​ 생성용​ DDL

# 주의사항
- 오픈API 호출을 위해 필요한 API key는 git에 저장하지 않고 별도 관리
- 데이터 조회/저장, 이미지검색 API 호출 등의 기능까지 이용하려면 진헌규(heonkyu.jin@gmail.com)에게 파일 요청할 것

# git 저장소 위치
- Bobplanet 안드로이드 앱과는 별개의 저장소로 관리함
