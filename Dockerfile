FROM registry.selfdesign.org/docker/ruby:2.3-alpine-latest

### Set Defaults and Arguments
ENV GITLAB_VER="10.6.0-ee" \
    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_LOG_DIR="/var/log/gitlab" \
    RAILS_ENV="production" \
    NODE_ENV="production"

ENV GITLAB_DATA_DIR="${GITLAB_HOME}/data"

ENV GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
    
    GITLAB_BACKUP_DIR="${GITLAB_DATA_DIR}/backups" \
    GITLAB_REPOS_DIR="${GITLAB_DATA_DIR}/repositories" \
    GITLAB_BUILDS_DIR="${GITLAB_DATA_DIR}/builds" \
    GITLAB_UPLOADS_DIR="${GITLAB_DATA_DIR}/uploads" \

    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GITLAB_LOG_DIR="/var/log/gitlab" \

    # Temporary
    GITLAB_TEMP_DIR="${GITLAB_DATA_DIR}/tmp" \
    GITLAB_DOWNLOADS_DIR="${GITLAB_DATA_DIR}/tmp/downloads" \

    # Shared
    GITLAB_SHARED_DIR="${GITLAB_DATA_DIR}/shared" \
    GITLAB_ARTIFACTS_DIR="${GITLAB_DATA_DIR}/shared/artifacts" \
    GITLAB_LFS_OBJECTS_DIR="${GITLAB_DATA_DIR}/shared/lfs-objects" \
    GITLAB_PAGES_DIR="${GITLAB_DATA_DIR}/shared/pages" \
    GITLAB_REGISTRY_DIR="${GITLAB_DATA_DIR}/shared/registry" \
    GITLAB_REGISTRY_CERTS_DIR="${GITLAB_DATA_DIR}/certs" \

    MODE="START" \

    # SSHD
    SSHD_HOST_KEYS_DIR="${GITLAB_DATA_DIR}/ssh" \
    SSHD_LOG_LEVEL="VERBOSE" \
    SSHD_PASSWORD_AUTHENTICATION="no" \
    SSHD_PERMIT_USER_ENV="yes" \
    SSHD_USE_DNS="no"

RUN set -xe && \

### Add User
    addgroup -g 1000 -S ${GITLAB_USER} && \
	adduser -u 1000 -D -S -s /bin/bash -G ${GITLAB_USER} ${GITLAB_USER} && \
	sed -i '/^git/s/!/*/' /etc/shadow && \
	echo "PS1='\w\$ '" >> ${GITHOME_HOME}/.bashrc && \
    echo "PATH=/usr/local/sbin:/usr/local/bin:\$PATH" >> ${GITLAB_HOME}/.profile && \

