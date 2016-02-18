USE modelhub;

# START UTILS

DROP PROCEDURE IF EXISTS test_opUuid;
DELIMITER $$
CREATE PROCEDURE test_opUuid()
BEGIN
	#generates a valid uuid
	IF NOT(HEX(opUuid()) REGEXP '^[0-9a-fA-F]{32}$') THEN
		CALL STOP_TEST_FAILED();
	END IF;
END $$
DELIMITER ;
CALL test_opUuid();
DROP PROCEDURE IF EXISTS test_opUuid;


DROP PROCEDURE IF EXISTS test_createTempIdsTable;
DELIMITER $$
CREATE PROCEDURE test_createTempIdsTable()
BEGIN
	DECLARE expectedUuid1 VARCHAR(32) DEFAULT '0123456789abcdef0123456789abcdef';
	DECLARE expectedUuid2 VARCHAR(32) DEFAULT 'fedcba9876543210fedcba9876543210';
	DECLARE errorInvalidCharUuid VARCHAR(32) DEFAULT 'GGGcba9876543210fedcba9876543210';
	DECLARE errorShortUuid VARCHAR(32) DEFAULT 'edcba987654321';
	DECLARE errorLongUuid VARCHAR(60) DEFAULT 'edcba987654321123123123123123123123123123123123123123';
	DECLARE actualUuid VARCHAR(32) DEFAULT NULL;
    DECLARE tableLength INT DEFAULT NULL;
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45001 SELECT TRUE INTO errorReceiver;
	
    #generates correct table with only one uuid
	IF NOT(createTempIdsTable(expectedUuid1)) THEN
		CALL STOP_TEST_FAILED();
	END IF;
    
    SELECT COUNT(*), HEX(id) INTO tableLength, actualUuid FROM tempIds;
    IF tableLength != 1 OR actualUuid != expectedUuid1 THEN
		CALL STOP_TEST_FAILED();
    END IF;
	
    #generates correct table with more than one uuid
	IF NOT(createTempIdsTable(CONCAT(expectedUuid1, ',', expectedUuid2))) THEN
		CALL STOP_TEST_FAILED();
	END IF;
    
    SELECT COUNT(*) INTO tableLength FROM tempIds;
    IF tableLength != 2 THEN
		CALL STOP_TEST_FAILED();
    END IF;
    
    SELECT HEX(id) INTO actualUuid FROM (SELECT id FROM tempIds LIMIT 0, 1) AS firstTempId;
    IF actualUuid != expectedUuid1 THEN
		CALL STOP_TEST_FAILED();
    END IF;  
    
    SELECT HEX(id) INTO actualUuid FROM (SELECT id FROM tempIds LIMIT 1, 1) AS secondTempId;
    IF actualUuid != expectedUuid2 THEN
		CALL STOP_TEST_FAILED();
    END IF;  
    
    # fails to generate table with invalid character uuid
	IF createTempIdsTable(errorInvalidCharUuid) THEN
		CALL STOP_TEST_FAILED();
	END IF;
    
    # fails to generate table with short uuid
	IF createTempIdsTable(errorShortUuid) THEN
		CALL STOP_TEST_FAILED();
	END IF;
    
    # fails to generate table with long uuid
	IF createTempIdsTable(errorLongUuid) THEN
		CALL STOP_TEST_FAILED();
	END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END $$
DELIMITER ;
CALL test_createTempIdsTable();
DROP PROCEDURE IF EXISTS test_createTempIdsTable;

# END UTILS

# START PERMISSION

