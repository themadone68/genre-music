CREATE TABLE users (userid NOT NULL UNIQUE PRIMARY KEY,name NOT NULL,email NOT NULL UNIQUE,password NOT NULL);
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
CREATE TABLE roles (roleid NOT NULL UNIQUE PRIMARY KEY,name);
CREATE TABLE role_members (roleid NOT NULL,userid NOT NULL);

DROP TRIGGER users_userid_upd;
CREATE TRIGGER users_userid_upd AFTER UPDATE OF userid ON users
  FOR EACH ROW BEGIN
    UPDATE sessions SET userid=new.userid WHERE userid=old.userid;
    UPDATE songs SET addedby=new.userid WHERE addedby=old.userid;
    UPDATE albums SET addedby=new.userid WHERE addedby=old.userid;
    UPDATE artists SET addedby=new.userid WHERE addedby=old.userid;
    UPDATE songs SET moderatedby=new.userid WHERE moderatedby=old.userid;
    UPDATE albums SET moderatedby=new.userid WHERE moderatedby=old.userid;
    UPDATE artists SET moderatedby=new.userid WHERE moderatedby=old.userid;
    UPDATE song_tags SET addedby=new.userid WHERE addedby=old.userid;
    UPDATE album_tags SET addedby=new.userid WHERE addedby=old.userid;
    UPDATE artist_tags SET addedby=new.userid WHERE addedby=old.userid;
    UPDATE role_members SET userid=new.userid WHERE userid=old.userid;
  END;

DROP TRIGGER songs_songid_upd;
CREATE TRIGGER songs_songid_upd AFTER UPDATE OF songid ON songs
  FOR EACH ROW BEGIN
    UPDATE song_tags SET songid=new.songid WHERE songid=old.songid;
    UPDATE song_contributors SET songid=new.songid WHERE songid=old.songid;
    UPDATE song_links SET songid=new.songid WHERE songid=old.songid;
    UPDATE album_songs SET songid=new.songid WHERE songid=old.songid;
  END;
DROP TRIGGER songs_songid_del;
CREATE TRIGGER songs_songid_del AFTER DELETE ON songs
  FOR EACH ROW BEGIN
    DELETE FROM song_tags WHERE songid=old.songid;
    DELETE FROM song_contributors WHERE songid=old.songid;
    DELETE FROM song_links WHERE songid=old.songid;
    DELETE FROM album_songs WHERE songid=old.songid;
  END;
DROP TRIGGER albums_albumid_upd;
CREATE TRIGGER albums_albumid_upd AFTER UPDATE OF albumid ON albums
  FOR EACH ROW BEGIN
    UPDATE album_tags SET albumid=new.albumid WHERE albumid=old.albumid;
    UPDATE album_links SET albumid=new.albumid WHERE albumid=old.albumid;
    UPDATE album_songs SET albumid=new.albumid WHERE albumid=old.albumid;
  END;
DROP TRIGGER albums_albumid_del;
CREATE TRIGGER albums_albumid_del AFTER DELETE ON albums
  FOR EACH ROW BEGIN
    DELETE FROM album_tags WHERE albumid=old.albumid;
    DELETE FROM album_links WHERE albumid=old.albumid;
    DELETE FROM album_songs WHERE albumid=old.albumid;
  END;
DROP TRIGGER artists_artistid_upd;
CREATE TRIGGER artists_artistid_upd AFTER UPDATE OF artistid ON artists
  FOR EACH ROW BEGIN
    UPDATE artist_tags SET artistid=new.artistid WHERE artistid=old.artistid;
    UPDATE artist_links SET artistid=new.artistid WHERE artistid=old.artistid;
    UPDATE song_contributors SET artistid=new.artistid WHERE artistid=old.artistid;
  END;
DROP TRIGGER artists_artistid_del;
CREATE TRIGGER artists_artistid_del AFTER DELETE ON artists
  FOR EACH ROW BEGIN
    DELETE FROM artist_tags WHERE artistid=old.artistid;
    DELETE FROM artist_links WHERE artistid=old.artistid;
    DELETE FROM song_contributors WHERE artistid=old.artistid;
  END;

DROP TRIGGER roles_roleid_upd;
CREATE TRIGGER roles_roleid_upd AFTER UPDATE OF roleid ON roles
  FOR EACH ROW BEGIN
    UPDATE role_members SET roleid=new.userid WHERE roleid=old.userid;
  END;
