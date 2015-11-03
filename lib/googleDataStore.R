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

.auth <- function() {
  server <- oauth_app('google', DATASTORE_API_KEY, DATASTORE_API_SECRET)
  token <- oauth2.0_token(oauth_endpoints('google'), server, scope = CLOUD_SCOPE)
  return(token)
}

token <- .auth()

# transaction 시작
.beginTransaction <- function() {
  r <- POST(DATASTORE_TX, config(token = token), content_type_json())
  stop_for_status(r)
  tx <- content(r)$transaction
  return(tx)
}

# 메뉴아이템 데이터 저장
uploadItem <- function(item) {
  flog.info('%s$uploadItem() started.', TAG)
  if (NROW(item) == 0) {
    flog.info("No new item exists", stderr())
    return()
  }
  
  upsert <- item %>% rowwise %>% transmute(
    key = list(list(path = list(kind = 'Item', name = title) %>% data.frame)),
    properties = list(list(
      image = list(stringValue = unbox(image), indexed = unbox(F)),
      thumbnail = list(stringValue = unbox(thumbnail), indexed = unbox(F))
    ))
  )

  # 트랜잭션 제한을 피하기 위해 20개 단위로 끊어서 저장
  n <- NROW(upsert)
  ntx <- 25
  Map(.commit, split(upsert, cut(1:n, seq(from = 1, to = n + ntx, by = ntx), right = F)))
  
  flog.info('%s$uploadItem() finished.', TAG)
}

# 메뉴 데이터 저장
uploadMenu <- function(menu) {
  flog.info('%s$uploadMenu() started.', TAG)
  
  upsert <- menu %>% rowwise %>% transmute(
    key = list(list(path = list(kind = 'Menu', id = ID) %>% data.frame)),
    properties = list(list(
      date = list(stringValue = unbox(date)),
      when = list(stringValue = unbox(when)),
      type = list(stringValue = unbox(type), indexed = unbox(F)),
      item = list(keyValue = list(path = list(kind = 'Item', name = title) %>% data.frame)),
      origin = list(stringValue = unbox(origin), indexed = unbox(F)),
      calories = list(integerValue = unbox(calories), indexed = unbox(F))
      ))
  )
  
  for (i in 1:length(menu$submenu)) {
    upsert$properties[[i]]$submenu$listValue <- 
        menu[i, ]$submenu[[1]] %>% rowwise %>% transmute(
          entityValue = list(list(
            properties = list(
              item = list(
                keyValue = list(path = list(kind = 'Item', name = title) %>% data.frame)
              ),
              origin = list(stringValue = unbox(origin))
            )
          ))
        )
  }

  .commit(upsert)
  
  flog.info('%s$uploadMenu() finished.', TAG)
}

# 특정 종류의 객체 전체 리스트를 data.frame 형태로 받아온다
dumpKind <- function(kind) {
  body <- list(
    query = list(
      kinds = data.frame(name = unbox(kind))
    )
  ) %>% toJSON
  
  r <- POST(DATASTORE_QUERY, body = body,
            config(token = token), c(content_type_json()))
  
  content(r)$batch$entityResults
  #fromJSON(content(r))
}

.commit <- function(upsert) {
  tx <- .beginTransaction()
  
  body <- list(
    transaction = unbox(tx),
    mutation = list(
      upsert = upsert
    )
  ) %>% toJSON
  
  r <- POST(DATASTORE_COMMIT, body = body,
            config(token = token), c(content_type_json()))
  
  if (status_code(r) != 200) {
    stop_for_status(r)
    flog.error("Datastore commit error: %s", content(r))
  }
}