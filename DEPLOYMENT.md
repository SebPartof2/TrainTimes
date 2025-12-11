# Deployment Guide - Cloudflare Pages & Workers

This guide will help you deploy the Train Times app to Cloudflare Pages with a CORS proxy worker.

## Prerequisites

- A Cloudflare account (free tier works fine)
- Node.js installed (for Wrangler CLI)
- Flutter SDK installed
- Git repository (GitHub, GitLab, etc.)

## Part 1: Deploy the Cloudflare Worker (CORS Proxy)

The worker acts as a proxy to solve CORS issues when fetching GTFS data.

### Step 1: Install Wrangler CLI

```bash
npm install -g wrangler
```

### Step 2: Login to Cloudflare

```bash
wrangler login
```

This will open a browser window to authenticate.

### Step 3: Deploy the Worker

```bash
cd cloudflare-worker
wrangler deploy
```

After deployment, you'll see output like:
```
Published train-times-proxy (0.01 sec)
  https://train-times-proxy.your-username.workers.dev
```

**Copy this URL** - you'll need it in the next step!

### Step 4: Test the Worker

Test that your worker is working:

```bash
curl "https://train-times-proxy.your-username.workers.dev?url=https://schedules.metrarail.com/gtfs/schedule.zip" -I
```

You should see CORS headers in the response:
```
Access-Control-Allow-Origin: *
```

## Part 2: Configure the Flutter App

### Step 1: Update the CORS Proxy URL

Edit [lib/main.dart](lib/main.dart) and update line 12:

```dart
// Replace null with your worker URL
const String? kCorsProxyUrl = 'https://train-times-proxy.your-username.workers.dev';
```

### Step 2: Build the Flutter Web App

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for web with release mode
flutter build web --release --web-renderer html
```

The build output will be in `build/web/`

## Part 3: Deploy to Cloudflare Pages

You have two options: Git integration (recommended) or Direct upload.

### Option A: Git Integration (Recommended)

1. **Push your code to GitHub/GitLab**
   ```bash
   git add .
   git commit -m "Ready for deployment"
   git push origin main
   ```

2. **Create a Cloudflare Pages Project**
   - Go to https://dash.cloudflare.com/
   - Click "Workers & Pages" in the sidebar
   - Click "Create application" → "Pages" → "Connect to Git"
   - Authenticate with GitHub/GitLab
   - Select your repository

3. **Configure Build Settings**
   - Framework preset: **None**
   - Build command: `flutter build web --release --web-renderer html`
   - Build output directory: `build/web`
   - Root directory: `/` (leave empty)

4. **Environment Variables**
   Click "Add variable" and add:
   - Name: `FLUTTER_BUILD_MODE`
   - Value: `release`

5. **Deploy**
   - Click "Save and Deploy"
   - Wait for the build to complete (3-5 minutes)
   - Your app will be live at `https://your-project.pages.dev`

### Option B: Direct Upload (Quick Test)

1. **Build the app** (if not already done)
   ```bash
   flutter build web --release --web-renderer html
   ```

2. **Install Wrangler** (if not installed)
   ```bash
   npm install -g wrangler
   ```

3. **Deploy**
   ```bash
   cd build/web
   wrangler pages deploy . --project-name=train-times
   ```

4. Your app will be live at `https://train-times.pages.dev`

## Part 4: Custom Domain (Optional)

1. Go to your Pages project in Cloudflare Dashboard
2. Click "Custom domains"
3. Click "Set up a custom domain"
4. Enter your domain (e.g., `trains.yourdomain.com`)
5. Follow the DNS configuration instructions
6. SSL certificate will be automatically provisioned

## Part 5: Updating Your App

### Git Integration Method
Just push to your repository:
```bash
git add .
git commit -m "Update app"
git push origin main
```
Cloudflare Pages will automatically rebuild and deploy.

### Direct Upload Method
```bash
flutter build web --release --web-renderer html
cd build/web
wrangler pages deploy . --project-name=train-times
```

## Troubleshooting

### CORS Errors Persist
- Make sure you updated `kCorsProxyUrl` in [lib/main.dart](lib/main.dart)
- Verify your worker is deployed and accessible
- Check browser console for the actual error

### Build Fails on Cloudflare Pages
- Make sure Flutter SDK is available in the build environment
- Try using the Direct Upload method instead
- Check build logs in Cloudflare Dashboard

### App Loads But No Stations
- Click "Load Stations" button
- Check browser console for errors
- Verify the GTFS URL is accessible
- Test your worker directly with curl

### Worker Not Working
```bash
# View worker logs
wrangler tail train-times-proxy

# Then load your app and watch for requests
```

## Performance Tips

1. **Enable Caching**
   The worker already includes 1-hour cache headers. GTFS data doesn't change frequently.

2. **Use HTML Renderer**
   We're using `--web-renderer html` which has better compatibility and smaller bundle size.

3. **Optimize Build**
   ```bash
   flutter build web --release --web-renderer html --tree-shake-icons
   ```

## Cost

Both Cloudflare Pages and Workers have generous free tiers:

- **Pages**: 500 builds/month, unlimited bandwidth
- **Workers**: 100,000 requests/day

This should be more than enough for a personal or small-scale deployment.

## Security Considerations

The current worker allows any GTFS URL. For production, consider:

1. Whitelist specific GTFS URLs in the worker
2. Add rate limiting
3. Use environment variables for allowed origins

Example worker update:
```javascript
const ALLOWED_URLS = [
  'https://schedules.metrarail.com/gtfs/schedule.zip',
  // Add more as needed
];

if (!ALLOWED_URLS.some(allowed => targetUrl.startsWith(allowed))) {
  return new Response('URL not allowed', { status: 403 });
}
```

## Next Steps

- Add more cities and agencies in [lib/config/cities_config.dart](lib/config/cities_config.dart)
- Monitor usage in Cloudflare Dashboard
- Set up analytics with Cloudflare Web Analytics (free)
