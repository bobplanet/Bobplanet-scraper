# SQLite DB에 들어있는 메뉴 Item 데이터를 Google spreadsheet로 export

library(dplyr)
library(tidyr)
library(googlesheets)

SHEET_KEY <- '17BS_HH-P059K1IHzFRj3aKa6T12Cn_hu1aVEHWTJhN8'

metadata <- loadLib('lib/metadata.R')
search <- loadLib('lib/daumSearch.R')

# 데이터 생성 및 담당자 할당
team <- c('bigapple01', 'DoosikKim', 'dusskapark', 'hkjinlee', 'hoyoonjung', 'jhh7984', 'jinsueng', 'sjs1178') %>% sort
assignee <- sapply(team, rep, 106) %>% c(last(team))
item <- metadata$getItem() %>% arrange(title) %>% mutate(담당 = assignee) %>% 
  select(메뉴 = title, 담당, url = thumbnail)

# 대안이미지 URL 추가
item$urls <- Map(function(title) { 
  search$imageSearch(title, 10) %>% { 
    paste0(.$thumbnail, collapse='|') 
    }
  }, item$메뉴) %>% 
  unlist
item.url <- item %>% separate(urls, into = paste0('url', c(1:10)), sep = '\\|') %>% 
  mutate_each(funs(paste0('=IMAGE("', ., '", 3)')), contains('url'))

write.csv(item.url, 'cache/item.url.csv', row.names = F)

# 시트 로드
sheet <- gs_key(SHEET_KEY)

# 첫번째 worksheet에 데이터 부어넣기
gs_edit_cells(sheet, ws = 2, input = item.url)
