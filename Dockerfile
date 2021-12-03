FROM docker.io/tiredofit/nginx:debian-bullseye
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

### Set Defaults and Arguments
ENV GITLAB_VERSION="14.5.1-ee" \
    GO_VERSION="1.17.1" \
    RUBY_VERSION="2.7.4" \
    GITLAB_HOME="/home/git"

ENV GITLAB_INSTALL_DIR="${GITLAB_HOME}/gitlab" \
    GITLAB_SHELL_INSTALL_DIR="${GITLAB_HOME}/gitlab-shell" \
    GITLAB_WORKHORSE_INSTALL_DIR="${GITLAB_HOME}/gitlab-workhorse" \
    GITLAB_ELASTICSEARCH_INDEXER_INSTALL_DIR="${GITLAB_HOME}/gitlab-elasticsearch-indexer" \
    GITLAB_PAGES_INSTALL_DIR="${GITLAB_HOME}/gitlab-pages" \
    GITLAB_GITALY_INSTALL_DIR="${GITLAB_HOME}/gitaly" \
    GITLAB_DATA_DIR="${GITLAB_HOME}/data" \
    GITLAB_BUILD_DIR="/usr/src" \
    GITLAB_LOG_DIR="/var/log" \
    GITLAB_RUNTIME_DIR="${GITLAB_CACHE_DIR}/runtime" \
    GITLAB_USER="git" \
    MODE="START" \
    NGINX_LOG_ACCESS_FILE=nginx-access.log \
    NGINX_LOG_ACCESS_LOCATION=/home/git/gitlab/log/nginx \
    NGINX_LOG_ERROR_FILE=nginx-error.log \
    NGINX_LOG_ERROR_LOCATION=/home/git/gitlab/log/nginx \
    NODE_ENV="production" \
    SKIP_SANITY_CHECK=FALSE \
    RAILS_ENV="production"


RUN set -x && \
    curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
    echo "deb https://deb.nodesource.com/node_16.x $(cat /etc/os-release |grep "VERSION=" | awk 'NR>1{print $1}' RS='(' FS=')') main" > /etc/apt/sources.list.d/nodejs.list && \
    curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    curl -ssL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(cat /etc/os-release |grep "VERSION=" | awk 'NR>1{print $1}' RS='(' FS=')')-pgdg main" > /etc/apt/sources.list.d/postgres.list && \
    #echo "deb http://deb.debian.org/debian $(cat /etc/os-release |grep "VERSION=" | awk 'NR>1{print $1}' RS='(' FS=')')-backports main" > /etc/apt/sources.list.d/bullseye-backports.list && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
                gettext-base \
                graphicsmagick \
                libcurl4 \
                libffi7 \
                libgdbm6 \
                libicu67 \
                libimage-exiftool-perl \
                libncurses5 \
                libpq5 \
                libpcre2-8-0 \
                libre2-dev \
                libreadline8 \
                #libssl1.0.0 \
                libxml2 \
                libxslt1.1 \
                libyaml-0-2 \
                locales \
                openssh-server \
                nodejs \
                postgresql-client-14 \
                postgresql-contrib-14 \
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
    apt-get install -y --no-install-recommends ${BUILD_DEPENDENCIES} && \
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
    rm -rf /etc/nginx/conf.d/default.conf && \
    \
### Setup Ruby
    mkdir -p /usr/src/ruby && \
    curl -sSL https://cache.ruby-lang.org/pub/ruby/$(echo ${RUBY_VERSION} | cut -c1-3)/ruby-${RUBY_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr/src/ruby && \
    cd /usr/src/ruby && \
    ./configure --disable-install-rdoc --enable-shared && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    \
### Configure git
    sudo -u ${GITLAB_USER} git config --global core.autocrlf input && \
    sudo -u ${GITLAB_USER} git config --global gc.auto 0 && \
    sudo -u ${GITLAB_USER} git config --global repack.writeBitmaps true && \
    sudo -u ${GITLAB_USER} git config --global receive.advertisePushOptions true && \
    sudo -u ${GITLAB_USER} git config --global core.fsyncObjectFiles true && \
    \
