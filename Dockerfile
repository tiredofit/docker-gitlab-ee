ARG DISTRO="debian"
ARG DISTRO_VARIANT="bullseye"

FROM docker.io/tiredofit/nginx:${DISTRO}-${DISTRO_VARIANT}
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

ARG GITLAB_VERSION
ARG GO_VERSION
ARG RUBY_VERSION

### Set Defaults and Arguments
ENV GITLAB_VERSION=${GITLAB_VERSION:-"15.7.4-ee"} \
    GO_VERSION=${GO_VERSION:-"1.19.5"} \
    RUBY_VERSION=${RUBY_VERSION:-"3.0.5"} \
    GITLAB_HOME="/home/git" \
    IMAGE_NAME="tiredofit/gitlab-ee" \
    IMAGE_REPO_URL="https://github.com/tiredofit/docker-gitlab-ee/"

ENV GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_WORKHORSE_INSTALL_DIR="${GITLAB_HOME}/gitlab-workhorse" \
    GITLAB_ELASTICSEARCH_INDEXER_INSTALL_DIR="${GITLAB_HOME}/gitlab-elasticsearch-indexer" \
    GITLAB_PAGES_INSTALL_DIR="${GITLAB_HOME}/gitlab-pages" \
    GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_DATA_DIR="${GITLAB_HOME}/data" \
    GITLAB_BUILD_DIR="/usr/src/" \
    GITLAB_LOG_DIR="/var/log/gitlab" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime" \
    GITLAB_USER="git" \
    MODE="START" \
    NGINX_APPLICATION_CONFIGURATION=FALSE \
    NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    NGINX_LOG_ACCESS_FILE=gitlab-access.log \
    NGINX_LOG_ACCESS_LOCATION=/www/logs/nginx \
    NGINX_LOG_ERROR_FILE=gitlab-error.log \
    NGINX_LOG_ERROR_LOCATION=/www/logs/nginx \
    NGINX_SITE_ENABLED=null \
    NODE_ENV="production" \
    SKIP_SANITY_CHECK=FALSE \
    RAILS_ENV="production" \
    RUBY_ALLOCATOR=/usr/lib/libjemalloc.so.2 \
    prometheus_multiproc_dir=/dev/shm

RUN source /assets/functions/00-container && \
    set -x && \
    curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
    echo "deb https://deb.nodesource.com/node_16.x $(cat /etc/os-release |grep "VERSION=" | awk 'NR>1{print $1}' RS='(' FS=')') main" > /etc/apt/sources.list.d/nodejs.list && \
    curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    curl -ssL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(cat /etc/os-release |grep "VERSION=" | awk 'NR>1{print $1}' RS='(' FS=')')-pgdg main" > /etc/apt/sources.list.d/postgres.list && \
    package update && \
    package upgrade -y && \
    package install \
                gettext-base \
                graphicsmagick \
                libcurl4 \
                libffi7 \
                libgdbm6 \
                libicu67 \
                libimage-exiftool-perl \
                libjemalloc2 \
                libncurses5 \
                libpq5 \
                libpcre2-8-0 \
                libre2-dev \
                libreadline8 \
                libxml2 \
                libxslt1.1 \
                libyaml-0-2 \
                locales \
                openssh-server \
                nodejs \
                postgresql-client-15 \
                postgresql-contrib-15 \
                python3 \
                python3-docutils \
                redis-tools \
                tzdata \
                unzip \
                yarn \
                zlib1g \
    && \
    \
    update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX && \
    locale-gen en_US.UTF-8 && \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales && \
    \
    BUILD_DEPENDENCIES="build-essential \
                        cmake \
                        g++ \
                        gcc \
                        gettext \
                        git \
                        libc6-dev \
                        libcurl4-openssl-dev \
                        libexpat1-dev \
                        libffi-dev \
                        libgdbm-dev \
                        libicu-dev \
                        libjemalloc-dev \
                        libkrb5-dev \
                        libncurses5-dev \
                        libpcre2-dev \
                        libpq-dev \
                        libreadline-dev \
                        libssl-dev \
                        libxml2-dev \
                        libxslt-dev \
                        libyaml-dev \
                        make \
                        patch \
                        pkg-config \
                        zlib1g-dev" \
                        && \
    package install ${BUILD_DEPENDENCIES} && \
    rm -rf /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
    cd / && \
    \
    mkdir -p /usr/local/go && \
    echo "Downloading Go ${GO_VERSION}..." && \
    curl -sSL  https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz | tar xvfz - --strip 1 -C /usr/local/go && \
    ln -sf /usr/local/go/bin/go /usr/local/bin/ && \
    ln -sf /usr/local/go/bin/godoc /usr/local/bin/ && \
    ln -sf /usr/local/go/bin/gfmt /usr/local/bin/ && \
    \
    ### Add User
    addgroup --gid 1000 --system ${GITLAB_USER} && \
    adduser --uid 1000 --gid 1000 --home /home/git --gecos "Gitlab" --shell /bin/bash --disabled-password ${GITLAB_USER} && \
    sed -i '/^git/s/!/*/' /etc/shadow && \
    echo "PS1='\w\$ '" >> ${GITLAB_HOME}/.bashrc && \
    echo "PATH=/usr/local/sbin:/usr/local/bin:\$PATH" >> ${GITLAB_HOME}/.profile && \
    \
