# Install & Run Oracle APEX in a Docker Environment
![Platform](https://img.shields.io/badge/docker-blue) ![Flavor](https://img.shields.io/badge/docker-compose-DeepSkyBlue)
## Why This Repository
So far, with the manuals both on Oracle's website as well as the ones found on blogs etc. I never really succeeded in putting up the APEX stack on docker.

However, starting to try with some more (docker) experience after procrastinating APEX in the recent 3 years, and with new energy, I found some key hints about getting it done.

## TL;DR
Here's the recipe to get this done:
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

```ORACLE_PWD=<password without quotes of any kind>```

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
Replace ```<ORACLE_PWD>``` with the password from the express container and the ```<hostname>``` with the express container's hostname (```express```), e.g.:
```
CONN_STRING=sys/1230321abcABC@express:1521/XEPDB1
```

Then run the following command to
* create and run the container ```rad-oracle-apex-ords-temp```
* install APEX in the DB of the ```express``` DB

```
docker run \
	-d \
	--name ords \
	--network rad-oracle-apex \
    -v $(pwd)/ORDS/config:/etc/ords/config \
	-v $(pwd)/ORDS/variables:/opt/oracle/variables \
	-p 8181:8181 \
    container-registry.oracle.com/database/ords-developer:latest
```
If you want to check, run the command as is, and open http://<docker-host>/ords:8181 to see whether the APEX environment has been installed successfully.

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
#### Run Docker Compose for APEX
```
services:
  express: # XE database
    image: container-registry.oracle.com/database/express:latest # 21.3.0-xe
    container_name: rad-oracle-apex-express
    # hostname: oracledev
    restart: unless-stopped
    # env_file: .env
    environment:
      - ORACLE_PWD=${ORACLE_PWD}
    networks:
      - apex
    ports:
      - 1521:1521
    #  - 5500:5500
    # depends_on:
      # - oracle-ords
    volumes:
      # - /volume1/docker/rad-ORACLE/express:/mnt/express:rw
      - ./express/oradata:/opt/oracle/oradata
      - ./express/scripts/setup:/opt/oracle/scripts/setup
      - ./express/scripts/startup:/opt/oracle/scripts/startup
    #healthcheck:
    #  test: ["CMD", "curl", "-f", "http://localhost:1521"]
    #  interval: 1m30s
    #  timeout: 10s
    #  retries: 10
    #  start_period: 7m30s
    #  start_interval: 5s # not allowed?

  ords:
    #image: container-registry.oracle.com/database/ords-developer:latest
    image: container-registry.oracle.com/database/ords:latest
    container_name: rad-oracle-apex-ords
    restart: unless-stopped
    depends_on:
      express:
        condition: service_healthy
    volumes:
    #  - ./ORDS/variables:/opt/oracle/variables
      - ./ORDS/config:/etc/ords/config
      - ./ORDS/apex/:/opt/oracle/apex
    networks:
      - apex
    ports:
      - 58080:8080

networks:
  apex:
    name: rad-oracle-apex
```
> [!IMPORTANT]
> run the CLI of the docker in order to update the config with the installed APEX files: docker exec -it ```rad-oracle-apex-ords sh```. Then run ```config set standalone.static.path /opt/oracle/apex/images```.
> Reason: The ords image does not contain the APEX files.
#### Log Into APEX
Login:

- Workspace: ```internal```
- User:      ```ADMIN```
- Password:  ```Welcome_1```

> [!WARNING]
> If you changed the password during log-in check from running the temporary ORDS-Developer container, use the updated password!
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

## APEX Programming
* Report Generation
  * Responsive Classic Report in ORACLE APEX [https://blogs.ontoorsolutions.com/post/responsive-classic-report-in-oracle-apex/]
  * How to control interative report columns [https://forums.oracle.com/ords/apexds/post/how-to-control-interactive-report-columns-width-9688]
* Authentication
  * How to log in with user credentials from database table [https://forums.oracle.com/ords/apexds/post/how-to-log-in-with-user-credentials-from-database-table-6626]
  * Custom Authentication in Oracle APEX [https://o7planning.org/10443/custom-authentication-in-oracle-apex]

## Integration With 3rd Party Tools
* Keycloak
  * https://levelupdata.eu/oracle-apex-keycloak/
  * https://stackoverflow.com/questions/45352880/keycloak-invalid-parameter-redirect-uri
  * https://stackoverflow.com/questions/53564499/keycloak-invalid-parameter-redirect-uri-behind-a-reverse-proxy
  * OpenID Connect with Nextcloud and Keycloak [https://janikvonrotz.ch/2020/10/20/openid-connect-with-nextcloud-and-keycloak/]
