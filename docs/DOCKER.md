# Preview the docs site with Docker

This matches the **GitHub Pages** build as closely as practical: the [`github-pages`](https://github.com/github/pages-gem) Ruby gem (Jekyll, Minima, kramdown, Rouge, etc.—see [dependency versions](https://pages.github.com/versions/)).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2

## Run the local server

From the `docs/` directory:

```bash
docker compose up --build
```

When Jekyll reports “Server running”, open:

**http://127.0.0.1:4000/solutions/**

Use the **`/solutions`** prefix because `_config.yml` sets `baseurl: "/solutions"` for project Pages (same as production). Paths like `/architecture/` only work with that prefix locally.

LiveReload is enabled on port **35729** (optional in the browser).

## Static build only

```bash
docker compose run --rm jekyll build
```

Output is written to `_site/` on the host (under `docs/`).

## Stop

`Ctrl+C`, or from another terminal:

```bash
docker compose down
```

## Native Ruby (no Docker)

```bash
cd docs && bundle install && bundle exec jekyll serve --livereload
```

Then open the same **http://127.0.0.1:4000/solutions/** URL.
