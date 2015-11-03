# 네이버 이미지 검색 API 모듈
# - 더이상 사용하지 않음. 이유는 https://github.com/bobplanet/Bobplanet/issues/39 참조
# - 스펙은 http://developer.naver.com/wiki/pages/SrchImage 참조

library(rvest)

NAVER_API_KEY <- Sys.getenv('NAVER_API_KEY')

# 네이버 이미지 검색 API를 이용해서 이미지 및 썸네일주소 가져옴
imageSearch <- function(keyword) {
  url <- sprintf('http://openapi.naver.com/search?key=%s&target=image&query=%s&display=1&filter=middle',
                 NAVER_API_KEY, URLencode(keyword))
  r <- read_xml(url, encoding='utf-8')
  
  result <- tryCatch({
    list(
      image = r %>% xml_node(xpath = '//item/link') %>% xml_text,
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
