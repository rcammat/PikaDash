FROM node:22.12.0 AS frontend-build

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM node:22.12.0 AS backend-deps

WORKDIR /app/backend
COPY backend/package*.json ./
RUN npm ci --omit=dev

FROM node:22.12.0 AS runtime

ENV NODE_ENV=production
WORKDIR /app/backend

COPY --from=backend-deps /app/backend/node_modules ./node_modules
COPY backend/ ./
COPY --from=frontend-build /app/frontend/dist ../frontend/dist

EXPOSE 5001

CMD ["node", "index.js"]
