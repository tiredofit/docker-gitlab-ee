FROM tiredofit/ruby:2.6-alpine
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

### Set Defaults and Arguments
ENV GITLAB_VERSION="13.0.8-ee" \
    GITLAB_SHELL_VERSION="13.2.0" \
    GITLAB_WORKHORSE_VERSION="8.31.2" \
    GITLAB_PAGES_VERSION="1.18.0" \
    GITALY_SERVER_VERSION="13.0.8" \
    GITLAB_ELASTICSEARCH_INDEXER_VERSION="2.3.0" \
    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    RAILS_ENV="production" \
    NODE_ENV="production"

ENV GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_WORKHORSE_INSTALL_DIR="${GITLAB_HOME}/gitlab-workhorse" \
    GITLAB_ELASTICSEARCH_INDEXER_INSTALL_DIR="${GITLAB_HOME}/gitlab-elasticsearch-indexer" \
    GITLAB_PAGES_INSTALL_DIR="${GITLAB_HOME}/gitlab-pages" \
    GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_DATA_DIR="${GITLAB_HOME}/data" \
    GITLAB_BUILD_DIR="/usr/src" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime" \
    GITLAB_LOG_DIR="/var/log" \
    MODE="START" \
    SKIP_SANITY_CHECK=TRUE

### Set Nginx Version Number
ENV NGINX_VERSION=1.18.0 \
    NGINX_AUTH_LDAP_VERSION=master \
    NGINX_BROTLI_VERSION=e505dce68acc190cc5a1e780a3b0275e39f160ca \
    NGINX_USER=git \
    NGINX_GROUP=git \
    NGINX_WEBROOT=/www/html \
    NGINX_ENABLE_APPLICATION_CONFIGURATION=FALSE \
    NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    NGINX_LOG_ACCESS_FILE=${NGINX_LOG_ACCESS_FILE:-"nginx-access.log"} \
    NGINX_LOG_ACCESS_LOCATION=${NGINX_LOG_ACCESS_LOCATION:-"/home/git/gitlab/log/nginx"} \
    NGINX_LOG_ERROR_FILE=${NGINX_LOG_ERROR_FILE:-"nginx-error.log"} \
    NGINX_LOG_ERROR_LOCATION=${NGINX_LOG_ERROR_LOCATION:-"/home/git/gitlab/log/nginx"} \
    NGINX_LOG_LEVEL_ERROR=${NGINX_LOG_LEVEL_ERROR:-"warn"}

### Install Nginx
RUN set -x && \
    CONFIG="\
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/var/run/nginx.pid \
      --lock-path=/var/run/nginx.lock \
      --http-client-body-temp-path=/var/cache/nginx/client_temp \
      --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
      --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
      --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
      --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
      --user=nginx \
      --group=www-data \
      --with-http_addition_module \
      --with-http_auth_request_module \
      --with-http_dav_module \
      --with-http_flv_module \
      --with-http_geoip_module=dynamic \
      --with-http_gunzip_module \
      --with-http_gzip_static_module \
      --with-http_image_filter_module=dynamic \
      --with-http_mp4_module \
      --with-http_perl_module=dynamic \
      --with-http_random_index_module \
      --with-http_realip_module \
      --with-http_secure_link_module \
      --with-http_ssl_module \
      --with-http_stub_status_module \
      --with-http_sub_module \
      --with-http_xslt_module=dynamic \
      --with-threads \
      --with-stream \
      --with-stream_ssl_module \
      --with-stream_ssl_preread_module \
      --with-stream_realip_module \
      --with-stream_geoip_module=dynamic \
      --with-http_slice_module \
      --with-mail \
      --with-mail_ssl_module \
      --with-compat \
      --with-file-aio \
      --with-http_v2_module \
