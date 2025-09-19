# Stage 1: Build the application
FROM node:current-alpine3.22 AS build

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json into the working directory
COPY package*.json ./

# Update npm to the latest version && Install dependencies
RUN npm install --ignore-scripts -g npm@latest && \
    npm install --ignore-scripts

# Copy the application code
COPY . .

# Build NodeJs app for production
RUN npm run build

# Stage 2: Create the final image
FROM alpine:3.22.1 AS run

# Install Node.js and npm
RUN apk add --no-cache nodejs npm

# Create a non-root user and group
RUN addgroup -S warranty && adduser -S warranty -G warranty

# Set the working directory
WORKDIR /app

# Copy only the necessary files from the build stage
COPY --from=build /app /app

# Change ownership of the application files to the non-root user
RUN chown -R warranty:warranty /app

# Switch to the non-root user
USER warranty

# Expose the port
EXPOSE 5173

# Set environment variables
ENV PORT 5173
ENV HOSTNAME "0.0.0.0"

# Start the application
CMD ["npm", "start"]
