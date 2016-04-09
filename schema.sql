CREATE TABLE users (userid NOT NULL UNIQUE PRIMARY KEY,name NOT NULL,email NOT NULL,password NOT NULL);
CREATE TABLE sessions (sessionid NOT NULL UNIQUE PRIMARY KEY,userid NOT NULL,password NOT NULL,created INTEGER,last_active INTEGER,last_cookie INTEGER,ipaddr NOT NULL);
CREATE TABLE songs (songid INTEGER NOT NULL UNIQUE PRIMARY KEY,name NOT NULL,description,addedby NOT NULL,added INTEGER NOT NULL,moderatedby NOT NULL,moderated INTEGER);
CREATE TABLE albums (albumid INTEGER NOT NULL UNIQUE PRIMARY KEY,name NOT NULL,description,addedby NOT NULL,added INTEGER NOT NULL,moderatedby NOT NULL,moderated INTEGER);
CREATE TABLE artists (artistid INTEGER NOT NULL UNIQUE PRIMARY KEY,name NOT NULL,description,addedby NOT NULL,added INTEGER NOT NULL,moderatedby NOT NULL,moderated INTEGER);
CREATE TABLE song_tags (songid INTEGER NOT NULL,tag NOT NULL,addedby NOT NULL,added INTEGER NOT NULL);
CREATE TABLE album_tags (albumid INTEGER NOT NULL,tag NOT NULL,addedby NOT NULL,added INTEGER NOT NULL);
CREATE TABLE artist_tags (artistid INTEGER NOT NULL,tag NOT NULL,addedby NOT NULL,added INTEGER NOT NULL);
CREATE TABLE song_contributors (songid INTEGER NOT NULL,artistid INTEGER NOT NULL,relationship NOT NULL);
CREATE TABLE album_songs (albumid INTEGER NOT NULL,songid INTEGER NOT NULL);
CREATE TABLE song_links (songid INTEGER NOT NULL,url NOT NULL);
CREATE TABLE album_links (albumid INTEGER NOT NULL,url NOT NULL);
CREATE TABLE artist_links (artistid INTEGER NOT NULL,url NOT NULL);

DROP TRIGGER users_userid_upd;
CREATE TRIGGER users_userid_upd AFTER UPDATE OF userid ON users
  FOR EACH ROW BEGIN
    UPDATE sessions SET userid=new.userid WHERE userid=old.userid;
  END;

DROP TRIGGER songs_songid_upd;
CREATE TRIGGER songs_songid_upd AFTER UPDATE OF songid ON songs
  FOR EACH ROW BEGIN
    UPDATE song_tags SET songid=new.songid WHERE userid=old.songid;
    UPDATE song_contributors SET songid=new.songid WHERE userid=old.songid;
    UPDATE song_links SET songid=new.songid WHERE userid=old.songid;
    UPDATE album_songs SET songid=new.songid WHERE userid=old.songid;
  END;