### Setup Ruby
    mkdir -p /usr/src/ruby && \
    curl -sSL https://cache.ruby-lang.org/pub/ruby/$(echo ${RUBY_VERSION} | cut -c1-3)/ruby-${RUBY_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr/src/ruby && \
    cd /usr/src/ruby && \
    ./configure \
                --disable-install-rdoc \
                --enable-shared \
                --with-jemalloc \
                && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    \
### Configure git
    sudo -u ${GITLAB_USER} git config --global core.autocrlf input && \
    sudo -u ${GITLAB_USER} git config --global gc.auto 0 && \
    sudo -u ${GITLAB_USER} git config --global repack.writeBitmaps true && \
    sudo -u ${GITLAB_USER} git config --global receive.advertisePushOptions true && \
    sudo -u ${GITLAB_USER} git config --global core.fsyncObjectFiles true && \
    sudo -u ${GITLAB_USER} git config --global advice.detachedHead false && \
    sudo -u ${GITLAB_USER} git config --global --add safe.directory "${GITLAB_INSTALL_DIR}" && \
    \
### Download and Install Gitlab
    GITLAB_CLONE_URL=https://gitlab.com/gitlab-org/gitlab && \
    clone_git_repo ${GITLAB_CLONE_URL} v${GITLAB_VERSION} ${GITLAB_INSTALL_DIR} && \
    \
    sed -i "/\ \ \ \ \ \ return \[\] unless Gitlab::Database.exists?/a \ \ \ \ \ \ return \[\] unless Feature::FlipperFeature.table_exists?" ${GITLAB_INSTALL_DIR}/lib/feature.rb && \
    sed -i "/\ \ \ \ \ \ return default_enabled unless Gitlab::Database.exists?/a \ \ \ \ \ \ return default_enabled unless Feature::FlipperFeature.table_exists?" ${GITLAB_INSTALL_DIR}/lib/feature.rb && \
    \
    chown -R ${GITLAB_USER}:${GITLAB_USER} ${GITLAB_INSTALL_DIR} && \
    sudo -HEu git sed -i "/headers\['Strict-Transport-Security'\]/d" ${GITLAB_INSTALL_DIR}/app/controllers/application_controller.rb && \
    sudo -HEu git sed -i 's/db:reset/db:setup/' ${GITLAB_INSTALL_DIR}/lib/tasks/gitlab/setup.rake && \
    \
    cd ${GITLAB_INSTALL_DIR} && \
    BUNDLER_VERSION="$(grep "BUNDLED WITH" ${GITLAB_INSTALL_DIR}/Gemfile.lock -A 1 | grep -v "BUNDLED WITH" | tr -d "[:space:]")" && \
    gem install bundler:"${BUNDLER_VERSION}" && \
    sudo -HEu git bundle config set --local deployment 'true' && \
    sudo -HEu git bundle config set --local without 'development test mysql aws kerberos' && \
    sudo -HEu git bundle install -j"$(nproc)" && \
    \
    chown -R ${GITLAB_USER}:${GITLAB_USER} /usr/local/lib/ruby/gems/$(echo ${RUBY_VERSION} | cut -c1-3).0/ && \
    chown -R ${GITLAB_USER}: ${GITLAB_HOME} && \
    #  gitlab.yml and database.yml are required for `assets:precompile`
    sudo -HEu git cp ${GITLAB_INSTALL_DIR}/config/resque.yml.example ${GITLAB_INSTALL_DIR}/config/resque.yml && \
    sudo -HEu git cp ${GITLAB_INSTALL_DIR}/config/gitlab.yml.example ${GITLAB_INSTALL_DIR}/config/gitlab.yml && \
    sudo -HEu git cp ${GITLAB_INSTALL_DIR}/config/database.yml.postgresql ${GITLAB_INSTALL_DIR}/config/database.yml && \
    \
    # Installs nodejs packages required to compile webpack
    sudo -HEu git yarn install --production --pure-lockfile && \
    sudo -HEu git yarn add ajv@^4.0.0 && \
    \
    echo "Compiling assets. Please be patient, this could take a while..." && \
    sudo -HEu git bundle exec rake gitlab:assets:compile USE_DB=false SKIP_STORAGE_VALIDATION=true NODE_OPTIONS="--max-old-space-size=4096" && \
    \
    # remove auto generated ${GITLAB_DATA_DIR}/config/secrets.yml
    rm -rf ${GITLAB_DATA_DIR}/config/secrets.yml && \
    \
    # remove gitlab shell and workhorse secrets
    rm -f ${GITLAB_INSTALL_DIR}/.gitlab_shell_secret ${GITLAB_INSTALL_DIR}/.gitlab_workhorse_secret && \
    \
    sudo -HEu git mkdir -p ${GITLAB_INSTALL_DIR}/tmp/pids/ ${GITLAB_INSTALL_DIR}/tmp/sockets/ && \
    chmod -R u+rwX ${GITLAB_INSTALL_DIR}/tmp && \
    \
    ### symlink ${GITLAB_INSTALL_DIR}/log -> ${GITLAB_LOG_DIR}
    rm -rf ${GITLAB_INSTALL_DIR}/log && \
    \
    ### symlink ${GITLAB_INSTALL_DIR}/public/uploads -> ${GITLAB_DATA_DIR}/uploads
    rm -rf ${GITLAB_INSTALL_DIR}/public/uploads && \
    sudo -HEu git ln -sf ${GITLAB_DATA_DIR}/uploads ${GITLAB_INSTALL_DIR}/public/uploads && \
    \
    ### symlink ${GITLAB_INSTALL_DIR}/.secret -> ${GITLAB_DATA_DIR}/.secret
    rm -rf ${GITLAB_INSTALL_DIR}/.secret && \
    sudo -HEu git ln -sf ${GITLAB_DATA_DIR}/.secret ${GITLAB_INSTALL_DIR}/.secret && \
    \
    rm -rf ${GITLAB_INSTALL_DIR}/builds && \
    rm -rf ${GITLAB_INSTALL_DIR}/shared && \
    \
    ### install gitlab bootscript, to silence gitlab:check warnings
    cp ${GITLAB_INSTALL_DIR}/lib/support/init.d/gitlab /etc/init.d/gitlab && \
    chmod +x /etc/init.d/gitlab && \
    \
