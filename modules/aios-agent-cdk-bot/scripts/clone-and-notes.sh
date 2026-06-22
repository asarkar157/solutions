#!/usr/bin/env bash
# Thin wrapper — canonical logic in stage-runner.sh (embed via heredoc in ONE execute_series).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stage-runner.sh" clone "$@"
