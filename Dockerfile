ARG RUBY_VERSION=3.4.3
FROM ruby:$RUBY_VERSION-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUNDLE_APP_CONFIG=/bundle

WORKDIR /app
COPY Gemfile Gemfile.lock .tool-versions ./

ENV BUNDLE_WITHOUT="development:test"
RUN bundle install --without development test

COPY . .

ENTRYPOINT ["ruby", "/app/entrypoint.rb"]