FROM tiredofit/ruby:2.4-alpine-latest
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

### Set Defaults and Arguments
ENV GITLAB_VERSION="11.8.0-ee" \
    GITLAB_SHELL_VERSION="8.4.4" \
    GITLAB_WORKHORSE_VERSION="8.3.1" \
    GITLAB_PAGES_VERSION="1.5.0" \
    GITALY_SERVER_VERSION="1.20.0" \
    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    RAILS_ENV="production" \
    NODE_ENV="production"

ENV GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_WORKHORSE_INSTALL_DIR="${GITLAB_HOME}/gitlab-workhorse" \
    GITLAB_PAGES_INSTALL_DIR="${GITLAB_HOME}/gitlab-pages" \
    GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_DATA_DIR="${GITLAB_HOME}/data" \
    GITLAB_BUILD_DIR="/usr/src" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime" \
    GITLAB_LOG_DIR="/var/log" \
    MODE="START" 

### Add User
RUN set -x && \
    addgroup -g 1000 -S ${GITLAB_USER} && \
    adduser -u 1000 -D -S -s /bin/bash -G ${GITLAB_USER} ${GITLAB_USER} && \
    sed -i '/^git/s/!/*/' /etc/shadow && \
    echo "PS1='\w\$ '" >> ${GITHOME_HOME}/.bashrc && \
    echo "PATH=/usr/local/sbin:/usr/local/bin:\$PATH" >> ${GITLAB_HOME}/.profile && \
    \
### Install Dependencies
    apk add --update --no-cache -t .gitlab-rundeps \
        git \
        grep \
        icu-libs \
        krb5-libs \
        libcom_err \
        libc6-compat \
        libre2 \
        libressl \
        make \
        mariadb-client \
        nodejs-current \
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
        libre2-dev \
        libressl-dev \
        libgcrypt-dev \
        libxml2-dev \
        libxslt-dev \
        linux-headers \
        mariadb-dev \
        ncurses-dev \
        nodejs \
        npm \
        patch \
        postgresql-dev \
        readline-dev \
        sqlite-dev \
        yaml-dev \
        zlib-dev \
        && \
    \
    rm -rf /etc/nginx/conf.d/default.conf && \
    npm install -g yarn@v1.13 && \
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
    GITLAB_CLONE_URL=https://gitlab.com/gitlab-org/gitlab-ee.git && \
    mkdir -p ${GITLAB_INSTALL_DIR} && \
    git clone -q -b v${GITLAB_VERSION} --depth 1 ${GITLAB_CLONE_URL} ${GITLAB_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} ${GITLAB_INSTALL_DIR} && \
    su-exec git sed -i "/headers\['Strict-Transport-Security'\]/d" ${GITLAB_INSTALL_DIR}/app/controllers/application_controller.rb && \
    cd ${GITLAB_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} /usr/local/lib/ruby/gems/2.4.0/ && \
    chown -R ${GITLAB_USER}:${GITLAB_USER} /usr/local/bundle/ && \
    \
    ### Install gems (build from source).
    export BUNDLE_FORCE_RUBY_PLATFORM=1 && \
    export CPU_COUNT=`awk '/^processor/{n+=1}END{print n}' /proc/cpuinfo` && \
    su-exec git bundle install --jobs $CPU_COUNT --deployment --verbose --without development test aws && \
    \
    ### Make sure everything in ${GITLAB_HOME} is owned by ${GITLAB_USER} user
    chown -R ${GITLAB_USER}: ${GITLAB_HOME} && \
    \
    ### gitlab.yml and database.yml are required for `assets:precompile`
    su-exec git cp ${GITLAB_INSTALL_DIR}/config/resque.yml.example ${GITLAB_INSTALL_DIR}/config/resque.yml && \
    su-exec git cp ${GITLAB_INSTALL_DIR}/config/gitlab.yml.example ${GITLAB_INSTALL_DIR}/config/gitlab.yml && \
    su-exec git cp ${GITLAB_INSTALL_DIR}/config/database.yml.mysql ${GITLAB_INSTALL_DIR}/config/database.yml && \
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
    su-exec git ./bin/compile && \
    su-exec git ./bin/install && \
    \
    su-exec git rm -rf ${GITLAB_HOME}/repositories && \
    \
### Download And Install Gitlab Workhorse
    GITLAB_WORKHORSE_URL=https://gitlab.com/gitlab-org/gitlab-workhorse.git && \
    GITLAB_WORKHORSE_VERSION=${GITLAB_WORKHOUSE_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_WORKHORSE_VERSION)} && \
    echo "Cloning gitlab-workhorse v.${GITLAB_WORKHORSE_VERSION}..." && \
    su-exec git git clone -q -b v${GITLAB_WORKHORSE_VERSION} --depth 1 ${GITLAB_WORKHORSE_URL} ${GITLAB_WORKHORSE_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}: ${GITLAB_WORKHORSE_INSTALL_DIR} && \
    cd ${GITLAB_WORKHORSE_INSTALL_DIR} && \
    make install && \
    \
