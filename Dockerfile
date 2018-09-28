FROM ruby:2.5.1-alpine
RUN gem update --system && gem install bundler -v 1.16.5
RUN apk update && apk add build-base

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
RUN bundle install

COPY bot.rb /usr/src/app
COPY data.json /usr/src/app

CMD ["bundle", "exec", "ruby", "bot.rb"]
