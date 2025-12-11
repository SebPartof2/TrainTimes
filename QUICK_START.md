# Quick Start Guide

## The Problem You Encountered

The CORS error you saw:
```
Access to fetch at 'https://schedules.metrarail.com/gtfs/schedule.zip' from origin 'http://localhost:8098' has been blocked by CORS policy
```

This happens because browsers block web apps from making requests to external sites for security reasons, and the Metra website doesn't allow cross-origin requests.

## The Solution

We've implemented a **Cloudflare Worker** that acts as a proxy to solve this issue. Here's how to set it up:

---

## Local Development (Quick Test)

### Option 1: Use a CORS Browser Extension (Fastest)

1. Install a CORS extension for your browser:
   - **Chrome**: "CORS Unblock" or "Allow CORS"
   - **Firefox**: "CORS Everywhere"

2. Enable the extension

3. Run your app:
   ```bash
   flutter run -d chrome
   ```

4. Click "Load Stations" - it should work now!

**Note**: This only works on your local machine and is NOT suitable for deployment.

### Option 2: Deploy the CORS Proxy (Recommended)

This works for both development and production.

---

## Deploy to Cloudflare (Recommended - 10 minutes)

### Step 1: Deploy the Worker (CORS Proxy)

```bash
# Install Wrangler CLI
npm install -g wrangler

# Login to Cloudflare (free account works)
cd cloudflare-worker
wrangler login

# Deploy the worker
npm install
npm run deploy
```

You'll get a URL like: `https://train-times-proxy.YOUR-USERNAME.workers.dev`

**Copy this URL!**

### Step 2: Configure Your App

Edit `lib/main.dart` line 12:

```dart
// Change from:
const String? kCorsProxyUrl = null;

// To (use your actual worker URL):
const String? kCorsProxyUrl = 'https://train-times-proxy.YOUR-USERNAME.workers.dev';
```

### Step 3: Test Locally

```bash
flutter run -d chrome
```

Click "Load Stations" - it should work!

### Step 4: Deploy to Cloudflare Pages

```bash
# Build the app
flutter build web --release --web-renderer html

# Deploy to Cloudflare Pages
cd build/web
wrangler pages deploy . --project-name=train-times
```

Your app will be live at: `https://train-times.pages.dev`

---

## Alternative: Deploy via Git (Auto-updates)

1. **Push to GitHub:**
   ```bash
   git add .
   git commit -m "Initial commit"
   git push origin main
   ```

2. **Connect to Cloudflare Pages:**
   - Go to https://dash.cloudflare.com/
   - Click "Workers & Pages" → "Create application" → "Pages"
   - Connect to your GitHub repository
   - Build command: `flutter build web --release --web-renderer html`
   - Build output: `build/web`
   - Click "Save and Deploy"

Now every time you push to GitHub, your app automatically updates!

---

## Troubleshooting

### "Identifier 'styles' has already been declared"
This is a Flutter framework warning that can be ignored. If it persists:
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### CORS Errors Still Happening
1. Make sure you updated `kCorsProxyUrl` in [lib/main.dart](lib/main.dart:12)
2. Verify your worker is deployed: visit the worker URL in your browser
3. Check the browser console for the actual error

### Worker Not Deploying
```bash
# Make sure you're logged in
wrangler whoami

# If not logged in
wrangler login

# Try deploying again
cd cloudflare-worker
npm run deploy
```

---

## Next Steps

1. **Add More Cities**: Edit [lib/config/cities_config.dart](lib/config/cities_config.dart)
2. **Customize UI**: Edit [lib/main.dart](lib/main.dart)
3. **Add Routes**: Extend the GTFS parser to read routes.txt
4. **Real-time Data**: Integrate GTFS-RT feeds

---

## Full Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Complete deployment guide
- [README.md](README.md) - Full project documentation
- [cloudflare-worker/README.md](cloudflare-worker/README.md) - Worker documentation

---

## Costs

**Everything is FREE** (generous free tiers):
- Cloudflare Workers: 100,000 requests/day
- Cloudflare Pages: 500 builds/month, unlimited bandwidth
- Perfect for personal projects and small-scale apps!
