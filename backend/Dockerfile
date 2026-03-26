FROM node:20-alpine AS deps

WORKDIR /app

# Prisma engines need OpenSSL in Alpine images
RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci

FROM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache openssl

COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY tsconfig*.json nest-cli.json ./
COPY prisma ./prisma
COPY src ./src
COPY test ./test

RUN npx prisma generate
RUN npm run build
RUN npm prune --omit=dev

FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache openssl

ENV NODE_ENV=production

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/dist ./dist

EXPOSE 3000

CMD ["node", "dist/main"]
