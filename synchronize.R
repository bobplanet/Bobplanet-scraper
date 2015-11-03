# Datastore와 SQLite를 동기화
library(dplyr)
library(magrittr)
library(futile.logger)

loadModule <- function(Rfile) {
  flog.info('Loading module %s', Rfile)
  env <- new.env()
  source(Rfile, local = env, encoding = 'utf-8')
  return(env)
}

metadata <- loadModule('lib/metadata.R')
dataStore <- loadModule('lib/googleDataStore.R')

item <- dataStore$dumpKind('Item')