DROP PROCEDURE IF EXISTS test_permissions_and_invitations;
DELIMITER $$
CREATE PROCEDURE test_permissions_and_invitations()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
	
    IF _permission_getRole(UNHEX(ashId), UNHEX(ashProjId), UNHEX(ashId)) != 'owner' THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    IF _permission_getRole(UNHEX(ashId), UNHEX(ashProjId), UNHEX(bobId)) IS NOT NULL THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    IF _permission_getRole(UNHEX(ashId), UNHEX(bobProjId), UNHEX(bobId)) IS NOT NULL THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #ash trys to add bob to her project as an admin, EXPECT: success, ash is the owner on her project so can add admins
	CALL projectAddAdmins(ashId, ashProjId, bobId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(bobId) AND role = 'admin') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(bobId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #bob accepts the invitation, EXPECT invitation row has gone and permission row has been inserted
    CALL projectAcceptInvitation(bobId, ashProjId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(bobId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(bobId) AND role = 'admin') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    IF _permission_getRole(UNHEX(ashId), UNHEX(ashProjId), UNHEX(bobId)) != 'admin' THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #ash trys to add bob to ash's project as an admin again, EXPECT: no change, making duplicate calls has no side effects, no new invitation created, no new permission created
	CALL projectAddAdmins(ashId, ashProjId, bobId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(bobId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(bobId) AND role = 'admin') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #ash trys to add cat to ash's project as an admin, EXPECT: success, ash is the owner on her project so can add admins
	CALL projectAddAdmins(ashId, ashProjId, catId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId) AND role = 'admin') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #cat declines the invitation, EXPECT invitation row has gone and no permission row has been created
    CALL projectDeclineInvitation(catId, ashProjId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #ash trys to add cat to bob's project, EXPECT: no invitation or permissions are created as ash is not an owner or admin on bobs project
	CALL projectAddObservers(ashId, bobProjId, catId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(bobProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(bobProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #bob trys to add cat to ash's project as an owner, EXPECT: cat is not added as bob is an admin and so can not add owners
	CALL projectAddOwners(bobId, ashProjId, catId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #bob trys to add cat to ash's project as an admin, EXPECT: cat is not added as bob is an admin and so can not add other admins
	CALL projectAddAdmins(bobId, ashProjId, catId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #bob trys to add cat to ash's project as an organiser, EXPECT: cat is added as bob is an admin and so can add organisers
	CALL projectAddOrganisers(bobId, ashProjId, catId);
    CALL projectAcceptInvitation(catId, ashProjId);
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId) AND role = 'organiser') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #bob trys to change cat to a contributor in ash's project, EXPECT: cat is changed to a contributor as bob is an admin and so can change non owners/admins to contributors
	CALL projectAddContributors(bobId, ashProjId, catId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId) AND role = 'contributor') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #bob trys to change cat to an observer in ash's project, EXPECT: cat is changed to an observer as bob is an admin and so can change non owners/admins to observers
	CALL projectAddObservers(bobId, ashProjId, catId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId) AND role = 'observer') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #bob trys to remove cat from ash's project, EXPECT: cat is removed as bob is an admin and so can remove non owners/admins
	CALL projectRemoveUsers(bobId, ashProjId, catId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #bob trys to remove ash from ash's project, EXPECT: ash is still an owner as bob is an admin and so can not remove owners
	CALL projectRemoveUsers(bobId, ashProjId, ashId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(ashId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(ashId) AND role = 'owner') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #ash trys to add cat to her project as an owner, EXPECT: cat is added as an owner
	CALL projectAddOwners(ashId, ashProjId, catId);
    CALL projectAcceptInvitation(catId, ashProjId);
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId) AND role = 'owner') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #cat trys to remove both bob and ash from ash's project, EXPECT: ash and bob are removed as cat is an owner on ash's project and so can remove anyone
	CALL projectRemoveUsers(catId, ashProjId, CONCAT(ashId, ',', bobId));
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user IN (UNHEX(ashId),UNHEX(bobId))) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user IN (UNHEX(ashId),UNHEX(bobId))) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #cat trys to remove herself from ash's project, EXPECT: cat is not removed as she is the last owner
	CALL projectRemoveUsers(catId, ashProjId, catId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId) AND role = 'owner') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #cat adds ash back into ash's project as an owner, EXPECT: ash is added as an owner to ash's project
	CALL projectAddOwners(catId, ashProjId, ashId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(ashId) AND role = 'owner') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(ashId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #ash accepts the invitation, EXPECT invitation row has gone and permission row has been inserted
    CALL projectAcceptInvitation(ashId, ashProjId);
    IF (SELECT COUNT(*) FROM invitation WHERE project = UNHEX(ashProjId) AND user = UNHEX(ashId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(ashId) AND role = 'owner') != 1 THEN
		CALL STOP_TEST_FAIL();
    END IF;
	
    #cat trys to remove herself from ash's project, EXPECT: cat is removed as she is no longer the only owner
	CALL projectRemoveUsers(catId, ashProjId, catId);
    IF (SELECT COUNT(*) FROM permission WHERE project = UNHEX(ashProjId) AND user = UNHEX(catId)) != 0 THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_permissions_and_invitations();
DROP PROCEDURE IF EXISTS test_permissions_and_invitations;

# END PERMISSION

# START USER

DROP PROCEDURE IF EXISTS test_userLogin;
DELIMITER $$
CREATE PROCEDURE test_userLogin()
BEGIN
	DECLARE _id BINARY(16) DEFAULT NULL;
	DECLARE _autodeskId VARCHAR(50) DEFAULT NULL;
	DECLARE _openId VARCHAR(500) DEFAULT NULL;
	DECLARE _username VARCHAR(100) DEFAULT NULL;
	DECLARE _avatar VARCHAR(500) DEFAULT NULL;
	DECLARE _fullName VARCHAR(100) DEFAULT NULL;
	DECLARE _email VARCHAR(100) DEFAULT NULL;
	DECLARE _superUser BOOL DEFAULT NULL;
	DECLARE _lastLogin DATETIME DEFAULT NULL;
	DECLARE _description VARCHAR(250) DEFAULT NULL;
	DECLARE _uiLanguage VARCHAR(10) DEFAULT NULL;
	DECLARE _uiTheme VARCHAR(10) DEFAULT NULL;
	DECLARE _locale VARCHAR(10) DEFAULT NULL;
	DECLARE _timeFormat VARCHAR(20) DEFAULT NULL;
    
    SELECT '<someUuid>, ash username, ash avatar, ash fullName, FALSE, NULL, en, dark, en-US, llll';
	CALL userLogin('ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email');
    
    SELECT 
		id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, email, description, uiLanguage, uiTheme, locale, timeFormat
	INTO
		_id, _autodeskId, _openId, _username, _avatar, _fullName, _email, _superUser, _lastLogin, _email, _description, _uiLanguage, _uiTheme, _locale, _timeFormat
	FROM
		user
	WHERE
		autodeskId = 'ash autodeskId';
    
    IF _autodeskId != 'ash autodeskId' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _openId != 'ash openId' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _username != 'ash username' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _avatar != 'ash avatar' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _fullName != 'ash fullName' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _email != 'ash email' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _superUser != FALSE THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _description != '' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _uiLanguage != 'en' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _uiTheme != 'dark' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _locale != 'en-US' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _timeFormat != 'llll' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    UPDATE
		user SET superUser = TRUE, description = 'description edit', uiLanguage = 'en edit', uiTheme = 'dark edit', locale = 'en-US edit', timeFormat = 'llll edit'
	WHERE
		autodeskId = 'ash autodeskId';
    
    
    SELECT SLEEP(1);
    
    SELECT '<someUuid>, ash username edit, ash avatar edit, ash fullName edit, TRUE, description edit, en edit, dark edit, en-US edit, llll edit';
	CALL userLogin('ash autodeskId', 'ash openId edit', 'ash username edit', 'ash avatar edit', 'ash fullName edit', 'ash email edit');
    
    SELECT 
		id, autodeskId, openId, username, avatar, fullName, email, superUser, email, description, uiLanguage, uiTheme, locale, timeFormat
	INTO
		_id, _autodeskId, _openId, _username, _avatar, _fullName, _email, _superUser, _email, _description, _uiLanguage, _uiTheme, _locale, _timeFormat
	FROM
		user
	WHERE
		autodeskId = 'ash autodeskId';
    
    IF _autodeskId != 'ash autodeskId' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _openId != 'ash openId edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _username != 'ash username edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _avatar != 'ash avatar edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _fullName != 'ash fullName edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _email != 'ash email edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _superUser != TRUE THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _lastLogin = (SELECT lastLogin FROM user WHERE autodeskId = 'ash autodeskId') THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _description != 'description edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _uiLanguage != 'en edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _uiTheme != 'dark edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _locale != 'en-US edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF _timeFormat != 'llll edit' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
END $$
DELIMITER ;
CALL test_userLogin();
DROP PROCEDURE IF EXISTS test_userLogin;

DROP PROCEDURE IF EXISTS test_userSetDescription;
DELIMITER $$
CREATE PROCEDURE test_userSetDescription()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
        
	CALL userSetDescription(ashId, 'my new description');
    
    IF (SELECT description FROM user WHERE id = UNHEX(ashId)) != 'my new description' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
END $$
DELIMITER ;
CALL test_userSetDescription();
DROP PROCEDURE IF EXISTS test_userSetDescription;

DROP PROCEDURE IF EXISTS test_userSetUILanguage;
DELIMITER $$
CREATE PROCEDURE test_userSetUILanguage()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
        
	CALL userSetUILanguage(ashId, 'de');
    
    IF (SELECT uiLanguage FROM user WHERE id = UNHEX(ashId)) != 'de' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
END $$
DELIMITER ;
CALL test_userSetUILanguage();
DROP PROCEDURE IF EXISTS test_userSetUILanguage;

DROP PROCEDURE IF EXISTS test_userSetUITheme;
DELIMITER $$
CREATE PROCEDURE test_userSetUITheme()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
        
	CALL userSetUITheme(ashId, 'new light');
    
    IF (SELECT uiTheme FROM user WHERE id = UNHEX(ashId)) != 'new light' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
END $$
DELIMITER ;
CALL test_userSetUITheme();
DROP PROCEDURE IF EXISTS test_userSetUITheme;

DROP PROCEDURE IF EXISTS test_userSetLocale;
DELIMITER $$
CREATE PROCEDURE test_userSetLocale()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
        
	CALL userSetLocale(ashId, 'en-GB');
    
    IF (SELECT locale FROM user WHERE id = UNHEX(ashId)) != 'en-GB' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
END $$
DELIMITER ;
CALL test_userSetLocale();
DROP PROCEDURE IF EXISTS test_userSetLocale;

DROP PROCEDURE IF EXISTS test_userSetTimeFormat;
DELIMITER $$
CREATE PROCEDURE test_userSetTimeFormat()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
        
	CALL userSetTimeFormat(ashId, 'YYYY-MM-DD');
    
    IF (SELECT timeFormat FROM user WHERE id = UNHEX(ashId)) != 'YYYY-MM-DD' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
END $$
DELIMITER ;
CALL test_userSetTimeFormat();
DROP PROCEDURE IF EXISTS test_userSetTimeFormat;

DROP PROCEDURE IF EXISTS test_userGet;
DELIMITER $$
CREATE PROCEDURE test_userGet()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
        
    SELECT 'ash, bob';
	CALL userGet('00000000000000000000000000000000,11111111111111111111111111111111');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
END $$
DELIMITER ;
CALL test_userGet();
DROP PROCEDURE IF EXISTS test_userGet;

DROP PROCEDURE IF EXISTS test_userSearch;
DELIMITER $$
CREATE PROCEDURE test_userSearch()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
	
    SELECT '1, ash';
	CALL userSearch('ash', 0, 5, 'fullNameAsc');
    SELECT '1';
	CALL userSearch('ash', 1, 5, 'fullNameAsc');
    SELECT '3, bob, cat';
	CALL userSearch('username', 1, 5, 'fullNameAsc');
    SELECT '3, bob, ash';
	CALL userSearch('username', 1, 5, 'fullNameDesc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
END $$
DELIMITER ;
CALL test_userSearch();
DROP PROCEDURE IF EXISTS test_userSearch;

DROP PROCEDURE IF EXISTS test_userGetInProjectContext;
DELIMITER $$
CREATE PROCEDURE test_userGetInProjectContext()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'admin'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
    
    SELECT 'error, ash trying to get users for bobs project';
	CALL userGetInProjectContext('00000000000000000000000000000000', '44444444444444444444444444444444', 'any', 0, 5, 'fullNameAsc');
    SELECT 'error, ash trying to get users for cats project';
	CALL userGetInProjectContext('00000000000000000000000000000000', '55555555555555555555555555555555', 'any', 0, 5, 'fullNameAsc');
    SELECT 'error, bob trying to get users for ashs project and he is only an observer';
	CALL userGetInProjectContext('00000000000000000000000000000000', '55555555555555555555555555555555', 'any', 0, 5, 'fullNameAsc');
    SELECT '3, ash, bob, cat';
	CALL userGetInProjectContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'any', 0, 5, 'fullNameAsc');
    SELECT '1, bob';
	CALL userGetInProjectContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'observer', 0, 5, 'fullNameAsc');
    SELECT '1 nothing';
	CALL userGetInProjectContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'observer', 1, 5, 'fullNameAsc');
    SELECT '1, cat';
	CALL userGetInProjectContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'admin', 0, 5, 'fullNameAsc');
    SELECT '3, cat, bob, ash';
	CALL userGetInProjectContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'any', 0, 5, 'roleAsc');
    SELECT '3, bob, cat';
	CALL userGetInProjectContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'any', 1, 5, 'fullNameAsc');
    SELECT '3, bob';
	CALL userGetInProjectContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'any', 1, 1, 'roleAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_userGetInProjectContext();
