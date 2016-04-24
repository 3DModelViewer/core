DROP DATABASE IF EXISTS modelhub;
CREATE DATABASE modelhub;
USE modelhub;

# START UTIL

DROP FUNCTION IF EXISTS opUuid;
DELIMITER $$
CREATE FUNCTION opUuid() RETURNS BINARY(16) NOT DETERMINISTIC
BEGIN
    DECLARE src VARCHAR(36) DEFAULT UUID();
    RETURN UNHEX(CONCAT(SUBSTR(src, 15, 4), SUBSTR(src, 10, 4), SUBSTR(src, 1, 8), SUBSTR(src, 20, 4), SUBSTR(src, 25)));
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS lex;
DELIMITER $$
CREATE FUNCTION lex(src BINARY(16)) RETURNS VARCHAR(32) DETERMINISTIC
BEGIN
    RETURN LOWER(HEX(src));
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS createTempIdsTable;
DELIMITER $$
CREATE FUNCTION createTempIdsTable(ids varchar(3300)) RETURNS BOOL NOT DETERMINISTIC
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tempIds;
    CREATE TEMPORARY TABLE tempIds(
		id BINARY(16) NOT NULL, 
		PRIMARY KEY (id)
	);
    
    IF ids IS NOT NULL && NOT(ids REGEXP '^([0-9a-fA-F]{32},)*[0-9a-fA-F]{32}$') THEN
		SIGNAL SQLSTATE 
			'45001'
		SET
			MESSAGE_TEXT = 'Invalid ids argument',
            MYSQL_ERRNO = 45001;
		RETURN FALSE;
    END IF;
 
	WHILE ids != '' > 0 DO
		INSERT INTO tempIds (id) VALUES (UNHEX(SUBSTRING_INDEX(ids, ',', 1)));
		SET ids = SUBSTRING(ids, 34);
	END WHILE;
    
    RETURN TRUE;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS createTempSheetTransformHashJsonsTable;
DELIMITER $$
CREATE FUNCTION createTempSheetTransformHashJsonsTable(sheetTransformHashJsons varchar(21000)) RETURNS BOOL NOT DETERMINISTIC
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tempSheetTransformHashJsons;
    CREATE TEMPORARY TABLE tempSheetTransformHashJsons(
		hashJson VARCHAR(1000) NOT NULL, 
		PRIMARY KEY (hashJson)
	);
    
    IF sheetTransformHashJsons IS NULL THEN
		SIGNAL SQLSTATE 
			'45001'
		SET
			MESSAGE_TEXT = 'Invalid sheetTransformHashJsons argument',
            MYSQL_ERRNO = 45001;
		RETURN FALSE;
    END IF;
 
	parse: WHILE sheetTransformHashJsons != '' > 0 DO
		INSERT INTO tempSheetTransformHashJsons (hashJson) VALUES (SUBSTRING_INDEX(sheetTransformHashJsons, '#', 1))
        ON DUPLICATE KEY UPDATE
			hashJson = hashJson;
		IF INSTR(sheetTransformHashJsons, '#') = 0 THEN
			LEAVE parse;
        END IF;
		SET sheetTransformHashJsons = SUBSTRING(sheetTransformHashJsons, INSTR(sheetTransformHashJsons, '#') + 1);
	END WHILE;
    
    RETURN TRUE;
END$$
DELIMITER ;

# END UTIL

# START TABLES

DROP TABLE IF EXISTS user;
CREATE TABLE user(
	id BINARY(16) NOT NULL,
    autodeskId VARCHAR(50) NOT NULL,
    openId VARCHAR(500) NOT NULL,
    username VARCHAR(100) NOT NULL,
    avatar VARCHAR(500) NOT NULL,
    fullName VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    superUser BOOL NOT NULL DEFAULT FALSE,
    lastLogin DATETIME NOT NULL,
    uiLanguage VARCHAR(10) NOT NULL,
    uiTheme VARCHAR(10) NOT NULL,
    timeFormat VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE INDEX (autodeskId),
    FULLTEXT (username, fullName, email)
);

DROP TABLE IF EXISTS project;
CREATE TABLE project(
	id BINARY(16) NOT NULL,
    name VARCHAR(100) NOT NULL,
    created DATETIME NOT NULL,
    thumbnailType VARCHAR(50) NOT NULL,
    PRIMARY KEY (id),
    FULLTEXT (name)
);
INSERT INTO project (id, name, created, thumbnailType)
VALUES (UNHEX('00000000000000000000000000000000'), '', UTC_TIMESTAMP(), '');

DROP TABLE IF EXISTS role;
CREATE TABLE role(
	id VARCHAR(50) NOT NULL,
    PRIMARY KEY(id)
);

INSERT INTO role (id) 
	VALUES
		('owner'),
        ('admin'),
		('organiser'),
        ('contributor'),
        ('observer');

