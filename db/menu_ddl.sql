DROP TABLE IF EXISTS Menu;
CREATE TABLE Menu(
  id INTEGER PRIMARY KEY,
  date TEXT,
  "when" TEXT,
  "type" TEXT,
  "name" TEXT,
  origin TEXT,
  calories INTEGER
);

DROP TABLE IF EXISTS Submenu;
CREATE TABLE Submenu(
  id INTEGER PRIMARY KEY,
  "name" TEXT,
  origin TEXT,
  "menu.id" INTEGER
);

DROP TABLE IF EXISTS Item;
CREATE TABLE Item(
  "name" TEXT PRIMARY KEY,
  image TEXT,
  thumbnail TEXT
);
