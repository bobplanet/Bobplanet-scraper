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
  item <- tbl(db, 'Item') %>% collect %T>% { Encoding(.$name) <- 'UTF-8' }
  
  # 추가된 메뉴 확인(서브메뉴 포함)
  names <- c(menu$name, sapply(menu$submenu, `[[`, 'name') %>% unlist) %>% unique
  newitem <- data.frame(name = names) %>% anti_join(item %>% select(name), copy = T)
  
  # 이미지 추가
  image <- Map(function(name) { search$imageSearch(name, 1) }, newitem$name) %>% Reduce(bind_rows, .)
  newitem$image <- image$image
  newitem$thumbnail <- image$thumbnail
  
  # DB에 저장
  .upsert(newitem, 'Item', db)

  # 일간메뉴 저장
  menu %>% select(-submenu) %>% .upsert('Menu', db)
  menu$submenu %>% Reduce(rbind, .) %>% .upsert('Submenu', db)
  
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
  item <- tbl(db, 'Item') %>% collect %T>% { Encoding(.$name) <- 'UTF-8' }
  
  image <- Map(daum$imageSearch, item$name) %>% Reduce(bind_rows, .)
  item$image <- image$image
  item$thumbnail <- image$thumbnail

  .upsert(item, 'Item', db)
}

# 전체 메뉴아이템 리스트 반환
getAllItem <- function() {
  db <- src_sqlite(DB_MENU)
  tbl(db, 'Item') %>% collect %T>% { Encoding(.$name) <- 'UTF-8' }
}

# 메뉴아이템 추가
upsertItem <- function(item) {
  db <- src_sqlite(DB_MENU)
  .upsert(item %>% select(name, image, thumbnail), 'Item', db)  
}

# 전체 메뉴아이템 삭제
deleteAllItem <- function() {
  db <- src_sqlite(DB_MENU)
  dbSendQuery(db$con, "DELETE FROM Item")
}

# 전체 메뉴 리스트 반환
getAllMenu <- function() {
  db <- src_sqlite(DB_MENU)
  tbl(db, 'Menu') %>% collect %T>% { 
    Encoding(.$name) <- 'UTF-8'
    Encoding(.$origin) <- 'UTF-8'
  }
}

# 메뉴 리스트 삽입
insertMenu <- function(menu) {
  db <- src_sqlite(DB_MENU)
  .upsert(menu %>% select(id, date, when, type, name, origin, calories), 'Menu', db)
}

# 전체 메뉴 삭제
deleteAllMenu <- function() {
  db <- src_sqlite(DB_MENU)
  dbSendQuery(db$con, 'DELETE FROM Menu')
}