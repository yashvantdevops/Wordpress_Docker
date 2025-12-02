## WordPress with MySQL
This example defines one of the basic setups for WordPress. More details on how this works can be found on the official [WordPress image page](https://hub.docker.com/_/wordpress).


Project structure:
```
.
├── compose.yaml
└── README.md
```

[_compose.yaml_](compose.yaml)
```
services:
  db:
    # We use a mariadb image which supports both amd64 & arm64 architecture
    image: mariadb:10.6.4-focal
    # If you really want to use MySQL, uncomment the following line
    #image: mysql:8.0.27
    ...
  wordpress:
    image: wordpress:latest
    ports:
      - 80:80
    restart: always
    ...
```

When deploying this setup, docker compose maps the WordPress container port 80 to
port 80 of the host as specified in the compose file.

> ℹ️ **_INFO_**  
> For compatibility purpose between `AMD64` and `ARM64` architecture, we use a MariaDB as database instead of MySQL.  
> You still can use the MySQL image by uncommenting the following line in the Compose file   
> `#image: mysql:8.0.27`

## Deploy with docker compose

```
$ docker compose up -d
Creating network "wordpress-mysql_default" with the default driver
Creating volume "wordpress-mysql_db_data" with default driver
...
Creating wordpress-mysql_db_1        ... done
Creating wordpress-mysql_wordpress_1 ... done
```



## Docker Compose: WordPress + MySQL + Redis (dev)

This workspace includes a Docker Compose setup that runs:

Files of interest:

Quick start (from this repo root):

```pwsh
docker compose --env-file .env up -d --build
```

Profiles / Environments (dev / staging / production)

This compose setup supports multiple environments via build args and Compose profiles.

- `BUILD_ENV` controls how the WordPress image is built. It is passed as a build-arg into the Dockerfile and can be `development`, `staging`, or `production`.
- `phpmyadmin` and `wpcli` are placed in the `dev` profile so they only start in development.

Examples:

Start development (default `.env` includes `BUILD_ENV=development`):

```pwsh
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env --profile dev up -d --build
```

Start only production profile services (no dev-only services):

```pwsh
# set BUILD_ENV=production in .env or env var, then
docker compose --env-file .env --profile "" up -d --build
```

Start staging (example):

```pwsh
# Ensure BUILD_ENV=staging in .env or export environment variable, then
docker compose -f docker-compose.yaml -f docker-compose.staging.yaml --env-file .env up -d --build
```

Start with explicit profile selection (start dev services):

```pwsh
docker compose -f docker-compose.yaml -f docker-compose.dev.yaml --env-file .env --profile dev up -d --build
```

Start production (build with production flags; this override removes the `wp_html` bind mount so the container uses the built-in image files):

```pwsh
# Ensure BUILD_ENV=production in .env or export environment variable, then
docker compose -f docker-compose.yaml -f docker-compose.prod.yaml --env-file .env up -d --build
```

Notes:
- When building for `production` the Dockerfile removes build tools and dev helpers (like xdebug and git/composer), producing a smaller runtime image.
- For `staging` the image keeps composer but you can toggle enabling xdebug by setting `BUILD_ENV=development` if required.
- If you want a dedicated `docker-compose.prod.yaml` override (for example to swap to a hosted database or different ports), I can add one.
Access locally:
- WordPress: http://localhost:8080
- phpMyAdmin: http://localhost:8081

Notes about Redis and WordPress:
- The custom WordPress image includes the `php-redis` extension so WordPress can communicate with the Redis server.
- To use Redis Object Cache in WordPress, install and activate a Redis cache plugin such as "Redis Object Cache" from the admin Plugins screen.
- After activating, follow the plugin instructions (often click "Enable Object Cache"). Some plugins accept `WORDPRESS_REDIS_HOST`/`WORDPRESS_REDIS_PORT` environment variables.
- Alternatively, you can use `wp-cli` to install/activate plugins if desired (not included by default).

Using WP-CLI (added service)

This repo includes a `wpcli` service so you can run WP-CLI commands against the site files and database.

Run examples from the repo root:

```pwsh
# Install and activate the Redis object-cache plugin (example)
docker compose run --rm wpcli plugin install redis-cache --activate

# Verify WordPress core is installed and show version
docker compose run --rm wpcli core version

# Run database migrations, update URLs, etc.
docker compose run --rm wpcli db export
```

Notes:
- The `wpcli` service mounts the same `wp_html` volume as the `wordpress` service. Commands executed with `docker compose run --rm wpcli` act on that filesystem and connect to the database over the Docker network.
- If you need to run WP-CLI as root or set specific PHP options, prefix your command with `--user` or override with `docker compose run --rm --entrypoint "php -d memory_limit=512M /usr/local/bin/wp" wpcli <args>`.


Changing credentials:
- Edit `.env` to set `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` before running the compose command.

## Expected result

Check containers are running and the port mapping:
```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                 NAMES
5fbb4181a069        wordpress:latest    "docker-entrypoint.s…"   35 seconds ago      Up 34 seconds       0.0.0.0:80->80/tcp    wordpress-mysql_wordpress_1
e0884a8d444d        mysql:8.0.19        "docker-entrypoint.s…"   35 seconds ago      Up 34 seconds       3306/tcp, 33060/tcp   wordpress-mysql_db_1
```

Navigate to `http://localhost:80` in your web browser to access WordPress.

![page](output.jpg)

Stop and remove the containers

```
$ docker compose down
```

To remove all WordPress data, delete the named volumes by passing the `-v` parameter:
```
$ docker compose down -v
```
