ARG AIDEN_RUNNER_IMAGE=ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main
FROM ${AIDEN_RUNNER_IMAGE}

ARG SCRIPT_PACK_VERSION
ARG SPECIFY_CLI_REF=git+https://github.com/github/spec-kit.git@v0.10.3
ARG OPENSPEC_VERSION=1.4.1
ARG INSTALL_CURSOR_CLI=0
# Factory minimum: shell + SCM + SDD CLIs + apt bootstrap for ensure-shell-tool.sh (rg).
# Child utilities (grep, mkdir, tar, …) run inside pack scripts via sh -c and are not listed.
ARG ALLOWED_CLIS=bash,sh,sudo,apt-get,apt,git,gh,jq,npm,specify,openspec

ENV SPECSYM_SCRIPT_PACK_VERSION=${SCRIPT_PACK_VERSION}
ENV SPECSYM_PACK_DIR=/home/runner/.spec-symphony/pack/${SCRIPT_PACK_VERSION}
ENV SPECSYM_ALLOW_DIRECT=1

USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl gnupg sudo \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends \
    nodejs python3 python3-pip python3-venv ripgrep jq git \
  && curl -LsSf https://astral.sh/uv/install.sh | sh \
  && npm install -g @fission-ai/openspec@${OPENSPEC_VERSION} \
  && /root/.local/bin/uv tool install specify-cli --from ${SPECIFY_CLI_REF} \
  && ln -sf /root/.local/bin/specify /usr/local/bin/specify \
  && ln -sf /root/.local/bin/uv /usr/local/bin/uv \
  && echo 'runner ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt' > /etc/sudoers.d/runner-apt \
  && chmod 0440 /etc/sudoers.d/runner-apt \
  && rm -rf /var/lib/apt/lists/*

RUN if [ "$INSTALL_CURSOR_CLI" = "1" ]; then \
  curl -fsSL https://cursor.com/install | bash \
  && ln -sf /root/.cursor/bin/agent /usr/local/bin/agent \
  && ln -sf /root/.cursor/bin/agent /usr/local/bin/cursor; \
  fi

RUN mkdir -p "${SPECSYM_PACK_DIR}/templates" && chown -R runner:runner /home/runner/.spec-symphony
COPY --chown=runner:runner scripts/ "${SPECSYM_PACK_DIR}/"
COPY --chown=runner:runner templates/sdd-kit-starter/ "${SPECSYM_PACK_DIR}/templates/sdd-kit-starter/"
RUN chmod +x "${SPECSYM_PACK_DIR}"/*.sh \
  && test -x "${SPECSYM_PACK_DIR}/stage-runner.sh"

USER runner
ENV PATH="/home/runner/.local/bin:${PATH}"
ENV ALLOWED_CLIS=${ALLOWED_CLIS}
