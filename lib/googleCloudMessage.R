library(dplyr)
library(httr)
library(jsonlite)

API_URL <- 'https://android.googleapis.com/gcm/send'

GCM_API_KEY <- Sys.getenv('GCM_API_KEY')
GCM_API_KEY_DEV <- Sys.getenv('GCM_API_KEY_DEV')

buildMessage <- function(menu_id, title = '', text = '', detail = '') {
  list(type = unbox('server'),
       menuId = unbox(menu_id),
       title = unbox(title), 
       text = unbox(text), 
       detail = unbox(detail)
       )
}

send <- function(to, message) {
  body <- list(to = unbox(to), 
               data = message) %>% toJSON
  
  r <- POST(API_URL,
            add_headers(Authorization = sprintf('key=%s', API_KEY)),
            content_type_json(),
            verbose(),
            body = body
            )
  content(r)
}

message <- buildMessage(2229, title='오늘의 점심메뉴: 카레라이스')  
send('/topics/global', message)
