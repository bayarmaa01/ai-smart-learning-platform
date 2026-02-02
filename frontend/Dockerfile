# build stage
FROM node:18 AS build
WORKDIR /app
COPY package*.json ./
# Increase memory for npm
RUN node --max-old-space-size=4096 /usr/local/bin/npm install --legacy-peer-deps
COPY . .
RUN npm run build

# production stage
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
