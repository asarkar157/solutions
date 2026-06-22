# CDK bot remote runner — extends the Guild aiden-runner image with Node/CDK toolchain
# and bakes the workflow script pack at apply-time (SCRIPT_PACK_VERSION build-arg).
#
# Build context: module root (`aios-agent-cdk-bot/`) so `scripts/` is available.

ARG AIDEN_RUNNER_IMAGE=ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main
FROM ${AIDEN_RUNNER_IMAGE}

ARG SCRIPT_PACK_VERSION
ENV CDKBOT_SCRIPT_PACK_VERSION=${SCRIPT_PACK_VERSION}
ENV CDKBOT_PACK_DIR=/home/runner/.cdk-bot/pack/${SCRIPT_PACK_VERSION}
ENV CDKBOT_ALLOW_DIRECT=1

USER root

# Node 22 + CDK CLI + cfn-lint + common shell tools (validate-cdk.sh / implement subagents).
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl gnupg sudo \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends \
    nodejs python3-pip ripgrep jq git \
  && pip3 install --no-cache-dir --break-system-packages 'cfn-lint>=1.19.0' \
  && npm install -g aws-cdk@2 \
  && echo 'runner ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt' > /etc/sudoers.d/runner-apt \
  && chmod 0440 /etc/sudoers.d/runner-apt \
  && rm -rf /var/lib/apt/lists/*

# Bake workflow scripts into the pack directory (clone-pack + stage-runner + helpers).
RUN mkdir -p "${CDKBOT_PACK_DIR}" && chown -R runner:runner /home/runner/.cdk-bot
COPY --chown=runner:runner scripts/ "${CDKBOT_PACK_DIR}/"
RUN chmod +x "${CDKBOT_PACK_DIR}"/*.sh \
  && test -x "${CDKBOT_PACK_DIR}/validate-cdk.sh" \
  && test -x "${CDKBOT_PACK_DIR}/ensure-shell-tool.sh"

USER runner

# aiden-runner discovers CLIs on PATH; keep in sync with validate-cdk.sh / clone-pack.sh.
ENV ALLOWED_CLIS=bash,sh,sudo,apt-get,apt,node,npm,npx,git,gh,jq,curl,python3,pip,cfn-lint,aws,cdk,find,cat,grep,rg,ripgrep,awk,sed,head,tail,chmod,mkdir,cp,tar,mktemp,printf,test,command
