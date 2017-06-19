CREATE DATABASE camtriggers;
GRANT ALL PRIVILEGES ON camtriggers.* TO 'camtriggers'@'%' IDENTIFIED BY 'somepass';

USE camtriggers;
CREATE TABLE IF NOT EXISTS `triggers` (
  `timestamp` int(11) DEFAULT NULL,
  `camip` varchar(16) NOT NULL,
  `origin` varchar(64) NOT NULL,
  `comment` varchar(200) NOT NULL,
  KEY `timestamp` (`timestamp`,`camip`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


