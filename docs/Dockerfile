# Same Ruby family as https://pages.github.com/versions/ (GitHub Pages).
FROM ruby:3.3-slim-bookworm

RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends build-essential git curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/jekyll

ENV LANG=C.UTF-8 \
    BUNDLE_SILENCE_ROOT_WARNING=1

COPY Gemfile ./
RUN bundle install --jobs 4 --retry 3

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 4000 35729

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["serve"]
