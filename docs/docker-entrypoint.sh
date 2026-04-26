#!/bin/sh
set -e
cd /srv/jekyll

if [ ! -f Gemfile ]; then
  echo "docker-entrypoint: Gemfile not found in /srv/jekyll" >&2
  exit 1
fi

# Host-mounted tree may differ from image build; refresh gems if needed.
bundle check >/dev/null 2>&1 || bundle install --jobs 4 --retry 3

case "$1" in
  serve)
    shift
    exec bundle exec jekyll serve --host 0.0.0.0 --livereload "$@"
    ;;
  build)
    shift
    exec bundle exec jekyll build "$@"
    ;;
  *)
    exec bundle exec jekyll "$@"
    ;;
esac
