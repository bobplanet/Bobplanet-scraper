suppressPackageStartupMessages(library(optparse))

# command line argument 처리
option_list <- list(
  make_option(c('-i', '--init'), action='store_true', default=FALSE, help='Initializes databases'),
  make_option(c('-b', '--before'), type='integer', default=0, help='Fetches menu of N weeks before')
)
opt <- parse_args(OptionParser(option_list = option_list))

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(futile.logger))

metadata <- loadModule('lib/metadata.R')

# 실행환경 초기화
if (opt$init) {
  flog.info('Initializing database...')
  metadata$init()
  flog.info('Database initialization finished.')
  quit()
}

pnetParser <- loadModule('lib/pnetParser.R')
dataStore <- loadModule('lib/googleDataStore.R')
daum <- loadModule('lib/daumSearch.R')

# argument가 없을 경우 가장 가까운 미래의 일요일을 기준일로 한다
sunday <- today() - wday(today()) + 8
# argument가 있을 경우 현재 시점부터 offset만큼 떨어져있는 주의 일요일이 기준일이 된다
sunday <- sunday - opt$before * 7

# P넷에서 일간메뉴를 가져온다
menu <- pnetParser$getMenu(sunday)

# 메뉴 업데이트(새로 등장한 메뉴 있을 수 있으므로)
newitem <- metadata$updateMenu(menu, daum)

# 구글 서버에 업로드
dataStore$uploadMenu(menu)
dataStore$uploadItem(newitem)
