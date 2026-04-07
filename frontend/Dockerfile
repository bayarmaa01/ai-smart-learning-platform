# Stage 1: Build

FROM node:20-alpine AS builder

# Set Node.js memory limit for stability
ENV NODE_OPTIONS=--max-old-space-size=4096

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
ARG VITE_API_URL=/api/v1
ARG VITE_AI_URL=/ai
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_AI_URL=$VITE_AI_URL
RUN npm run build

# Stage 2: Serve with NGINX
FROM nginx:1.25-alpine AS production

# Install security updates and utilities
RUN apk upgrade --no-cache && \
    apk add --no-cache wget

# Copy NGINX config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Create directories and set permissions
RUN mkdir -p /var/cache/nginx /var/log/nginx /var/run && \
    addgroup -g 1001 -S nginx-user && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G nginx-user nginx-user && \
    chown -R nginx-user:nginx-user /usr/share/nginx/html && \
    chown -R nginx-user:nginx-user /var/cache/nginx && \
    chown -R nginx-user:nginx-user /var/log/nginx && \
    chown -R nginx-user:nginx-user /var/run

# Create custom nginx.conf without user directive (running as non-root)
RUN echo "worker_processes auto;" > /etc/nginx/nginx.conf && \
    echo "error_log /var/log/nginx/error.log warn;" >> /etc/nginx/nginx.conf && \
    echo "pid /tmp/nginx.pid;" >> /etc/nginx/nginx.conf && \
    echo "events {" >> /etc/nginx/nginx.conf && \
    echo "    worker_connections 1024;" >> /etc/nginx/nginx.conf && \
    echo "}" >> /etc/nginx/nginx.conf && \
    echo "http {" >> /etc/nginx/nginx.conf && \
    echo "    include /etc/nginx/conf.d/*.conf;" >> /etc/nginx/nginx.conf && \
    echo "}" >> /etc/nginx/nginx.conf && \
    chown -R nginx-user:nginx-user /tmp /var/log/nginx /etc/nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
