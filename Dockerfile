FROM node:alpine

WORKDIR /usr/src/app

ARG APP_FULLNAME

ARG NODE_ENV=development
ENV NODE_ENV $NODE_ENV

COPY ./app /usr/src/app
RUN echo "module.exports  = {	baseUrl: '/${APP_FULLNAME}/' }" > /usr/src/app/config.js
RUN npm install

ENV PORT 3000
EXPOSE $PORT
CMD [ "npm", "start" ]