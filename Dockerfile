FROM phusion/baseimage:0.10.0

LABEL Maintainer="Daniel P. Clark <6ftdan@gmail.com>" \
      Version="1.0" \
      Description="Ruby on Rails with VueJS."

SHELL ["/bin/bash", "-c", "-l"]

ENV WORKDIR_PATH=/app/user \
    RUBY_VERSION=2.5.0 \
    RACK_ENV=production \
    RAILS_ENV=production \
    LANG=en_US.UTF-8 \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    DATABASE_URL=postgresql:does_not_exist
    
ENV PATH=$WORKDIR_PATH/bin:$PATH \
    BUNDLE_APP_CONFIG=/app/heroku/ruby/.bundle/config \
    POST_RUN_SCRIPT_PATH=/app/.post-run.d

# Copy init script
COPY ./init.sh /usr/bin/init.sh

RUN set -ex ;\
    mkdir -p $WORKDIR_PATH ;\
    echo "debconf debconf/frontend select Teletype" | debconf-set-selections ;\
    #####
    # Install dependencies
    #
    curl -sL https://deb.nodesource.com/setup_9.x | bash - ;\
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - ;\
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list ;\
    apt-get update && apt-get install -y --no-install-recommends \
        tzdata nodejs yarn libpq-dev \
        ; \
    apt-get clean -y ;\
    apt-get autoremove -y ;\
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ;\
    #####
    # Install Ruby
    #
    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 ;\
    curl -sSL https://get.rvm.io | bash -s stable --ruby=$RUBY_VERSION ;\
    apt-get clean -y ;\
    apt-get autoremove -y ;\
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ;\
    echo "source /usr/local/rvm/scripts/rvm" >> $(getent passwd $(whoami) | cut -d: -f6)/.bashrc ;\
    source /usr/local/rvm/scripts/rvm ;\
    rvm default $RUBY_VERSION ;\
    rvm use $RUBY_VERSION ;\
    #####
    # Install Bundler
    #
    gem install bundler --no-ri --no-rdoc ;\
    # forcebundle to use github https protocol
    bundle config github.https true ;\
    bundle config --global frozen 1 ;\
    #####
    # Set startup script
    #
    chmod +x /usr/bin/init.sh ;\
    # make folder to run startup scripts
    mkdir -p $POST_RUN_SCRIPT_PATH

#####
# Install application and its gems
#
ADD . $WORKDIR_PATH
RUN set -ex ;\
    # Run bundler to cache dependencies if we have a Gemfile
    if [ -f $WORKDIR_PATH/Gemfile ]; then bundle install --without development test --jobs 4; fi ;\
    # Run yarn to cache dependencies if we have a yarn lock file
    if [ -f $WORKDIR_PATH/yarn.lock ]; then yarn install; fi

WORKDIR $WORKDIR_PATH

RUN echo "Before your first Rails deploy:" &&\
    echo "Be sure to add 'webpack', 'babel-loader', and 'extract-text-webpack-plugin' with yarn." && \
    echo "Be sure to add 'RUN init.sh' in the container using this one." &&\
    echo "Make sure you 'heroku stack:set container'." &&\
    echo "And lastly you need to add any environment variables you want to use from Heroku" &&\
    echo "in your CMD.  For example CMD POSTGRES_URL=\$POSTGRES_URL…"

ENTRYPOINT ["/sbin/my_init"]