DROP TABLE IF EXISTS permission;
CREATE TABLE permission(
	project BINARY(16) NOT NULL,
	user BINARY(16) NOT NULL,
    role VARCHAR(50) NOT NULL,
    PRIMARY KEY (project, user),
    UNIQUE INDEX (user, project),
    UNIQUE INDEX (project, role, user),
    UNIQUE INDEX (user, role, project),
    FOREIGN KEY (project) REFERENCES project(id) ON DELETE CASCADE,
    FOREIGN KEY (user) REFERENCES user(id) ON DELETE CASCADE,
    FOREIGN KEY (role) REFERENCES role(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS invitation;
CREATE TABLE invitation(
	project BINARY(16) NOT NULL,
	user BINARY(16) NOT NULL,
    role VARCHAR(50) NOT NULL,
    PRIMARY KEY (project, user),
    UNIQUE INDEX (user, project),
    UNIQUE INDEX (project, role, user),
    UNIQUE INDEX (user, role, project),
    FOREIGN KEY (project) REFERENCES project(id) ON DELETE CASCADE,
    FOREIGN KEY (user) REFERENCES user(id) ON DELETE CASCADE,
    FOREIGN KEY (role) REFERENCES role(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS treeNodeType;
CREATE TABLE treeNodeType(
	id VARCHAR(50) NOT NULL,
    PRIMARY KEY (id)
);

INSERT INTO treeNodeType (id) 
	VALUES
		('folder'),
        ('document'),
		('projectSpace');

DROP TABLE IF EXISTS treeNode;
CREATE TABLE treeNode(
	id BINARY(16) NOT NULL,
	parent BINARY(16) NULL,
    project BINARY(16) NOT NULL,
    name VARCHAR(250) NOT NULL,
    nodeType VARCHAR(50) NOT NULL,
    PRIMARY KEY (project, id),
    UNIQUE INDEX (parent, nodeType, id),
    UNIQUE INDEX (nodeType, project, id),
    UNIQUE INDEX (id),
    FULLTEXT (name),
    FOREIGN KEY (project) REFERENCES project(id) ON DELETE CASCADE,
    FOREIGN KEY (parent) REFERENCES treeNode(id) ON DELETE CASCADE,
    FOREIGN KEY (nodeType) REFERENCES treeNodeType(id) ON DELETE CASCADE
);
INSERT INTO treeNode (id, parent, project, name, nodeType)
VALUES (UNHEX('00000000000000000000000000000000'), NULL, UNHEX('00000000000000000000000000000000'), '', 'folder');

DROP TABLE IF EXISTS documentVersion;
CREATE TABLE documentVersion(
	id BINARY(16) NOT NULL,
	document BINARY(16) NOT NULL,
    version MEDIUMINT NOT NULL,
    project BINARY(16) NOT NULL,
    uploaded DATETIME NOT NULL,
    uploadComment VARCHAR(250) NOT NULL,
    uploadedBy BINARY(16) NOT NULL,
    fileType VARCHAR(50) NOT NULL,
    fileExtension VARCHAR(10) NOT NULL,
    urn VARCHAR(1000) NOT NULL,
    status VARCHAR(50) NOT NULL,
    thumbnailType VARCHAR(50) NOT NULL,
	PRIMARY KEY (document, version, id),
    UNIQUE INDEX (id),
    FOREIGN KEY (project) REFERENCES project(id) ON DELETE CASCADE,
    FOREIGN KEY (document) REFERENCES treeNode(id) ON DELETE CASCADE,
    FOREIGN KEY (uploadedBy) REFERENCES user(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS projectSpaceVersion;
CREATE TABLE projectSpaceVersion(
	id BINARY(16) NOT NULL,
	projectSpace BINARY(16) NOT NULL,
    version MEDIUMINT NOT NULL,
    project BINARY(16) NOT NULL,
    created DATETIME NOT NULL,
    createComment VARCHAR(250) NOT NULL,
    createdBy BINARY(16) NOT NULL,
    thumbnailType VARCHAR(50) NOT NULL,
    cameraJson VARCHAR(1000) NOT NULL,
	PRIMARY KEY (projectSpace, version, id),
    UNIQUE INDEX (id),
    FOREIGN KEY (project) REFERENCES project(id) ON DELETE CASCADE,
    FOREIGN KEY (projectSpace) REFERENCES treeNode(id) ON DELETE CASCADE,
    FOREIGN KEY (createdBy) REFERENCES user(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS sheet;
CREATE TABLE sheet(
	id BINARY(16) NOT NULL,
	documentVersion BINARY(16) NOT NULL,
    project BINARY(16) NOT NULL,
    name VARCHAR(250) NOT NULL,
    baseUrn VARCHAR(500) NOT NULL,
    manifest VARCHAR(500) NOT NULL,
    thumbnails VARCHAR(4000) NOT NULL,
    role VARCHAR(50) NOT NULL,
	PRIMARY KEY (documentVersion, id),
    UNIQUE INDEX (id),
    UNIQUE INDEX (project, id),
    UNIQUE INDEX (baseUrn, manifest),
    FULLTEXT(name),
    FOREIGN KEY (project) REFERENCES project(id) ON DELETE CASCADE,
    FOREIGN KEY (documentVersion) REFERENCES documentVersion(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS sheetTransform;
CREATE TABLE sheetTransform(
	id BINARY(16) NOT NULL,
	sheet BINARY(16) NOT NULL,
    sheetTransformHashJson VARCHAR(1000) NOT NULL,
    clashChangeRegId BINARY(16) NOT NULL,
	PRIMARY KEY (id),
    UNIQUE INDEX (sheetTransformHashJson),
    INDEX (clashChangeRegId),
    FOREIGN KEY (sheet) REFERENCES sheet(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS projectSpaceVersionSheetTransform;
CREATE TABLE projectSpaceVersionSheetTransform(
	projectSpaceVersion BINARY(16) NOT NULL,
	sheetTransform BINARY(16) NOT NULL,
	PRIMARY KEY (projectSpaceVersion, sheetTransform),
    FOREIGN KEY (projectSpaceVersion) REFERENCES projectSpaceVersion(id) ON DELETE CASCADE,
    FOREIGN KEY (sheetTransform) REFERENCES sheetTransform(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS clashTest;
CREATE TABLE clashTest(
	id BINARY(16) NOT NULL,
    leftSheetTransform BINARY(16) NOT NULL,
    rightSheetTransform BINARY(16) NOT NULL,
	PRIMARY KEY (leftSheetTransform, rightSheetTransform),
	UNIQUE INDEX (id),
    FOREIGN KEY (leftSheetTransform) REFERENCES sheetTransform(id) ON DELETE CASCADE,
    FOREIGN KEY (rightSheetTransform) REFERENCES sheetTransform(id) ON DELETE CASCADE
);

# END TABLES

# START PERMISSION

DROP PROCEDURE IF EXISTS _permission_set;
DELIMITER $$
CREATE PROCEDURE _permission_set(forUserId VARCHAR(32), projectId VARCHAR(32), users VARCHAR(3300), addRole VARCHAR(50))
BEGIN
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
	DECLARE currentUserId BINARY(16) DEFAULT NULL;
	DECLARE currentUserRole VARCHAR(50) DEFAULT NULL;
	DECLARE n INT DEFAULT 0;
    DECLARE os INT DEFAULT 0;
    
	IF addRole IS NOT NULL && (SELECT COUNT(*) FROM role WHERE id = addRole) = 0 THEN
		SIGNAL SQLSTATE 
			'45003'
		SET
			MESSAGE_TEXT = 'Invalid action: set permissions with unknown role',
			MYSQL_ERRNO = 45003;
    END IF;
    
    SELECT role INTO forUserRole FROM permission WHERE user = UNHEX(forUserId) AND project = UNHEX(projectId);
    
    IF forUserRole IS NULL OR (forUserRole NOT IN ('owner', 'admin')) OR (forUserRole = 'admin' AND (addRole IN ('owner', 'admin'))) THEN
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: set permissions',
			MYSQL_ERRNO = 45002;
	ELSE
		IF createTempIdsTable(users) THEN
			SELECT COUNT(*) INTO n FROM tempIds;
			WHILE os < n DO 
				SELECT tId.id INTO currentUserId FROM (SELECT id FROM tempIds ORDER BY id LIMIT os, 1) As tId;
				SELECT role INTO currentUserRole FROM permission AS p WHERE p.project = UNHEX(projectId) AND p.user = currentUserId;
                IF currentUserRole  IS NULL THEN
					IF addRole IS NULL OR addRole = '' THEN
						#uninvite
						DELETE FROM invitation WHERE project = UNHEX(projectId) and user = currentUserId;
                    ELSE
						#initiate invite or assign new role in existing invite
						INSERT INTO invitation
							(project, user, role) 
                        VALUES
							(UNHEX(projectId), currentUserId, addRole)
						ON DUPLICATE KEY UPDATE
							project = project,
                            user = user,
                            role = addRole;
					END IF;
                ELSE
					IF (forUserRole = 'admin' AND (currentUserRole IN ('owner', 'admin'))) OR (currentUserRole = 'owner' AND (addRole IS NULL OR addRole = '') AND (SELECT COUNT(*) FROM permission WHERE project = UNHEX(projectId) && role = 'owner') <= 1) THEN
						SIGNAL SQLSTATE 
							'45002'
						SET
							MESSAGE_TEXT = 'Unauthorized action: set permissions',
							MYSQL_ERRNO = 45002;
					END IF;
					IF addRole IS NULL OR addRole = '' THEN
						#removing user from project
						DELETE FROM permission WHERE project = UNHEX(projectId) and user = currentUserId;
                    ELSE
						#assigning new role
						INSERT INTO permission
							(project, user, role) 
                        VALUES
							(UNHEX(projectId), currentUserId, addRole)
						ON DUPLICATE KEY UPDATE
							project = project,
                            user = user,
                            role = addRole;
                    END IF;
                END IF;
                SET os = os + 1;
			END WHILE;
		END IF;
    END IF;
	DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS _permission_getRole;
DELIMITER $$
CREATE FUNCTION _permission_getRole(forUserId BINARY(16), projectId BINARY(16), userId BINARY(16)) RETURNS VARCHAR(50) NOT DETERMINISTIC
BEGIN
	DECLARE userRole VARCHAR(50) DEFAULT NULL;
    SELECT role INTO userRole FROM permission WHERE user = forUserId AND project = projectId;
	
    IF userRole IS NULL THEN
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: get role',
            MYSQL_ERRNO = 45002;
		RETURN NULL;
	ELSE
		IF forUserId != userId THEN
			RETURN (SELECT role FROM permission WHERE user = userId AND project = projectId);
		END IF;
    END IF;
    RETURN userRole;
END$$
DELIMITER ;

# END PERMISSION

# START USER

DROP PROCEDURE IF EXISTS userLogin;
DELIMITER $$
CREATE PROCEDURE userLogin(autodeskId VARCHAR(50), openId VARCHAR(500), username VARCHAR(100), avatar VARCHAR(500), fullName VARCHAR(100), email VARCHAR(100))
BEGIN
	DECLARE opId BINARY(16) DEFAULT opUuid();
    
	INSERT INTO user
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, uiLanguage, uiTheme, timeFormat)
	VALUES
		(opId, autodeskId, openId, username, avatar, fullName, email, false, UTC_TIMESTAMP(), 'en', 'dark', 'llll')
	ON DUPLICATE KEY UPDATE
		id = id,
        openId = VALUES(openId),
        username = VALUES(username),
        avatar = VALUES(avatar),
        fullName = VALUES(fullName),
        email = VALUES(email),
        superUser = superUser,
        lastLogin = VALUES(lastLogin),
        uiLanguage = uiLanguage,
        uiTheme = uiTheme,
        timeFormat = timeFormat;
        
	SELECT lex(u.id) AS id FROM user AS u WHERE u.autodeskId = autodeskId;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userGetCurrent;
DELIMITER $$
CREATE PROCEDURE userGetCurrent(forUserId VARCHAR(32))
BEGIN        
	SELECT lex(u.id) AS id, u.avatar, u.fullName, u.superUser, u.uiLanguage, u.uiTheme, u.timeFormat FROM user AS u WHERE u.id = UNHEX(forUserId);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userSetUILanguage;
DELIMITER $$
CREATE PROCEDURE userSetUILanguage(forUserId VARCHAR(32), newUILanguage VARCHAR(10))
BEGIN
	UPDATE user SET uiLanguage = newUILanguage WHERE id = UNHEX(forUserId);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userSetUITheme;
DELIMITER $$
CREATE PROCEDURE userSetUITheme(forUserId VARCHAR(32), newUITheme VARCHAR(10))
BEGIN
	UPDATE user SET uiTheme = newUITheme WHERE id = UNHEX(forUserId);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userSetTimeFormat;
DELIMITER $$
CREATE PROCEDURE userSetTimeFormat(forUserId VARCHAR(32), newTimeFormat VARCHAR(20))
BEGIN
	UPDATE user SET timeFormat = newTimeFormat WHERE id = UNHEX(forUserId);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userGet;
DELIMITER $$
CREATE PROCEDURE userGet(ids VARCHAR(6600))
BEGIN
	IF createTempIdsTable(ids) THEN
		SELECT lex(u.id) AS id, avatar, fullName FROM user AS u INNER JOIN tempIds AS t ON u.id = t.id;
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userSearch;
DELIMITER $$
CREATE PROCEDURE userSearch(search VARCHAR(100), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;

	IF os < 0 THEN
		SET os = 0;
    END IF;

	IF l < 0 THEN
		SET l = 0;
    END IF;

	IF l > 100 THEN
		SET l = 100;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tempUserSearch;
    CREATE TEMPORARY TABLE tempUserSearch(
		id BINARY(16) NULL,
		avatar VARCHAR(500),
		fullName VARCHAR(100),
        INDEX (fullName)
    );

    INSERT INTO tempUserSearch (id, avatar, fullName) SELECT u.id, u.avatar, u.fullName FROM user AS u WHERE MATCH(username, fullName, email) AGAINST(search IN NATURAL LANGUAGE MODE);

    SELECT COUNT(*) INTO totalResults FROM tempUserSearch;

    IF os >= totalResults OR l = 0 THEN
		SELECT totalResults;
	ELSE IF sortBy = 'fullNameDesc' THEN
		SELECT totalResults, lex(id) AS id, avatar, fullName FROM tempUserSearch ORDER BY fullName DESC LIMIT os, l;
	ELSE
		SELECT totalResults, lex(id) AS id, avatar, fullName FROM tempUserSearch ORDER BY fullName ASC LIMIT os, l;
	END IF;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tempUserSearch;
END$$
DELIMITER ;

# END USER

# START PROJECT

DROP PROCEDURE IF EXISTS projectCreate;
DELIMITER $$
CREATE PROCEDURE projectCreate(forUserId VARCHAR(32), newProjectId VARCHAR(32), name VARCHAR(100), thumbnailType VARCHAR(50))
BEGIN    
    # create project
	INSERT INTO project
		(id, name, created, thumbnailType)
	VALUES
		(UNHEX(newProjectId), name, UTC_TIMESTAMP(), thumbnailType);
	
    #create default root folder
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(UNHEX(newProjectId), UNHEX('00000000000000000000000000000000'), UNHEX(newProjectId), 'root', 'folder');
        
	# add in owner permission
	INSERT INTO permission
		(project, user, role)
	VALUES
		(UNHEX(newProjectId), UNHEX(forUserId), 'owner');
    
	SELECT newProjectId AS id, name, created, thumbnailType FROM project WHERE id = UNHEX(newProjectId);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectDelete;
DELIMITER $$
CREATE PROCEDURE projectDelete(forUserId VARCHAR(32), projectId VARCHAR(32))
BEGIN
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
	IF forUserRole = 'owner' THEN
		DELETE FROM project WHERE id = UNHEX(projectId);
	ELSE
		SIGNAL SQLSTATE
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: project delete',
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSetName;
DELIMITER $$
CREATE PROCEDURE projectSetName(forUserId VARCHAR(32), projectId VARCHAR(32), newName VARCHAR(100))
BEGIN
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
	IF forUserRole = 'owner' THEN
		UPDATE project SET name = newName WHERE id = UNHEX(projectId);
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: project set name',
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSetThumbnailType;
DELIMITER $$
CREATE PROCEDURE projectSetThumbnailType(forUserId VARCHAR(32), projectId VARCHAR(32), newThumbnailType VARCHAR(10))
BEGIN
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
	IF forUserRole = 'owner' THEN
		UPDATE project SET thumbnailType = newThumbnailType WHERE id = UNHEX(projectId);
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: project set thumbnail type',
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectAddUsers;
DELIMITER $$
CREATE PROCEDURE projectAddUsers(forUserId VARCHAR(32), projectId VARCHAR(32), role VARCHAR(50), users VARCHAR(3300))
BEGIN
	CALL _permission_set(forUserId, projectId, users, role);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectRemoveUsers;
DELIMITER $$
CREATE PROCEDURE projectRemoveUsers(forUserId VARCHAR(32), projectId VARCHAR(32), users VARCHAR(3300))
BEGIN
	CALL _permission_set(forUserId, projectId, users, NULL);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectAcceptInvite;
DELIMITER $$
CREATE PROCEDURE projectAcceptInvite(forUserId VARCHAR(32), projectId VARCHAR(32))
BEGIN
	IF (SELECT COUNT(*) FROM  invitation WHERE project = UNHEX(projectId) AND user = UNHEX(forUserId)) = 1 THEN 
		INSERT INTO permission
			(project, user, role) 
		SELECT 
			i.project, i.user, i.role FROM invitation AS i WHERE i.project = UNHEX(projectId) AND i.user = UNHEX(forUserId)
		ON DUPLICATE KEY UPDATE
			project = i.project,
			user = i.user,
			role = i.role;
		DELETE FROM invitation WHERE project = UNHEX(projectId) AND user = UNHEX(forUserId);
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectDeclineInvite;
DELIMITER $$
CREATE PROCEDURE projectDeclineInvite(forUserId VARCHAR(32), projectId VARCHAR(32))
BEGIN
	DELETE FROM invitation WHERE project = UNHEX(projectId) AND user = UNHEX(forUserId);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectGetRole;
DELIMITER $$
CREATE PROCEDURE projectGetRole(forUserId VARCHAR(32), projectId VARCHAR(32))
BEGIN
	SELECT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId)) AS role;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectGetMemberships;
DELIMITER $$
CREATE PROCEDURE projectGetMemberships(forUserId VARCHAR(32), projectId VARCHAR(32), filterRole VARCHAR(50), os int, l int, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
    
	IF forUserRole IN ('owner', 'admin') THEN
    
		IF os < 0 THEN
			SET os = 0;
		END IF;
		
		IF l < 0 THEN
			SET l = 0;
		END IF;
    
		IF l > 100 THEN
			SET l = 100;
		END IF;
    
		DROP TEMPORARY TABLE IF EXISTS tempProjectGetMemberships;
		CREATE TEMPORARY TABLE tempProjectGetMemberships(
			id BINARY(16) NOT NULL,
			fullName VARCHAR(100),
            role VARCHAR(50),
            PRIMARY KEY (id),
			INDEX (fullName),
            INDEX (role, fullName)
		);
    
		IF filterRole IS NULL OR filterRole = '' OR filterRole = 'any' THEN
			INSERT INTO tempProjectGetMemberships (id, fullName, role) SELECT u.id, u.fullName, p.role FROM user AS u INNER JOIN permission p ON u.id = p.user WHERE p.project = UNHEX(projectId);
		ELSE
			INSERT INTO tempProjectGetMemberships (id, fullName, role) SELECT u.id, u.fullName, p.role FROM user AS u INNER JOIN permission p ON u.id = p.user WHERE p.project = UNHEX(projectId) AND p.role = filterRole;
        END IF;
    
		SELECT COUNT(*) INTO totalResults FROM tempProjectGetMemberships;
    
		IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
		ELSE IF sortBy = 'roleDesc' THEN
			SELECT totalResults, lex(id) AS id, role FROM tempProjectGetMemberships ORDER BY role DESC, fullName ASC LIMIT os, l;
		ELSE IF sortBy = 'roleAsc' THEN
			SELECT totalResults, lex(id) AS id, role FROM tempProjectGetMemberships ORDER BY role ASC, fullName ASC LIMIT os, l;
        ELSE IF sortBy = 'fullNameDesc' THEN
			SELECT totalResults, lex(id) AS id, role FROM tempProjectGetMemberships ORDER BY fullName DESC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(id) AS id, role FROM tempProjectGetMemberships ORDER BY fullName ASC LIMIT os, l;
		END IF;
		END IF;
        END IF;
		END IF;
    
		DROP TEMPORARY TABLE IF EXISTS tempProjectGetMemberships;
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: get memberships',
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectGetMembershipInvites;
DELIMITER $$
CREATE PROCEDURE projectGetMembershipInvites(forUserId VARCHAR(32), projectId VARCHAR(32), filterRole VARCHAR(50), os int, l int, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
    
	IF forUserRole IN ('owner', 'admin') THEN
    
		IF os < 0 THEN
			SET os = 0;
		END IF;
    
		IF l < 0 THEN
			SET l = 0;
		END IF;
    
		IF l > 100 THEN
			SET l = 100;
		END IF;
    
		DROP TEMPORARY TABLE IF EXISTS tempProjectGetMembershipInvites;
		CREATE TEMPORARY TABLE tempProjectGetMembershipInvites(
			id BINARY(16) NOT NULL,
			fullName VARCHAR(100),
            role VARCHAR(50),
            PRIMARY KEY (id),
			INDEX (fullName),
            INDEX (role)
		);
    
		IF filterRole IS NULL OR filterRole = '' OR filterRole = 'any' THEN
			INSERT INTO tempProjectGetMembershipInvites (id, fullName, role) SELECT u.id, u.fullName, p.role FROM user AS u INNER JOIN invitation p ON u.id = p.user WHERE p.project = UNHEX(projectId);
		ELSE
			INSERT INTO tempProjectGetMembershipInvites (id, fullName, role) SELECT u.id, u.fullName, p.role FROM user AS u INNER JOIN invitation p ON u.id = p.user WHERE p.project = UNHEX(projectId) AND p.role = filterRole;
        END IF;
    
		SELECT COUNT(*) INTO totalResults FROM tempProjectGetMembershipInvites;
    
		IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
		ELSE IF sortBy = 'roleDesc' THEN
			SELECT totalResults, lex(id) AS id, role FROM tempProjectGetMembershipInvites ORDER BY role DESC, fullName ASC LIMIT os, l;
		ELSE IF sortBy = 'roleAsc' THEN
			SELECT totalResults, lex(id) AS id, role FROM tempProjectGetMembershipInvites ORDER BY role ASC, fullName ASC LIMIT os, l;
        ELSE IF sortBy = 'fullNameDesc' THEN
			SELECT totalResults, lex(id) AS id, role FROM tempProjectGetMembershipInvites ORDER BY fullName DESC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(id) AS id, role FROM tempProjectGetMembershipInvites ORDER BY fullName ASC LIMIT os, l;
		END IF;
		END IF;
        END IF;
        END IF;
    
		DROP TEMPORARY TABLE IF EXISTS tempProjectGetMembershipInvites;
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: get membership invites',
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectGet;
DELIMITER $$
CREATE PROCEDURE projectGet(forUserId VARCHAR(32), projects VARCHAR(3300))
BEGIN
	DECLARE projectsCount INT DEFAULT 0;
    DECLARE permissionsCount INT DEFAULT 0;
    
	IF createTempIdsTable(projects) THEN        
		SELECT COUNT(*) INTO projectsCount FROM tempIds;
        SELECT COUNT(*) INTO permissionsCount FROM permission AS p INNER JOIN tempIds AS t ON p.project = t.id WHERE p.user = UNHEX(forUserId);
        IF projectsCount = permissionsCount THEN
			SELECT lex(p.id) AS id, name, created, thumbnailType FROM project AS p INNER JOIN tempIds AS t ON p.id = t.id;
        ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: get projects',
				MYSQL_ERRNO = 45002;
        END IF;		
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectGetInUserContext;
DELIMITER $$
CREATE PROCEDURE projectGetInUserContext(forUserId VARCHAR(32), userId VARCHAR(32), filterRole VARCHAR(50), os int, l int, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tempProjectGetInUserContext;
	CREATE TEMPORARY TABLE tempProjectGetInUserContext(
		id BINARY(16) NOT NULL,
		name VARCHAR(100) NULL,
		created DATETIME NOT NULL,
		thumbnailType VARCHAR(50) NULL,
        role VARCHAR(50),
		PRIMARY KEY (id),
		INDEX (name),
        INDEX (created),
        INDEX (role)
	);
    
	IF filterRole IS NULL OR filterRole = '' OR filterRole = 'any' THEN
		IF forUserId = userId THEN
			INSERT INTO tempProjectGetInUserContext SELECT p.id, p.name, p.created, p.thumbnailType, perm1.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin');
        ELSE
			INSERT INTO tempProjectGetInUserContext SELECT p.id, p.name, p.created, p.thumbnailType, perm2.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project INNER JOIN permission perm2 ON perm1.project = perm2.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND perm2.user = UNHEX(userId);
		END IF;
    ELSE
		IF forUserId = userId THEN
			INSERT INTO tempProjectGetInUserContext SELECT p.id, p.name, p.created, p.thumbnailType, perm1.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND perm1.role = filterRole;
        ELSE
			INSERT INTO tempProjectGetInUserContext SELECT p.id, p.name, p.created, p.thumbnailType, perm2.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project INNER JOIN permission perm2 ON perm1.project = perm2.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND perm2.user = UNHEX(userId) AND perm2.role = filterRole;
		END IF;
	END IF;
    
    SELECT COUNT(*) INTO totalResults FROM tempProjectGetInUserContext;
    
    IF os >= totalResults OR l = 0 THEN
		SELECT totalResults;
    ELSE IF sortBy = 'roleDesc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserContext ORDER BY role DESC LIMIT os, l;
    ELSE IF sortBy = 'roleAsc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserContext ORDER BY role ASC LIMIT os, l;
    ELSE IF sortBy = 'createdDesc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserContext ORDER BY created DESC LIMIT os, l;
    ELSE IF sortBy = 'createdAsc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserContext ORDER BY created ASC LIMIT os, l;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserContext ORDER BY name DESC LIMIT os, l;
	ELSE
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserContext ORDER BY name ASC LIMIT os, l;
	END IF;
    END IF;
    END IF;
    END IF;
    END IF;
    END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tempProjectGetInUserContext;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectGetInUserInviteContext;
DELIMITER $$
CREATE PROCEDURE projectGetInUserInviteContext(forUserId VARCHAR(32), userId VARCHAR(32), filterRole VARCHAR(50), os int, l int, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tempProjectGetInUserInviteContext;
	CREATE TEMPORARY TABLE tempProjectGetInUserInviteContext(
		id BINARY(16) NOT NULL,
		name VARCHAR(100) NULL,
		created DATETIME NOT NULL,
		thumbnailType VARCHAR(50) NULL,
        role VARCHAR(50),
		PRIMARY KEY (id),
		INDEX (name),
        INDEX (created),
        INDEX (role)
	);
    
	IF filterRole IS NULL OR filterRole = '' OR filterRole = 'any' THEN
		IF forUserId = userId THEN
			INSERT INTO tempProjectGetInUserInviteContext SELECT p.id, p.name, p.created, p.thumbnailType, i.role FROM project AS p INNER JOIN invitation As i ON p.Id = i.project WHERE i.user = UNHEX(forUserId);
        ELSE
			INSERT INTO tempProjectGetInUserInviteContext SELECT p.id, p.name, p.created, p.thumbnailType, i.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project INNER JOIN invitation i ON perm1.project = i.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND i.user = UNHEX(userId);
		END IF;
    ELSE
		IF forUserId = userId THEN
			INSERT INTO tempProjectGetInUserInviteContext SELECT p.id, p.name, p.created, p.thumbnailType, i.role FROM project AS p INNER JOIN invitation As i ON p.Id = i.project WHERE i.user = UNHEX(forUserId) AND i.role = filterRole;
        ELSE
			INSERT INTO tempProjectGetInUserInviteContext SELECT p.id, p.name, p.created, p.thumbnailType, i.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project INNER JOIN invitation i ON perm1.project = i.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND i.user = UNHEX(userId) AND i.role = filterRole;
		END IF;
	END IF;
    
    SELECT COUNT(*) INTO totalResults FROM tempProjectGetInUserInviteContext;
    
    IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
    ELSE IF sortBy = 'roleDesc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserInviteContext ORDER BY role DESC LIMIT os, l;
    ELSE IF sortBy = 'roleAsc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserInviteContext ORDER BY role ASC LIMIT os, l;
    ELSE IF sortBy = 'createdDesc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserInviteContext ORDER BY created DESC LIMIT os, l;
    ELSE IF sortBy = 'createdAsc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserInviteContext ORDER BY created ASC LIMIT os, l;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserInviteContext ORDER BY name DESC LIMIT os, l;
	ELSE
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType, role FROM tempProjectGetInUserInviteContext ORDER BY name ASC LIMIT os, l;
	END IF;
    END IF;
    END IF;
    END IF;
    END IF;
    END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tempProjectGetInUserInviteContext;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSearch;
DELIMITER $$
CREATE PROCEDURE projectSearch(forUserId VARCHAR(32), search VARCHAR(100), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tempProjectSearch;
	CREATE TEMPORARY TABLE tempProjectSearch(
		id BINARY(16) NOT NULL,
		name VARCHAR(100) NULL,
		created DATETIME NOT NULL,
		thumbnailType VARCHAR(50) NULL,
		PRIMARY KEY (id),
		INDEX (name),
		INDEX (created)
	);
    
	INSERT INTO tempProjectSearch SELECT p.id, name, p.created, p.thumbnailType FROM project AS p INNER JOIN permission AS perm ON p.id = perm.project WHERE perm.user = UNHEX(forUserId) AND MATCH(name) AGAINST(search IN NATURAL LANGUAGE MODE);
    
    SELECT COUNT(*) INTO totalResults FROM tempProjectSearch;
    
    IF os >= totalResults OR l = 0 THEN
		SELECT totalResults;
    ELSE IF sortBy = 'createdDesc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType FROM tempProjectSearch ORDER BY created DESC LIMIT os, l;
    ELSE IF sortBy = 'createdAsc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType FROM tempProjectSearch ORDER BY created ASC LIMIT os, l;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType FROM tempProjectSearch ORDER BY name DESC LIMIT os, l;
    ELSE
		SELECT totalResults, lex(id) AS id, name, created, thumbnailType FROM tempProjectSearch ORDER BY name ASC LIMIT os, l;
	END IF;
    END IF;
    END IF;
    END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tempProjectSearch;
END$$
DELIMITER ;

# END PROJECT

# START TREENODE

DROP PROCEDURE IF EXISTS _treeNode_createNode;
DELIMITER $$
CREATE PROCEDURE _treeNode_createNode(forUserId VARCHAR(32), newTreeNodeId Binary(16), parentId VARCHAR(32), newNodeName VARCHAR(250), newNodeType VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
    DECLARE parentNodeType VARCHAR(50) DEFAULT NULL;
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
    
    SELECT project, nodeType INTO projectId, parentNodeType FROM treeNode WHERE id = UNHEX(parentId);
    
    IF parentNodeType = 'folder' THEN
        SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
		IF (newNodeType = 'folder' AND forUserRole IN ('owner', 'admin', 'organiser')) OR (newNodeType != 'folder' AND forUserRole IN ('owner', 'admin', 'organiser', 'contributor')) THEN
			INSERT INTO treeNode (id, parent, project, name, nodeType) VALUES (newTreeNodeId, UNHEX(parentId), projectId, newNodeName, newNodeType);
			SELECT lex(newTreeNodeId) AS id, parentId AS parent, lex(projectId) AS project, newNodeName AS name, newNodeType AS nodeType, 0 as children;
		ELSE 
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: treeNode create node',
				MYSQL_ERRNO = 45002;
		END IF;
    ELSE
		SIGNAL SQLSTATE 
			'45003'
		SET
			MESSAGE_TEXT = 'Invalid action: place treeNodes under a none folder parent',
            MYSQL_ERRNO = 45003;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeCreateFolder;
DELIMITER $$
CREATE PROCEDURE treeNodeCreateFolder(forUserId VARCHAR(32), parentId VARCHAR(32), folderName VARCHAR(250))
BEGIN
    DECLARE newTreeNodeId BINARY(16) DEFAULT opUuid();
	CALL _treeNode_createNode(forUserId, newTreeNodeId, parentId, folderName, 'folder');
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeCreateDocument;
DELIMITER $$
CREATE PROCEDURE treeNodeCreateDocument(forUserId VARCHAR(32), parentId VARCHAR(32), documentName VARCHAR(250), documentVersionId VARCHAR(32), uploadComment VARCHAR(250), fileType VARCHAR(50), fileExtension VARCHAR(10), urn VARCHAR(1000), status VARCHAR(50), thumbnailType VARCHAR(50))
BEGIN
    DECLARE newTreeNodeId BINARY(16) DEFAULT opUuid();
	CALL _treeNode_createNode(forUserId, newTreeNodeId, parentId, documentName, 'document');
    CALL documentVersionCreate(forUserId, lex(newTreeNodeId), documentVersionId, uploadComment, fileType, fileExtension, urn, status, thumbnailType);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeCreateProjectSpace;
DELIMITER $$
CREATE PROCEDURE treeNodeCreateProjectSpace(forUserId VARCHAR(32), parentId VARCHAR(32), projectSpaceName VARCHAR(250), projectSpaceVersionId VARCHAR(32), createComment VARCHAR(250), cameraJson VARCHAR(1000), thumbnailType VARCHAR(50))
BEGIN
    DECLARE newTreeNodeId BINARY(16) DEFAULT opUuid();
    DECLARE newProjectSpaceVersionId BINARY(16) DEFAULT opUuid();
	CALL _treeNode_createNode(forUserId, newTreeNodeId, parentId, projectSpaceName, 'projectSpace');
    CALL projectSpaceVersionCreate(forUserId, lex(newTreeNodeId), projectSpaceVersionId, createComment, cameraJson, thumbnailType);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeSetName;
DELIMITER $$
CREATE PROCEDURE treeNodeSetName(forUserId VARCHAR(32), treeNodeId VARCHAR(32), newName VARCHAR(250))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM treeNode WHERE id = UNHEX(treeNodeId));
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
	IF forUserRole IN ('owner', 'admin', 'organiser') AND UNHEX(treeNodeId) != projectId THEN
		UPDATE treeNode SET name = newName WHERE id = UNHEX(treeNodeId);
	ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: treeNode set name',
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeMove;
DELIMITER $$
CREATE PROCEDURE treeNodeMove(forUserId VARCHAR(32), newParentId VARCHAR(32), treeNodes VARCHAR(3300))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
    DECLARE newParentNodeType VARCHAR(50) DEFAULT NULL;
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
	DECLARE treeNodesCount INT DEFAULT 0;
    DECLARE treeNodesInSameProjectCount INT DEFAULT 0;
	DECLARE rootParent BINARY(16) DEFAULT UNHEX('00000000000000000000000000000000');
    DECLARE currentParent BINARY(16) DEFAULT NULL;
    DECLARE treeNodeId BINARY(16) DEFAULT NULL;
    
	DROP TEMPORARY TABLE IF EXISTS tempTreeNodeMoveParents;
	CREATE TEMPORARY TABLE tempTreeNodeMoveParents(
		id BINARY(16) NOT NULL,
		PRIMARY KEY (id)
	);
    
    SELECT project, parent, nodeType INTO projectId, currentParent, newParentNodeType FROM treeNode WHERE id = UNHEX(newParentId);
    SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    
	IF forUserRole IN ('owner', 'admin', 'organiser') THEN
		IF newParentNodeType = 'folder' THEN
			IF createTempIdsTable(treeNodes) THEN
				SELECT COUNT(*) INTO treeNodesCount FROM tempIds;
                SELECT COUNT(*) INTO treeNodesInSameProjectCount FROM treeNode AS tn INNER JOIN tempIds AS t ON tn.id = t.id WHERE tn.project = projectId;
				IF treeNodesCount = treeNodesInSameProjectCount THEN
					IF (SELECT COUNT(*) FROM treeNode AS tn INNER JOIN tempIds AS t ON tn.id = t.id WHERE tn.id = tn.project) = 0 THEN
						INSERT INTO tempTreeNodeMoveParents (id) VALUES (UNHEX(newParentId));
						WHILE currentParent != rootParent DO
							SELECT id, parent INTO treeNodeId, currentParent FROM treeNode WHERE id = currentParent;
							INSERT INTO tempTreeNodeMoveParents (id) VALUES (treeNodeId);
						END WHILE;
                        
                        IF (SELECT COUNT(*) FROM tempIds AS t INNER JOIN tempTreeNodeMoveParents AS tp ON t.id = tp.id) = 0 THEN
							UPDATE treeNode SET parent = UNHEX(newParentId) WHERE id IN (SELECT id FROM tempIds);
						ELSE
							SIGNAL SQLSTATE 
								'45003'
							SET
								MESSAGE_TEXT = 'Invalid action: treeNode move would result in looping folder state',
								MYSQL_ERRNO = 45003;
                        END IF;
					ELSE
						SIGNAL SQLSTATE 
							'45003'
						SET
							MESSAGE_TEXT = 'Invalid action: treeNode move root folder',
							MYSQL_ERRNO = 45003;
                    END IF;
				ELSE
					SIGNAL SQLSTATE 
						'45002'
					SET
						MESSAGE_TEXT = 'Unauthorized action: treeNode cross project move',
						MYSQL_ERRNO = 45002;
				END IF;	
            END IF;
		ELSE 
			SIGNAL SQLSTATE 
				'45003'
			SET
				MESSAGE_TEXT = 'Invalid action: place treeNodes under a none folder parent',
				MYSQL_ERRNO = 45003;
		END IF;
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: treeNode move',
			MYSQL_ERRNO = 45002;
	END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
	DROP TEMPORARY TABLE IF EXISTS tempTreeNodeMoveParents;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeGet;
DELIMITER $$
CREATE PROCEDURE treeNodeGet(forUserId VARCHAR(32), treeNodes VARCHAR(3300))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
    DECLARE distinctProjectsCount INT DEFAULT 0;
    
	IF createTempIdsTable(treeNodes) THEN
		SELECT project INTO projectId FROM treeNode WHERE id = (SELECT id FROM tempIds LIMIT 1);
        SELECT COUNT(DISTINCT project) INTO distinctProjectsCount FROM treeNode AS dv INNER JOIN tempIds AS t ON dv.id = t.id;
        IF distinctProjectsCount = 1 AND projectId IS NOT NULL AND _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId)) IS NOT NULL THEN
			SELECT lex(tn1.id) AS id, lex(tn1.parent) AS parent, lex(tn1.project) AS project, name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 INNER JOIN tempIds AS t ON tn1.id = t.id;
        ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: treeNode get cross project',
				MYSQL_ERRNO = 45002;
        END IF;		
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeGetChildren;
DELIMITER $$
CREATE PROCEDURE treeNodeGetChildren(forUserId VARCHAR(32), parentId VARCHAR(32), childNodeType VARCHAR(50), os INT, l INT, sortBy VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
    DECLARE parentNodeType VARCHAR(50) DEFAULT NULL;
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
    DECLARE totalResults INT DEFAULT 0;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
    SELECT project, nodeType INTO projectId, parentNodeType FROM treeNode WHERE id = UNHEX(parentId);
    SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    
    IF parentNodeType = 'folder' THEN
		IF forUserRole IS NOT NULL THEN
			IF childNodeType = '' OR childNodeType = 'any' THEN
				SELECT COUNT(*) INTO totalResults FROM treeNode WHERE parent = UNHEX(parentId);
			ELSE
				SELECT COUNT(*) INTO totalResults FROM treeNode WHERE parent = UNHEX(parentId) AND nodeType = childNodeType;
			END IF;
            
			IF os >= totalResults OR l = 0 THEN
				SELECT totalResults;
            ELSE IF sortBy = 'nameDesc' THEN
				IF childNodeType = '' OR childNodeType = 'any' THEN
					SELECT totalResults, lex(tn1.id) AS id, lex(tn1.parent) AS parent, lex(tn1.project) AS project, name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 WHERE tn1.parent = UNHEX(parentId) ORDER BY name DESC LIMIT os, l;
				ELSE
					SELECT totalResults, lex(tn1.id) AS id, lex(tn1.parent) AS parent, lex(tn1.project) AS project, name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 WHERE tn1.parent = UNHEX(parentId) AND tn1.nodeType = childNodeType ORDER BY name DESC LIMIT os, l;
				END IF;
            ELSE
				IF childNodeType = '' OR childNodeType = 'any' THEN
					SELECT totalResults, lex(tn1.id) AS id, lex(tn1.parent) AS parent, lex(tn1.project) AS project, name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 WHERE tn1.parent = UNHEX(parentId) ORDER BY name ASC LIMIT os, l;
				ELSE
					SELECT totalResults, lex(tn1.id) AS id, lex(tn1.parent) AS parent, lex(tn1.project) AS project, name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 WHERE tn1.parent = UNHEX(parentId) AND tn1.nodeType = childNodeType ORDER BY name ASC LIMIT os, l;
				END IF;			
            END IF;
            END IF;
		ELSE 
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: treeNode get children',
				MYSQL_ERRNO = 45002;
		END IF;
	ELSE
		SIGNAL SQLSTATE 
			'45003'
		SET
			MESSAGE_TEXT = 'Invalid action: get treeNodes from a none folder parent',
            MYSQL_ERRNO = 45003;
	END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeGetParents;
DELIMITER $$
CREATE PROCEDURE treeNodeGetParents(forUserId VARCHAR(32), treeNodeId VARCHAR(32))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
	DECLARE rootParent BINARY(16) DEFAULT UNHEX('00000000000000000000000000000000');
    DECLARE currentParent BINARY(16) DEFAULT NULL;
    DECLARE currentName VARCHAR(250) DEFAULT NULL;
    DECLARE depthCounter INT DEFAULT 0;
    
    SELECT project, parent INTO projectId, currentParent  FROM treeNode WHERE id = UNHEX(treeNodeId);
    SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    
	IF forUserRole IS NOT NULL THEN
		DROP TEMPORARY TABLE IF EXISTS tempTreeNodeGetParents;
		CREATE TEMPORARY TABLE tempTreeNodeGetParents(
			depth INT NOT NULL,
			id VARCHAR(32) NOT NULL,
			parent VARCHAR(32) NULL,
			name VARCHAR(250) NULL,
            PRIMARY KEY (depth)
		);
		WHILE currentParent != rootParent DO
			SELECT lex(id), parent, name INTO treeNodeId, currentParent, currentName FROM treeNode WHERE id = currentParent;
			INSERT INTO tempTreeNodeGetParents (depth, id, parent, name) VALUES (depthCounter, treeNodeId, lex(currentParent), currentName);
            SET depthCounter = depthCounter + 1;
		END WHILE;
        SELECT id, parent, lex(projectId) AS project, name, 'folder' AS nodeType, 0 as childCount FROM tempTreeNodeGetParents ORDER BY depth DESC;
	ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: treeNode get parents',
			MYSQL_ERRNO = 45002;
	END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tempTreeNodeGetParents;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeGlobalSearch;
DELIMITER $$
CREATE PROCEDURE treeNodeGlobalSearch(forUserId VARCHAR(32), search VARCHAR(100), childNodeType VARCHAR(50), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT DEFAULT 0;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tempTreeNodeGlobalSearch;
	CREATE TEMPORARY TABLE tempTreeNodeGlobalSearch(
		id BINARY(16) NOT NULL,
		parent BINARY(16) NULL,
        project BINARY(16) NOT NULL,
		name VARCHAR(250) NULL,
        nodeType VARCHAR(50) NOT NULL,
        childCount INT NOT NULL,
        INDEX (name)
	);
    
	IF childNodeType = '' OR childNodeType = 'any' THEN
		INSERT INTO tempTreeNodeGlobalSearch (id, parent, project, name, nodeType, childCount) SELECT tn1.id, tn1.parent, tn1.project, tn1.name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 INNER JOIN permission AS p ON tn1.project = p.project WHERE p.user = UNHEX(forUserId) AND MATCH(tn1.name) AGAINST(search IN NATURAL LANGUAGE MODE); 
    ELSE
		INSERT INTO tempTreeNodeGlobalSearch (id, parent, project, name, nodeType, childCount) SELECT tn1.id, tn1.parent, tn1.project, tn1.name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 INNER JOIN permission AS p ON tn1.project = p.project WHERE p.user = UNHEX(forUserId) AND tn1.nodeType = childNodeType AND MATCH(tn1.name) AGAINST(search IN NATURAL LANGUAGE MODE); 
    END IF;
    SELECT COUNT(*) INTO totalResults FROM tempTreeNodeGlobalSearch;
    
    IF os >= totalResults OR l = 0 THEN
		SELECT totalResults;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, lex(id) AS id, lex(parent) AS parent, lex(project) AS project, name, nodeType, childCount FROM tempTreeNodeGlobalSearch ORDER BY name DESC LIMIT os, l;
    ELSE
		SELECT totalResults, lex(id) AS id, lex(parent) AS parent, lex(project) AS project, name, nodeType, childCount FROM tempTreeNodeGlobalSearch ORDER BY name ASC LIMIT os, l;			
    END IF;
    END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tempTreeNodeGlobalSearch;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeProjectSearch;
DELIMITER $$
CREATE PROCEDURE treeNodeProjectSearch(forUserId VARCHAR(32), projectId VARCHAR(32), search VARCHAR(100), childNodeType VARCHAR(50), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT DEFAULT 0;
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tempTreeNodeProjectSearch;
	CREATE TEMPORARY TABLE tempTreeNodeProjectSearch(
		id BINARY(16) NOT NULL,
		parent BINARY(16) NULL,
        project BINARY(16) NOT NULL,
		name VARCHAR(250) NULL,
        nodeType VARCHAR(50) NOT NULL,
        childCount INT NOT NULL,
        INDEX (name)
	);
    
    SET forUserRole = _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
    
	IF forUserRole IS NOT NULL THEN
    
		IF childNodeType = '' OR childNodeType = 'any' THEN
			INSERT INTO tempTreeNodeProjectSearch (id, parent, project, name, nodeType, childCount) SELECT tn1.id, tn1.parent, tn1.project, tn1.name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 WHERE tn1.project = UNHEX(projectId) AND MATCH(tn1.name) AGAINST(search IN NATURAL LANGUAGE MODE); 
		ELSE
			INSERT INTO tempTreeNodeProjectSearch (id, parent, project, name, nodeType, childCount) SELECT tn1.id, tn1.parent, tn1.project, tn1.name, tn1.nodeType, (SELECT COUNT(*) + (SELECT COUNT(*) FROM documentVersion WHERE document = tn1.id) + (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = tn1.id) FROM treenode AS tn2 WHERE tn1.id = tn2.parent) AS childCount FROM treeNode AS tn1 WHERE tn1.project = UNHEX(projectId) AND tn1.nodeType = childNodeType AND MATCH(tn1.name) AGAINST(search IN NATURAL LANGUAGE MODE);
		END IF;
		SELECT COUNT(*) INTO totalResults FROM tempTreeNodeProjectSearch;
		
		IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
		ELSE IF sortBy = 'nameDesc' THEN
			SELECT totalResults, lex(id) AS id, lex(parent) AS parent, lex(project) AS project, name, nodeType, childCount FROM tempTreeNodeProjectSearch ORDER BY name DESC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(id) AS id, lex(parent) AS parent, lex(project) AS project, name, nodeType, childCount FROM tempTreeNodeProjectSearch ORDER BY name ASC LIMIT os, l;		
		END IF;
        END IF;
    END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tempTreeNodeProjectSearch;
END$$
DELIMITER ;

# END TREENODE

# START DOCUMENTVERSION

DROP PROCEDURE IF EXISTS documentVersionCreate;
DELIMITER $$
CREATE PROCEDURE documentVersionCreate(forUserId VARCHAR(32), documentId VARCHAR(32), documentVersionId VARCHAR(32), uploadComment VARCHAR(250), fileType VARCHAR(50), fileExtension VARCHAR(10), urn VARCHAR(1000), status VARCHAR(50), thumbnailType VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM treeNode WHERE id = UNHEX(documentId));
    DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    DECLARE version INT DEFAULT (SELECT COUNT(*) FROM documentVersion WHERE document = UNHEX(documentId)) + 1;
    
    IF forUserRole IN ('owner', 'admin', 'organiser', 'contributor') THEN
		INSERT INTO documentVersion (id, document, version, project, uploaded, uploadComment, uploadedBy, fileType, fileExtension, urn, status, thumbnailType)
        VALUES (UNHEX(documentVersionId), UNHEX(documentId), version, projectId, UTC_TIMESTAMP(), uploadComment, UNHEX(forUserId), fileType, fileExtension, urn, status, thumbnailType);
        SELECT lex(dv.id) AS id, lex(document) AS document, version, lex(project) AS project, uploaded, uploadComment, lex(uploadedBy) AS uploadedBy, fileType, fileExtension, urn, status, thumbnailType, 0 AS sheetCount FROM documentVersion AS dv WHERE dv.id = UNHEX(documentVersionId);
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: documentVersion create',
			MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS documentVersionSetStatus;
DELIMITER $$
CREATE PROCEDURE documentVersionSetStatus(documentVersionId VARCHAR(32), newStatus VARCHAR(50))
BEGIN
	UPDATE documentVersion SET status = newStatus WHERE id = UNHEX(documentVersionId);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS documentVersionGet;
DELIMITER $$
CREATE PROCEDURE documentVersionGet(forUserId VARCHAR(32), documentVersions VARCHAR(3300))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
    DECLARE distinctProjectsCount INT DEFAULT 0;
    
	IF createTempIdsTable(documentVersions) THEN
		SELECT project INTO projectId FROM documentVersion WHERE id = (SELECT id FROM tempIds LIMIT 1) LIMIT 1;
        SELECT COUNT(DISTINCT project) INTO distinctProjectsCount FROM documentVersion AS dv INNER JOIN tempIds AS t ON dv.id = t.id;
        IF distinctProjectsCount = 1 AND projectId IS NOT NULL AND _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId)) IS NOT NULL THEN
			SELECT lex(dv.id) AS id, lex(document) AS document, version, lex(project) AS project, uploaded, uploadComment, lex(uploadedBy) AS uploadedBy, fileType, fileExtension, urn, status, thumbnailType, (SELECT COUNT(*) FROM sheet AS s WHERE s.documentVersion = dv.id) AS sheetCount FROM documentVersion AS dv INNER JOIN tempIds AS t ON dv.id = t.id;
        ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: documentVersion get cross project',
				MYSQL_ERRNO = 45002;
        END IF;		
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS documentVersionGetForDocument;
DELIMITER $$
CREATE PROCEDURE documentVersionGetForDocument(forUserId VARCHAR(32), documentId VARCHAR(32), os INT, l INT, sortBy VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM treeNode WHERE id = UNHEX(documentId));
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    DECLARE totalResults INT DEFAULT 0;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
	IF forUserRole IS NOT NULL THEN
		SELECT COUNT(*) INTO totalResults FROM documentVersion WHERE document = UNHEX(documentId);
        IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
		ELSE IF sortBy = 'versionAsc' THEN
			SELECT totalResults, lex(dv.id) AS id, lex(dv.document) AS document, dv.version, lex(dv.project) AS project, dv.uploaded, dv.uploadComment, lex(dv.uploadedBy) AS uploadedBy, dv.fileType, dv.fileExtension, dv.urn, dv.status, dv.thumbnailType, (SELECT COUNT(*) FROM sheet AS s WHERE s.documentVersion = dv.id) AS sheetCount FROM documentVersion AS dv WHERE dv.document = UNHEX(documentId) ORDER BY version ASC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(dv.id) AS id, lex(dv.document) AS document, dv.version, lex(dv.project) AS project, dv.uploaded, dv.uploadComment, lex(dv.uploadedBy) AS uploadedBy, dv.fileType, dv.fileExtension, dv.urn, dv.status, dv.thumbnailType, (SELECT COUNT(*) FROM sheet AS s WHERE s.documentVersion = dv.id) AS sheetCount FROM documentVersion AS dv WHERE dv.document = UNHEX(documentId) ORDER BY version DESC LIMIT os, l;
        END IF;
        END IF;
    ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: documentVersion get by document',
			MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

# END DOCUMENTVERSION

# START PROJECTSPACEVERSION

DROP PROCEDURE IF EXISTS projectSpaceVersionCreate;
DELIMITER $$
CREATE PROCEDURE projectSpaceVersionCreate(forUserId VARCHAR(32), projectSpaceId VARCHAR(32), projectSpaceVersionId VARCHAR(32), createComment VARCHAR(250), cameraJson VARCHAR(1000), thumbnailType VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM treeNode WHERE id = UNHEX(projectSpaceId));
    DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    DECLARE version INT DEFAULT (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = UNHEX(projectSpaceId)) + 1;
    
    IF forUserRole IN ('owner', 'admin', 'organiser', 'contributor') THEN
		INSERT INTO projectSpaceVersion (id, projectSpace, version, project, created, createComment, createdBy, cameraJson, thumbnailType)
        VALUES (UNHEX(projectSpaceVersionId), UNHEX(projectSpaceId), version, projectId, UTC_TIMESTAMP(), createComment, UNHEX(forUserId), cameraJson, thumbnailType);
        SELECT lex(psv.id) AS id, lex(projectSpace) AS projectSpace, version, lex(project) AS project, created, createComment, lex(createdBy) AS createdBy, cameraJson, thumbnailType, 0 AS sheetTransformCount FROM projectSpaceVersion AS psv WHERE psv.id = UNHEX(projectSpaceVersionId);
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: projectSpaceVersion create',
			MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSpaceVersionGet;
DELIMITER $$
CREATE PROCEDURE projectSpaceVersionGet(forUserId VARCHAR(32), projectSpaceVersions VARCHAR(3300))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
    DECLARE distinctProjectsCount INT DEFAULT 0;
    
	IF createTempIdsTable(projectSpaceVersions) THEN
		SELECT project INTO projectId FROM projectSpaceVersion WHERE id = (SELECT id FROM tempIds LIMIT 1) LIMIT 1;
        SELECT COUNT(DISTINCT project) INTO distinctProjectsCount FROM projectSpaceVersion AS psv INNER JOIN tempIds AS t ON psv.id = t.id;
        IF distinctProjectsCount = 1 AND projectId IS NOT NULL AND _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId)) IS NOT NULL THEN
			SELECT lex(psv.id) AS id, lex(projectSpace) AS projectSpace, version, lex(project) AS project, created, createComment, lex(createdBy) AS createdBy, cameraJson, thumbnailType, (SELECT COUNT(*) FROM projectSpaceVersionsheetTransform AS psvst WHERE psvst.projectSpaceVersion = psv.id) AS sheetTransformCount FROM projectSpaceVersion AS psv INNER JOIN tempIds AS t ON psv.id = t.id;
        ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: projectSpaceVersion get cross project',
				MYSQL_ERRNO = 45002;
        END IF;		
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSpaceVersionGetForProjectSpace;
DELIMITER $$
CREATE PROCEDURE projectSpaceVersionGetForProjectSpace(forUserId VARCHAR(32), projectSpaceId VARCHAR(32), os INT, l INT, sortBy VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM treeNode WHERE id = UNHEX(projectSpaceId));
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    DECLARE totalResults INT DEFAULT 0;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
	IF forUserRole IS NOT NULL THEN
		SELECT COUNT(*) INTO totalResults FROM projectSpaceVersion WHERE projectSpace = UNHEX(projectSpaceId);
        IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
		ELSE IF sortBy = 'versionAsc' THEN
			SELECT totalResults, lex(psv.id) AS id, lex(psv.projectSpace) AS projectSpace, psv.version, lex(psv.project) AS project, psv.created, psv.createComment, lex(psv.createdBy) AS createdBy, cameraJson, psv.thumbnailType, (SELECT COUNT(*) FROM projectSpaceVersionsheetTransform AS psvst WHERE psvst.projectSpaceVersion = psv.id) AS sheetTransformCount FROM projectSpaceVersion AS psv WHERE psv.projectSpace = UNHEX(projectSpaceId) ORDER BY version ASC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(psv.id) AS id, lex(psv.projectSpace) AS projectSpace, psv.version, lex(psv.project) AS project, psv.created, psv.createComment, lex(psv.createdBy) AS createdBy, cameraJson, psv.thumbnailType, (SELECT COUNT(*) FROM projectSpaceVersionsheetTransform AS psvst WHERE psvst.projectSpaceVersion = psv.id) AS sheetTransformCount FROM projectSpaceVersion AS psv WHERE psv.projectSpace = UNHEX(projectSpaceId) ORDER BY version DESC LIMIT os, l;
        END IF;
        END IF;
    ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: projectSpaceVersion get by projectSpace',
			MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

# END PROJECTSPACEVERSION

# START SHEET

DROP PROCEDURE IF EXISTS sheetCreate;
DELIMITER $$
CREATE PROCEDURE sheetCreate(documentVersionId VARCHAR(32), projectId VARCHAR(32), name VARCHAR(250), baseUrn VARCHAR(1000), manifest VARCHAR(1000), thumbnails VARCHAR(4000), role VARCHAR(50))
BEGIN
    INSERT INTO sheet (id, documentVersion, project, name, baseUrn, manifest, thumbnails, role)
    VALUES (opUuid(), UNHEX(documentVersionId), UNHEX(projectId), name, baseUrn, manifest, thumbnails, role);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetSetName;
DELIMITER $$
CREATE PROCEDURE sheetSetName(forUserId VARCHAR(32), sheetId VARCHAR(32), newName VARCHAR(250))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM sheet WHERE id = UNHEX(sheetId));
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
	IF forUserRole IN ('owner', 'admin', 'organiser') THEN
		UPDATE sheet SET name = newName WHERE id = UNHEX(sheetId);
	ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: sheet set name',
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetGet;
DELIMITER $$
CREATE PROCEDURE sheetGet(forUserId VARCHAR(32), sheets VARCHAR(3300))
BEGIN
    DECLARE projectId BINARY(16) DEFAULT NULL;
    
    IF createTempIdsTable(sheets) THEN
		SET projectId = (SELECT project FROM sheet WHERE id = (SELECT id FROM tempIds LIMIT 0, 1));
        IF _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId)) IS NOT NULL THEN
			IF (SELECT COUNT(DISTINCT project) FROM sheet WHERE id IN (SELECT id FROM tempIds)) = 1 THEN
				SELECT lex(id) AS id, lex(documentVersion) AS documentVersion, lex(project) AS project, name, baseUrn, manifest, thumbnails, role FROM sheet WHERE id IN (SELECT id FROM tempIds);
			ELSE
				SIGNAL SQLSTATE 
					'45002'
				SET
					MESSAGE_TEXT = 'Unauthorized action: sheet get cross project',
					MYSQL_ERRNO = 45002;
				
            END IF;
		ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: sheet get',
				MYSQL_ERRNO = 45002;
        END IF;
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetGetForDocumentVersion;
DELIMITER $$
CREATE PROCEDURE sheetGetForDocumentVersion(forUserId VARCHAR(32), documentVersionId VARCHAR(32), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM documentVersion WHERE id = UNHEX(documentVersionId));
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    DECLARE totalResults INT DEFAULT 0;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
	IF forUserRole IS NOT NULL THEN
		SELECT COUNT(*) INTO totalResults FROM sheet WHERE documentVersion = UNHEX(documentVersionId);
        IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
		ELSE IF sortBy = 'nameDesc' THEN
			SELECT totalResults, lex(id) AS id, lex(documentVersion) AS documentVersion, lex(project) AS project, name, baseUrn, manifest, thumbnails, role FROM sheet WHERE documentVersion = UNHEX(documentVersionId) ORDER BY name DESC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(id) AS id, lex(documentVersion) AS documentVersion, lex(project) AS project, name, baseUrn, manifest, thumbnails, role FROM sheet WHERE documentVersion = UNHEX(documentVersionId) ORDER BY name ASC LIMIT os, l;
        END IF;
        END IF;
    ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: sheet get by documentVersion',
			MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetGlobalSearch;
DELIMITER $$
CREATE PROCEDURE sheetGlobalSearch(forUserId VARCHAR(32), search VARCHAR(100), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT DEFAULT 0;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tempSheetGlobalSearch;
	CREATE TEMPORARY TABLE tempSheetGlobalSearch(
		id BINARY(16) NOT NULL,
		documentVersion BINARY(16) NOT NULL,
		project BINARY(16) NOT NULL,
		name VARCHAR(250) NULL,
		baseUrn VARCHAR(1000) NOT NULL,
		manifest VARCHAR(1000) NOT NULL,
		thumbnails VARCHAR(4000) NULL,
		role VARCHAR(50) NULL,
		PRIMARY KEY (documentVersion, id),
        INDEX (name)
	);
    
    INSERT INTO tempSheetGlobalSearch (id, documentVersion, project, name, baseUrn, manifest, thumbnails, role) SELECT s.id, s.documentVersion, s.project, s.name, s.baseUrn, s.manifest, s.thumbnails, s.role FROM sheet AS s INNER JOIN permission AS p ON s.project = p.project WHERE p.user = UNHEX(forUserId) AND MATCH(s.name) AGAINST(search IN NATURAL LANGUAGE MODE); 
    SELECT COUNT(*) INTO totalResults FROM tempSheetGlobalSearch;
    
    IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, lex(id) AS id, lex(documentVersion) AS documentVersion, lex(project) AS project, name, baseUrn, manifest, thumbnails, role FROM tempSheetGlobalSearch ORDER BY name DESC LIMIT os, l;
    ELSE
		SELECT totalResults, lex(id) AS id, lex(documentVersion) AS documentVersion, lex(project) AS project, name, baseUrn, manifest, thumbnails, role FROM tempSheetGlobalSearch ORDER BY name ASC LIMIT os, l;
    END IF;
    END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tempSheetGlobalSearch;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetProjectSearch;
DELIMITER $$
CREATE PROCEDURE sheetProjectSearch(forUserId VARCHAR(32), projectId VARCHAR(32), search VARCHAR(100), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT DEFAULT 0;
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
    
	IF os < 0 THEN
		SET os = 0;
	END IF;
    
	IF l < 0 THEN
		SET l = 0;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tempSheetProjectSearch;
	CREATE TEMPORARY TABLE tempSheetProjectSearch(
		id BINARY(16) NOT NULL,
		documentVersion BINARY(16) NOT NULL,
		project BINARY(16) NOT NULL,
		name VARCHAR(250) NULL,
		baseUrn VARCHAR(1000) NOT NULL,
		manifest VARCHAR(1000) NOT NULL,
		thumbnails VARCHAR(4000) NULL,
		role VARCHAR(50) NULL,
		PRIMARY KEY (documentVersion, id),
        INDEX (name)
	);
    
    SET forUserRole = _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
    
    IF forUserRole IS NOT NULL THEN
		INSERT INTO tempSheetProjectSearch (id, documentVersion, project, name, baseUrn, manifest, thumbnails, role) SELECT id, documentVersion, project, name, baseUrn, manifest, thumbnails, role FROM sheet WHERE project = UNHEX(projectId) AND MATCH(name) AGAINST(search IN NATURAL LANGUAGE MODE); 
		SELECT COUNT(*) INTO totalResults FROM tempSheetProjectSearch;
    
		IF os >= totalResults OR l = 0 THEN
			SELECT totalResults;
		ELSE IF sortBy = 'nameDesc' THEN
			SELECT totalResults, lex(id) AS id, lex(documentVersion) AS documentVersion, lex(project) AS project, name, baseUrn, manifest, thumbnails, role FROM tempSheetProjectSearch ORDER BY name DESC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(id) AS id, lex(documentVersion) AS documentVersion, lex(project) AS project, name, baseUrn, manifest, thumbnails, role FROM tempSheetProjectSearch ORDER BY name ASC LIMIT os, l;
		END IF;
		END IF;
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempSheetProjectSearch;
END$$
DELIMITER ;

# END SHEET

# START SHEETTRANSFORM

DROP PROCEDURE IF EXISTS sheetTransformCreate;
DELIMITER $$
CREATE PROCEDURE sheetTransformCreate(forUserId VARCHAR(32), sheetId VARCHAR(32), sheetTransformHashJsonArg VARCHAR(1000), clashChangeRegIdArg VARCHAR(32))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
    
    SELECT project INTO projectId FROM sheet WHERE id = UNHEX(sheetId);
    SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    
    IF forUserRole IN ('owner', 'admin', 'organiser', 'contributor') THEN
		INSERT INTO sheetTransform (id, sheet, sheetTransformHashJson, clashChangeRegId)
		VALUES (opUuid(), UNHEX(sheetId), sheetTransformHashJsonArg, UNHEX(clashChangeRegIdArg))
        ON DUPLICATE KEY UPDATE
			id = id,
            sheet = sheet,
            sheetTransformHashJson = sheetTransformHashJson,
            clashChangeRegId = clashChangeRegId;
	END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetTransformSetClashChangeRedId;
DELIMITER $$
CREATE PROCEDURE sheetTransformSetClashChangeRedId(sheetTransformId VARCHAR(32), clashChangeRegIdArg VARCHAR(32))
BEGIN
	UPDATE sheetTransform SET clashChangeRegId = UNHEX(clashChangeRegIdArg) WHERE id = UNHEX(sheetTransformId);	
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetTransformGet;
DELIMITER $$
CREATE PROCEDURE sheetTransformGet(forUserId VARCHAR(32), sheetTransforms VARCHAR(3300))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
    DECLARE distinctProjectsCount INT DEFAULT 0;
    
	IF createTempIdsTable(sheetTransforms) THEN
		SELECT s.project INTO projectId FROM sheetTransform AS st INNER JOIN sheet AS s ON st.sheet = s.id WHERE st.id = (SELECT id FROM tempIds LIMIT 1) LIMIT 1;
        SELECT COUNT(DISTINCT s.project) INTO distinctProjectsCount FROM sheetTransform AS st INNER JOIN sheet AS s ON st.sheet = s.id INNER JOIN tempIds AS t ON st.id = t.id;
        IF distinctProjectsCount = 1 AND projectId IS NOT NULL AND _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId)) IS NOT NULL THEN
			SELECT lex(st.id) AS id, lex(st.sheet) AS sheet, st.sheetTransformHashJson, lex(st.clashChangeRegId) AS clashChangeRegId, lex(s.documentVersion) AS documentVersion, lex(s.project) AS project, s.name, s.baseUrn, s.manifest, s.thumbnails, s.role FROM sheetTransform AS st INNER JOIN sheet AS s ON st.sheet = s.id INNER JOIN tempIds AS t ON st.id = t.id;
        ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: sheetTransform get cross project',
				MYSQL_ERRNO = 45002;
        END IF;		
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetTransformGetForHashJsons;
DELIMITER $$
CREATE PROCEDURE sheetTransformGetForHashJsons(hashJsons VARCHAR(21000))
BEGIN
	IF createTempSheetTransformHashJsonsTable(hashJsons) THEN
		SELECT lex(st.id) AS id, lex(st.sheet) AS sheet, st.sheetTransformHashJson, lex(st.clashChangeRegId) AS clashChangeRegId, lex(s.documentVersion) AS documentVersion, lex(s.project) AS project, s.name, s.baseUrn, s.manifest, s.thumbnails, s.role FROM sheetTransform AS st INNER JOIN sheet AS s ON st.sheet = s.id INNER JOIN tempSheetTransformHashJsons AS tsthj ON st.sheetTransformHashJson = tsthj.hashJson;
	END IF;
    DROP TEMPORARY TABLE IF EXISTS tempSheetTransformHashJsons;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sheetTransformGetForProjectSpaceVersion;
DELIMITER $$
CREATE PROCEDURE sheetTransformGetForProjectSpaceVersion(forUserId VARCHAR(32), projectSpaceVersionId VARCHAR(32), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM projectSpaceVersion WHERE id = UNHEX(projectSpaceVersionId));
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    DECLARE projectSpaceId BINARY(16) DEFAULT NULL;
    DECLARE totalResults INT DEFAULT 0;

    IF os < 0 THEN
        SET os = 0;
    END IF;
    
    IF l < 0 THEN
        SET l = 0;
    END IF;
    
    IF l > 100 THEN
        SET l = 100;
    END IF;

    
	IF forUserRole IS NOT NULL THEN
    
        SELECT COUNT(*) INTO totalResults FROM projectSpaceVersionSheetTransform WHERE projectSpaceVersion = UNHEX(projectSpaceVersionId);

    
		IF totalResults = 0 THEN
			SELECT projectSpace INTO projectSpaceId FROM projectSpaceVersion WHERE id = UNHEX(projectSpaceVersionId);
			DELETE FROM projectSpaceVersion WHERE id = UNHEX(projectSpaceVersionId);
            IF (SELECT COUNT(*) FROM projectSpaceVersion WHERE projectSpace = UNHEX(projectSpaceId)) = 0 THEN
				DELETE FROM treeNode WHERE id = projectSpaceId;
            END IF;
        END IF;
        
        IF os >= totalResults OR l = 0 THEN
            SELECT totalResults;
        ELSE IF sortBy = 'nameDesc' THEN
            SELECT totalResults, lex(st.id) AS id, lex(st.sheet) AS sheet, st.sheetTransformHashJson, lex(st.clashChangeRegId) AS clashChangeRegId, lex(s.documentVersion) AS documentVersion, lex(s.project) AS project, s.name, s.baseUrn, s.manifest, s.thumbnails, s.role FROM sheetTransform AS st INNER JOIN projectSpaceVersionSheetTransform AS psvst ON st.id = psvst.sheetTransform INNER JOIN sheet AS s ON st.sheet = s.id WHERE psvst.projectSpaceVersion = UNHEX(projectSpaceVersionId) ORDER BY s.name DESC LIMIT os, l;
        ELSE
            SELECT totalResults, lex(st.id) AS id, lex(st.sheet) AS sheet, st.sheetTransformHashJson, lex(st.clashChangeRegId) AS clashChangeRegId, lex(s.documentVersion) AS documentVersion, lex(s.project) AS project, s.name, s.baseUrn, s.manifest, s.thumbnails, s.role FROM sheetTransform AS st INNER JOIN projectSpaceVersionSheetTransform AS psvst ON st.id = psvst.sheetTransform INNER JOIN sheet AS s ON st.sheet = s.id WHERE psvst.projectSpaceVersion = UNHEX(projectSpaceVersionId) ORDER BY s.name ASC LIMIT os, l;
        END IF;
        END IF;
        
    ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: sheetTransform get by projectSpaceVersion',
			MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSpaceVersionSheetTransformCreate;
DELIMITER $$
CREATE PROCEDURE projectSpaceVersionSheetTransformCreate(projectSpaceVersionId VARCHAR(32), sheetTransformIds VARCHAR(3300))
BEGIN
	DECLARE projectSpaceVersionProjectId BINARY(16) DEFAULT (SELECT project FROM projectSpaceVersion WHERE id = UNHEX(projectSpaceVersionId));
	DECLARE sheetProjectId BINARY(16) DEFAULT NULL;
    
	IF createTempIdsTable(sheetTransformIds) THEN
		SELECT s.project INTO sheetProjectId FROM sheet as s INNER JOIN sheetTransform AS st ON s.id = st.sheet WHERE st.id = (SELECT id FROM tempIds LIMIT 1);
		IF projectSpaceVersionProjectId = sheetProjectId THEN
			INSERT INTO projectSpaceVersionSheetTransform (projectSpaceVersion, sheetTransform)
			SELECT UNHEX(projectSpaceVersionId), t.id FROM tempIds AS t;
        END IF;
    ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: projectSpaceVersionSheetTransformCreate cross project',
			MYSQL_ERRNO = 45002;
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

# END SHEETTRANSFORM

# START CLASH

DROP PROCEDURE IF EXISTS clashTestCreate;
DELIMITER $$
CREATE PROCEDURE clashTestCreate(forUserId VARCHAR(32), clashTestId VARCHAR(32), sheetTransformA VARCHAR(32), sheetTransformB VARCHAR(32))
BEGIN
	DECLARE lst BINARY(16) DEFAULT UNHEX(sheetTransformA);
	DECLARE rst BINARY(16) DEFAULT UNHEX(sheetTransformB);
	DECLARE lstProjectId BINARY(16) DEFAULT (SELECT s.project FROM sheet AS s INNER JOIN sheetTransform AS st ON s.id = st.sheet WHERE st.id = lst);
	DECLARE rstProjectId BINARY(16) DEFAULT (SELECT s.project FROM sheet AS s INNER JOIN sheetTransform AS st ON s.id = st.sheet WHERE st.id = rst);
    
    IF sheetTransformA = sheetTransformB THEN
		SIGNAL SQLSTATE 
			'45003'
		SET
			MESSAGE_TEXT = 'Invalid action: clashTestCreate same sheetTransform',
			MYSQL_ERRNO = 45003;   
    END IF;
    
    IF lstProjectId = rstProjectId THEN    
		IF _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId)) IS NOT NULL THEN
			IF sheetTransformB < sheetTransformA THEN
				SET lst = UNHEX(sheetTransformB);
				SET rst = UNHEX(sheetTransformA);
			END IF;
    
			INSERT INTO clashTest (id, leftSheetTransform, rightSheetTransform)
			VALUES (UNHEX(clashTestId), lst, rst);
        ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: get clash test',
				MYSQL_ERRNO = 45002;  
        
        END IF;    
    ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: clashTestCreate cross project',
			MYSQL_ERRNO = 45002;    
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS clashTestGetForSheetTransforms;
DELIMITER $$
CREATE PROCEDURE clashTestGetForSheetTransforms(forUserId VARCHAR(32), sheetTransformA VARCHAR(32), sheetTransformB VARCHAR(32))
BEGIN
	DECLARE lst BINARY(16) DEFAULT UNHEX(sheetTransformA);
	DECLARE rst BINARY(16) DEFAULT UNHEX(sheetTransformB);
	DECLARE lstProjectId BINARY(16) DEFAULT (SELECT s.project FROM sheet AS s INNER JOIN sheetTransform AS st ON s.id = st.sheet WHERE st.id = lst);
	DECLARE rstProjectId BINARY(16) DEFAULT (SELECT s.project FROM sheet AS s INNER JOIN sheetTransform AS st ON s.id = st.sheet WHERE st.id = rst);
    
    
    IF lstProjectId = rstProjectId THEN    
		IF _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId)) IS NOT NULL THEN
			IF sheetTransformB < sheetTransformA THEN
				SET lst = UNHEX(sheetTransformB);
				SET rst = UNHEX(sheetTransformA);
			END IF;
    
			SELECT lex(id) as id FROM clashTest WHERE leftSheetTransform = lst AND rightSheetTransform = rst;
		ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = 'Unauthorized action: get clash test',
				MYSQL_ERRNO = 45002;  
        
        END IF;
    ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = 'Unauthorized action: clashTestGetForSheetTransforms cross project',
			MYSQL_ERRNO = 45002;    
    END IF;
    
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS _clashTest_getForSheetTransforms;
DELIMITER $$
CREATE PROCEDURE _clashTest_getForSheetTransforms(sheetTransformA VARCHAR(32), sheetTransformB VARCHAR(32))
BEGIN
	DECLARE lst BINARY(16) DEFAULT UNHEX(sheetTransformA);
	DECLARE rst BINARY(16) DEFAULT UNHEX(sheetTransformB);
    
	IF sheetTransformB < sheetTransformA THEN
		SET lst = UNHEX(sheetTransformB);
		SET rst = UNHEX(sheetTransformA);
	END IF;
    
	SELECT lex(id) as id FROM clashTest WHERE leftSheetTransform = lst AND rightSheetTransform = rst;
END$$
DELIMITER ;

# END CLASH

# This username and password are for local testing purposes only, 
# formally deployed environments should have cryptographically
# strong usernames and passwords maintained by ops, developers
# shoulds not have access to these credentials.
DROP USER IF EXISTS 'modelhub-api'@'%';
CREATE USER 'modelhub-api'@'%' IDENTIFIED BY 'M0d-3l-Hu8-@p1'; 
GRANT EXECUTE ON modelhub.* TO 'modelhub-api'@'%';