DROP PROCEDURE IF EXISTS test_userGetInProjectContext;

DROP PROCEDURE IF EXISTS test_userGetInProjectInviteContext;
DELIMITER $$
CREATE PROCEDURE test_userGetInProjectInviteContext()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner');
        
    INSERT INTO invitation
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'admin'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
    
    SELECT 'error, ash trying to get users invites for bobs project';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '44444444444444444444444444444444', 'any', 0, 5, 'fullNameAsc');
    SELECT 'error, ash trying to get users invites for cats project';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '55555555555555555555555555555555', 'any', 0, 5, 'fullNameAsc');
    SELECT 'error, bob trying to get users invites for ashs project and he is only invitee observer';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '55555555555555555555555555555555', 'any', 0, 5, 'fullNameAsc');
    SELECT '2, bob, cat';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'any', 0, 5, 'fullNameAsc');
    SELECT '1, bob';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'observer', 0, 5, 'fullNameAsc');
    SELECT '1 nothing';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'observer', 1, 5, 'fullNameAsc');
    SELECT '1, cat';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'admin', 0, 5, 'fullNameAsc');
    SELECT '2, cat, bob';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'any', 0, 5, 'roleAsc');
    SELECT '2, cat';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'any', 1, 5, 'fullNameAsc');
    SELECT '2, cat';
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '33333333333333333333333333333333', 'any', 0, 1, 'roleAsc');
    SELECT 'error, bob trying to get users invites for ashs project and he is only an observer';
    CALL projectAcceptInvitation(bobId, ashProjId);
	CALL userGetInProjectInviteContext('00000000000000000000000000000000', '55555555555555555555555555555555', 'any', 0, 5, 'fullNameAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_userGetInProjectInviteContext();
DROP PROCEDURE IF EXISTS test_userGetInProjectInviteContext;

DROP PROCEDURE IF EXISTS test_projectCreate;
DELIMITER $$
CREATE PROCEDURE test_projectCreate()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
    DECLARE projectId BINARY(16) DEFAULT NULL;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
	
    SELECT '<someUuid>, ashs project, ashs awesome project, png';
    CALL projectCreate(ashId, 'ashs project', 'ashs awesome project', 'png');
    
    SELECT id INTO projectId FROM project;
    
    IF (SELECT project FROM permission WHERE user = UNHEX(ashId)) != projectId THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF (SELECT role FROM permission WHERE project = projectId AND user = UNHEX(ashId)) != 'owner' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF (SELECT id FROM treeNode WHERE project = projectId) != projectId THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF (SELECT parent FROM treeNode WHERE project = projectId) IS NOT NULL THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF (SELECT project FROM treeNode WHERE project = projectId) != projectId THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF (SELECT name FROM treeNode WHERE project = projectId) != 'root' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    IF (SELECT nodeType FROM treeNode WHERE project = projectId) != 'folder' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId');
	DELETE FROM project WHERE id IN (projectId);
END $$
DELIMITER ;
CALL test_projectCreate();
DROP PROCEDURE IF EXISTS test_projectCreate;

DROP PROCEDURE IF EXISTS test_projectSetName;
DELIMITER $$
CREATE PROCEDURE test_projectSetName()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
	
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner');
        
	CALL projectSetName(ashId, ashProjId, 'ashProj new name');
    
    IF (SELECT name FROM project WHERE id = UNHEX(ashProjId)) != 'ashProj new name' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    UPDATE permission SET role = 'admin' WHERE user = UNHEX(ashId);
        
	CALL projectSetName(ashId, ashProjId, 'ashProj new name 2.0');
    
    IF (SELECT name FROM project WHERE id = UNHEX(ashProjId)) != 'ashProj new name' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId));