#     --with-http_v3_module \
#      --with-quiche=/usr/src/quiche \
      --add-module=/usr/src/headers-more-nginx-module \
      --add-module=/usr/src/nginx-brotli \
      --add-module=/usr/src/nginx-auth-ldap \
    " && \
    addgroup -S www-data && \
    adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G www-data nginx && \
    apk update && \
    apk upgrade && \
    apk add -t .nginx-build-deps \
                gcc \
                gd-dev \
                geoip-dev \
                gnupg \
                libc-dev \
                libressl-dev \
                libxslt-dev \
                linux-headers \
                make \
                pcre-dev \
                perl-dev \
                tar \
                zlib-dev \
                && \
    \
    apk add -t .brotli-build-deps \
                autoconf \
                automake \
                cmake \
                g++ \
                git \
                libtool \
                && \
    \
#    apk add -t .quiche-build-deps \
#                cargo \
#                go \
#                rust \
#                && \
#    \
    apk add -t .auth-ldap-build-deps \
                openldap-dev \
                && \
    \
    mkdir -p /www /var/log/nginx && \
    chown -R nginx:www-data /var/log/nginx && \
#    git clone --recursive https://github.com/cloudflare/quiche /usr/src/quiche && \
    git clone --recursive https://github.com/openresty/headers-more-nginx-module.git /usr/src/headers-more-nginx-module && \
    git clone --recursive https://github.com/google/ngx_brotli.git /usr/src/nginx-brotli && \
    cd /usr/src/nginx-brotli && \
    git checkout -b $NGINX_BROTLI_VERSION $NGINX_BROTLI_VERSION && \
    cd /usr/src && \
    git clone https://github.com/kvspb/nginx-auth-ldap /usr/src/nginx-auth-ldap && \
    mkdir -p /usr/src/nginx && \
    curl -sSL http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr/src/nginx && \
    cd /usr/src/nginx && \
    ./configure $CONFIG --with-debug && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    mv objs/nginx objs/nginx-debug && \
    mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so && \
    mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so && \
    mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so && \
    mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so && \
    mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so && \
    ./configure $CONFIG && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    rm -rf /etc/nginx/html/ && \
    mkdir -p /etc/nginx/conf.d/ && \
    mkdir -p /usr/share/nginx/html/ && \
    install -m644 html/index.html /usr/share/nginx/html/ && \
    install -m644 html/50x.html /usr/share/nginx/html/ && \
    install -m755 objs/nginx-debug /usr/sbin/nginx-debug && \
    install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so && \
    install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so && \
    install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so && \
    install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so && \
    install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so && \
    ln -s ../../usr/lib/nginx/modules /etc/nginx/modules && \
    strip /usr/sbin/nginx* && \
    strip /usr/lib/nginx/modules/*.so && \
    \
    apk add -t .gettext \
        gettext && \
    mv /usr/bin/envsubst /tmp/ && \
    \
    runDeps="$( \
      scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
        | sort -u \
        | xargs -r apk info --installed \
        | sort -u \
    )" && \
    \
    apk add \
        $runDeps \
        apache2-utils \
        && \
    apk del .nginx-build-deps && \
    apk del .brotli-build-deps && \
    apk del .auth-ldap-build-deps && \
#    apk del .quiche-build-deps && \
    apk del .gettext && \
    mv /tmp/envsubst /usr/local/bin/ && \
    \
    rm -rf /etc/nginx/*.default && \
    \
### Add User
    cd / && \
    addgroup -g 1000 -S ${GITLAB_USER} && \
    adduser -u 1000 -D -S -s /bin/bash -G ${GITLAB_USER} ${GITLAB_USER} && \
    sed -i '/^git/s/!/*/' /etc/shadow && \
    echo "PS1='\w\$ '" >> ${GITHOME_HOME}/.bashrc && \
    echo "PATH=/usr/local/sbin:/usr/local/bin:\$PATH" >> ${GITLAB_HOME}/.profile && \
    \
### Install Dependencies
    apk add --update --no-cache -t .gitlab-rundeps \
        findutils \
        gettext \
        git \
        graphicsmagick \
        grep \
        icu-libs \
        krb5-libs \
        libcom_err \
        libc6-compat \
        libressl \
        make \
        nodejs \
        openssh \
        perl-image-exiftool \
        postgresql-client \
        python2 \
        re2 \
        rsync \
        shadow \
        su-exec \
        sudo \
        tzdata \
        zip \
        && \
        \
    apk add --update --no-cache -t .gitlab-build-deps \
        autoconf \
        build-base \
        cmake \
        coreutils \
        g++ \
        gdbm-dev \
        go \
        icu-dev \
        krb5-dev \
        libassuan-dev \
        libffi-dev \
        libressl-dev \
        libgcrypt-dev \
        libxml2-dev \
        libxslt-dev \
        linux-headers \
        ncurses-dev \
        nodejs \
        patch \
        postgresql-dev \
        re2-dev \
        readline-dev \
        sqlite-dev \
        yaml-dev \
        yarn \
        zlib-dev \
        && \
    \
    rm -rf /etc/nginx/conf.d/default.conf && \
    \
### Setup Ruby
    gem install bundler --no-document --version '< 2' && \
    \
