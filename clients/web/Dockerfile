FROM node:24.18.0-alpine AS build
WORKDIR /app/clients/web
ARG BOOHTACORD_CACHE_SCOPE=local-v1
COPY clients/web/package.json clients/web/package-lock.json ./
RUN --mount=type=cache,id=boohtacord-${BOOHTACORD_CACHE_SCOPE}-npm,target=/root/.npm,sharing=locked npm ci
ARG VITE_RNNOISE_ENABLED=true
ARG VITE_SCREEN_SHARE_DESCRIPTOR_V1=true
ARG VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=false
ARG VITE_PUBLIC_ORIGIN
ARG SOURCE_REVISION=unknown
ENV VITE_RNNOISE_ENABLED=${VITE_RNNOISE_ENABLED}
ENV VITE_SCREEN_SHARE_DESCRIPTOR_V1=${VITE_SCREEN_SHARE_DESCRIPTOR_V1}
ENV VITE_SCREEN_SHARE_BOUNDED_SIMULCAST=${VITE_SCREEN_SHARE_BOUNDED_SIMULCAST}
ENV VITE_PUBLIC_ORIGIN=${VITE_PUBLIC_ORIGIN}
ENV SOURCE_REVISION=${SOURCE_REVISION}
COPY clients/web/index.html clients/web/tsconfig.json clients/web/vite.config.ts ./
COPY clients/web/src ./src
COPY clients/web/public ./public
COPY contracts/client-build.json /app/contracts/client-build.json
COPY contracts/screen-share-profile-v1.catalog.json /app/contracts/screen-share-profile-v1.catalog.json
RUN npm run build

FROM nginx:1.27.4-alpine
COPY clients/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/clients/web/dist /usr/share/nginx/html
EXPOSE 80
