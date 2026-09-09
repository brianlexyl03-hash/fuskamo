FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
# `npm ci` requires package-lock.json, which isn't in this repo yet (see
# docs/production-checklist.md — generate one by running `npm install`
# once, with network access, from backend/, then commit it and switch
# this back to `npm ci --omit=dev` for reproducible, hash-verified
# installs). Until then, `npm install` works without a lockfile — it
# resolves versions fresh each build, which is fine for now but is not
# the reproducible-build guarantee `npm ci` gives you.
RUN npm install --omit=dev

COPY src/ ./src/

ENV NODE_ENV=production
EXPOSE 8080

CMD ["node", "src/server.js"]
