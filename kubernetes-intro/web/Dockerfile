FROM nginx:latest

RUN useradd -r -u 1001 -g nginx appuser

COPY nginx.conf /etc/nginx/conf.d/nginx.conf

RUN mkdir /app &&  \
chown -R appuser:nginx /app && chmod -R 755 /app && \
chown -R appuser:nginx /var/cache/nginx && \
chown -R appuser:nginx /var/log/nginx && \
chown -R appuser:nginx /etc/nginx/conf.d

WORKDIR /app

RUN touch /var/run/nginx.pid && chown -R appuser:nginx /var/run/nginx.pid

COPY homework.html /app
COPY index.html /app

USER appuser
EXPOSE 8000
CMD ["nginx", "-g", "daemon off;"]
