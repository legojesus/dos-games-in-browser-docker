FROM node:22-alpine

# Install Docker CLI for container management
RUN apk add --no-cache docker-cli

WORKDIR /app
COPY server.js .

EXPOSE 8080
CMD ["node", "server.js"]
