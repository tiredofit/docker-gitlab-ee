FROM tiredofit/debian:buster
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

### Set Defaults and Arguments
ENV GITLAB_VERSION="13.10.0-ee" \
    GITLAB_SHELL_VERSION="13.17.0" \
    GITLAB_PAGES_VERSION="1.36.0" \
    GITALY_SERVER_VERSION="13.10.0" \
    GITLAB_ELASTICSEARCH_INDEXER_VERSION="2.9.0" \
    GITLAB_USER="git" \
    GITLAB_HOME="/home/git" \
    GO_VERSION="1.15.7" \
    RUBY_VERSION="2.7.2" \
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
    SKIP_SANITY_CHECK=FALSE

### Set Nginx Version Number
ENV NGINX_VERSION=1.19.8 \
    NGINX_AUTH_LDAP_VERSION=master \
    NGINX_BROTLI_VERSION=25f86f0bac1101b6512135eac5f93c49c63609e3 \
    NGINX_BOT_BLOCKER_VERSION=V4.2020.11.2170 \
    NGINX_USER=nginx \
    NGINX_GROUP=www-data \
    NGINX_WEBROOT=/www/html

### Install Nginx
RUN set -x && \
    CONFIG="\
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/dev/null \
      --http-log-path=/dev/null.log \
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
 #     --with-pcre=/usr/src/pcre \
 #     --with-pcre-jit \
 #     --with-zlib=/usr/src/zlib \
 #     --with-openssl=/usr/src/openssl \
 #     --with-openssl-opt=no-nextprotoneg \
#     --with-http_v3_module \
#      --with-quiche=/usr/src/quiche \
      --add-module=/usr/src/headers-more-nginx-module \
      --add-module=/usr/src/nginx_cookie_flag_module \
      --add-module=/usr/src/nginx-brotli \
      --add-module=/usr/src/nginx-auth-ldap \
      --add-module=/usr/src/nginx-ext-dav \
    " && \
    adduser --disabled-password --system --home /var/cache/nginx --shell /sbin/nologin --ingroup www-data nginx && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
                    build-essential \
                    git \
                    software-properties-common \
                    inotify-tools \
                    perl \
                    libperl-dev \
                    libgd3 \
                    libgd-dev \
                    libgeoip1 \
                    libgeoip-dev \
                    geoip-bin \
                    libxml2 \
                    libxml2-dev \
                    libxslt1.1 \
                    libxslt1-dev \
                    libpcre3 \
                    libpcre3-dev \
                    zlib1g \
                    zlib1g-dev \
                    openssl \
                    libssl-dev \
                    libldap2-dev \
                    && \
    \
    mkdir -p /www /var/log/nginx && \
    chown -R nginx:www-data /var/log/nginx && \