### Install Dependencies
    apk add --update --no-cache -t .gitlab-rundeps \
        git \
        grep \
        icu-libs \
        libc6-compat \
        libre2 \
        libressl \
        make \
        mariadb-client \
        nginx \
        openssh \
        postgresql-client \
        python2 \
        rsync \
        shadow \
        su-exec \
        sudo \
        tzdata \
        zip \
        && \

    apk add --update --no-cache -t .gitlab-build-deps \
        autoconf \
        build-base \
        cmake \
        coreutils \
        g++ \
        gdbm-dev \
        go \
        icu-dev \
        libffi-dev \
        libre2-dev \
        libressl-dev \
        libgcrypt-dev \
        libxml2-dev \
        libxslt-dev \
        linux-headers \
        mariadb-dev \
        ncurses-dev \
        nodejs \
        patch \
        postgresql-dev \
        readline-dev \
        sqlite-dev \
        yaml-dev \
        yarn \
        zlib-dev \
        && \
    
    rm -rf /etc/nginx/conf.d/default.conf && \

    ### Temporary install package to get specific bins
    apk add --update redis postgresql && \
    cp /usr/bin/redis-cli /tmp && \
    cp /usr/bin/pg_* /tmp && \
    apk del --purge redis postgresql && \
    mv /tmp/redis-cli /usr/bin/ && \
    mv /tmp/pg_* /usr/bin/ && \
    
    ### Download gitlab.
    mkdir -p ${GITLAB_INSTALL_DIR} && \
    gitlab_url="https://gitlab.com/gitlab-org/gitlab-ee/repository/archive.tar.gz?ref=v${GITLAB_VER}" && \
    wget -qO- ${gitlab_url} | tar xz --strip-components=1 -C ${GITLAB_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} ${GITLAB_INSTALL_DIR} && \
     
    cd ${GITLAB_INSTALL_DIR} && \
    su-exec git cp config/database.yml.postgresql config/database.yml && \
    su-exec git cp config/gitlab.yml.example config/gitlab.yml && \
     
    chown -R ${GITLAB_USER}:${GITLAB_USER} /usr/local/lib/ruby/gems/2.3.0/ && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} /usr/local/bundle/ && \
     
    ### Install gems (build from source).
    export BUNDLE_FORCE_RUBY_PLATFORM=1 && \
    su-exec git bundle install -j$(nproc) --deployment --verbose --without development aws kerberos && \
     
    ### Compile assets
    su-exec git yarn install --production --pure-lockfile && \
    # webpack issue workaround https://gitlab.com/gitlab-org/gitlab-ce/issues/38275
    su-exec git yarn add ajv@^4.0.0 && \
    su-exec git bundle exec rake gitlab:assets:compile && \
     
    ### PO files
    su-exec git bundle exec rake gettext:pack && \
    su-exec git bundle exec rake gettext:po_to_json && \
     
    ### Install gitlab shell.
    su-exec git bundle exec rake gitlab:shell:install REDIS_URL=redis:6379 SKIP_STORAGE_VALIDATION=true && \
     
    ### Install gitlab pages.
    gitlab_pages_version=$(cat "${GITLAB_INSTALL_DIR}/GITLAB_PAGES_VERSION") && \
    gitlab_pages_url="https://gitlab.com/gitlab-org/gitlab-pages/repository/archive.tar.gz" && \
    wget -qO- "${gitlab_pages_url}?ref=v${gitlab_pages_version}" | tar xz -C /usr/src/ && \
    export GOPATH="/usr/src/go" && \
    mkdir -p "/usr/src/go/src/gitlab.com/gitlab-org" && \
    ln -s /usr/src/gitlab-pages* "$GOPATH/src/gitlab.com/gitlab-org/gitlab-pages" && \
    cd "$GOPATH/src/gitlab.com/gitlab-org/gitlab-pages" && \
    make && \
    mv gitlab-pages /usr/local/bin && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} /usr/src && \
    
    ### Install workhorse
    cd ${GITLAB_INSTALL_DIR} && \
    su-exec git bundle exec rake "gitlab:workhorse:install[/usr/src/workhorse]" && \
    cd /usr/src/workhorse/ && \
    mv gitlab-workhorse gitlab-zip-cat gitlab-zip-metadata /usr/local/bin/ && \
    cd ${GITLAB_INSTALL_DIR} && \
     
    ### Install gitaly (build gems from source)
    chown -R git $(go env GOROOT)/pkg && \
    export BUNDLE_FORCE_RUBY_PLATFORM=1 && \
    su-exec git bundle exec rake "gitlab:gitaly:install[${GITLAB_GITALY_INSTALL_DIR}]" && \
     
    su-exec git sed -i 's/db:reset/db:setup/' ${GITLAB_INSTALL_DIR}/lib/tasks/gitlab/setup.rake && \
     
    ### Configure git
    git config --global core.autocrlf input && \
    git config --global gc.auto 0 && \
    git config --global repack.writeBitmaps true && \
     
        ### Configure sudoers
    echo "git ALL=(root) NOPASSWD: /usr/sbin/sshd >/etc/sudoers.d/git" && \
    rm -rf "${GITLAB_HOME}/.ssh" && \
    ln -sf "${GITLAB_DATA_DIR}/.ssh" "/home/git/.ssh" && \
     
    ### Prepare directories and symlinks
    mkdir -p ${GITLAB_INSTALL_DIR}/tmp/pids/ ${GITLAB_INSTALL_DIR}/tmp/sockets/ && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} ${GITLAB_INSTALL_DIR}/tmp/ /etc/ssh/sshd_config && \
         
    mkdir -p \
        "${GITLAB_DATA_DIR}" \
        "${GITLAB_BACKUP_DIR}" \
        "${GITLAB_REPOS_DIR}" \
        "${GITLAB_BUILDS_DIR}" \
        "${GITLAB_UPLOADS_DIR}" \
        "${GITLAB_TEMP_DIR}" \
        "${GITLAB_DOWNLOADS_DIR}" \
        "${GITLAB_SHARED_DIR}" \
        "${GITLAB_ARTIFACTS_DIR}" \
        "${GITLAB_LFS_OBJECTS_DIR}" \
        "${GITLAB_PAGES_DIR}" \
        "${GITLAB_REGISTRY_DIR}" \
        "${GITLAB_REGISTRY_CERTS_DIR}" \
        "${GITLAB_LOG_DIR}" && \
     
    chown -R ${GITLAB_USER}:${GITLAB_USER} "${GITLAB_DATA_DIR}" "${GITLAB_LOG_DIR}" && \
     
    rm -rf "${GITLAB_INSTALL_DIR}/shared" "${GITLAB_INSTALL_DIR}/builds" && \
    su-exec git ln -sf "${GITLAB_SHARED_DIR}" "${GITLAB_INSTALL_DIR}/shared" && \
    su-exec git ln -sf "${GITLAB_BUILDS_DIR}" "${GITLAB_INSTALL_DIR}/builds" && \
    su-exec git ln -sf "${GITLAB_UPLOADS_DIR}" "${GITLAB_INSTALL_DIR}/public/uploads" && \
     
    ### Cleanup
    apk del --purge .gitlab-build-deps && \
    rm -rf ${GITLAB_INSTALL_DIR}/node_modules && \
    rm -rf /usr/src/* && \
    rm -rf /var/cache/apk/*

ENV EXECJS_RUNTIME "Disabled"

### Entrypoint Configuration
WORKDIR ${GITLAB_INSTALL_DIR}

### Network Configuration
EXPOSE 22/tcp 80/tcp 443/tcp

### Add Assets
ADD install /