### Install Gitlab Workhorse
    echo "Building Gitlab Workhorse" && \
    make -C ${GITLAB_INSTALL_DIR}/workhorse install && \
    \
### Download and Install Gitlab-Shell
    cd ${GITLAB_HOME} && \
    GITLAB_SHELL_VERSION=${GITLAB_SHELL_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_SHELL_VERSION)} && \
    GITLAB_SHELL_URL=https://gitlab.com/gitlab-org/gitlab-shell/-/archive/v${GITLAB_SHELL_VERSION}/gitlab-shell-v${GITLAB_SHELL_VERSION}.tar.gz && \
    echo "Downloading gitlab-shell v.${GITLAB_SHELL_VERSION}..." && \
    mkdir -p ${GITLAB_SHELL_INSTALL_DIR} && \
    curl -sSL ${GITLAB_SHELL_URL}?ref=v${GITLAB_SHELL_VERSION} | tar xfvz - --strip 1 -C ${GITLAB_SHELL_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}: ${GITLAB_SHELL_INSTALL_DIR} && \
    \
    cd ${GITLAB_SHELL_INSTALL_DIR} && \
    sudo -HEu git cp -a ${GITLAB_SHELL_INSTALL_DIR}/config.yml.example ${GITLAB_SHELL_INSTALL_DIR}/config.yml && \
    sudo -HEu git ./bin/install && \
    rm -rf /home/git/.ssh && \
    sudo -HEu git bundle config set --local deployment 'true' && \
    sudo -HEu git bundle config set --local without 'development test' && \
    sudo -HEu git bundle install -j"$(nproc)" && \
    sudo -HEu git GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH go mod vendor && \
    sudo -HEu git GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH make fmt && \
    sudo -HEu git GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH make setup && \
    \
    sudo -HEu git rm -rf ${GITLAB_HOME}/repositories && \
    \
### Download and Install Gitlab Elasticsearch-indexer
    GITLAB_ELASTICSEARCH_INDEXER_URL=https://gitlab.com/gitlab-org/gitlab-elasticsearch-indexer && \
    GITLAB_ELASTICSEARCH_INDEXER_VERSION=${GITLAB_ELASTICSEARCH_INDEXER_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_ELASTICSEARCH_INDEXER_VERSION)} && \
    echo "Cloning gitlab-elasticsearch-indexer v.${GITLAB_ELASTICSEARCH_INDEXER_VERSION}..." && \
    clone_git_repo ${GITLAB_ELASTICSEARCH_INDEXER_URL} v${GITLAB_ELASTICSEARCH_INDEXER_VERSION} /usr/src/gitlab-elasticsearch-indexer && \
    make -C /usr/src/gitlab-elasticsearch-indexer && \
    make -C /usr/src/gitlab-elasticsearch-indexer install  && \
    cp -af /usr/src/gitlab-elasticsearch-indexer/bin/gitlab-elasticsearch-indexer /usr/local/bin && \
    \
