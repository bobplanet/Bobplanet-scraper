# Windows용 환경설정: 날짜 parse할때 로케일 깨지는 문제 해결
if (Sys.info()['sysname'] == 'Windows') {
  Sys.setlocale('LC_TIME', 'C')
}

# stringsAsFactors 옵션 끔
options(stringsAsFactors=FALSE)

# HTTPS 통신을 위한 인증서 체크옵션 해제
options(RCurlOptions=list(ssl.verifypeer=FALSE))

# 공용 함수
loadModule <- function(Rfile) {
  write('Loading module %s', stderr())
  env <- new.env()
  source(Rfile, local = env, encoding = 'utf-8')
  return(env)
}