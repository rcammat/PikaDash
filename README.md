# PikaDash Deploy

PikaDash queda desplegado como una sola imagen:

- `backend` Express
- frontend Angular ya compilado
- misma origin para login, panel y API web

Esto evita problemas de cookies, CORS y callback de Discord.

## Requisitos

- Docker y Docker Compose en la Raspberry Pi 5
- `PikaBot` ya levantado
- la red Docker compartida creada por `PikaBot`
- un dominio o subdominio, por ejemplo `pikadash.rcammat.com`
- un proxy inverso en la Raspberry o en otro servicio del host para publicar `https://pikadash.rcammat.com`

## Paso 1. Ajustar la red de PikaBot

En `C:\Dev\PikaBot\docker-compose.yml` la red ya quedó fijada como:

- `pikabot_shared`

Y el bot ya queda preparado para aceptar control web desde Docker con:

- `BOT_CONTROL_HOST=0.0.0.0`

Si aún no has recreado `PikaBot`, hazlo antes de levantar `PikaDash`.

## Paso 2. Preparar variables de entorno

Copia:

```bash
cp .env.example .env
```

Y rellena al menos:

- `PUBLIC_BASE_URL`
- `FRONTEND_URL`
- `DISCORD_CALLBACK_URL`
- `DISCORD_CLIENT_ID`
- `DISCORD_CLIENT_SECRET`
- `SESSION_SECRET`
- `JWT_SECRET`
- `BOT_TOKEN`

Para integración con `PikaBot`, por defecto ya valen:

- `PIKABOT_API_URL=http://api:5000`
- `PIKABOT_CONTROL_URL=http://bot:3300`

Eso funciona mientras `PikaDash` y `PikaBot` estén en la red Docker compartida `pikabot_shared`.

## URLs públicas recomendadas para Discord Developer Portal

Si vas a usar monetización de aplicaciones en Discord, deja preparadas estas URLs públicas:

- `https://pikadash.rcammat.com/terms`
- `https://pikadash.rcammat.com/privacy`

La idea es que Discord pueda revisar fácilmente:

- landing pública del producto,
- política de privacidad,
- términos del servicio,
- y una propuesta premium visible y coherente.

## Paso 3. Construir y levantar

```bash
docker compose build
docker compose up -d
```

Comprobación rápida:

```bash
curl http://127.0.0.1:5001/health
```

Debe responder con `success: true`.

## Paso 4. Cloudflare Tunnel

Si quieres evitar abrir puertos en la Raspberry, esta es la opción más limpia.

### Opción recomendada: túnel remoto gestionado desde Cloudflare

1. Entra en `Zero Trust`.
2. Ve a `Networks` → `Tunnels`.
3. Crea un túnel nuevo de tipo `Cloudflared`.
4. Elige la opción de conector Docker.
5. Crea un hostname público:

- `pikadash.rcammat.com`
- servicio: `http://pikadash:5001`

6. Cloudflare te dará un `TUNNEL_TOKEN`.
7. Guárdalo en `.env` como:

```env
CLOUDFLARED_TUNNEL_TOKEN=tu_token_aqui
```

8. Levanta `PikaDash` con el perfil de túnel:

```bash
docker compose --profile tunnel up -d --build
```

Con eso:

- `pikadash` sirve la web internamente en Docker
- `cloudflared` publica `pikadash.rcammat.com`
- no hace falta exponer `5001` a Internet

### Notas importantes

- `PUBLIC_BASE_URL`, `FRONTEND_URL` y `DISCORD_CALLBACK_URL` deben seguir apuntando a `https://pikadash.rcammat.com`
- en Discord Developer Portal tienes que añadir también:

```text
https://pikadash.rcammat.com/auth/discord/callback
```

- el servicio `cloudflared` ya está preparado en [docker-compose.yml](C:/Dev/PikaDash/docker-compose.yml) usando el perfil `tunnel`

## Paso 5. DNS en Cloudflare

Si usas túnel gestionado por Cloudflare, el hostname público normalmente queda enlazado desde el propio panel del túnel, así que no tendrás que crear manualmente un `A` normal hacia la Raspberry.

Si prefieres seguir con DNS manual tradicional y proxy inverso, entonces sí puedes crear el registro aparte.

## Paso 6. DNS tradicional o proxy clásico

Si no usas Cloudflare Tunnel y prefieres proxy inverso tradicional:

En Cloudflare crea:

- un registro `A` o `AAAA` para `pikadash.rcammat.com`
- apuntando a la IP pública de la Raspberry o del router si haces NAT

Recomendación:

- usa proxy de Cloudflare activado
- en SSL/TLS usa `Full (strict)` si tu proxy/origen sirve HTTPS real

## Paso 7. Proxy inverso clásico

Lo ideal es publicar `PikaDash` detrás de Nginx o Caddy y reenviar a:

- `http://127.0.0.1:5001`

Cabeceras importantes:

- `Host`
- `X-Forwarded-For`
- `X-Forwarded-Proto https`

Como el backend ya usa `TRUST_PROXY=1`, las cookies seguras funcionarán bien detrás del proxy.

## OAuth Discord

En Discord Developer Portal configura:

- `Redirect URI`: `https://pikadash.rcammat.com/auth/discord/callback`

Si cambia el subdominio, cambia también:

- `PUBLIC_BASE_URL`
- `FRONTEND_URL`
- `DISCORD_CALLBACK_URL`

## Arquitectura de red

`PikaDash` habla con:

- `api:5000` para la API persistente de `PikaBot`
- `bot:3300` para el control interno del bot

Ese puerto `3300` no hace falta exponerlo a Internet. Solo debe ser visible dentro de la red Docker compartida.

Si usas `cloudflared`, tampoco necesitas exponer `5001` fuera de la Raspberry para servicio público.

## Actualizar

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

## Problemas típicos

- Si el login con Discord vuelve a `localhost`, revisa `PUBLIC_BASE_URL`, `FRONTEND_URL` y `DISCORD_CALLBACK_URL`.
- Si la pestaña de música falla, revisa que `PikaBot` esté recreado con `BOT_CONTROL_HOST=0.0.0.0`.
- Si el panel no llega a `api` o `bot`, revisa que ambos proyectos estén en la red `pikabot_shared`.
- Si las cookies no persisten detrás de Cloudflare/proxy, revisa `TRUST_PROXY=1` y que el proxy envíe `X-Forwarded-Proto https`.
- Si `cloudflared` no conecta, revisa que `CLOUDFLARED_TUNNEL_TOKEN` sea válido y que el hostname del túnel apunte al servicio `http://pikadash:5001`.
