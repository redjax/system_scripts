FROM node:26-slim

RUN npm install --global vsix-scan \
  && npm cache clean --force

WORKDIR /scan

ENTRYPOINT ["vsix-scan", "scan-all"]

