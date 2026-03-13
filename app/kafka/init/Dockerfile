FROM amazoncorretto:17-alpine

ENV KAFKA_VERSION=3.8.0
ENV SCALA_VERSION=2.13
ENV MSK_IAM_AUTH_VERSION=1.1.6

WORKDIR /opt

# install tools
RUN apk add --no-cache bash curl unzip

# download Kafka
RUN curl -fsSL -o kafka.tgz \
    https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz \
 && tar -xzf kafka.tgz \
 && mv kafka_${SCALA_VERSION}-${KAFKA_VERSION} kafka \
 && rm kafka.tgz

# download AWS MSK IAM auth "all" jar
RUN curl -fsSL -o /opt/aws-msk-iam-auth.jar \
    https://github.com/aws/aws-msk-iam-auth/releases/download/v${MSK_IAM_AUTH_VERSION}/aws-msk-iam-auth-${MSK_IAM_AUTH_VERSION}-all.jar

# client config for MSK IAM
RUN mkdir -p /opt/kafka/config
COPY client.properties /opt/kafka/config/client.properties

# entrypoint script
COPY ./scripts/create-topics.sh /create-topics.sh
RUN chmod +x /create-topics.sh

ENTRYPOINT ["/create-topics.sh"]
