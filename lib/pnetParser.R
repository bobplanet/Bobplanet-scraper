library(jsonlite)
library(rvest)
library(magrittr)
library(dplyr)
library(stringr)

HTML_DIR <- 'cache/html'

# 저장 디렉토리 없으면 만들고 시작
if (!dir.exists(HTML_DIR)) {
  dir.create(HTML_DIR, recursive = T)
}

# 일간메뉴 페이지를 읽어 메뉴내용(JSON)만 추출
getMenu <- function(sunday, nameCleanser) {
  sunday <- str_replace_all(sunday, '-', '')
  htmlFile <- sprintf('%s/%s.html', HTML_DIR, sunday)
  
  if (!file.exists(htmlFile)) {
    system2('lib/pnetScraper.bat', c(sunday, htmlFile))
  }
  html <- read_html(htmlFile, encoding='UTF-8', stderr=F)
  
  menu.raw <- .extractMenu(html)
  menu <- .toDataFrame(menu.raw, nameCleanser)

  return(menu)  
}

# HTML에서 JSON 추출
.extractMenu <- function(html) {
  script_text <- html %>% html_nodes(xpath = '//script[@type="text/javascript"]') %>% .[[4]]
  menu_text <- script_text %>% html_text %>% 
    ifelse(Sys.info()['sysname'] == 'Windows', iconv(., from = 'UTF-8'), .) %>% 
    strsplit('\r{0,1}\n') %>% .[[1]] %>% .[2:4] %>% 
    str_extract('\\[.*\\](?=;)') %>% 
    str_replace_all('new Date\\(([^)]*)\\)', '\\1')
  menu.raw <- lapply(menu_text, fromJSON)
}

# JSON에서 읽어낸 데이터를 human readable한 dataframe으로 변환
.toDataFrame <- function(menu.raw, nameCleanser) {
  whenTable <- c('아침', '점심', '저녁')

  menu <- menu.raw %>% 
    Map(. %>% transmute(
      id = CfMenuID,
      date = (CfMenu_Date / 1000) %>% as.POSIXct(origin='1970-01-01') %>% strftime('%Y-%m-%d'),
      when = whenTable[as.integer(CfMeal_Gubun)],
      type = CfMenu_Name,
      name = CfMenu_Food %>% str_trim %>% namer$cleanse(),
      origin = CfMenu_Origin %>% str_trim,
      submenu = MenuFoodList,
      calories = CfMenu_KCal
    ) %T>% {
      .$submenu <- lapply(.$submenu, function(x) { 
        if (length(x) > 0) {
          names(x) <- c('id', 'name', 'origin', 'menu.id') 
        }
        x$name <- namer$cleanse(x$name)
        x %>% filter(name != '')
      })
    }, .) %>% Reduce(rbind, .) %>% 
    filter(name != '') %>% 
    arrange(id)
  
  return(menu)
}