### Download and Install Gitlab Pages
    GITLAB_PAGES_URL=https://gitlab.com/gitlab-org/gitlab-pages.git && \
    GITLAB_PAGES_VERSION=${GITLAB_PAGES_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_PAGES_VERSION)} && \
    echo "Downloading gitlab-pages v.${GITLAB_PAGES_VERSION}..." && \
    su-exec git git clone -q -b v${GITLAB_PAGES_VERSION} --depth 1 ${GITLAB_PAGES_URL} ${GITLAB_PAGES_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}: ${GITLAB_PAGES_INSTALL_DIR} && \
    cd ${GITLAB_PAGES_INSTALL_DIR} && \
    make && \
    cp -f gitlab-pages /usr/local/bin/ && \
    \
### Download and Install Gitaly
    GITLAB_GITALY_URL=https://gitlab.com/gitlab-org/gitaly.git && \
    echo "Downloading gitaly v.${GITALY_SERVER_VERSION}..." && \
    su-exec git git clone -q -b v${GITALY_SERVER_VERSION} --depth 1 ${GITLAB_GITALY_URL} ${GITLAB_GITALY_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}: ${GITLAB_GITALY_INSTALL_DIR} && \
    su-exec git cp ${GITLAB_GITALY_INSTALL_DIR}/config.toml.example ${GITLAB_GITALY_INSTALL_DIR}/config.toml && \
    cd ${GITLAB_GITALY_INSTALL_DIR} && \
    export BUNDLE_FORCE_RUBY_PLATFORM=1 && \
    make install && \
    make clean && \
    ## Symbolic Link hack to fix problem with Gitlab Upstream
    ln -s /usr/local/bin/gitaly-ssh /home/git/gitaly/gitaly-ssh && \
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
        /etc/ssh/sshd_config && \
    \
    echo "UseDNS no" >> /etc/ssh/sshd_config && \
    \
### Configure git
    sudo -u ${GITLAB_USER} git config --global core.autocrlf input && \
    sudo -u ${GITLAB_USER} git config --global gc.auto 0 && \
    sudo -u ${GITLAB_USER} git config --global repack.writeBitmaps true && \
    sudo -u ${GITLAB_USER} git config --global receive.advertisePushOptions true && \
    \
### Configure sudoers
    echo ${GITLAB_USER}" ALL=(root) NOPASSWD: /usr/sbin/sshd >/etc/sudoers.d/git" && \
    rm -rf "${GITLAB_HOME}/.ssh" && \
    ln -sf "${GITLAB_DATA_DIR}/.ssh" "${GITLAB_HOME}/.ssh" && \
    \
### Cleanup
    npm uninstall -g yarn && \
    apk del --purge .gitlab-build-deps && \
    rm -rf ${GITLAB_INSTALL_DIR}/node_modules && \
    rm -rf ${GITLAB_HOME}/.bundle && \
    rm -rf ${GITLAB_HOME}/.cache && \
    rm -rf ${GITLAB_HOME}/.yarn && \
    rm -rf ${GITLAB_INSTALL_DIR}/*.md && \
    rm -rf ${GITLAB_INSTALL_DIR}/docker* && \
    rm -rf ${GITLAB_INSTALL_DIR}/qa && \
    rm -rf ${GITLAB_GITALY_INSTALL_DIR}/*.md && \
    rm -rf ${GITLAB_GITALY_INSTALL_DIR}/Dockerfile && \
    rm -rf ${GITLAB_GITALY_INSTALL_DIR}/*.example && \
    rm -rf ${GITLAB_GITALY_INSTALL_DIR}/Makefile && \
    rm -rf ${GITLAB_SHELL_INSTALL_DIR}/*.md && \
    rm -rf ${GITLAB_SHELL_INSTALL_DIR}/*.example && \
    rm -rf ${GITLAB_WORKHORSE_INSTALL_DIR}/_build && \
    rm -rf ${GITLAB_WORKHORSE_INSTALL_DIR}/*.md && \
    rm -rf ${GITLAB_WORKHORSE_INSTALL_DIR}/testdata && \
    rm -rf ${GITLAB_PAGES_INSTALL_DIR}/.git && \
    rm -rf /usr/local/bundle/cache && \
    rm -rf /usr/share/vim/vim80/doc/* && \
    rm -rf /usr/src/* && \
    rm -rf /var/cache/apk/*

ENV EXECJS_RUNTIME "Disabled"

### Entrypoint Configuration
WORKDIR ${GITLAB_INSTALL_DIR}

### Network Configuration
EXPOSE 22/tcp 80/tcp 443/tcp

### Add Assets
ADD install /
