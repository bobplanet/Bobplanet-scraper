# 메타데이터 관리. 데이터는 local sqlite db에 저장된다.

library(dplyr)
library(magrittr)
library(RSQLite)
library(stringr)

DB_MENU <- 'db/menu.sqlite3'
DDL_FILE <- 'db/menu_ddl.sql'

TAG <- 'metadata'

# DB 스키마 초기화
init <- function() {
  tryCatch({
    conn <- dbConnect(RSQLite::SQLite(), DB_MENU)
    
    readLines(DDL_FILE) %>% 
      paste(collapse=' ') %>% str_split(';') %>% unlist %>% str_trim %>% 
      Map(function(sql) {
        if (str_length(sql) > 0) { dbSendQuery(conn, sql) }
        }, .)
    
    dbClearResult(conn)
  }, finally = {
    dbDisconnect(conn)
  })
}

# 일간메뉴를 DB에 저장하면서 새로운 메뉴는 별도저장. 이 때 메뉴 아이콘도 업데이트함
updateMenu <- function(menu, search) {
  flog.info('%s$updateMenu() started.', TAG)
  
  db <- src_sqlite(DB_MENU)
  item <- tbl(db, 'item') %>% collect %T>% { Encoding(.$title) <- 'UTF-8' }
  
  # 추가된 메뉴 확인(서브메뉴 포함)
  titles <- c(menu$title, sapply(menu$submenu, `[[`, 'title') %>% unlist) %>% unique
  newitem <- data.frame(title = titles) %>% anti_join(item %>% select(title), copy = T)
  
  # 이미지 추가
  image <- Map(function(title) { search$imageSearch(title, 1) }, newitem$title) %>% Reduce(bind_rows, .)
  newitem$image <- image$image
  newitem$thumbnail <- image$thumbnail
  
  # DB에 저장
  .upsert(newitem, 'item', db)

  # 일간메뉴 저장
  menu %>% select(-submenu) %>% .upsert('menu', db)
  menu$submenu %>% Reduce(rbind, .) %>% .upsert('submenu', db)
  
  flog.info('%s$updateMenu() finished.', TAG)
  return(newitem)
}

# 주어진 dataframe을 DB테이블에 INSERT/REPLACE한다. 주로 데이터 추가할 때 사용.
.upsert <- function(df, tableName, db) {
  if (nrow(df) == 0) return()
  
  tempTableName <- sprintf("%s_temp", tableName)
  copy_to(db, df, tempTableName)
  
  dbSendQuery(db$con, sprintf("INSERT OR REPLACE INTO %s SELECT * FROM %s", tableName, tempTableName))
}

# 메뉴아이템 이미지 일괄 업데이트
updateImage <- function() {
  db <- src_sqlite(DB_MENU)
  item <- tbl(db, 'item') %>% collect %T>% { Encoding(.$title) <- 'UTF-8' }
  
  image <- Map(daum$imageSearch, item$title) %>% Reduce(bind_rows, .)
  item$image <- image$image
  item$thumbnail <- image$thumbnail

  .upsert(item, 'item', db)
}

# 전체 메뉴아이템 리스트 반환
getItem <- function() {
  db <- src_sqlite(DB_MENU)
  tbl(db, 'item') %>% collect %T>% { Encoding(.$title) <- 'UTF-8' }
}