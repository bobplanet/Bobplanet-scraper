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
getMenu <- function(sunday) {
  sunday <- str_replace_all(sunday, '-', '')
  htmlFile <- sprintf('%s/%s.html', HTML_DIR, sunday)
  
  if (!file.exists(htmlFile)) {
    system2('lib/pnetScraper.bat', c(sunday, htmlFile))
  }
  html <- read_html(htmlFile, encoding='utf-8', stderr=F)
  
  menu.raw <- .extractMenu(html)
  menu <- .toDataFrame(menu.raw)

  return(menu)  
}

# HTML에서 JSON 추출
.extractMenu <- function(html) {
  script_text <- html %>% html_nodes(xpath='//script[@type="text/javascript"]') %>% .[[4]]
  menu_text <- script_text %>% html_text %>% iconv(from='utf-8') %>% 
    strsplit('\r\n') %>% .[[1]] %>% .[2:4] %>% 
    str_extract('\\[.*\\](?=;)') %>% 
    str_replace_all('new Date\\(([^)]*)\\)', '\\1')
  menu.raw <- lapply(menu_text, fromJSON)
}

# JSON에서 읽어낸 데이터를 human readable한 dataframe으로 변환
.toDataFrame <- function(menu.raw) {
  whenTable <- c('아침', '점심', '저녁')

  menu <- menu.raw %>% 
    Map(. %>% transmute(
      ID = CfMenuID,
      date = (CfMenu_Date / 1000) %>% as.POSIXct(origin='1970-01-01') %>% strftime('%Y-%m-%d'),
      when = whenTable[as.integer(CfMeal_Gubun)],
      type = CfMenu_Name,
      title = CfMenu_Food %>% str_trim,
      origin = CfMenu_Origin %>% str_trim,
      submenu = MenuFoodList,
      calories = CfMenu_KCal
    ) %T>% {
      .$submenu <- lapply(.$submenu, function(x) { 
        if (length(x) > 0) {
          names(x) <- c('ID', 'title', 'origin', 'menuID') 
        }
        x %>% filter(title != '')
      })
    }, .) %>% Reduce(rbind, .) %>% 
    filter(title != '') %>% 
    arrange(ID)
  
  return(menu)
}