# Train Times CORS Proxy Worker

This Cloudflare Worker acts as a CORS proxy to allow the Train Times web app to fetch GTFS data from transit agencies that don't enable CORS.

## Quick Start

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Login to Cloudflare:**
   ```bash
   npx wrangler login
   ```

3. **Deploy:**
   ```bash
   npm run deploy
   ```

4. **Copy the worker URL** and update it in `lib/main.dart`:
   ```dart
   const String? kCorsProxyUrl = 'https://train-times-proxy.your-username.workers.dev';
   ```

## How It Works

The worker receives requests with a `url` query parameter and:
1. Validates the URL is a GTFS feed
2. Fetches the data from the transit agency
3. Adds CORS headers to the response
4. Returns the data to the browser

## Usage

Request format:
```
https://your-worker.workers.dev?url=https://schedules.metrarail.com/gtfs/schedule.zip
```

## Development

Test locally:
```bash
npm run dev
```

View logs:
```bash
npm run tail
```

## Configuration

Edit `wrangler.toml` to customize:
- Worker name
- Routes
- Environment variables

## Security

For production, consider:
- Whitelisting allowed GTFS URLs
- Adding rate limiting
- Restricting allowed origins
