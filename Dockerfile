# ---- runtime only ----
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

# Copy the JAR produced by your Jenkins Maven stage
# (Spring Boot creates a single fat JAR under target/)
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar

EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
