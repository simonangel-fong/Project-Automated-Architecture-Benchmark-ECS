# flyway/Dockerfile
FROM flyway/flyway:11-alpine

WORKDIR /flyway
# copy db scripts
COPY ./conf /flyway/conf
# copy sql scripts
COPY ./sql /flyway/sql
# copy conf
COPY ./conf /flyway/conf/

CMD ["migrate", "-outOfOrder=true"]
