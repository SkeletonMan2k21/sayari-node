FROM node:22 as base

WORKDIR /home/node/app
COPY node/package*.json ./

RUN npm i

COPY . .

