# 다음 이미지검색 API 라이브러리
# - 상세 스펙은 http://developers.daum.net/services/apis/search/image 참조

library(magrittr)
library(rvest)

DAUM_API_KEY <- Sys.getenv('DAUM_API_KEY')

# 다음 이미지 검색 API를 이용해서 이미지 및 썸네일주소 가져옴
imageSearch <- function(keyword, n = 1) {
  url <- sprintf('https://apis.daum.net/search/image?apikey=%s&q=%s&result=%d&output=xml',
                 DAUM_API_KEY, URLencode(keyword), n)
  r <- read_xml(url, encoding = 'utf-8')
  
  result <- tryCatch({
    data.frame(
      image = r %>% xml_nodes(xpath = '//item/image') %>% sapply(xml_text),
      thumbnail = r %>% xml_nodes(xpath = '//item/thumbnail') %>% sapply(xml_text)
    ) %T>% {
      if (NROW(.) == 0) {
        stop('No image found')
      }
    }
  }, error = function(e) {
    write(sprintf("Image fetch error for %s, error: %s", keyword, e), stderr())
    data.frame(
      image = '',
      thumbnail = ''
    )
  })
  
  return(result)
}
