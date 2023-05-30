---
layout: post
title: Configuring nginx with php-fpm in kubernetes and the "File not found." error
excerpt: It was not trivial to setup nginx with php-fpm to run in separate containers in kubernetes. Therefore I want to explain how I got it to work.

tags:
    - nginx
    - php
    - docker
    - kubernetes
---

For a course at university I wanted to setup two different containers:

- One should run a PHP application using php-fpm
- Another one should run nginx

This sounds rather easy, but unfortunately it took me quite some time to get this working. Mostly because I could not
find enough information on the internet about it. The biggest issue was how to setup FastCGI for nginx, so that it
passes the requests correctly to the container running php-fpm.

But let me start with the setup of the docker image itself. I've already had an application written using Symfony, and
the repository contained a `Dockerfile` in the root of the project directory:

```dockerfile
FROM php:8.2-fpm
WORKDIR /var/www
RUN apt-get update
RUN apt-get install -y libpq-dev libzip-dev zip zlib1g-dev
RUN docker-php-ext-install pdo_pgsql
RUN docker-php-ext-install zip
RUN pecl install redis-5.3.7 && docker-php-ext-enable redis
COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY . .
RUN composer install
```

This might not be perfect and I might still run into stuff using that, but since that's not the point of this article I
am just going to ignore that part. In order to build the docker image and push it to a registry I executed the following
commands (which I am only publishing in this blog post with some placeholders):

```bash
docker build -t <project-name> .
docker tag <project-name> <username>/<project-name>
docker push <username>/<project-name>
```

Afterwards I created a YAML file to describe a [Kubernetes
deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/). Since the software I was building
was about administering something, I called this file `administration.yaml`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: administration-deployment
spec:
    replicas: 1
    selector:
        matchLabels:
            app: administration
    template:
        metadata:
            labels:
                app: administration
        spec:
            containers:
                - name: administration
                  image: <username>/<project-name>:latest
                  envFrom:
                      - secretRef:
                            name: administration
```

This was good enough to have my docker image using php-fpm running. However, a web server was still missing. Therefore I
wanted to create a Kubernetes deployment running a nginx web server. I stored the following YAML configuration in
`nginx-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: nginx-deployment
spec:
    replicas: 1
    selector:
        matchLabels:
            app: nginx
    template:
        metadata:
            labels:
                app: nginx
        spec:
            containers:
                - name: nginx
                  image: nginx:1.24
                  volumeMounts:
                      - name: nginx-configmap
                        mountPath: /etc/nginx/conf.d
            volumes:
                - name: nginx-configmap
                  configMap:
                      name: nginx-configmap
```

This starts an nginx web server container, and maps a `ConfigMap` to the file system of the container at
`/etc/nginx/conf.d`, which happens to be the folder for nginx configuration files. Now the crucial part to get that
setup working: The `ConfigMap` mounted in the previous file:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: nginx-configmap
data:
    default.conf: |
        server {
            location / {
                try_files $uri /index.php$is_args$args;
            }

            location ~ ^/index\.php(/|$) {
                fastcgi_split_path_info ^(.+\.php)(/.*)$;

                fastcgi_pass administration-service:9000;
                fastcgi_param SCRIPT_FILENAME /var/www/public/index.php;
                fastcgi_param REQUEST_METHOD $request_method;
                fastcgi_param REQUEST_URI $request_uri;

                internal;
            }

            location ~ \.php$ {
                return 404;
            }
        }
```

**The crucial part is setting the correct `SCRIPT_FILENAME` as `fastcgi_param`.** And the problem is that I hardly found
any information about this on the world-wide web (which motivates me to write this blog post). I've took a look at the
[examples I found on the nginx website](https://www.nginx.com/resources/wiki/start/topics/examples/fastcgiexample/), but
none of them seemed to run nginx and php-fpm in a different container. Including the default configuration file
`fastcgi_params` that comes with many distributions did not work. **The problem was that they set the `SCRIPT_FILENAME`
to `$document_root$fastcgi_script_name` and `$documentRoot` is a path within the nginx machine, but in the php-fpm
container there was another folder structure.** This made the php-fpm container always respond with a page saying "File
not found.", and since it did not even say which file, this was rather hard to debug.

I am sure there are different ways to solve it, e.g. by mirroring the folder structure in both container, but I found it
easier (and also cleaner) to **simply adjust the `fastci_param SCRIPT_FILENAME` and set it to the absolute path of the
`public/index.php` file of the Symfony application on the php-fpm container**.

So all left to do is to execute the `kubectl apply -f <directory>` command and enjoy a working Symfony application.
