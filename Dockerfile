FROM fabric8/java-jboss-openjdk8-jdk:1.2
ENV JAVA_APP_DIR=/deployments

ARG JAR_FILE

EXPOSE 8080 8778 9779
COPY ${JAR_FILE} /deployments/