END $$
DELIMITER ;
CALL test_projectSetName();
DROP PROCEDURE IF EXISTS test_projectSetName;

DROP PROCEDURE IF EXISTS test_projectSetDescription;
DELIMITER $$
CREATE PROCEDURE test_projectSetDescription()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
	
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner');
        
	CALL projectSetDescription(ashId, ashProjId, 'ashProj new description');
    
    IF (SELECT description FROM project WHERE id = UNHEX(ashProjId)) != 'ashProj new description' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    UPDATE permission SET role = 'admin' WHERE user = UNHEX(ashId);
        
	CALL projectSetDescription(ashId, ashProjId, 'ashProj new description 2.0');
    
    IF (SELECT description FROM project WHERE id = UNHEX(ashProjId)) != 'ashProj new description' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId));    
END $$
DELIMITER ;
CALL test_projectSetDescription();
DROP PROCEDURE IF EXISTS test_projectSetDescription;

DROP PROCEDURE IF EXISTS test_projectSetImageFileExtension;
DELIMITER $$
CREATE PROCEDURE test_projectSetImageFileExtension()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll');
	
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner');
        
	CALL projectSetImageFileExtension(ashId, ashProjId, 'jpeg');
    
    IF (SELECT imageFileExtension FROM project WHERE id = UNHEX(ashProjId)) != 'jpeg' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    UPDATE permission SET role = 'admin' WHERE user = UNHEX(ashId);
        
	CALL projectSetImageFileExtension(ashId, ashProjId, 'gif');
    
    IF (SELECT imageFileExtension FROM project WHERE id = UNHEX(ashProjId)) != 'jpeg' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId));    
END $$
DELIMITER ;
CALL test_projectSetImageFileExtension();
DROP PROCEDURE IF EXISTS test_projectSetImageFileExtension;

DROP PROCEDURE IF EXISTS test_projectGetRole;
DELIMITER $$
CREATE PROCEDURE test_projectGetRole()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	SELECT 'owner';
	CALL projectGetRole(ashId, ashProjId);
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_projectGetRole();
DROP PROCEDURE IF EXISTS test_projectGetRole;

DROP PROCEDURE IF EXISTS test_projectGet;
DELIMITER $$
CREATE PROCEDURE test_projectGet()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'admin'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	SELECT 'ash proj';
    CALL projectGet(ashId, ashProjId);
	SELECT 'nothing, errors because ash doesnt have access to bobs proj';
    CALL projectGet(ashId, CONCAT(ashProjId, ',', bobProjId));
	SELECT 'ash proj, bob proj';
    CALL projectGet(bobId, CONCAT(ashProjId, ',', bobProjId));
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_projectGet();
DROP PROCEDURE IF EXISTS test_projectGet;

