FROM ruby:2.2.2
RUN apt update -y -qq && apt install -y -u postgresql-client gcc g++ build-essential sox libsox-fmt-mp3
WORKDIR /ruby-app
COPY ./ /ruby-app
COPY ./Gemfile /ruby-app/Gemfile
COPY ./Gemfile.lock /ruby-app/Gemfile.lock
RUN bundle install
