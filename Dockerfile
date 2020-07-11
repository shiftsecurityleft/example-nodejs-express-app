FROM nginx
ARG APP_FULLNAME
COPY ./app/build /usr/share/nginx/html/$APP_FULLNAME
COPY nginx.conf /etc/nginx/nginx.conf