FROM alpine:3.5

WORKDIR /app
COPY docker-entrypoint.sh .

ENTRYPOINT ./docker-entrypoint.sh
CMD [""]
