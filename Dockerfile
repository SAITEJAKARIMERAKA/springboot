
# Build stage
FROM maven:3.9.4-eclipse-temurin-17 AS builder
WORKDIR /workspace
COPY pom.xml .
RUN mvn -B -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -B -DskipTests package

# Runtime stage
FROM eclipse-temurin:17-jre-jammy
RUN groupadd -r app && useradd -r -g app app
WORKDIR /app
COPY --from=builder /workspace/target/*.jar app.jar
EXPOSE 8080
USER app
ENTRYPOINT ["java","-Xms256m","-Xmx512m","-jar","/app/app.jar"]