DROP PROCEDURE IF EXISTS test_projectSearch;
DELIMITER $$
CREATE PROCEDURE test_projectSearch()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'admin'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	SELECT '1, ash proj';
    CALL projectSearch(ashId, 'ashProj', 0, 5, 'nameDesc');
	SELECT '1, nothing';
    CALL projectSearch(ashId, 'ashProj', 1, 5, 'nameDesc');
	SELECT '1, ash proj';
    CALL projectSearch(bobId, 'ashProj', 0, 5, 'nameDesc');
	SELECT '2, bob proj, ash proj';
    CALL projectSearch(bobId, 'name', 0, 5, 'nameDesc');
	SELECT '2 nothing';
    CALL projectSearch(bobId, 'name', 2, 5, 'nameDesc');
	SELECT '2, ash proj';
    CALL projectSearch(bobId, 'name', 1, 5, 'nameDesc');
	SELECT '2, bob proj';
    CALL projectSearch(bobId, 'name', 0, 1, 'nameDesc');
	SELECT '2, ash proj, bob proj';
    CALL projectSearch(bobId, 'name', 0, 5, 'nameAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_projectSearch();
DROP PROCEDURE IF EXISTS test_projectSearch;

DROP PROCEDURE IF EXISTS test_projectGetInUserContext;
DELIMITER $$
CREATE PROCEDURE test_projectGetInUserContext()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'admin'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	SELECT '1, ash proj owner';
    CALL projectGetInUserContext(ashId, ashId, 'any', 0, 5, 'nameDesc');
	SELECT '1, nothing';
    CALL projectGetInUserContext(ashId, ashId, 'any', 1, 5, 'nameDesc');
	SELECT '0, as bob is only an observer and so shouldnt see ashs project';
    CALL projectGetInUserContext(bobId, ashId, 'any', 0, 5, 'nameDesc');
	SELECT '1, ash proj';
    CALL projectGetInUserContext(catId, ashId, 'any', 0, 5, 'nameDesc');
	SELECT '2 cat proj, ash proj';
    CALL projectGetInUserContext(catId, catId, 'any', 0, 5, 'nameDesc');
	SELECT '1 ash proj';
    CALL projectGetInUserContext(catId, catId, 'admin', 0, 5, 'nameDesc');
	SELECT '2 ash proj';
    CALL projectGetInUserContext(catId, catId, 'any', 1, 5, 'nameDesc');
	SELECT '2 ash proj';
    CALL projectGetInUserContext(catId, catId, 'any', 0, 1, 'nameAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_projectGetInUserContext();
DROP PROCEDURE IF EXISTS test_projectGetInUserContext;

DROP PROCEDURE IF EXISTS test_projectGetInUserInviteContext;
DELIMITER $$
CREATE PROCEDURE test_projectGetInUserInviteContext()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(catId), 'admin'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
    INSERT INTO invitation
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'organiser'), 
		(UNHEX(ashProjId), UNHEX(catId), 'admin'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	SELECT '1, ash proj owner';
    CALL projectGetInUserInviteContext(ashId, ashId, 'any', 0, 5, 'nameDesc');
	SELECT '1, nothing';
    CALL projectGetInUserInviteContext(ashId, ashId, 'any', 1, 5, 'nameDesc');
	SELECT '0, as bob is only an observer and so shouldnt see ashs project invites';
    CALL projectGetInUserInviteContext(bobId, ashId, 'any', 0, 5, 'nameDesc');
	SELECT '1, ash proj';
    CALL projectGetInUserInviteContext(catId, ashId, 'any', 0, 5, 'nameDesc');
	SELECT '2 cat proj, ash proj';
    CALL projectGetInUserInviteContext(catId, catId, 'any', 0, 5, 'nameDesc');
	SELECT '1 ash proj';
    CALL projectGetInUserInviteContext(catId, catId, 'admin', 0, 5, 'nameDesc');
	SELECT '2 ash proj';
    CALL projectGetInUserInviteContext(catId, catId, 'any', 1, 5, 'nameDesc');
	SELECT '2 ash proj';
    CALL projectGetInUserInviteContext(catId, catId, 'any', 0, 1, 'nameAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_projectGetInUserInviteContext();
DROP PROCEDURE IF EXISTS test_projectGetInUserInviteContext;

DROP PROCEDURE IF EXISTS test_treeNodeCreateFolder;
DELIMITER $$
CREATE PROCEDURE test_treeNodeCreateFolder()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'contributor'),
		(UNHEX(ashProjId), UNHEX(catId), 'admin'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX('99999999999999999999999999999999'), UNHEX(ashProjId), UNHEX(ashProjId), 'some doc', 'document');
        
	SELECT '<somUuid>, ashProjId, ashProjId, new folder, folder';
	CALL treeNodeCreateFolder(ashId, ashProjId, 'new folder');
	SELECT '<somUuid>, ashProjId, ashProjId, another new folder, folder';
	CALL treeNodeCreateFolder(catId, ashProjId, 'another new folder');
	SELECT 'error bob is not allowed to make folders';
	CALL treeNodeCreateFolder(bobId, ashProjId, 'another new folder');
	SELECT 'error cant create tree node under none folder node';
	CALL treeNodeCreateFolder(ashId, '99999999999999999999999999999999', 'another new folder');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeCreateFolder();
DROP PROCEDURE IF EXISTS test_treeNodeCreateFolder;

DROP PROCEDURE IF EXISTS test_treeNodeCreateDocument_and_documentVersionCreate;
DELIMITER $$
CREATE PROCEDURE test_treeNodeCreateDocument_and_documentVersionCreate()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'contributor'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX('99999999999999999999999999999999'), UNHEX(ashProjId), UNHEX(ashProjId), 'some doc', 'document');
        
	SELECT '<somUuid>, ashProjId, ashProjId, new doc, document';
	CALL treeNodeCreateDocument(ashId, ashProjId, 'new doc', HEX(opUuid()), 'new doc upload comment', 'nwd', 'a urn', 'a status');
	SELECT '<somUuid>, ashProjId, ashProjId, another new doc, document';
	CALL treeNodeCreateDocument(catId, ashProjId, 'another new doc', HEX(opUuid()), 'another new doc upload comment', 'nwd', 'another urn', 'another status');
	SELECT 'error bob is not allowed to make documents';
	CALL treeNodeCreateDocument(bobId, ashProjId, 'another new doc', HEX(opUuid()), 'a new doc upload comment', 'nwd', 'a urn', 'a status');
	SELECT 'error cant create tree node under none folder node';
	CALL treeNodeCreateDocument(ashId, '99999999999999999999999999999999', HEX(opUuid()), 'another new doc', 'a new doc upload comment', 'nwd', 'a urn', 'a status');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeCreateDocument_and_documentVersionCreate();
DROP PROCEDURE IF EXISTS test_treeNodeCreateDocument_and_documentVersionCreate;

DROP PROCEDURE IF EXISTS test_treeNodeCreateViewerState;
DELIMITER $$
CREATE PROCEDURE test_treeNodeCreateViewerState()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'contributor'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX('99999999999999999999999999999999'), UNHEX(ashProjId), UNHEX(ashProjId), 'some doc', 'document');
        
	SELECT '<somUuid>, ashProjId, ashProjId, new doc, viewerState';
	CALL treeNodeCreateViewerState(ashId, ashProjId, 'new viewerState');
	SELECT '<somUuid>, ashProjId, ashProjId, another new doc, viewerState';
	CALL treeNodeCreateViewerState(catId, ashProjId, 'another new viewerState');
	SELECT 'error bob is not allowed to make viewerState';
	CALL treeNodeCreateViewerState(bobId, ashProjId, 'another new viewerState');
	SELECT 'error cant create tree node under none folder node';
	CALL treeNodeCreateViewerState(ashId, '99999999999999999999999999999999', 'another new viewerState');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeCreateViewerState();
DROP PROCEDURE IF EXISTS test_treeNodeCreateViewerState;

