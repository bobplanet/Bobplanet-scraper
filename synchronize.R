# Datastore와 SQLite를 동기화
# 아직 개발중임

library(dplyr)
library(magrittr)
library(futile.logger)

source('env.R')

metadata <- loadLib('lib/metadata.R')
dataStore <- loadLib('lib/googleDataStore.R')

item <- dataStore$dumpItem()
