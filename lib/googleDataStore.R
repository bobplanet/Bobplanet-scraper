# Google DataStore에 데이터를 저장/조회하는 모듈
# - REST API를 이용하므로 jsonlite 모듈을 이용해 JSON 객체를 data.frame과 상호변환함
# - DataStore API의 결과값 포맷은 https://cloud.google.com/datastore/docs/apis/v1beta2/?hl=ko 참조

library(httr)
library(jsonlite)
library(lubridate)

DATASTORE_API_KEY <- Sys.getenv('DATASTORE_API_KEY')
DATASTORE_API_SECRET <- Sys.getenv('DATASTORE_API_SECRET')
CLOUD_SCOPE <- 'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/cloud-platform'

DATASTORE_TX <- 'https://www.googleapis.com/datastore/v1beta2/datasets/kr-bobplanet/beginTransaction'
DATASTORE_COMMIT <- 'https://www.googleapis.com/datastore/v1beta2/datasets/kr-bobplanet/commit'
DATASTORE_QUERY <- 'https://www.googleapis.com/datastore/v1beta2/datasets/kr-bobplanet/runQuery'

TAG <- 'googleDataStore'

# OAuth 토큰 생성
# - 이 함수가 호출되면 브라우저가 열리면서 OAuth 인증을 수행하게 됨
# - 최초 인증의 경우는 브라우저 안에 떠있는 인증번호를 R console에서도 입력해 주어야 함
# - 한번 인증이 끝나면 .httr-oauth 파일에 관련 정보 캐싱
.auth <- function() {
  server <- oauth_app('google', DATASTORE_API_KEY, DATASTORE_API_SECRET)
  token <- oauth2.0_token(oauth_endpoints('google'), server, scope = CLOUD_SCOPE)
  return(token)
}
token <- .auth()

# 메뉴아이템(갈비탕, 육개장...) 데이터를 DataStore에 저장
upsertItem <- function(item) {
  flog.info('%s$upsertItem() started.', TAG)
  if (NROW(item) == 0) {
    flog.info("No new item exists", stderr())
    return()
  }
  
  upsert <- item %>% rowwise %>% transmute(
    key = list(list(path = list(kind = 'Item', name = name) %>% data.frame)),
    properties = list(list(
      image = list(stringValue = unbox(image), indexed = unbox(F)),
      thumbnail = list(stringValue = unbox(thumbnail), indexed = unbox(F))
    ))
  )

  # 트랜잭션 제한을 피하기 위해 25개 단위로 끊어서 저장
  n <- NROW(upsert)
  ntx <- 25
  Map(.commit, split(upsert, cut(1:n, seq(from = 1, to = n + ntx, by = ntx), right = F)))
  
  flog.info('%s$upsertItem() finished.', TAG)
}

# 메뉴아이템 데이터를 DataStore에서 삭제
deleteItem <- function(item) {
  flog.info('%s$deleteItem() started.', TAG)
  if (NROW(item) == 0) {
    flog.info("No item for delete", stderr())
    return()
  }
  
  delete <- item %>% rowwise %>% transmute(
    path = list(data.frame(kind = 'Item', name = name))
  )
  
  # 트랜잭션 제한을 피하기 위해 25개 단위로 끊어서 저장
  n <- NROW(delete)
  ntx <- 25
  Map(.commit, delete = split(delete, cut(1:n, seq(from = 1, to = n + ntx, by = ntx), right = F)))
  
  flog.info('%s$deleteItem() finished.', TAG)
}

# 일간메뉴 데이터 저장
upsertMenu <- function(menu) {
  flog.info('%s$uploadMenu() started.', TAG)
  
  upsert <- menu %>% rowwise %>% transmute(
    key = list(list(path = list(kind = 'Menu', id = id) %>% data.frame)),
    properties = list(list(
      date = list(stringValue = unbox(date)),
      when = list(stringValue = unbox(when)),
      type = list(stringValue = unbox(type), indexed = unbox(F)),
      item = list(keyValue = list(path = list(kind = 'Item', name = name) %>% data.frame)),
      origin = list(stringValue = unbox(origin), indexed = unbox(F)),
      calories = list(integerValue = unbox(calories), indexed = unbox(F))
      ))
  )
  
  if (!is.null(menu$submenu)) {
    for (i in 1:length(menu$submenu)) {
      upsert$properties[[i]]$submenu$listValue <- 
          menu[i, ]$submenu[[1]] %>% rowwise %>% transmute(
            entityValue = list(list(
              properties = list(
                item = list(
                  keyValue = list(path = list(kind = 'Item', name = name) %>% data.frame)
                ),
                origin = list(stringValue = unbox(origin))
              )
            ))
          )
    }
  }

  .commit(upsert)
  
  flog.info('%s$uploadMenu() finished.', TAG)
}

# 메뉴아이템(갈비탕, 육개장...) 데이터를 DataStore에 저장
upsertItemStat <- function(item) {
  flog.info('%s$upsertItemStat() started.', TAG)
  if (NROW(item) == 0) {
    flog.info("No new stat exists", stderr())
    return()
  }
  
  upsert <- item %>% rowwise %>% transmute(
    key = list(list(path = list(kind = 'ItemStat', name = name) %>% data.frame)),
    properties = list(list(
      cnt_day30 = list(integerValue = unbox(cnt_day30), indexed = unbox(F)),
      cnt_day90 = list(integerValue = unbox(cnt_day90), indexed = unbox(F)),
      cnt_day180 = list(integerValue = unbox(cnt_day180), indexed = unbox(F))
    ))
  )

  # 트랜잭션 제한을 피하기 위해 25개 단위로 끊어서 저장
  n <- NROW(upsert)
  ntx <- 25
  Map(.commit, split(upsert, cut(1:n, seq(from = 1, to = n + ntx, by = ntx), right = F)))
  
  flog.info('%s$upsertItemStat() finished.', TAG)
}

# DataStore에서 메뉴아이템 데이터를 받아 data.frame으로 변환
dumpItem <- function() {
  item <- .dumpKind('Item')

  item %>% Map(function(row) {
    entity <- row$entity
    list(
      name = entity$key$path[[1]]$name,
      image = entity$properties$image$stringValue,
      thumbnail = entity$properties$thumbnail$stringValue,
      averageScore = entity$properties$averageScore$doubleValue,
      numThumbUps = entity$properties$numThumbUps$integerValue,
      numThumbDowns = entity$properties$numThumbDowns$integerValue
    ) %>% lapply(function(x) ifelse(is.null(x), NA, x))
  }, .) %>% Reduce(bind_rows, .)
}

# transaction 시작
.beginTransaction <- function() {
  r <- POST(DATASTORE_TX, config(token = token), content_type_json())
  stop_for_status(r)
  tx <- content(r)$transaction
  return(tx)
}

# transaction commit
.commit <- function(upsert = NULL, delete = NULL) {
  tx <- .beginTransaction()
  
  body <- list(
    transaction = unbox(tx),
    mutation = list(
      upsert = upsert,
      delete = delete
    )
  ) %>% toJSON
  
  r <- POST(DATASTORE_COMMIT, body = body,
            config(token = token), c(content_type_json()))
  
  if (status_code(r) != 200) {
    stop_for_status(r)
    flog.error("Datastore commit error: %s", content(r))
  }
}

# 특정 kind의 데이터 조회
.dumpKind <- function(kind) {
  body <- list(
    query = list(
      kinds = data.frame(name = unbox(kind))
    )
  ) %>% toJSON
  
  r <- POST(DATASTORE_QUERY, body = body,
            config(token = token), c(content_type_json()))

  content(r)$batch$entityResults
}
