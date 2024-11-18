# Install & Run Oracle APEX in a Docker Environment
![Docker](https://img.shields.io/badge/docker-blue) ![Docker-Compose](https://img.shields.io/badge/docker-compose-00BFFF) ![Oracle](https://img.shields.io/badge/oracle-c74634) ![Oracle-APEX](https://img.shields.io/badge/oracle-apex-ca4d3c)
## Why This Repository
So far, with the manuals both on Oracle's website as well as the ones found on blogs etc. I never really succeeded in putting up the APEX stack on docker.

However, starting to try with some more (docker) experience after procrastinating APEX in the recent 3 years, and with new energy, I found some key hints about getting it done.

## Content
This docker project contains the following:
* [Oracle Database Express (latest)](https://container-registry.oracle.com/ords/ocr/ba/database/express)
* [Oracle REST Data Services (ORDS) (latest)](https://container-registry.oracle.com/ords/ocr/ba/database/ords)
* [Oracle APEX (latest)](https://www.oracle.com/tools/downloads/apex-downloads/)

## TL;DR
Here's the recipe to get this done:
1. [Create folders](https://github.com/schnillerman/oracle-apex-docker/tree/main?tab=readme-ov-file#prepare-directories-for-persistent-data)
2. [Initialize Express DB](https://github.com/schnillerman/oracle-apex-docker/tree/main?tab=readme-ov-file#create--run-express-container-to-setup-persistent-db)
3. [Setup APEX in the Express DB](https://github.com/schnillerman/oracle-apex-docker/tree/main?tab=readme-ov-file#run-temporary-ords-developer-container-to-setupinstall-apex-in-the-express-db)
4. [Download APEX files](https://github.com/schnillerman/oracle-apex-docker/tree/main?tab=readme-ov-file#download--extract-apex-files)
5. [Create & Run Docker Compose](https://github.com/schnillerman/oracle-apex-docker/tree/main?tab=readme-ov-file#run-docker-compose-for-apex)
6. Optional: [Access APEX from WAN with HTTPS / Reverse Proxy](https://github.com/schnillerman/oracle-apex-docker/tree/main?tab=readme-ov-file#access-apex-from-wan-with-https--reverse-proxy)

## Detailed Instructions
### Prerequisites
#### Image Sources
I wanted to use the following images:
- Express DB:
  - [https://container-registry.oracle.com/ords/ocr/ba/database/**express**](https://container-registry.oracle.com/ords/ocr/ba/database/express) as opposed to
  - [https://container-registry.oracle.com/ords/ocr/ba/database/**free**](https://container-registry.oracle.com/ords/ocr/ba/database/free))
- ORDS:
  - [https://container-registry.oracle.com/ords/ocr/ba/database/**ords**](https://container-registry.oracle.com/ords/ocr/ba/database/ords) as opposed to
  - [https://container-registry.oracle.com/ords/ocr/ba/database/**ords-developer**](https://container-registry.oracle.com/ords/ocr/ba/database/ords-developer)
 
The ords-developer image **does not** contain and install APEX, but there's a solution.

#### Naming Conventions
A few remarks about the names of objects:
**I generally try to name docker containers, networks etc. by using prefixes so I can identify them easier in, e.g., lists (```docker ls ...```) or when searching for their repositories (directories).**

In this context, ```rad``` is short for _**R**apid **A**pplication **D**evelopment_, and, since there are several platforms, ```oracle-apex``` is the second prefix.
```express```and ```ords``` are then the specifying parts of the name.

In the case of docker service names, I use only ```express``` and ```ords``` because those service names are referred to only within the compose file.

### Prepare Directories For Persistent Data
Start in the docker project's direcctory.
#### Express
```
mkdir -p ./express/oradata && \
mkdir -p ./express/scripts/startup && \
mkdir -p ./express/scripts/setup
```
#### ORDS
```
mkdir -p ./ORDS/variables && \
mkdir -p ./ORDS/config
```
### Create & Run Express Container to Setup Persistent DB
Create ```.env``` file containing a ```ORACLE_PWD``` variable and a password (do not use special characters, only numbers, small and caps for compatibility reasons):

```ORACLE_PWD=<password without quotes of any kind>```, e.g., ```1230321abcABC```.

Then run the following command to
* create and run the container ```rad-oracle-apex-express```
* set up a persistent database (stored in ```./express/oradata```)

```
docker run \
	-d \
  --name rad-oracle-apex-express \
	--network rad-oracle-apex \
	--hostname express \
  --env-file ./.env
	-p 1521:1521 -e ORACLE_PWD=${ORACLE_PWD} \
	-v $(pwd)/express/oradata/:/opt/oracle/oradata \
	container-registry.oracle.com/database/express:latest
```
> [!NOTE]
> Note that running the container for the first time (initialization of persistent data) takes a long time - on my Synology DS918+, it took ~2.5hrs.

### Run Temporary ORDS-Developer Container to Setup/Install APEX in the Express DB
Create the file ```conn_string.txt``` in the directory ```./ORDS/variables``` with the following content:
```
CONN_STRING=sys/<ORACLE_PWD>@<express hostname>:1521/XEPDB1
```
Replace ```<ORACLE_PWD>``` with the password from the ```.env``` file and the ```<hostname>``` with the express container's hostname (```express```), e.g.:

```
CONN_STRING=sys/<ORACLE_PWD>@express:1521/XEPDB1
```
E.g.,
```
CONN_STRING=sys/1230321abcABC@express:1521/XEPDB1
```

Then run the following command to
* create and run the container ```rad-oracle-apex-ords-temp```
* install APEX in the Express

```
docker run \
	-d \
	--name rad-oracle-apex-ords \
	--network rad-oracle-apex \
    -v $(pwd)/ORDS/config:/etc/ords/config \
	-v $(pwd)/ORDS/variables:/opt/oracle/variables \
	-p 8181:8181 \
    container-registry.oracle.com/database/ords-developer:latest
```
If you want to check, run the command as is, and open ```http://<docker-host>/ords:8181``` to see whether the APEX environment has been installed successfully.

Login:

- Workspace: ```internal```
- User:      ```ADMIN```
- Password:  ```Welcome_1```

After successful check, the container can be stopped and removed (```docker stop <container-name> && docker rm <container name>```).

If you don't want to check right now, add the line ```--rm`\``` after ```-d \``` in order to remove the temporary container after APEX is installed.

### Finalize Setup
#### Download & Extract APEX Files
```
mkdir ./apex && \
cd ./apex && \
curl -o apex.zip https://download.oracle.com/otn_software/apex/apex-latest.zip && \
unzip -q apex.zip
```
#### Set The APEX Directory In The ORDS Container

> [!IMPORTANT]
> Run the ORDS container once in order to update the config with the installed APEX files:
> ```
> docker run --network --rm -it \
>  -v $(pwd)/ORDS/config:/etc/ords/config: \
>  -v $(pwd)/apex/:/opt/oracle/apex/ \ 
>  container-registry.oracle.com/database/ords:latest \
>  config set standalone.static.path /opt/oracle/apex/images
>  ```
> Reason: The ords image does not contain the APEX files.

#### Run Docker Compose for APEX
```
services:
  express: # XE database
    image: container-registry.oracle.com/database/express:latest # 21.3.0-xe
    container_name: rad-oracle-apex-express
    # hostname: oracledev
    restart: unless-stopped
    environment:
      - ORACLE_PWD=${ORACLE_PWD} # make sure the declaration is in the .env file as ORACLE_PWD=<your password, non complex, min. 8 chars small, cap, & numbers>
    networks:
      - apex
    #ports:
    #  - 1521:1521
    #  - 5500:5500
    # depends_on:
    #   - oracle-ords
    volumes:
      - ./express/oradata:/opt/oracle/oradata
      - ./express/scripts/setup:/opt/oracle/scripts/setup
      - ./express/scripts/startup:/opt/oracle/scripts/startup
    #healthcheck:
    #  #test command below is with grep because in my case, the output of checkDBstatus.sh is always "The Oracle base remains unchanged with value /opt/oracle" which seems to indicate the DB is fine.
    #  test: /opt/oracle/checkDBStatus.sh | grep -q 'remains unchanged'
    #  interval: 30s
    #  timeout: 10s
    #  retries: 10
    #  #  start_period: 120s not working on Synology NAS

  ords:
    #image: container-registry.oracle.com/database/ords-developer:latest
    image: container-registry.oracle.com/database/ords:latest
    container_name: rad-oracle-apex-ords
    restart: unless-stopped
    #depends_on:
    #  express:
    #    condition: service_healthy
    volumes:
      - ./ORDS/variables:/opt/oracle/variables
      - ./ORDS/config:/etc/ords/config
      - ./apex/:/opt/oracle/apex
    networks:
      - apex
    ports:
      - 8080:8080

networks:
  apex:
    name: rad-oracle-apex
```

#### Log Into APEX Workspace
1. Go to your instance's APEX homepage, e.g., ```http://<docker-host>```.
2. Select _Oracle APEX_ (the middle pane)
3. Login:
   - Workspace: ```internal```
   - User:      ```ADMIN```
   - Password:  ```Welcome_1```

> [!WARNING]
> If you changed the password during log-in check from running the temporary ORDS-Developer container, use the updated password!

#### [Log Into APEX Administration](https://docs.oracle.com/en/database/oracle/apex/24.1/aeadm/accessing-oracle-application-express-administration-services.html#GUID-C325A307-7047-4FCB-86B7-F7771069F995)
1. Go to your instance's APEX homepage, e.g., ```http://<docker-host>```.
2. Select _Oracle APEX_ (the middle pane)
3. Go to the bottom of the page and select _Administration_ in the _Tasks_ column
4. Login:
   - User: ```admin```
   - Password: The one you changed the default password ```Welcome_1``` to

#### Log Into SQL Developer Web (SDW)
Well, that's a whole different story: [_The workspace/database schema needs to be enabled for SDW_](https://docs.oracle.com/en/database/oracle/sql-developer-web/sdwad/accessing-sql-developer-web.html#GUID-63D265FC-7500-4F88-8870-1C60E0A286FF) as follows:

1. Log into the _express_ container's CLI:
   - To get to the SQL prompt directly: ```docker exec -it oracle-apex-express sqlplus sys/<ORACLE_PWD>@//localhost:1521/XEPDB1 as sysdba```
   - Via shell: ```docker exec -it oracle-apex-express sh``` and then enter ```sqlplus sys/<ORACLE_PWD>@//localhost:1521/XEPDB1 as sysdba``` at the prompt
2. Now, the following must be entered:
   ```
   BEGIN
    ords_admin.enable_schema(
     p_enabled => TRUE,
     p_schema => 'schema-name',
     p_url_mapping_type => 'BASE_PATH',
     p_url_mapping_pattern => 'schema-alias',
     p_auto_rest_auth => NULL
    );
    commit;
   END;
   /
   ```
> [!IMPORTANT]
> - The value of ```p_schema``` (```schema-name```) has to be all upper case!
> - The value of ```p_url_mapping_pattern``` (```schema-alias```) has to be all lower case!
> - [The ```/``` at the end of the statement is important in order to execute the statement](https://www.oreilly.com/library/view/oracle-sqlplus-the/1565925785/apas06.html).[^1]

   E.g.,
   ```
   BEGIN
    ords_admin.enable_schema(
     p_enabled => TRUE,
     p_schema => 'WORKSPACE1',
     p_url_mapping_type => 'BASE_PATH',
     p_url_mapping_pattern => 'workspace1',
     p_auto_rest_auth => NULL
    );
    commit;
   END;
   /
   ```
3. Optional: Verify if schema (= value used for ```p_schema```) has been enabled with ```select username from all_users order by username```
4. Change user password via SQL prompt: ```alter user <user> identified by <password>;``` (replace ```<user```) - every workspace, in the database, is basically a user, hence this step
5. Go to ```http(s)://<domain name>/ords/sql-developer``` and log in with the credentials used above

> [!WARNING]
> There seems to be a [bug](https://stackoverflow.com/questions/79093084/oracle-sql-developer-web-navigator-objects-not-loading) in ORDS which prevents objects from loading in SDW's _Data Modeler_ and _SQL Navigator_.
> The DB user (equals workspace name) therefore needs to be granted resource permissions as follows:
> ```
> grant <privilege> to <user>
> ```
> This solution might work, with me, it didn't. However, the ORDS update from Nov. 8, 2024, solved the issue.

## Access APEX from WAN with HTTPS / Reverse Proxy
Put the following 2 lines into ```./ORDS/config/global/settings.xml```, replacing ```<your apex domain, no trailing slash>``` with your domain's name:
```
<entry key="security.externalSessionTrustedOrigins">http://<your apex domain, no trailing slash>, https://<your apex domain, no trailing slash>:443</entry>
<entry key="security.forceHTTPS">true</entry>
```

The complete settings.xml might now look similar to:
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
<comment>Saved on Mon Oct 21 16:07:13 UTC 2024</comment>
<entry key="database.api.enabled">true</entry>
<entry key="db.invalidPoolTimeout">5s</entry>
<entry key="debug.printDebugToScreen">true</entry>
<entry key="standalone.static.path">/opt/oracle/apex/images</entry>
<entry key="security.externalSessionTrustedOrigins">http://<your apex domain, no trailing slash>, https://<your apex domain, no trailing slash>:443</entry>
<entry key="security.forceHTTPS">true</entry>
</properties>
```

## Docker Installation Sources
### Sources used for new attempt
* Oracle:
  * https://container-registry.oracle.com/ords/ocr/ba/database/express
  * https://container-registry.oracle.com/ords/ocr/ba/database/ords-developer
  * https://container-registry.oracle.com/ords/ocr/ba/database/ords
  * https://docs.oracle.com/en/database/oracle/sql-developer-web/19.1/sdweb/about-sdw.html#GUID-A79032C3-86DC-4547-8D39-85674334B4FE
* Schnell und einfach: Erstellen einer lokalen APEX-Umgebung mit Docker-Compose [https://blog.ordix.de/erstellen-einer-lokalen-apex-umgebung-docker-compose]
* https://github.com/akridge/oracle-apex-docker-stack?tab=readme-ov-file#how-to-install
* Docker Compose for Oracle APEX (https://tm-apex.hashnode.dev/docker-compose-for-oracle-apex)
* Oracle 23c Free Docker, APEX & ORDS – all in one simple guide - Pretius (https://pretius.com/blog/oracle-apex-docker-ords/)
* ... and, finally, for SSL: [How to Secure Oracle APEX Development Environment with Free SSL from Let's Encrypt?](https://www.youtube.com/watch?v=cRE_kxjz_zw)

### Sources used years ago
* oracle-apex-docker-stack [https://github.com/akridge/oracle-apex-docker-stack]
* https://github.com/oraclebase/dockerfiles/blob/master/ords/ol8_ords/Dockerfile
* https://oracle-base.com/articles/linux/articles-linux#docker
* https://oracle-base.com/blog/2021/11/05/apex-21-2-vagrant-and-docker-builds/
* https://registry.hub.docker.com/r/esestt/oracle-apex
* https://github.com/OraOpenSource/apex-nitro/issues/334
* https://chronicler.tech/mint-oracle-18c-xe/
* https://kenny-chlim.medium.com/oracle-18c-xe-installation-debian-10-4-buster-9cbf7f957d9f
* https://luca-bindi.medium.com/oracle-xe-and-apex-in-a-docker-container-25f00a2b8306
* https://www.google.com/search?q=sqlplus+begin+end
* https://www.google.com/search?q=install+%22sql+developer+web
* https://oracle-base.com/articles/misc/oracle-rest-data-services-ords-sql-developer-web#create-test-db-user
* https://matthiashoys.wordpress.com/2020/01/03/how-to-enable-sql-developer-web-sdw-on-ords-19-4/
* https://www.oracletutorial.com/oracle-administration/oracle-list-users/
* https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.3/books.html#AELIG90217

... and a few more.

### APEX Programming
* Report Generation
  * Responsive Classic Report in ORACLE APEX [https://blogs.ontoorsolutions.com/post/responsive-classic-report-in-oracle-apex/]
  * How to control interative report columns [https://forums.oracle.com/ords/apexds/post/how-to-control-interactive-report-columns-width-9688]
* Authentication
  * How to log in with user credentials from database table [https://forums.oracle.com/ords/apexds/post/how-to-log-in-with-user-credentials-from-database-table-6626]
  * Custom Authentication in Oracle APEX [https://o7planning.org/10443/custom-authentication-in-oracle-apex]

### Integration With 3rd Party Tools
* Keycloak
  * https://levelupdata.eu/oracle-apex-keycloak/
  * https://stackoverflow.com/questions/45352880/keycloak-invalid-parameter-redirect-uri
  * https://stackoverflow.com/questions/53564499/keycloak-invalid-parameter-redirect-uri-behind-a-reverse-proxy
  * OpenID Connect with Nextcloud and Keycloak [https://janikvonrotz.ch/2020/10/20/openid-connect-with-nextcloud-and-keycloak/]

[^1]: See also https://docs.oracle.com/en/database/oracle/oracle-database/21/sqpug/slash.html