### Temporary install package to get specific bins
    apk add --update redis postgresql && \
    cp /usr/bin/redis-cli /tmp && \
    cp /usr/bin/pg_* /tmp && \
    apk del --purge redis postgresql && \
    mv /tmp/redis-cli /usr/bin/ && \
    mv /tmp/pg_* /usr/bin/ && \
    \
### Download and install gitlab.
    GITLAB_CLONE_URL=https://gitlab.com/gitlab-org/gitlab.git && \
    mkdir -p ${GITLAB_INSTALL_DIR} && \
    git clone -q -b v${GITLAB_VERSION} --depth 1 ${GITLAB_CLONE_URL} ${GITLAB_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} ${GITLAB_INSTALL_DIR} && \
    su-exec git sed -i "/headers\['Strict-Transport-Security'\]/d" ${GITLAB_INSTALL_DIR}/app/controllers/application_controller.rb && \
    \
    cd ${GITLAB_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} /usr/local/lib/ruby/gems/2.6.0/ && \
    cd ${GITLAB_INSTALL_DIR} && \
    \
   ### Install gems (build from source).
    bundle update --bundler && \
    \
    export BUNDLE_FORCE_RUBY_PLATFORM=1 && \
    export CPU_COUNT=`awk '/^processor/{n+=1}END{print n}' /proc/cpuinfo` && \
    \
    su-exec git bundle install --jobs $CPU_COUNT --deployment --verbose --without development test mysql aws kerberos && \
    \
    ### Make sure everything in ${GITLAB_HOME} is owned by ${GITLAB_USER} user
    chown -R ${GITLAB_USER}: /home/${GITLAB_USER} && \
    \
    ### gitlab.yml and database.yml are required for `assets:precompile`
    su-exec git cp ${GITLAB_INSTALL_DIR}/config/resque.yml.example ${GITLAB_INSTALL_DIR}/config/resque.yml && \
    su-exec git cp ${GITLAB_INSTALL_DIR}/config/gitlab.yml.example ${GITLAB_INSTALL_DIR}/config/gitlab.yml && \
    su-exec git cp ${GITLAB_INSTALL_DIR}/config/database.yml.postgresql ${GITLAB_INSTALL_DIR}/config/database.yml && \
    \
    ### Compile assets
    su-exec git yarn install --production --pure-lockfile && \
    su-exec git yarn add ajv@^4.0.0 && \
    \
    cd ${GITLAB_INSTALL_DIR} && \
    #### Add NO_SOURCEMAPS to 11.6.1 for OOM issues
    su-exec git bundle exec rake gitlab:assets:compile NO_SOURCEMAPS=false USE_DB=false SKIP_STORAGE_VALIDATION=true && \
    \
    ### PO files
    su-exec git bundle exec rake gettext:compile RAILS_ENV=production && \
    \
### Download and Install Gitlab-Shell
    cd ${GITLAB_HOME} && \
    GITLAB_SHELL_URL=https://gitlab.com/gitlab-org/gitlab-shell/repository/archive.tar.gz && \
    GITLAB_SHELL_VERSION=${GITLAB_SHELL_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_SHELL_VERSION)} && \
    echo "Downloading gitlab-shell v.${GITLAB_SHELL_VERSION}..." && \
    mkdir -p ${GITLAB_SHELL_INSTALL_DIR} && \
    curl -sSL ${GITLAB_SHELL_URL}?ref=v${GITLAB_SHELL_VERSION} | tar xfvz - --strip 1 -C ${GITLAB_SHELL_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}: ${GITLAB_SHELL_INSTALL_DIR} && \
    \
    cd ${GITLAB_SHELL_INSTALL_DIR} && \
    su-exec git cp -a ${GITLAB_SHELL_INSTALL_DIR}/config.yml.example ${GITLAB_SHELL_INSTALL_DIR}/config.yml && \
    su-exec git ./bin/install && \
    su-exec git make setup && \
    \
    su-exec git rm -rf ${GITLAB_HOME}/repositories && \
    \
    ### Download And Install Gitlab Workhorse
    GITLAB_WORKHORSE_URL=https://gitlab.com/gitlab-org/gitlab-workhorse.git && \
    GITLAB_WORKHORSE_VERSION=${GITLAB_WORKHOUSE_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_WORKHORSE_VERSION)} && \
    echo "Cloning gitlab-workhorse v.${GITLAB_WORKHORSE_VERSION}..." && \
    git clone -q -b v${GITLAB_WORKHORSE_VERSION} --depth 1 ${GITLAB_WORKHORSE_URL} /usr/src/gitlab-workhorse && \
    make -C /usr/src/gitlab-workhorse install && \
    ### Download and Install Gitlab Elasticsearch-indexer
    GITLAB_ELASTICSEARCH_INDEXER_URL=https://gitlab.com/gitlab-org/gitlab-elasticsearch-indexer && \
    GITLAB_ELASTICSEARCH_INDEXER_VERSION=${GITLAB_ELASTICSEARCH_INDEXER_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_ELASTICSEARCH_INDEXER_VERSION)} && \
    echo "Cloning gitlab-elasticsearch-indexer v.${GITLAB_ELASTICSEARCH_INDEXER_VERSION}..." && \
    git clone -q -b v${GITLAB_ELASTICSEARCH_INDEXER_VERSION} --depth 1 ${GITLAB_ELASTICSEARCH_INDEXER_URL} /usr/src/gitlab-elasticsearch-indexer && \
    make -C /usr/src/gitlab-elasticsearch-indexer && \
    make -C /usr/src/gitlab-elasticsearch-indexer install  && \
    cp -af /usr/src/gitlab-elasticsearch-indexer/bin/gitlab-elasticsearch-indexer /usr/local/bin && \
    \
    ### Download and Install Gitlab Pages
    GITLAB_PAGES_URL=https://gitlab.com/gitlab-org/gitlab-pages.git && \
    GITLAB_PAGES_VERSION=${GITLAB_PAGES_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_PAGES_VERSION)} && \
    echo "Downloading gitlab-pages v.${GITLAB_PAGES_VERSION}..." && \
    git clone -q -b v${GITLAB_PAGES_VERSION} --depth 1 ${GITLAB_PAGES_URL} /usr/src/gitlab-pages && \
    make -C /usr/src/gitlab-pages && \
    cp -af /usr/src/gitlab-pages/gitlab-pages /usr/local/bin && \
    \