### Download and Install Gitlab
    GITLAB_CLONE_URL=https://gitlab.com/gitlab-org/gitlab.git && \
    mkdir -p ${GITLAB_INSTALL_DIR} && \
    git clone -q -b v${GITLAB_VERSION} --depth 1 ${GITLAB_CLONE_URL} ${GITLAB_INSTALL_DIR} && \
    \
    sed -i "/\ \ \ \ \ \ return \[\] unless Gitlab::Database.exists?/a \ \ \ \ \ \ return \[\] unless Feature::FlipperFeature.table_exists?" ${GITLAB_INSTALL_DIR}/lib/feature.rb && \
    sed -i "/\ \ \ \ \ \ return default_enabled unless Gitlab::Database.exists?/a \ \ \ \ \ \ return default_enabled unless Feature::FlipperFeature.table_exists?" ${GITLAB_INSTALL_DIR}/lib/feature.rb && \
    \
    chown -R ${GITLAB_USER}:${GITLAB_USER} ${GITLAB_INSTALL_DIR} && \
    sudo -HEu git sed -i "/headers\['Strict-Transport-Security'\]/d" ${GITLAB_INSTALL_DIR}/app/controllers/application_controller.rb && \
    sudo -HEu git sed -i 's/db:reset/db:setup/' ${GITLAB_INSTALL_DIR}/lib/tasks/gitlab/setup.rake && \
    \
    cd ${GITLAB_INSTALL_DIR} && \
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
    ### symlink ${GITLAB_INSTALL_DIR}/log -> ${GITLAB_LOG_DIR}/gitlab
    rm -rf ${GITLAB_INSTALL_DIR}/log && \
    ln -sf ${GITLAB_LOG_DIR}/gitlab ${GITLAB_INSTALL_DIR}/log && \
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
    ### disable default nginx configuration and enable gitlab's nginx configuration
    rm -rf /etc/nginx/conf.d/default.conf && \
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
    GITLAB_GITALY_VERSION=${GITLAB_GITALY_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITALY_SERVER_VERSION)} && \
    GITLAB_GITALY_URL=https://gitlab.com/gitlab-org/gitaly.git && \
    echo "Downloading gitaly v${GITLAB_GITALY_VERSION}..." && \
    mkdir -p ${GITLAB_GITALY_INSTALL_DIR} && \
    git clone -q -b v${GITLAB_GITALY_VERSION} --depth 1 ${GITLAB_GITALY_URL} /usr/src/gitaly && \
    cd /usr/src/gitaly/ruby && \
    bundler install && \
    cd /usr/src/gitaly && \
    make -C /usr/src/gitaly install && \
    cp -a /usr/src/gitaly/ruby ${GITLAB_GITALY_INSTALL_DIR} && \
    cp -a /usr/src/gitaly/config.toml.example ${GITLAB_GITALY_INSTALL_DIR}/config.toml && \
    rm -rf ${GITLAB_GITALY_INSTALL_DIR}/ruby/vendor/bundle/ruby/**/cache && \
    chown -R ${GITLAB_USER}: ${GITLAB_GITALY_INSTALL_DIR} && \
    cd /home/git/gitaly && \
    ln -s /usr/local/bin/gitaly* . && \
    \
    ## Install Git that comes with Gitaly
    make -C /usr/src/gitaly git GIT_PREFIX=/usr/local && \
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
    apt-get purge -y ${BUILD_DEPENDENCIES} && \
    apt-get autoremove -y && \
    apt-get clean && \
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
    rm -rf /usr/local/go && \
    rm -rf /usr/local/bin/go* && \
    rm -rf /usr/src/* && \
    rm -rf /root/go && \
    rm -rf /root/.cache && \
    rm -rf /root/.bundle && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

ENV EXECJS_RUNTIME "Disabled"

### Entrypoint Configuration
WORKDIR ${GITLAB_INSTALL_DIR}

### Network Configuration
EXPOSE 22/tcp 80/tcp 443/tcp

### Add Assets
ADD install /
