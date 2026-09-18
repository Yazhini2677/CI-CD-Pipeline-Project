# ---- Build stage ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY app/pom.xml .
RUN mvn -B dependency:go-offline
COPY app/src ./src
RUN mvn -B clean package -DskipTests

# ---- Runtime stage ----
FROM eclipse-temurin:17-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /build/target/*.jar app.jar
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
