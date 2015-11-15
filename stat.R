library(dplyr)
library(tidyr)
library(lubridate)
library(arules)
library(futile.logger)

source('env.R')

metadata <- loadLib('lib/metadata.R')
dataStore <- loadLib('lib/googleDataStore.R')

item <- metadata$getAllItem()
menu <- metadata$getAllMenu()
submenu <- metadata$getAllSubmenu()

# 30일, 90일, 180일 사이에 몇 번 등장했는지 카운팅해서 DataStore에 업로드
period <- c(30, 90, 180)
ymd.period <- today() - period

item.stat.cnt <- menu %>% group_by(name) %>% 
  summarise(cnt_day30 = length(name[date >= ymd.period[1]]),
            cnt_day90 = length(name[date >= ymd.period[2]]),
            cnt_day180 = length(name[date >= ymd.period[3]]))
dataStore$upsertItemStat(item.stat.cnt)

# 함께 서빙되는 메뉴 분석. 아직 작업중임.
item.txset <- menu %>% left_join(submenu, by=c('id' = 'menu.id')) %>% 
  group_by(id) %>% summarise(name = min(name.x), submenu = paste0(name.y, collapse=',')) %>% 
  transmute(items = paste(name, submenu, sep=','))

FILE <- 'tx.txt'
write.table(item.txset, FILE, row.names = F, col.names = F, quote = F)
tx <- read.transactions(FILE, format = 'basket', sep = ',', rm.duplicates = T, encoding = 'UTF-8')

itemInfo(tx)
nitems(tx)
inspect(tx)
rules <- apriori(tx, parameter = list(support=.01, conf=.05, minlen=2, maxlen=2, target='frequent itemsets'))
inspect(rules)