DROP PROCEDURE IF EXISTS test_treeNodeSetName;
DELIMITER $$
CREATE PROCEDURE test_treeNodeSetName()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'contributor'),
		(UNHEX(ashProjId), UNHEX(catId), 'organiser'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder');
        
	CALL treeNodeSetName(ashId, ashProjId, 'root renamed');
    IF (SELECT name FROM treeNode WHERE id = UNHEX(ashProjId)) != 'root renamed' THEN
		CALL STOP_TEST_FAIL();
    END IF;
        
	CALL treeNodeSetName(catId, ashProjId, 'root renamed again');
    IF (SELECT name FROM treeNode WHERE id = UNHEX(ashProjId)) != 'root renamed again' THEN
		CALL STOP_TEST_FAIL();
    END IF;
        
	CALL treeNodeSetName(bobId, ashProjId, 'this wont happen');
    IF (SELECT name FROM treeNode WHERE id = UNHEX(ashProjId)) = 'this wont happen' THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeSetName();
DROP PROCEDURE IF EXISTS test_treeNodeSetName;

DROP PROCEDURE IF EXISTS test_treeNodeMove;
DELIMITER $$
CREATE PROCEDURE test_treeNodeMove()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE docId VARCHAR(32) DEFAULT '77777777777777777777777777777777';
    DECLARE subFolder1Id VARCHAR(32) DEFAULT '88888888888888888888888888888888';
    DECLARE subFolder2Id VARCHAR(32) DEFAULT '99999999999999999999999999999999';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'contributor'),
		(UNHEX(ashProjId), UNHEX(catId), 'organiser'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), UNHEX('00000000000000000000000000000000'), UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX(bobProjId), UNHEX('00000000000000000000000000000000'), UNHEX(bobProjId), 'root', 'folder'),
		(UNHEX(catProjId), UNHEX('00000000000000000000000000000000'), UNHEX(catProjId), 'root', 'folder'),
		(UNHEX(subFolder1Id), UNHEX(ashProjId), UNHEX(ashProjId), 'sub folder 1', 'folder'),
		(UNHEX(subFolder2Id), UNHEX(ashProjId), UNHEX(ashProjId), 'sub folder 2', 'folder'),
		(UNHEX(docId), UNHEX(subFolder1Id), UNHEX(ashProjId), 'doc', 'document');
	
    #ash trys to move her root folder to be under subfolder 1; expect: error, root folders can't be moved
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(ashProjId)) != UNHEX('00000000000000000000000000000000') THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #cat trys to move sub folder 1 to her projects root folder; expect: error, cross project move
	CALL treeNodeMove(catId, catProjId, subFolder1Id);
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(subFolder1Id)) != UNHEX(ashProjId) THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #bob trys to move doc to ashs projects root folder; expect: error, bob doesn't have sufficient access
	CALL treeNodeMove(bobId, ashProjId, docId);
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(docId)) != UNHEX(subFolder1Id) THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #cat trys to move doc and subFolder1 to subFolder2; expect: success
	CALL treeNodeMove(catId, subFolder2Id, CONCAT(subFolder1Id, ',', docId));
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(docId)) != UNHEX(subFolder2Id) THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(subFolder1Id)) != UNHEX(subFolder2Id) THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #ash trys to move doc and subFolder1 and subFolder2 to root; expect: success
	CALL treeNodeMove(ashId, ashProjId, CONCAT(subFolder1Id, ',', docId, ',', subFolder2Id));
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(docId)) != UNHEX(ashProjId) THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(subFolder1Id)) != UNHEX(ashProjId) THEN
		CALL STOP_TEST_FAIL();
    END IF;
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(subFolder2Id)) != UNHEX(ashProjId) THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #ash trys to move subFolder2 to subFolder1; expect: success
	CALL treeNodeMove(ashId, subFolder1Id, subFolder2Id);
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(subFolder2Id)) != UNHEX(subFolder1Id) THEN
		CALL STOP_TEST_FAIL();
    END IF;
    
    #ash trys to move subFolder1 to subFolder2; expect: error
	CALL treeNodeMove(ashId, subFolder2Id, subFolder1Id);
    IF (SELECT parent FROM treeNode WHERE id = UNHEX(subFolder2Id)) != UNHEX(subFolder1Id) THEN
		CALL STOP_TEST_FAIL();
    END IF;
        
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeMove();
DROP PROCEDURE IF EXISTS test_treeNodeMove;

DROP PROCEDURE IF EXISTS test_treeNodeGetChildren;
DELIMITER $$
CREATE PROCEDURE test_treeNodeGetChildren()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE docId VARCHAR(32) DEFAULT '77777777777777777777777777777777';
    DECLARE subFolder1Id VARCHAR(32) DEFAULT '88888888888888888888888888888888';
    DECLARE subFolder2Id VARCHAR(32) DEFAULT '99999999999999999999999999999999';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'contributor'),
		(UNHEX(ashProjId), UNHEX(catId), 'organiser'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX(bobProjId), NULL, UNHEX(bobProjId), 'root', 'folder'),
		(UNHEX(catProjId), NULL, UNHEX(catProjId), 'root', 'folder'),
		(UNHEX(subFolder1Id), UNHEX(ashProjId), UNHEX(ashProjId), 'sub folder 1', 'folder'),
		(UNHEX(subFolder2Id), UNHEX(ashProjId), UNHEX(ashProjId), 'sub folder 2', 'folder'),
		(UNHEX(docId), UNHEX(subFolder1Id), UNHEX(ashProjId), 'doc', 'document');
	
    SELECT '2, sub folder 1, sub folder 2';
	CALL treeNodeGetChildren(ashId, ashProjId, 'folder', 0, 5, 'nameAsc');
    SELECT '2, sub folder 2, sub folder 1';
	CALL treeNodeGetChildren(ashId, ashProjId, 'folder', 0, 5, 'nameDesc');
    SELECT '2, sub folder 1';
	CALL treeNodeGetChildren(ashId, ashProjId, 'folder', 1, 5, 'nameDesc');
    SELECT '2, sub folder 2';
	CALL treeNodeGetChildren(ashId, ashProjId, 'folder', 0, 1, 'nameDesc');
    SELECT '0';
	CALL treeNodeGetChildren(ashId, ashProjId, 'document', 0, 5, 'nameDesc');
    SELECT '1 doc';
	CALL treeNodeGetChildren(ashId, subFolder1Id, 'document', 0, 5, 'nameDesc');
    SELECT 'error ash is not a member of bobs project';
	CALL treeNodeGetChildren(ashId, bobProjId, 'folder', 0, 5, 'nameDesc');
        
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeGetChildren();
DROP PROCEDURE IF EXISTS test_treeNodeGetChildren;

DROP PROCEDURE IF EXISTS test_treeNodeGetParents;
DELIMITER $$
CREATE PROCEDURE test_treeNodeGetParents()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE docId VARCHAR(32) DEFAULT '77777777777777777777777777777777';
    DECLARE subFolder1Id VARCHAR(32) DEFAULT '88888888888888888888888888888888';
    DECLARE subFolder2Id VARCHAR(32) DEFAULT '99999999999999999999999999999999';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(catId), 'organiser'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), UNHEX(''), UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX(bobProjId), UNHEX(''), UNHEX(bobProjId), 'root', 'folder'),
		(UNHEX(catProjId), UNHEX(''), UNHEX(catProjId), 'root', 'folder'),
		(UNHEX(subFolder1Id), UNHEX(ashProjId), UNHEX(ashProjId), 'sub folder 1', 'folder'),
		(UNHEX(subFolder2Id), UNHEX(subFolder1Id), UNHEX(ashProjId), 'sub folder 2', 'folder'),
		(UNHEX(docId), UNHEX(subFolder2Id), UNHEX(ashProjId), 'doc', 'document');
	
    SELECT 'root, sub folder 1, sub folder 2';
	CALL treeNodeGetParents(ashId, docId);
    SELECT 'nothing as bob is not a member of ashs project';
	CALL treeNodeGetParents(bobId, docId);
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeGetParents();
DROP PROCEDURE IF EXISTS test_treeNodeGetParents;

