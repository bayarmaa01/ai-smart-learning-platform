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
ARG VITE_API_URL=http://localhost:4200/api/v1
ARG VITE_AI_URL=http://localhost:5200
ARG VITE_BUILD_TIME=unknown
ARG VITE_APP_VERSION=1.0.0
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_AI_URL=$VITE_AI_URL
ENV VITE_BUILD_TIME=$VITE_BUILD_TIME
ENV VITE_APP_VERSION=$VITE_APP_VERSION
RUN npm run build

# Stage 2: Serve with NGINX
FROM nginx:alpine

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
