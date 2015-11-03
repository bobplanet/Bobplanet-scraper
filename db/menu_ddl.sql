DROP TABLE IF EXISTS menu;
CREATE TABLE menu(
  ID INTEGER PRIMARY KEY,
  date TEXT,
  "when" TEXT,
  "type" TEXT,
  title TEXT,
  origin TEXT,
  calories INTEGER
);

DROP TABLE IF EXISTS submenu;
CREATE TABLE submenu(
  ID INTEGER PRIMARY KEY,
  title TEXT,
  origin TEXT,
  menuID INTEGER
);

DROP TABLE IF EXISTS item;
CREATE TABLE item(
  title TEXT PRIMARY KEY,
  image TEXT,
  thumbnail TEXT
);

DROP TABLE IF EXISTS flagIcon;
CREATE TABLE flagIcon(
  nation TEXT PRIMARY KEY,
  iconURL TEXT
);