### Download and Install Gitaly
    GITLAB_GITALY_URL=https://gitlab.com/gitlab-org/gitaly.git && \
    echo "Downloading gitaly v.${GITALY_SERVER_VERSION}..." && \
    mkdir -p ${GITLAB_GITALY_INSTALL_DIR} && \
    git clone -q -b v${GITALY_SERVER_VERSION} --depth 1 ${GITLAB_GITALY_URL} /usr/src/gitaly && \
    cd /usr/src/gitaly && \
    make -C /usr/src/gitaly install && \
    cp -a /usr/src/gitaly/ruby ${GITLAB_GITALY_INSTALL_DIR} && \
    cp -a /usr/src/gitaly/config.toml.example ${GITLAB_GITALY_INSTALL_DIR}/config.toml && \
    rm -rf ${GITLAB_GITALY_INSTALL_DIR}/ruby/vendor/bundle/ruby/*/cache && \
    chown -R ${GITLAB_USER}: ${GITLAB_GITALY_INSTALL_DIR} && \
    \
    ## Symbolic Links to fix problem with Gitlab Upstream
    ln -s /usr/local/bin/gitaly /home/git/gitaly/gitaly && \
    ln -s /usr/local/bin/gitaly-debug /home/git/gitaly/gitaly-debug && \
    ln -s /usr/local/bin/gitaly-hooks /home/git/gitaly/gitaly-hooks && \
    ln -s /usr/local/bin/gitaly-ssh /home/git/gitaly/gitaly-ssh && \
    ln -s /usr/local/bin/gitaly-wrapper /home/git/gitaly/gitaly-wrapper && \
    \
### Filesystem Cleanup and Setup
    ### revert `rake gitlab:setup` changes from gitlabhq/gitlabhq@a54af831bae023770bf9b2633cc45ec0d5f5a66a
    su-exec git sed -i 's/db:reset/db:setup/' ${GITLAB_INSTALL_DIR}/lib/tasks/gitlab/setup.rake && \
    \
    ### remove auto generated ${GITLAB_DATA_DIR}/config/secrets.yml
    rm -rf ${GITLAB_DATA_DIR}/config/secrets.yml && \
    \
    ### remove gitlab shell and workhorse secrets
    rm -f ${GITLAB_INSTALL_DIR}/.gitlab_shell_secret ${GITLAB_INSTALL_DIR}/.gitlab_workhorse_secret && \
    \
    su-exec git mkdir -p ${GITLAB_INSTALL_DIR}/tmp/pids/ ${GITLAB_INSTALL_DIR}/tmp/sockets/ && \
    chmod -R u+rwX ${GITLAB_INSTALL_DIR}/tmp && \
    \
    ### symlink ${GITLAB_HOME}/.ssh -> ${GITLAB_LOG_DIR}/gitlab
    rm -rf ${GITLAB_HOME}/.ssh && \
    su-exec git ln -sf ${GITLAB_DATA_DIR}/.ssh ${GITLAB_HOME}/.ssh && \
    \
    ### symlink ${GITLAB_INSTALL_DIR}/log -> ${GITLAB_LOG_DIR}/gitlab
    rm -rf ${GITLAB_INSTALL_DIR}/log && \
    ln -sf ${GITLAB_LOG_DIR}/gitlab ${GITLAB_INSTALL_DIR}/log && \
    \
    ### symlink ${GITLAB_INSTALL_DIR}/public/uploads -> ${GITLAB_DATA_DIR}/uploads
    rm -rf ${GITLAB_INSTALL_DIR}/public/uploads && \
    su-exec git ln -sf ${GITLAB_DATA_DIR}/uploads ${GITLAB_INSTALL_DIR}/public/uploads && \
    \
    ### symlink ${GITLAB_INSTALL_DIR}/.secret -> ${GITLAB_DATA_DIR}/.secret
    rm -rf ${GITLAB_INSTALL_DIR}/.secret && \
    su-exec git ln -sf ${GITLAB_DATA_DIR}/.secret ${GITLAB_INSTALL_DIR}/.secret && \
    \
    rm -rf ${GITLAB_INSTALL_DIR}/builds && \
    rm -rf ${GITLAB_INSTALL_DIR}/shared && \
    \
    ### install gitlab bootscript, to silence gitlab:check warnings
    cp ${GITLAB_INSTALL_DIR}/lib/support/init.d/gitlab /etc/init.d/gitlab && \
    chmod +x /etc/init.d/gitlab && \
    \
    ### disable default nginx configuration and enable gitlab's nginx configuration
    rm -rf /etc/nginx/conf.d/default.conf && \
    \
### Configure SSH
    sed -i \
        -e "s|^[#]*UsePAM yes|UsePAM no|" \
        -e "s|^[#]*UsePrivilegeSeparation yes|UsePrivilegeSeparation no|" \
        -e "s|^[#]*PasswordAuthentication yes|PasswordAuthentication no|" \
        -e "s|^[#]*LogLevel INFO|LogLevel VERBOSE|" \
        -e "s|^[#]*AuthorizedKeysFile.*|AuthorizedKeysFile %h/.ssh/authorized_keys %h/.ssh/authorized_keys_proxy|" \
        /etc/ssh/sshd_config && \
    \
    echo "UseDNS no" >> /etc/ssh/sshd_config && \
    \
### Configure git
    sudo -u ${GITLAB_USER} git config --global core.autocrlf input && \
    sudo -u ${GITLAB_USER} git config --global gc.auto 0 && \
    sudo -u ${GITLAB_USER} git config --global repack.writeBitmaps true && \
    sudo -u ${GITLAB_USER} git config --global receive.advertisePushOptions true && \
    sudo -u ${GITLAB_USER} git config --global core.fsyncObjectFiles true && \
    \
### Configure sudoers
    echo ${GITLAB_USER}" ALL=(root) NOPASSWD: /usr/sbin/sshd >/etc/sudoers.d/git" && \
    rm -rf "${GITLAB_HOME}/.ssh" && \
    ln -sf "${GITLAB_DATA_DIR}/.ssh" "${GITLAB_HOME}/.ssh" && \
    \
### Cleanup
    apk del --purge .gitlab-build-deps && \
    rm -rf ${GITLAB_INSTALL_DIR}/node_modules && \
    rm -rf ${GITLAB_HOME}/.bundle && \
    rm -rf ${GITLAB_HOME}/.cache && \
    rm -rf ${GITLAB_HOME}/.yarn && \
    rm -rf ${GITLAB_INSTALL_DIR}/*.md && \
    rm -rf ${GITLAB_INSTALL_DIR}/docker* && \
    rm -rf ${GITLAB_INSTALL_DIR}/qa && \
    rm -rf ${GITLAB_SHELL_INSTALL_DIR}/*.md && \
    rm -rf ${GITLAB_SHELL_INSTALL_DIR}/*.example && \
    rm -rf /usr/local/bundle/cache && \
    rm -rf /usr/share/vim/vim80/doc/* && \
    rm -rf /usr/src/* && \
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*

ENV EXECJS_RUNTIME "Disabled"

### Entrypoint Configuration
WORKDIR ${GITLAB_INSTALL_DIR}

### Network Configuration
EXPOSE 22/tcp 80/tcp 443/tcp

### Add Assets
ADD install /