### Download and Install Gitlab Pages
    GITLAB_PAGES_URL=https://gitlab.com/gitlab-org/gitlab-pages && \
    GITLAB_PAGES_VERSION=${GITLAB_PAGES_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_PAGES_VERSION)} && \
    echo "Downloading gitlab-pages v.${GITLAB_PAGES_VERSION}..." && \
    clone_git_repo ${GITLAB_PAGES_URL} v${GITLAB_PAGES_VERSION} /usr/src/gitlab-pages && \
    make -C /usr/src/gitlab-pages -j$(getconf _NPROCESSORS_ONLN) && \
    cp -af /usr/src/gitlab-pages/gitlab-pages /usr/local/bin && \
    \
    ### Download and Install Gitaly
    mkdir -p ${GITLAB_GITALY_INSTALL_DIR} && \
    GITLAB_GITALY_VERSION=${GITLAB_GITALY_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITALY_SERVER_VERSION)} && \
    GITLAB_GITALY_URL=https://gitlab.com/gitlab-org/gitaly && \
    echo "Downloading gitaly v${GITLAB_GITALY_VERSION}..." && \
    clone_git_repo ${GITLAB_GITALY_URL} v${GITLAB_GITALY_VERSION} /usr/src/gitaly && \
    cd /usr/src/gitaly/ruby && \
    bundler install && \
    cd /usr/src/gitaly && \
    make -C /usr/src/gitaly -j$(getconf _NPROCESSORS_ONLN) install && \
    cd /usr/src/gitaly && \
    cp -a /usr/src/gitaly/config.toml.example ${GITLAB_GITALY_INSTALL_DIR}/config.toml && \
    cp -R /usr/src/gitaly/ruby ${GITLAB_GITALY_INSTALL_DIR}/ && \
    rm -rf ${GITLAB_GITALY_INSTALL_DIR}/ruby/vendor/bundle/ruby/**/cache && \
    chown -R ${GITLAB_USER}: ${GITLAB_GITALY_INSTALL_DIR} && \
    cd /home/git/gitaly && \
    ln -s /usr/local/bin/gitaly* . && \
    \
    ## Install Git that comes with Gitaly
    make -C /usr/src/gitaly -j$(getconf _NPROCESSORS_ONLN) git GIT_PREFIX=/usr/local && \
    \
    ## Final Cleanup
    rm -rf ${GITLAB_HOME}/.ssh && \
    sudo -HEu git ln -sf ${GITLAB_DATA_DIR}/.ssh ${GITLAB_HOME}/.ssh && \
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
### Configure sudoers
    echo ${GITLAB_USER}" ALL=(root) NOPASSWD: /usr/sbin/sshd >/etc/sudoers.d/git" && \
    rm -rf "${GITLAB_HOME}/.ssh" && \
    ln -sf "${GITLAB_DATA_DIR}/.ssh" "${GITLAB_HOME}/.ssh" && \
    \
### Cleanup
    go clean --modcache && \
    package remove ${BUILD_DEPENDENCIES} && \
    package cleanup && \
    rm -rf \
            ${GITLAB_INSTALL_DIR}/node_modules \
            ${GITLAB_HOME}/.bundle \
            ${GITLAB_HOME}/.cache \
            ${GITLAB_HOME}/.yarn \
            ${GITLAB_INSTALL_DIR}/*.md \
            ${GITLAB_INSTALL_DIR}/docker* \
            ${GITLAB_INSTALL_DIR}/qa \
            ${GITLAB_SHELL_INSTALL_DIR}/*.md \
            ${GITLAB_SHELL_INSTALL_DIR}/*.example \
            /etc/logroate.d/* \
            /usr/local/bundle/cache \
            /usr/share/vim/vim80/doc/* \
            /usr/local/go \
            /usr/local/bin/go* \
            /usr/src/* \
            /root/go \
            /root/.cache \
            /root/.bundle \
            /var/lib/apt/lists/* \
            /var/log/* \
            /tmp/*


ENV EXECJS_RUNTIME "Disabled"
WORKDIR ${GITLAB_INSTALL_DIR}
EXPOSE 22/tcp 80/tcp 443/tcp
COPY install/ /
