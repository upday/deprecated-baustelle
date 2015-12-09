FROM alpine:3.1

# libxml2 and libxslt is needed for building native extensions of nokogiri gem
# libffi-dev is needed for building native extensions of ffi gem

RUN apk --update add ca-certificates ruby-dev build-base git libxml2-dev libxslt-dev libffi-dev \
	&& gem install bundler

COPY . /app/
RUN cd /app \
	&& bundle config build.nokogiri --use-system-libraries \
	&& bundle install

WORKDIR /app
ENTRYPOINT ["bundle", "exec", "baustelle"]
