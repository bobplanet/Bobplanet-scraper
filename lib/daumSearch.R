# 다음 이미지검색 API 라이브러리
# - 상세 스펙은 http://developers.daum.net/services/apis/search/image 참조

library(rvest)

DAUM_API_KEY <- Sys.getenv('DAUM_API_KEY')

# 다음 이미지 검색 API를 이용해서 이미지 및 썸네일주소 가져옴
imageSearch <- function(keyword) {
  url <- sprintf('https://apis.daum.net/search/image?apikey=%s&q=%s&result=1&output=xml',
                 DAUM_API_KEY, URLencode(keyword))
  r <- read_xml(url, encoding = 'utf-8')
  
  result <- tryCatch({
    list(
      image = r %>% xml_node(xpath = '//item/image') %>% xml_text,
      thumbnail = r %>% xml_node(xpath = '//item/thumbnail') %>% xml_text
    )
  }, error = function(e) {
    write(sprintf("No image for %s, error: %s", keyword, e), stderr())
    list(
      image = '',
      thumbnail = ''
    )
  })
  
  return(result)
}
