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
			MESSAGE_TEXT = "Invalid ids argument",
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

# END UTIL

# START TABLES
DROP TABLE IF EXISTS user;
CREATE TABLE user(
	id BINARY(16) NOT NULL,
    autodeskId VARCHAR(50) NOT NULL,
    openId VARCHAR(500) NULL,
    username VARCHAR(100) NULL,
    avatar VARCHAR(500) NULL,
    fullName VARCHAR(100) NULL,
    email VARCHAR(100) NULL,
    superUser BOOL DEFAULT FALSE,
    lastLogin DATETIME NOT NULL,
    description VARCHAR(250) NULL,
    uiLanguage VARCHAR(10) NOT NULL,
    uiTheme VARCHAR(10) NOT NULL,
    locale VARCHAR(10) NOT NULL,
    timeFormat VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE INDEX (autodeskId),
    FULLTEXT (username, fullName, email)
);

DROP TABLE IF EXISTS project;
CREATE TABLE project(
	id BINARY(16) NOT NULL,
    name VARCHAR(100) NULL,
    description VARCHAR(250) NULL,
    created DATETIME NOT NULL,
    imageFileExtension VARCHAR(10) NULL,
    PRIMARY KEY (id),
    FULLTEXT (name)
);

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
		('viewerState');

DROP TABLE IF EXISTS treeNode;
CREATE TABLE treeNode(
	id BINARY(16) NOT NULL,
	parent BINARY(16) NULL,
    project BINARY(16) NOT NULL,
    name VARCHAR(50) NULL,
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

DROP TABLE IF EXISTS documentVersion;
CREATE TABLE documentVersion(
	id BINARY(16) NOT NULL,
	document BINARY(16) NOT NULL,
    version MEDIUMINT NOT NULL,
    project BINARY(16) NOT NULL,
    uploaded DATETIME NOT NULL,
    uploadComment VARCHAR(250) NULL,
    uploadedBy BINARY(16) NOT NULL,
    fileExtension VARCHAR(10) NOT NULL,
    urn VARCHAR(1000) NOT NULL,
    status VARCHAR(50) NOT NULL,
	PRIMARY KEY (document, version, id),
    UNIQUE INDEX (id),
    FOREIGN KEY (project) REFERENCES project(id) ON DELETE CASCADE,
    FOREIGN KEY (document) REFERENCES treeNode(id) ON DELETE CASCADE,
    FOREIGN KEY (uploadedBy) REFERENCES user(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS sheet;
CREATE TABLE sheet(
	id BINARY(16) NOT NULL,
	documentVersion BINARY(16) NOT NULL,
    project BINARY(16) NOT NULL,
    name VARCHAR(100) NULL,
    baseUrn VARCHAR(1000) NOT NULL,
    path VARCHAR(1000) NOT NULL,
    role VARCHAR(50) NULL,
	PRIMARY KEY (documentVersion, id),
    UNIQUE INDEX (id),
    UNIQUE INDEX (project, id),
    FULLTEXT(name),
    FOREIGN KEY (project) REFERENCES project(id) ON DELETE CASCADE,
    FOREIGN KEY (documentVersion) REFERENCES documentVersion(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS thumbnail;
CREATE TABLE thumbnail(
	sheet BINARY(16) NOT NULL,
	path VARCHAR(1000) NOT NULL,
	PRIMARY KEY (sheet, path),
    FOREIGN KEY (sheet) REFERENCES sheet(id) ON DELETE CASCADE
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
    
    SELECT role INTO forUserRole FROM permission WHERE user = UNHEX(forUserId) AND project = UNHEX(projectId);
    
    IF forUserRole IS NULL OR (forUserRole NOT IN ('owner', 'admin')) OR (forUserRole = 'admin' AND (addRole IN ('owner', 'admin'))) THEN
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: set permissions",
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
							MESSAGE_TEXT = "Unauthorized action: set permissions",
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
			MESSAGE_TEXT = "Unauthorized action: get role",
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

DROP PROCEDURE IF EXISTS permissionGetRole;
DELIMITER $$
CREATE PROCEDURE permissionGetRole(forUserId VARCHAR(32), projectId VARCHAR(32))
BEGIN
	SELECT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId)) AS role;
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
		(id, autodeskId, openId, username, avatar, fullName, email, superUser, lastLogin, description, uiLanguage, uiTheme, locale, timeFormat)
	VALUES
		(opId, autodeskId, openId, username, avatar, fullName, email, false, UTC_TIMESTAMP(), NULL, "en", "dark", "en-US", "llll")
	ON DUPLICATE KEY UPDATE
		id = id,
        openId = VALUES(openId),
        username = VALUES(username),
        avatar = VALUES(avatar),
        fullName = VALUES(fullName),
        email = VALUES(email),
        superUser = superUser,
        lastLogin = VALUES(lastLogin),
        description = description,
        uiLanguage = uiLanguage,
        uiTheme = uiTheme,
        locale = locale,
        timeFormat = timeFormat;
        
	SELECT lex(u.id) AS id, u.username, u.avatar, u.fullName, u.superUser, u.description, u.uiLanguage, u.uiTheme, u.locale, u.timeFormat FROM user AS u WHERE u.autodeskId = autodeskId;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userSetDescription;
DELIMITER $$
CREATE PROCEDURE userSetDescription(forUserId VARCHAR(32), newDescription VARCHAR(250))
BEGIN
	UPDATE user SET description = newDescription WHERE id = UNHEX(forUserId);
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

DROP PROCEDURE IF EXISTS userSetLocale;
DELIMITER $$
CREATE PROCEDURE userSetLocale(forUserId VARCHAR(32), newLocale VARCHAR(10))
BEGIN
	UPDATE user SET locale = newLocale WHERE id = UNHEX(forUserId);
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
		SELECT lex(u.id) AS id, username, avatar, fullName FROM user AS u INNER JOIN tempIds AS t ON u.id = t.id;
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
    
	IF l < 1 THEN
		SET l = 1;
    END IF;
    
	IF l > 100 THEN
		SET l = 100;
    END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tempUserSearch;
    CREATE TEMPORARY TABLE tempUserSearch(
		id BINARY(16) NULL,
		username VARCHAR(100),
		avatar VARCHAR(500),
		fullName VARCHAR(100),
        description VARCHAR(250),
        INDEX (username),
        INDEX (fullName)
    );
    
    INSERT INTO tempUserSearch (id, username, avatar, fullName, description) SELECT u.id, u.username, u.avatar, u.fullName, u.description FROM user AS u WHERE MATCH(username, fullName, email) AGAINST(search IN NATURAL LANGUAGE MODE);
	
    SELECT COUNT(*) INTO totalResults FROM tempUserSearch;
    
    IF os >= totalResults THEN
		SELECT totalResults;
        SIGNAL SQLSTATE
			'45004'
		SET
			MESSAGE_TEXT = "offset beyond the end of results set",
            MYSQL_ERRNO = 45004;
    ELSE IF sortBy = 'usernameAsc' THEN
		SELECT totalResults, lex(id) AS id, username, avatar, fullName, description FROM tempUserSearch ORDER BY username ASC LIMIT os, l;
	ELSE IF sortBy = 'usernameDesc' THEN
		SELECT totalResults, lex(id) AS id, username, avatar, fullName, description FROM tempUserSearch ORDER BY username DESC LIMIT os, l;
	ELSE IF sortBy = 'fullNameDesc' THEN
		SELECT totalResults, lex(id) AS id, username, avatar, fullName, description FROM tempUserSearch ORDER BY fullName DESC LIMIT os, l;
	ELSE
		SELECT totalResults, lex(id) AS id, username, avatar, fullName, description FROM tempUserSearch ORDER BY fullName ASC LIMIT os, l;
	END IF;
    END IF;
    END IF;
    END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tempUserSearch;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userGetInProjectContext;
DELIMITER $$
CREATE PROCEDURE userGetInProjectContext(forUserId VARCHAR(32), projectId VARCHAR(32), filterRole VARCHAR(50), os int, l int, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
    
	IF forUserRole IN ('owner', 'admin') THEN
    
		IF os < 0 THEN
			SET os = 0;
		END IF;
		
		IF l < 1 THEN
			SET l = 1;
		END IF;
    
		IF l > 100 THEN
			SET l = 100;
		END IF;
    
		DROP TEMPORARY TABLE IF EXISTS tempUserGetInProjectContext;
		CREATE TEMPORARY TABLE tempUserGetInProjectContext(
			id BINARY(16) NOT NULL,
			username VARCHAR(100),
			avatar VARCHAR(500),
			fullName VARCHAR(100),
            role VARCHAR(50),
            PRIMARY KEY (id),
			INDEX (username),
			INDEX (fullName),
            INDEX (role, fullName)
		);
    
		IF filterRole IS NULL OR filterRole = '' OR filterRole = 'any' THEN
			INSERT INTO tempUserGetInProjectContext (id, username, avatar, fullName, role) SELECT u.id, u.username, u.avatar, u.fullName, p.role FROM user AS u INNER JOIN permission p ON u.id = p.user WHERE p.project = UNHEX(projectId);
		ELSE
			INSERT INTO tempUserGetInProjectContext (id, username, avatar, fullName, role) SELECT u.id, u.username, u.avatar, u.fullName, p.role FROM user AS u INNER JOIN permission p ON u.id = p.user WHERE p.project = UNHEX(projectId) AND p.role = filterRole;
        END IF;
    
		SELECT COUNT(*) INTO totalResults FROM tempUserGetInProjectContext;
    
		IF os >= totalResults THEN
			SELECT totalResults;
			SIGNAL SQLSTATE
				'45004'
			SET
				MESSAGE_TEXT = "offset beyond the end of results set",
				MYSQL_ERRNO = 45004;
		ELSE IF sortBy = 'roleDesc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectContext ORDER BY role DESC, fullName ASC LIMIT os, l;
		ELSE IF sortBy = 'roleAsc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectContext ORDER BY role ASC, fullName ASC LIMIT os, l;
		ELSE IF sortBy = 'usernameDesc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectContext ORDER BY username DESC LIMIT os, l;
		ELSE IF sortBy = 'usernameAsc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectContext ORDER BY username ASC LIMIT os, l;
        ELSE IF sortBy = 'fullNameDesc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectContext ORDER BY fullName DESC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectContext ORDER BY fullName ASC LIMIT os, l;
		END IF;
		END IF;
        END IF;
		END IF;
        END IF;
        END IF;
    
		DROP TEMPORARY TABLE IF EXISTS tempUserGetInProjectContext;
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: get user in project context",
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS userGetInProjectInviteContext;
DELIMITER $$
CREATE PROCEDURE userGetInProjectInviteContext(forUserId VARCHAR(32), projectId VARCHAR(32), filterRole VARCHAR(50), os int, l int, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
    
	IF forUserRole IN ('owner', 'admin') THEN
    
		IF os < 0 THEN
			SET os = 0;
		END IF;
    
		IF l < 1 THEN
			SET l = 1;
		END IF;
    
		IF l > 100 THEN
			SET l = 100;
		END IF;
    
		DROP TEMPORARY TABLE IF EXISTS tempUserGetInProjectInviteContext;
		CREATE TEMPORARY TABLE tempUserGetInProjectInviteContext(
			id BINARY(16) NOT NULL,
			username VARCHAR(100),
			avatar VARCHAR(500),
			fullName VARCHAR(100),
            role VARCHAR(50),
            PRIMARY KEY (id),
			INDEX (username),
			INDEX (fullName),
            INDEX (role)
		);
    
		IF filterRole IS NULL OR filterRole = '' OR filterRole = 'any' THEN
			INSERT INTO tempUserGetInProjectInviteContext (id, username, avatar, fullName, role) SELECT u.id, u.username, u.avatar, u.fullName, p.role FROM user AS u INNER JOIN invitation p ON u.id = p.user WHERE p.project = UNHEX(projectId);
		ELSE
			INSERT INTO tempUserGetInProjectInviteContext (id, username, avatar, fullName, role) SELECT u.id, u.username, u.avatar, u.fullName, p.role FROM user AS u INNER JOIN invitation p ON u.id = p.user WHERE p.project = UNHEX(projectId) AND p.role = filterRole;
        END IF;
    
		SELECT COUNT(*) INTO totalResults FROM tempUserGetInProjectInviteContext;
    
		IF os >= totalResults THEN
			SELECT totalResults;
			SIGNAL SQLSTATE
				'45004'
			SET
				MESSAGE_TEXT = "offset beyond the end of results set",
				MYSQL_ERRNO = 45004;
		ELSE IF sortBy = 'roleDesc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectInviteContext ORDER BY role DESC, fullName ASC LIMIT os, l;
		ELSE IF sortBy = 'roleAsc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectInviteContext ORDER BY role ASC, fullName ASC LIMIT os, l;
		ELSE IF sortBy = 'usernameDesc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectInviteContext ORDER BY username DESC LIMIT os, l;
		ELSE IF sortBy = 'usernameAsc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectInviteContext ORDER BY username ASC LIMIT os, l;
        ELSE IF sortBy = 'fullNameDesc' THEN
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectInviteContext ORDER BY fullName DESC LIMIT os, l;
		ELSE
			SELECT totalResults, lex(id) AS id, username, avatar, fullName, role FROM tempUserGetInProjectInviteContext ORDER BY fullName ASC LIMIT os, l;
		END IF;
		END IF;
        END IF;
        END IF;
        END IF;
        END IF;
    
		DROP TEMPORARY TABLE IF EXISTS tempUserGetInProjectInviteContext;
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: get user in project invites context",
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

# END USER

# START PROJECT

DROP PROCEDURE IF EXISTS projectCreate;
DELIMITER $$
CREATE PROCEDURE projectCreate(forUserId VARCHAR(32), name VARCHAR(100), description VARCHAR(1000), imageFileExtension VARCHAR(10))
BEGIN
	DECLARE opId BINARY(16) DEFAULT opUuid();
    
    # create project
	INSERT INTO project
		(id, name, description, created, imageFileExtension)
	VALUES
		(opId, name, description, UTC_TIMESTAMP(), imageFileExtension);
	
    #create default root folder
	INSERT INTO treeNode
		(id, parent, project, name, nodeType)
	VALUES
		(opId, NULL, opId, 'root', 'folder');
        
	# add in owner permission
	INSERT INTO permission
		(project, user, role)
	VALUES
		(opId, UNHEX(forUserId), 'owner');
    
	SELECT lex(id) AS id, name, description, created, imageFileExtension FROM project WHERE id = opId;
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
			MESSAGE_TEXT = "Unauthorized action: project set name",
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSetDescription;
DELIMITER $$
CREATE PROCEDURE projectSetDescription(forUserId VARCHAR(32), projectId VARCHAR(32), newDescription VARCHAR(250))
BEGIN
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
	IF forUserRole = 'owner' THEN
		UPDATE project SET description = newDescription WHERE id = UNHEX(projectId);
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: project set description",
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSetImageFileExtension;
DELIMITER $$
CREATE PROCEDURE projectSetImageFileExtension(forUserId VARCHAR(32), projectId VARCHAR(32), newImageFileExtension VARCHAR(10))
BEGIN
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
	IF forUserRole = 'owner' THEN
		UPDATE project SET imageFileExtension = newImageFileExtension WHERE id = UNHEX(projectId);
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: project set image file extension",
            MYSQL_ERRNO = 45002;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectAddOwners;
DELIMITER $$
CREATE PROCEDURE projectAddOwners(forUserId VARCHAR(32), projectId VARCHAR(32), users VARCHAR(3300))
BEGIN
	CALL _permission_set(forUserId, projectId, users, 'owner');
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectAddAdmins;
DELIMITER $$
CREATE PROCEDURE projectAddAdmins(forUserId VARCHAR(32), projectId VARCHAR(32), users VARCHAR(3300))
BEGIN
	CALL _permission_set(forUserId, projectId, users, 'admin');
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectAddOrganisers;
DELIMITER $$
CREATE PROCEDURE projectAddOrganisers(forUserId VARCHAR(32), projectId VARCHAR(32), users VARCHAR(3300))
BEGIN
	CALL _permission_set(forUserId, projectId, users, 'organiser');
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectAddContributors;
DELIMITER $$
CREATE PROCEDURE projectAddContributors(forUserId VARCHAR(32), projectId VARCHAR(32), users VARCHAR(3300))
BEGIN
	CALL _permission_set(forUserId, projectId, users, 'contributor');
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectAddObservers;
DELIMITER $$
CREATE PROCEDURE projectAddObservers(forUserId VARCHAR(32), projectId VARCHAR(32), users VARCHAR(3300))
BEGIN
	CALL _permission_set(forUserId, projectId, users, 'observer');
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectRemoveUsers;
DELIMITER $$
CREATE PROCEDURE projectRemoveUsers(forUserId VARCHAR(32), projectId VARCHAR(32), users VARCHAR(3300))
BEGIN
	CALL _permission_set(forUserId, projectId, users, NULL);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectAcceptInvitation;
DELIMITER $$
CREATE PROCEDURE projectAcceptInvitation(forUserId VARCHAR(32), projectId VARCHAR(32))
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

DROP PROCEDURE IF EXISTS projectDeclineInvitation;
DELIMITER $$
CREATE PROCEDURE projectDeclineInvitation(forUserId VARCHAR(32), projectId VARCHAR(32))
BEGIN
	DELETE FROM invitation WHERE project = UNHEX(projectId) AND user = UNHEX(forUserId);
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
			SELECT lex(p.id) AS id, name, description, created, imageFileExtension FROM project AS p INNER JOIN tempIds AS t ON p.id = t.id;
        ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = "Unauthorized action: get projects",
				MYSQL_ERRNO = 45002;
        END IF;		
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS projectSearch;
DELIMITER $$
CREATE PROCEDURE projectSearch(forUserId VARCHAR(32), search VARCHAR(100), os INT, l INT, sortBy VARCHAR(50))
BEGIN
    DECLARE totalResults INT;
    
	DROP TEMPORARY TABLE IF EXISTS tempProjectSearch;
	CREATE TEMPORARY TABLE tempProjectSearch(
		id BINARY(16) NOT NULL,
		name VARCHAR(100) NULL,
		description VARCHAR(250) NULL,
		created DATETIME NOT NULL,
		imageFileExtension VARCHAR(10) NULL,
		PRIMARY KEY (id),
		INDEX (name),
		INDEX (created)
	);
    
	INSERT INTO tempProjectSearch SELECT p.id, name, p.description, p.created, p.imageFileExtension FROM project AS p INNER JOIN permission AS perm ON p.id = perm.project WHERE perm.user = UNHEX(forUserId) AND MATCH(name) AGAINST(search IN NATURAL LANGUAGE MODE);
    
    SELECT COUNT(*) INTO totalResults FROM tempProjectSearch;
    
    IF os >= totalResults THEN
		SELECT totalResults;
        SIGNAL SQLSTATE
			'45004'
		SET
			MESSAGE_TEXT = "offset beyond the end of results set",
            MYSQL_ERRNO = 45004;
    ELSE IF sortBy = 'createdDesc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension FROM tempProjectSearch ORDER BY created DESC LIMIT os, l;
    ELSE IF sortBy = 'createdAsc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension FROM tempProjectSearch ORDER BY created ASC LIMIT os, l;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension FROM tempProjectSearch ORDER BY name DESC LIMIT os, l;
    ELSE
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension FROM tempProjectSearch ORDER BY name ASC LIMIT os, l;
	END IF;
    END IF;
    END IF;
    END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tempProjectSearch;
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
    
	IF l < 1 THEN
		SET l = 1;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tempProjectGetInUserContext;
	CREATE TEMPORARY TABLE tempProjectGetInUserContext(
		id BINARY(16) NOT NULL,
		name VARCHAR(100) NULL,
		description VARCHAR(250) NULL,
		created DATETIME NOT NULL,
		imageFileExtension VARCHAR(10) NULL,
        role VARCHAR(50),
		PRIMARY KEY (id),
		INDEX (name),
        INDEX (created),
        INDEX (role)
	);
    
	IF filterRole IS NULL OR filterRole = '' OR filterRole = 'any' THEN
		IF forUserId = userId THEN
			INSERT INTO tempProjectGetInUserContext SELECT p.id, p.name, p.description, p.created, p.imageFileExtension, perm1.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin');
        ELSE
			INSERT INTO tempProjectGetInUserContext SELECT p.id, p.name, p.description, p.created, p.imageFileExtension, perm2.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project INNER JOIN permission perm2 ON perm1.project = perm2.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND perm2.user = UNHEX(userId);
		END IF;
    ELSE
		IF forUserId = userId THEN
			INSERT INTO tempProjectGetInUserContext SELECT p.id, p.name, p.description, p.created, p.imageFileExtension, perm1.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND perm1.role = filterRole;
        ELSE
			INSERT INTO tempProjectGetInUserContext SELECT p.id, p.name, p.description, p.created, p.imageFileExtension, perm2.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project INNER JOIN permission perm2 ON perm1.project = perm2.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND perm2.user = UNHEX(userId) AND perm2.role = filterRole;
		END IF;
	END IF;
    
    SELECT COUNT(*) INTO totalResults FROM tempProjectGetInUserContext;
    
    IF os >= totalResults THEN
		SELECT totalResults;
        SIGNAL SQLSTATE
			'45004'
		SET
			MESSAGE_TEXT = "offset beyond the end of results set",
            MYSQL_ERRNO = 45004;
    ELSE IF sortBy = 'roleDesc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserContext ORDER BY role DESC LIMIT os, l;
    ELSE IF sortBy = 'roleAsc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserContext ORDER BY role ASC LIMIT os, l;
    ELSE IF sortBy = 'createdDesc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserContext ORDER BY created DESC LIMIT os, l;
    ELSE IF sortBy = 'createdAsc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserContext ORDER BY created ASC LIMIT os, l;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserContext ORDER BY name DESC LIMIT os, l;
	ELSE
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserContext ORDER BY name ASC LIMIT os, l;
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
    
	IF l < 1 THEN
		SET l = 1;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tempProjectGetInUserInviteContext;
	CREATE TEMPORARY TABLE tempProjectGetInUserInviteContext(
		id BINARY(16) NOT NULL,
		name VARCHAR(100) NULL,
		description VARCHAR(250) NULL,
		created DATETIME NOT NULL,
		imageFileExtension VARCHAR(10) NULL,
        role VARCHAR(50),
		PRIMARY KEY (id),
		INDEX (name),
        INDEX (created),
        INDEX (role)
	);
    
	IF filterRole IS NULL OR filterRole = '' OR filterRole = 'any' THEN
		IF forUserId = userId THEN
			INSERT INTO tempProjectGetInUserInviteContext SELECT p.id, p.name, p.description, p.created, p.imageFileExtension, i.role FROM project AS p INNER JOIN invitation As i ON p.Id = i.project WHERE i.user = UNHEX(forUserId);
        ELSE
			INSERT INTO tempProjectGetInUserInviteContext SELECT p.id, p.name, p.description, p.created, p.imageFileExtension, i.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project INNER JOIN invitation i ON perm1.project = i.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND i.user = UNHEX(userId);
		END IF;
    ELSE
		IF forUserId = userId THEN
			INSERT INTO tempProjectGetInUserInviteContext SELECT p.id, p.name, p.description, p.created, p.imageFileExtension, i.role FROM project AS p INNER JOIN invitation As i ON p.Id = i.project WHERE i.user = UNHEX(forUserId) AND i.role = filterRole;
        ELSE
			INSERT INTO tempProjectGetInUserInviteContext SELECT p.id, p.name, p.description, p.created, p.imageFileExtension, i.role FROM project AS p INNER JOIN permission As perm1 ON p.Id = perm1.project INNER JOIN invitation i ON perm1.project = i.project WHERE perm1.user = UNHEX(forUserId) AND perm1.role IN ('owner', 'admin') AND i.user = UNHEX(userId) AND i.role = filterRole;
		END IF;
	END IF;
    
    SELECT COUNT(*) INTO totalResults FROM tempProjectGetInUserInviteContext;
    
    IF os >= totalResults THEN
		SELECT totalResults;
        SIGNAL SQLSTATE
			'45004'
		SET
			MESSAGE_TEXT = "offset beyond the end of results set",
            MYSQL_ERRNO = 45004;
    ELSE IF sortBy = 'roleDesc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserInviteContext ORDER BY role DESC LIMIT os, l;
    ELSE IF sortBy = 'roleAsc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserInviteContext ORDER BY role ASC LIMIT os, l;
    ELSE IF sortBy = 'createdDesc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserInviteContext ORDER BY created DESC LIMIT os, l;
    ELSE IF sortBy = 'createdAsc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserInviteContext ORDER BY created ASC LIMIT os, l;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserInviteContext ORDER BY name DESC LIMIT os, l;
	ELSE
		SELECT totalResults, lex(id) AS id, name, description, created, imageFileExtension, role FROM tempProjectGetInUserInviteContext ORDER BY name ASC LIMIT os, l;
	END IF;
    END IF;
    END IF;
    END IF;
    END IF;
    END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tempProjectGetInUserInviteContext;
END$$
DELIMITER ;

# END PROJECT

# START TREENODE

DROP PROCEDURE IF EXISTS _treeNode_createNode;
DELIMITER $$
CREATE PROCEDURE _treeNode_createNode(forUserId VARCHAR(32), newTreeNodeId Binary(16), parentId VARCHAR(32), newNodeName VARCHAR(50), newNodeType VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT NULL;
    DECLARE parentNodeType VARCHAR(50) DEFAULT NULL;
	DECLARE forUserRole VARCHAR(50) DEFAULT NULL;
    
    SELECT project, nodeType INTO projectId, parentNodeType FROM treeNode WHERE id = UNHEX(parentId);
    
    IF parentNodeType = 'folder' THEN
        SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
		IF (newNodeType = 'folder' AND forUserRole IN ('owner', 'admin', 'organiser')) OR (newNodeType != 'folder' AND forUserRole IN ('owner', 'admin', 'organiser', 'contributor')) THEN
			INSERT INTO treeNode (id, parent, project, name, nodeType) VALUES (newTreeNodeId, UNHEX(parentId), projectId, newNodeName, newNodeType);
			SELECT lex(newTreeNodeId) AS id, parentId AS parent, lex(projectId) AS project, newNodeName AS name, newNodeType AS nodeType;
		ELSE 
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = "Unauthorized action: treeNode create node",
				MYSQL_ERRNO = 45002;
		END IF;
    ELSE
		SIGNAL SQLSTATE 
			'45003'
		SET
			MESSAGE_TEXT = "Invalid action: place treeNodes under a none folder parent",
            MYSQL_ERRNO = 45003;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeCreateFolder;
DELIMITER $$
CREATE PROCEDURE treeNodeCreateFolder(forUserId VARCHAR(32), parentId VARCHAR(32), folderName VARCHAR(50))
BEGIN
    DECLARE newTreeNodeId BINARY(16) DEFAULT opUuid();
	CALL _treeNode_createNode(forUserId, newTreeNodeId, parentId, folderName, 'folder');
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeCreateDocument;
DELIMITER $$
CREATE PROCEDURE treeNodeCreateDocument(forUserId VARCHAR(32), parentId VARCHAR(32), documentName VARCHAR(50), documentVersionId VARCHAR(32), uploadComment VARCHAR(250), fileExtension VARCHAR(10), urn VARCHAR(1000), status VARCHAR(50))
BEGIN
    DECLARE newTreeNodeId BINARY(16) DEFAULT opUuid();
	CALL _treeNode_createNode(forUserId, newTreeNodeId, parentId, documentName, 'document');
    CALL documentVersionCreate(forUserId, lex(newTreeNodeId), documentVersionId, uploadComment, fileExtension, urn, status);
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeCreateViewerState;
DELIMITER $$
CREATE PROCEDURE treeNodeCreateViewerState(forUserId VARCHAR(32), parentId VARCHAR(32), viewerStateName VARCHAR(50))
BEGIN
    DECLARE newTreeNodeId BINARY(16) DEFAULT opUuid();
	CALL _treeNode_createNode(forUserId, newTreeNodeId, parentId, viewerStateName, 'viewerState');
    #TODO insert viewerState rows
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS treeNodeSetName;
DELIMITER $$
CREATE PROCEDURE treeNodeSetName(forUserId VARCHAR(32), treeNodeId VARCHAR(32), newName VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM treeNode WHERE id = UNHEX(treeNodeId));
	DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
	IF forUserRole IN ('owner', 'admin', 'organiser') AND UNHEX(treeNodeId) != projectId THEN
		UPDATE treeNode SET name = newName WHERE id = UNHEX(treeNodeId);
	ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: treeNode set name",
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
    
    SELECT project, nodeType INTO projectId, newParentNodeType FROM treeNode WHERE id = UNHEX(newParentId);
    SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    
	IF forUserRole IN ('owner', 'admin', 'organiser') THEN
		IF newParentNodeType = 'folder' THEN
			IF createTempIdsTable(treeNodes) THEN
				SELECT COUNT(*) INTO treeNodesCount FROM tempIds;
                SELECT COUNT(*) INTO treeNodesInSameProjectCount FROM treeNode AS tn INNER JOIN tempIds AS t ON tn.id = t.id WHERE project = projectId;
				IF treeNodesCount = treeNodesInSameProjectCount THEN
					IF (SELECT COUNT(*) FROM treeNode AS tn INNER JOIN tempIds AS t ON tn.id = t.id WHERE tn.id = project) = 0 THEN
						UPDATE treeNode SET parent = UNHEX(newParentId) WHERE id IN (SELECT id FROM tempIds);
					ELSE
						SIGNAL SQLSTATE 
							'45003'
						SET
							MESSAGE_TEXT = "Invalid action: treeNode move root folder",
							MYSQL_ERRNO = 45003;
                    END IF;
				ELSE
					SIGNAL SQLSTATE 
						'45002'
					SET
						MESSAGE_TEXT = "Unauthorized action: treeNode cross project move",
						MYSQL_ERRNO = 45002;
				END IF;	
            END IF;
		ELSE 
			SIGNAL SQLSTATE 
				'45003'
			SET
				MESSAGE_TEXT = "Invalid action: place treeNodes under a none folder parent",
				MYSQL_ERRNO = 45003;
		END IF;
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: treeNode move",
			MYSQL_ERRNO = 45002;
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
    
	IF l < 1 THEN
		SET l = 1;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
    SELECT project, nodeType INTO projectId, parentNodeType FROM treeNode WHERE id = UNHEX(parentId);
    SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    
    IF parentNodeType = 'folder' THEN
		IF forUserRole IS NOT NULL THEN
			SELECT COUNT(*) INTO totalResults FROM treeNode WHERE parent = UNHEX(parentId) AND nodeType = childNodeType;
            IF totalResults = 0 THEN
				SELECT totalResults;
            ELSE IF sortBy = 'nameDesc' THEN
				SELECT totalResults, lex(id) AS id, lex(parent) AS parent, lex(project) AS project, name, nodeType FROM treeNode WHERE parent = UNHEX(parentId) AND nodeType = childNodeType ORDER BY name DESC LIMIT os, l;
            ELSE
				SELECT totalResults, lex(id) AS id, lex(parent) AS parent, lex(project) AS project, name, nodeType FROM treeNode WHERE parent = UNHEX(parentId) AND nodeType = childNodeType ORDER BY name ASC LIMIT os, l;				
            END IF;
            END IF;
		ELSE 
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = "Unauthorized action: treeNode get children",
				MYSQL_ERRNO = 45002;
		END IF;
	ELSE
		SIGNAL SQLSTATE 
			'45003'
		SET
			MESSAGE_TEXT = "Invalid action: get treeNodes from a none folder parent",
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
    DECLARE currentParent BINARY(16) DEFAULT NULL;
    DECLARE currentName VARCHAR(50) DEFAULT NULL;
    DECLARE depthCounter INT DEFAULT 0;
    
    SELECT project, parent INTO projectId, currentParent  FROM treeNode WHERE id = UNHEX(treeNodeId);
    SET forUserRole = _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    
	IF forUserRole IS NOT NULL THEN
		DROP TEMPORARY TABLE IF EXISTS tempTreeNodeGetParents;
		CREATE TEMPORARY TABLE tempTreeNodeGetParents(
			depth INT NOT NULL,
			id VARCHAR(32) NOT NULL,
			parent VARCHAR(32) NULL,
			name VARCHAR(50) NULL,
            PRIMARY KEY (depth)
		);
		WHILE currentParent IS NOT NULL DO
			SELECT lex(id), parent, name INTO treeNodeId, currentParent, currentName FROM treeNode WHERE id = currentParent;
			INSERT INTO tempTreeNodeGetParents (depth, id, parent, name) VALUES (depthCounter, treeNodeId, lex(currentParent), currentName);
            SET depthCounter = depthCounter + 1;
		END WHILE;
        SELECT id, parent, name FROM tempTreeNodeGetParents ORDER BY depth DESC;
	ELSE 
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: treeNode get parents",
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
    
	IF l < 1 THEN
		SET l = 1;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tempTreeNodeGlobalSearch;
	CREATE TEMPORARY TABLE tempTreeNodeGlobalSearch(
		id VARCHAR(32) NOT NULL,
		parent VARCHAR(32) NULL,
        project VARCHAR(32) NOT NULL,
		name VARCHAR(50) NULL,
        nodeType VARCHAR(50) NOT NULL,
        INDEX (name)
	);
    
    INSERT INTO tempTreeNodeGlobalSearch (id, parent, project, name, nodeType) SELECT lex(tn.id), lex(tn.parent), lex(tn.project), tn.name, tn.nodeType FROM treeNode AS tn INNER JOIN permission AS p ON tn.project = p.project WHERE p.user = UNHEX(forUserId) AND tn.nodeType = childNodeType AND MATCH(tn.name) AGAINST(search IN NATURAL LANGUAGE MODE); 
    SELECT COUNT(*) INTO totalResults FROM tempTreeNodeGlobalSearch;
    
    IF totalResults = 0 THEN
		SELECT totalResults;
    ELSE IF sortBy = 'nameDesc' THEN
		SELECT totalResults, id, parent, project, name, nodeType FROM tempTreeNodeGlobalSearch ORDER BY name DESC LIMIT os, l;
    ELSE
		SELECT totalResults, id, parent, project, name, nodeType FROM tempTreeNodeGlobalSearch ORDER BY name ASC LIMIT os, l;				
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
    
	IF l < 1 THEN
		SET l = 1;
	END IF;
    
	IF l > 100 THEN
		SET l = 100;
	END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tempTreeNodeProjectSearch;
	CREATE TEMPORARY TABLE tempTreeNodeProjectSearch(
		id VARCHAR(32) NOT NULL,
		parent VARCHAR(32) NULL,
        project VARCHAR(32) NOT NULL,
		name VARCHAR(50) NULL,
        nodeType VARCHAR(50) NOT NULL,
        INDEX (name)
	);
    
    SET forUserRole = _permission_getRole(UNHEX(forUserId), UNHEX(projectId), UNHEX(forUserId));
    
	IF forUserRole IS NOT NULL THEN
		INSERT INTO tempTreeNodeProjectSearch (id, parent, project, name, nodeType) SELECT lex(id), lex(parent), lex(project), name, nodeType FROM treeNode WHERE project = UNHEX(projectId) AND nodeType = childNodeType AND MATCH(name) AGAINST(search IN NATURAL LANGUAGE MODE); 
		SELECT COUNT(*) INTO totalResults FROM tempTreeNodeProjectSearch;
    
		IF totalResults = 0 THEN
			SELECT totalResults;
		ELSE IF sortBy = 'nameDesc' THEN
			SELECT totalResults, id, parent, project, name, nodeType FROM tempTreeNodeProjectSearch ORDER BY name DESC LIMIT os, l;
		ELSE
			SELECT totalResults, id, parent, project, name, nodeType FROM tempTreeNodeProjectSearch ORDER BY name ASC LIMIT os, l;				
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
CREATE PROCEDURE documentVersionCreate(forUserId VARCHAR(32), documentId VARCHAR(32), documentVersionId VARCHAR(32), uploadComment VARCHAR(250), fileExtension VARCHAR(10), urn VARCHAR(1000), status VARCHAR(50))
BEGIN
	DECLARE projectId BINARY(16) DEFAULT (SELECT project FROM treeNode WHERE id = UNHEX(documentId));
    DECLARE forUserRole VARCHAR(50) DEFAULT _permission_getRole(UNHEX(forUserId), projectId, UNHEX(forUserId));
    DECLARE version INT DEFAULT (SELECT COUNT(*) FROM documentVersion WHERE document = UNHEX(documentId)) + 1;
    
    IF forUserRole IN ('owner', 'admin', 'organiser', 'contributor') THEN
		INSERT INTO documentVersion (id, document, version, project, uploaded, uploadComment, uploadedBy, fileExtension, urn, status)
        VALUES (UNHEX(documentVersionId), UNHEX(documentId), version, projectId, UTC_TIMESTAMP(), uploadComment, UNHEX(forUserId), fileExtension, urn, status);
	ELSE
		SIGNAL SQLSTATE 
			'45002'
		SET
			MESSAGE_TEXT = "Unauthorized action: documentVersion create",
			MYSQL_ERRNO = 45002;
    END IF;
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
			SELECT lex(dv.id) AS id, lex(document) as document, version, lex(project) AS project, uploaded, uploadComment, lex(uploadedBy) AS uploadedBy, FileExtension, status FROM documentVersion AS dv INNER JOIN tempIds AS t ON dv.id = t.id;
        ELSE
			SIGNAL SQLSTATE 
				'45002'
			SET
				MESSAGE_TEXT = "Unauthorized action: documentVersion get",
				MYSQL_ERRNO = 45002;
        END IF;		
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tempIds;
END$$
DELIMITER ;

# END DOCUMENTVERSION