#    mkdir -p /usr/src/pcre && \
#    curl -ssL https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz | tar xvfz - --strip 1 -C /usr/src/pcre && \
#    mkdir -p /usr/src/zlib && \
#    curl -ssL https://www.zlib.net/zlib-1.2.11.tar.gz | tar xvfz - --strip 1 -C /usr/src/zlib && \
#    mkdir -p /usr/src/openssl && \
#    curl -ssL https://www.openssl.org/source/openssl-1.1.1c.tar.gz | tar xvfz - --strip 1 -C /usr/src/openssl && \
#    git clone --recursive https://github.com/cloudflare/quiche /usr/src/quiche && \
    git clone --recursive https://github.com/openresty/headers-more-nginx-module.git /usr/src/headers-more-nginx-module && \
    git clone --recursive https://github.com/google/ngx_brotli.git /usr/src/nginx-brotli && \
    git clone --recursive https://github.com/AirisX/nginx_cookie_flag_module /usr/src/nginx_cookie_flag_module && \
    cd /usr/src/nginx-brotli && \
    git checkout -b $NGINX_BROTLI_VERSION $NGINX_BROTLI_VERSION && \
    cd /usr/src && \
    git clone https://github.com/arut/nginx-dav-ext-module/ /usr/src/nginx-ext-dav && \
    git clone https://github.com/kvspb/nginx-auth-ldap /usr/src/nginx-auth-ldap && \
    mkdir -p /usr/src/nginx && \
    curl -sSL http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr/src/nginx && \
    cd /usr/src/nginx && \
    ./configure $CONFIG && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    rm -rf /etc/nginx/html/ && \
    mkdir -p /etc/nginx/conf.d/ && \
    mkdir -p /usr/share/nginx/html/ && \
    install -m644 html/index.html /usr/share/nginx/html/ && \
    install -m644 html/50x.html /usr/share/nginx/html/ && \
    ln -s ../../usr/lib/nginx/modules /etc/nginx/modules && \
    mkdir -p /var/log/nginx && \
    mkdir -p /etc/nginx/nginx.conf.d/blockbots && \
    mkdir -p /etc/nginx/nginx.conf.d/blockbots-custom && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/bad-referrer-words.conf -o /etc/nginx/nginx.conf.d/blockbots/bad-referrer-words.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/bad-referrers.conf -o /etc/nginx/nginx.conf.d/blockbots/bad-referrers.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/blacklist-ips.conf -o /etc/nginx/nginx.conf.d/blockbots/blacklist-ips.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/blacklist-user-agents.conf -o /etc/nginx/nginx.conf.d/blockbots/blacklist-user-agents.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/blockbots.conf -o /etc/nginx/nginx.conf.d/blockbots/blockbots.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/custom-bad-referrers.conf -o /etc/nginx/nginx.conf.d/blockbots/custom-bad-referrers.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/ddos.conf -o /etc/nginx/nginx.conf.d/blockbots/ddos.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/whitelist-domains.conf -o /etc/nginx/nginx.conf.d/blockbots/whitelist-domains.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/bots.d/whitelist-ips.conf -o /etc/nginx/nginx.conf.d/blockbots/whitelist-ips.conf && \
    curl -sL https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/conf.d/globalblacklist.conf -o /etc/nginx/nginx.conf.d/blockbots/globalblacklist.conf && \
    sed -i "s|/etc/nginx/bots.d/|/etc/nginx/nginx.conf.d/blockbots/|g" /etc/nginx/nginx.conf.d/blockbots/globalblacklist.conf && \
    sed -i "s|/etc/nginx/nginx.conf.d/blockbots/bad-referrer-words.conf|/etc/nginx/nginx.conf.d/blockbots-custom/bad-referrer-words.conf|g" /etc/nginx/nginx.conf.d/blockbots/globalblacklist.conf && \
    sed -i "s|/etc/nginx/nginx.conf.d/blockbots/blacklist-ips.conf|/etc/nginx/nginx.conf.d/blockbots-custom/blacklist-ips.conf|g" /etc/nginx/nginx.conf.d/blockbots/globalblacklist.conf && \
    sed -i "s|/etc/nginx/nginx.conf.d/blockbots/blacklist-user-agents.conf|/etc/nginx/nginx.conf.d/blockbots-custom/blacklist-user-agents.conf|g" /etc/nginx/nginx.conf.d/blockbots/globalblacklist.conf && \
    sed -i "s|/etc/nginx/nginx.conf.d/blockbots/whitelist-domains.conf|/etc/nginx/nginx.conf.d/blockbots-custom/whitelist-domains.conf|g" /etc/nginx/nginx.conf.d/blockbots/globalblacklist.conf && \
    sed -i "s|/etc/nginx/nginx.conf.d/blockbots/whitelist-ips.conf|/etc/nginx/nginx.conf.d/blockbots-custom/whitelist-ips.conf|g" /etc/nginx/nginx.conf.d/blockbots/globalblacklist.conf && \
    \
    apt-get purge -y  build-essential \
                      libgd-dev \
                      libgeoip-dev \
                      libldap2-dev \
                      libperl-dev \
                      libpcre3-dev \
                      libssl-dev \
                      libxml2-dev \
                      libxslt1-dev \
                      zlib1g-dev \
                      && \
    \
    rm -rf /etc/nginx/*.default /usr/src/* /var/tmp/* /var/lib/apt/lists/* && \
    \
    curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
    echo "deb https://deb.nodesource.com/node_12.x buster main" > /etc/apt/sources.list.d/nodejs.list && \
    curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    curl -ssL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgres.list && \
    echo "deb http://deb.debian.org/debian buster-backports main" > /etc/apt/sources.list.d/buster-backports.list && \
    apt-get update && \
    apt-get install -y \
                gettext-base \
                graphicsmagick \
                libcurl4 \
                libffi6 \
                libgdbm6 \
                libicu63 \
                libimage-exiftool-perl \
                libncurses5 \
                libpq5 \
                libpcre2-8-0 \
                libre2-dev \
                libreadline7 \
                #libssl1.0.0 \
                libxml2 \
                libxslt1.1 \
                libyaml-0-2 \
                locales \
                openssh-server \
                nodejs \
                postgresql-client-13 \
                postgresql-contrib-13 \
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
                        git/buster-backports \
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
    ./configure --disable-install-rdoc && \
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
    sudo -HEu git bundle install -j"$(nproc)" --deployment --without development test mysql aws && \
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
    GITLAB_SHELL_URL=https://gitlab.com/gitlab-org/gitlab-shell/repository/archive.tar.gz && \
    GITLAB_SHELL_VERSION=${GITLAB_SHELL_VERSION:-$(cat ${GITLAB_INSTALL_DIR}/GITLAB_SHELL_VERSION)} && \
    echo "Downloading gitlab-shell v.${GITLAB_SHELL_VERSION}..." && \
    mkdir -p ${GITLAB_SHELL_INSTALL_DIR} && \
    curl -sSL ${GITLAB_SHELL_URL}?ref=v${GITLAB_SHELL_VERSION} | tar xfvz - --strip 1 -C ${GITLAB_SHELL_INSTALL_DIR} && \
    chown -R ${GITLAB_USER}: ${GITLAB_SHELL_INSTALL_DIR} && \
    \
    cd ${GITLAB_SHELL_INSTALL_DIR} && \
    sudo -HEu git cp -a ${GITLAB_SHELL_INSTALL_DIR}/config.yml.example ${GITLAB_SHELL_INSTALL_DIR}/config.yml && \
    sudo -HEu git ./bin/install && \
    rm -rf /home/git/.ssh && \
    sudo -HEu git bundle install -j"$(nproc)" --deployment --with development test && \
    sudo -HEu git GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH make verify setup && \
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
    GITLAB_GITALY_URL=https://gitlab.com/gitlab-org/gitaly.git && \
    echo "Downloading gitaly v.${GITALY_SERVER_VERSION}..." && \
    mkdir -p ${GITLAB_GITALY_INSTALL_DIR} && \
    git clone -q -b v${GITALY_SERVER_VERSION} --depth 1 ${GITLAB_GITALY_URL} /usr/src/gitaly && \
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
