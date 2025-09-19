FROM node:current-alpine3.22 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build:dev

FROM nginx:alpine AS run
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.dev.conf /etc/nginx/nginx.conf
EXPOSE 5173
CMD ["nginx", "-g", "daemon off;"]