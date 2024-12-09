FROM node:22 as base

WORKDIR /home/node/app
COPY node/package*.json ./
COPY node/prisma/schema.prisma ./prisma/
RUN npm i
RUN npx prisma generate

COPY . .