DROP PROCEDURE IF EXISTS test_treeNodeGlobalSearch;
DELIMITER $$
CREATE PROCEDURE test_treeNodeGlobalSearch()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE docId VARCHAR(32) DEFAULT '77777777777777777777777777777777';
    DECLARE subFolder1Id VARCHAR(32) DEFAULT '88888888888888888888888888888888';
    DECLARE subFolder2Id VARCHAR(32) DEFAULT '99999999999999999999999999999999';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(catId), 'organiser'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX(bobProjId), NULL, UNHEX(bobProjId), 'root', 'folder'),
		(UNHEX(catProjId), NULL, UNHEX(catProjId), 'root', 'folder'),
		(UNHEX(subFolder1Id), UNHEX(ashProjId), UNHEX(ashProjId), 'sub folder 1', 'folder'),
		(UNHEX(subFolder2Id), UNHEX(subFolder1Id), UNHEX(ashProjId), 'sub folder 2', 'folder'),
		(UNHEX(docId), UNHEX(subFolder2Id), UNHEX(ashProjId), 'doc', 'document');
	
    SELECT '2, sub folder 2, sub folder 1';
	CALL treeNodeGlobalSearch(ashId, 'sub', 'folder', 0, 5, 'nameDesc');
    SELECT '2, sub folder 2, sub folder 1';
	CALL treeNodeGlobalSearch(catId, 'sub', 'folder', 0, 5, 'nameDesc');
    SELECT '2, root, root';
	CALL treeNodeGlobalSearch(catId, 'root', 'folder', 0, 5, 'nameDesc');
    SELECT '1, root';
	CALL treeNodeGlobalSearch(ashId, 'root', 'folder', 0, 5, 'nameDesc');
    SELECT '0';
	CALL treeNodeGlobalSearch(bobId, 'sub', 'folder', 0, 5, 'nameDesc');
    SELECT '2, sub folder 1, sub folder 2';
	CALL treeNodeGlobalSearch(ashId, 'sub', 'folder', 0, 5, 'nameAsc');
    SELECT '0';
	CALL treeNodeGlobalSearch(ashId, 'sub', 'document', 0, 5, 'nameAsc');
    SELECT '1 doc';
	CALL treeNodeGlobalSearch(ashId, 'doc', 'document', 0, 5, 'nameAsc');
    SELECT '2, sub folder 1';
	CALL treeNodeGlobalSearch(ashId, 'sub', 'folder', 0, 1, 'nameAsc');
    SELECT '2, sub folder 2';
	CALL treeNodeGlobalSearch(ashId, 'sub', 'folder', 1, 1, 'nameAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeGlobalSearch();
DROP PROCEDURE IF EXISTS test_treeNodeGlobalSearch;

DROP PROCEDURE IF EXISTS test_treeNodeProjectSearch;
DELIMITER $$
CREATE PROCEDURE test_treeNodeProjectSearch()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE docId VARCHAR(32) DEFAULT '77777777777777777777777777777777';
    DECLARE subFolder1Id VARCHAR(32) DEFAULT '88888888888888888888888888888888';
    DECLARE subFolder2Id VARCHAR(32) DEFAULT '99999999999999999999999999999999';
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(catId), 'organiser'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX(bobProjId), NULL, UNHEX(bobProjId), 'root', 'folder'),
		(UNHEX(catProjId), NULL, UNHEX(catProjId), 'root', 'folder'),
		(UNHEX(subFolder1Id), UNHEX(ashProjId), UNHEX(ashProjId), 'sub folder 1', 'folder'),
		(UNHEX(subFolder2Id), UNHEX(subFolder1Id), UNHEX(ashProjId), 'sub folder 2', 'folder'),
		(UNHEX(docId), UNHEX(subFolder2Id), UNHEX(ashProjId), 'doc', 'document');
	
    SELECT '2, sub folder 2, sub folder 1';
	CALL treeNodeProjectSearch(ashId, ashProjId, 'sub', 'folder', 0, 5, 'nameDesc');
    SELECT '2, sub folder 2, sub folder 1';
	CALL treeNodeProjectSearch(catId, ashProjId, 'sub', 'folder', 0, 5, 'nameDesc');
    SELECT '1, root';
	CALL treeNodeProjectSearch(catId, ashProjId, 'root', 'folder', 0, 5, 'nameDesc');
    SELECT '1, root';
	CALL treeNodeProjectSearch(catId, catProjId, 'root', 'folder', 0, 5, 'nameDesc');
    SELECT 'error bob is not a member of ashs project';
	CALL treeNodeProjectSearch(bobId, ashProjId, 'sub', 'folder', 0, 5, 'nameDesc');
    SELECT '2, sub folder 1, sub folder 2';
	CALL treeNodeProjectSearch(ashId, ashProjId, 'sub', 'folder', 0, 5, 'nameAsc');
    SELECT '0';
	CALL treeNodeProjectSearch(ashId, ashProjId, 'sub', 'document', 0, 5, 'nameAsc');
    SELECT '1 doc';
	CALL treeNodeProjectSearch(ashId, ashProjId, 'doc', 'document', 0, 5, 'nameAsc');
    SELECT '2, sub folder 1';
	CALL treeNodeProjectSearch(ashId, ashProjId, 'sub', 'folder', 0, 1, 'nameAsc');
    SELECT '2, sub folder 2';
	CALL treeNodeProjectSearch(ashId, ashProjId, 'sub', 'folder', 1, 1, 'nameAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_treeNodeProjectSearch();
DROP PROCEDURE IF EXISTS test_treeNodeProjectSearch;

DROP PROCEDURE IF EXISTS test_documentVersionGet;
DELIMITER $$
CREATE PROCEDURE test_documentVersionGet()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE docVer1Id VARCHAR(32) DEFAULT HEX(opUuid());
    DECLARE docVer2Id VARCHAR(32) DEFAULT HEX(opUuid());
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'contributor'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX('99999999999999999999999999999999'), UNHEX(ashProjId), UNHEX(ashProjId), 'some doc', 'document');
        
	SELECT '<somUuid>, ashProjId, ashProjId, new doc, document';
	CALL treeNodeCreateDocument(ashId, ashProjId, 'new doc', docVer1Id, 'new doc upload comment', 'nwd', 'a urn', 'a status');
	SELECT '<somUuid>, ashProjId, ashProjId, another new doc, document';
	CALL treeNodeCreateDocument(catId, ashProjId, 'another new doc', docVer2Id, 'another new doc upload comment', 'nwd', 'another urn', 'another status');
    
    SELECT '2';
    CALL documentVersionGet(ashId, CONCAT(docVer1Id, ',', docVer2Id));
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_documentVersionGet();
DROP PROCEDURE IF EXISTS test_documentVersionGet;

