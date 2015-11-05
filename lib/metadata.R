# 메타데이터 관리. 데이터는 local sqlite db에 저장된다.

library(dplyr)
library(magrittr)
library(RSQLite)
library(stringr)

DB_MENU <- 'db/menu.sqlite3'
DDL_FILE <- 'db/menu_ddl.sql'

TAG <- 'metadata'

# 메뉴명에서 발견된 오타 교정
ERRATA <- c(
  '그랜샐러드'='그린샐러드', '꺳'='깻', '꺠'='깨', '깍뚜기'='깍두기', 
  '돈가스'='돈까스', '둥글레'='둥굴레', '다미사'='다시마', '떙'='땡', 
  '마늘쫑'='마늘종', '만둣'='만두', '메쉬드'='매쉬드', '매쉬([!드])'='매쉬드\\1',
  '메실'='매실', '메콤'='매콤', '무료동'='무교동', 
  '복음'='볶음', '부치'='부추',
  '소세지'='소시지', '스크램블([!드])'='스크램블드\\1', '쌈짱'='쌈장', 
  '어욱'='어묵', '엣날'='옛날', '우뷰'='유부', 
  '케찹'='케첩', '코올슬로'='코울슬로',
  'D$'='드레싱', 'S$'='소스'
)

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
getAllItem <- function() {
  db <- src_sqlite(DB_MENU)
  tbl(db, 'item') %>% collect %T>% { Encoding(.$title) <- 'UTF-8' }
}

# 전체 메뉴 리스트 반환
getAllMenu <- function() {
  db <- src_sqlite(DB_MENU)
  tbl(db, 'menu') %>% collect %T>% { 
    Encoding(.$title) <- 'UTF-8'
    Encoding(.$origin) <- 'UTF-8'
  }
}

# 메뉴명 클렌징
# - 괄호수식어 제거: '(양은)김치찌개' => '김치찌개'
# - 스페이스/특수문자 제거: '계란후라이 ' => '계란후라이'
# - 맨 마지막의 특수문자 제거: '커피*' => '커피'
# - 오타/네이밍 교정: '우뷰우동' => '유부우동'
cleanseTitle <- function(title) {
  title %>% 
    str_replace('^\\(.*\\)', '') %>% 
    str_replace('[ `!?]', '') %>% 
    str_replace('[&*]$', '') %>% 
    str_replace_all(ERRATA)
}