DROP PROCEDURE IF EXISTS test_documentVersionGetForDocument;
DELIMITER $$
CREATE PROCEDURE test_documentVersionGetForDocument()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE docVer1Id VARCHAR(32) DEFAULT HEX(opUuid());
    DECLARE docVer2Id VARCHAR(32) DEFAULT HEX(opUuid());
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(bobId), 'observer'),
		(UNHEX(ashProjId), UNHEX(catId), 'contributor'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX('99999999999999999999999999999999'), UNHEX(ashProjId), UNHEX(ashProjId), 'some doc', 'document');
        
	CALL documentVersionCreate(ashId, '99999999999999999999999999999999', docVer1Id, 'upload comment', 'nwd', 'urn', 'status');
	CALL documentVersionCreate(ashId, '99999999999999999999999999999999', docVer2Id, 'upload comment', 'nwd', 'urn', 'status');
    
    SELECT '2, 1';
    CALL documentVersionGetForDocument(ashId, '99999999999999999999999999999999', 0, 5, 'versionDesc');
    SELECT '1, 2';
    CALL documentVersionGetForDocument(ashId, '99999999999999999999999999999999', 0, 5, 'versionAsc');
    SELECT '1';
    CALL documentVersionGetForDocument(ashId, '99999999999999999999999999999999', 0, 1, 'versionAsc');
    SELECT '2';
    CALL documentVersionGetForDocument(ashId, '99999999999999999999999999999999', 1, 1, 'versionAsc');
    SELECT 'totalResults only 2';
    CALL documentVersionGetForDocument(ashId, '99999999999999999999999999999999', 2, 1, 'versionAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_documentVersionGetForDocument();
DROP PROCEDURE IF EXISTS test_documentVersionGetForDocument;

DROP PROCEDURE IF EXISTS test_sheet;
DELIMITER $$
CREATE PROCEDURE test_sheet()
BEGIN
	DECLARE ashId VARCHAR(32) DEFAULT '00000000000000000000000000000000';
	DECLARE bobId VARCHAR(32) DEFAULT '11111111111111111111111111111111';
	DECLARE catId VARCHAR(32) DEFAULT '22222222222222222222222222222222';
    DECLARE ashProjId VARCHAR(32) DEFAULT '33333333333333333333333333333333';
    DECLARE bobProjId VARCHAR(32) DEFAULT '44444444444444444444444444444444';
    DECLARE catProjId VARCHAR(32) DEFAULT '55555555555555555555555555555555';
    DECLARE docVer1Id VARCHAR(32) DEFAULT HEX(opUuid());
    DECLARE errorReceiver BOOL;
	DECLARE CONTINUE HANDLER FOR 45002 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45003 SELECT TRUE INTO errorReceiver;
	DECLARE CONTINUE HANDLER FOR 45004 SELECT TRUE INTO errorReceiver;
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(UNHEX(ashId), 'ash autodeskId', 'ash openId', 'ash username', 'ash avatar', 'ash fullName', 'ash email', FALSE, UTC_TIMESTAMP(), 'ash description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(bobId), 'bob autodeskId', 'bob openId', 'bob username', 'bob avatar', 'bob fullName', 'bob email', FALSE, UTC_TIMESTAMP(), 'bob description', 'en', 'dark', 'en-GB', 'llll'),
		(UNHEX(catId), 'cat autodeskId', 'cat openId', 'cat username', 'cat avatar', 'cat fullName', 'cat email', FALSE, UTC_TIMESTAMP(), 'cat description', 'en', 'dark', 'en-GB', 'llll');
    
    INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(UNHEX(ashProjId), 'ashProj name', 'ashProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(bobProjId), 'bobProj name', 'bobProj description', UTC_TIMESTAMP(), 'png'),
		(UNHEX(catProjId), 'catProj name', 'catProj description', UTC_TIMESTAMP(), 'png');
    
    INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(ashProjId), UNHEX(ashId), 'owner'),
		(UNHEX(ashProjId), UNHEX(catId), 'contributor'),
		(UNHEX(bobProjId), UNHEX(bobId), 'owner'),
		(UNHEX(catProjId), UNHEX(catId), 'owner');
        
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(ashProjId), NULL, UNHEX(ashProjId), 'root', 'folder'),
		(UNHEX('99999999999999999999999999999999'), UNHEX(ashProjId), UNHEX(ashProjId), 'some doc', 'document');
        
	CALL documentVersionCreate(ashId, '99999999999999999999999999999999', docVer1Id, 'upload comment', 'nwd', 'urn', 'status');
    
    CALL sheetCreate(docVer1Id, ashProjId, 'sheet 1', 'baseUrn 1', 'path 1', 'thumbnails 1', 'role 1');
    CALL sheetCreate(docVer1Id, ashProjId, 'name 2', 'baseUrn 2', 'path 2', 'thumbnails 2', 'role 2');
    
    SELECT 'sheet 1';
    CALL sheetGet(ashId, (SELECT lex(id) FROM sheet LIMIT 0, 1));
    SELECT 'name 2';
    CALL sheetGet(ashId, (SELECT lex(id) FROM sheet LIMIT 1, 1));
    SELECT '2, sheet 1, name 2';
    CALL sheetGetForDocumentVersion(ashId, docVer1Id, 0, 5, 'nameDesc');
    SELECT '2, name 2, sheet 1';
    CALL sheetGetForDocumentVersion(ashId, docVer1Id, 0, 5, 'nameAsc');
    SELECT '2, sheet 1';
    CALL sheetGetForDocumentVersion(ashId, docVer1Id, 1, 5, 'nameAsc');
    SELECT '2, name 2';
    CALL sheetGetForDocumentVersion(ashId, docVer1Id, 0, 1, 'nameAsc');
    SELECT 'error bob is not a member of ashs project';
    CALL sheetGetForDocumentVersion(bobId, docVer1Id, 0, 5, 'nameAsc');
    SELECT '1, sheet';
    CALL sheetGlobalSearch(ashId, 'sheet', 0, 5, 'nameAsc');
    SELECT '1, name';
    CALL sheetGlobalSearch(ashId, 'name', 0, 5, 'nameAsc');
    SELECT '0';
    CALL sheetGlobalSearch(bobId, 'sheet', 0, 5, 'nameAsc');
    SELECT '0';
    CALL sheetGlobalSearch(bobId, 'name', 0, 5, 'nameAsc');
    SELECT '1, sheet';
    CALL sheetProjectSearch(catId, ashProjId, 'sheet', 0, 5, 'nameAsc');
    SELECT '0';
    CALL sheetProjectSearch(catId, catProjId, 'sheet', 0, 5, 'nameAsc');
    SELECT 'error bob is not a member of ashs project';
    CALL sheetProjectSearch(bobId, ashProjId, 'sheet', 0, 5, 'nameAsc');
    
	DELETE FROM user WHERE autodeskId IN ('ash autodeskId', 'bob autodeskId', 'cat autodeskId');
	DELETE FROM project WHERE id IN (UNHEX(ashProjId), UNHEX(bobProjId), UNHEX(catProjId));
END $$
DELIMITER ;
CALL test_sheet();
DROP PROCEDURE IF EXISTS test_sheet;