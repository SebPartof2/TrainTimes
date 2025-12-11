.PHONY: help build deploy clean run install deploy-worker deploy-all dev deploy-gh-pages

# Configuration - Update these for your repo
GITHUB_USER := SebPartof2
REPO_NAME := TrainTimes

# Default target
help:
	@echo "Available commands:"
	@echo "  make install        - Install Flutter dependencies"
	@echo "  make dev            - Run development server"
	@echo "  make build          - Build Flutter web app for production"
	@echo "  make deploy         - Build and deploy to GitHub Pages"
	@echo "  make deploy-worker  - Deploy CORS proxy worker"
	@echo "  make deploy-all     - Deploy both worker and app"
	@echo "  make clean          - Clean build files"
	@echo "  make run            - Run app in Chrome"

# Install dependencies
install:
	flutter pub get

# Run development server
dev:
	flutter run -d chrome

# Run app in Chrome (alias)
run:
	flutter run -d chrome

# Build for production (GitHub Pages)
build:
	@echo "Building Flutter web app for GitHub Pages..."
	flutter clean
	flutter pub get
	flutter build web --release --base-href="/$(REPO_NAME)/"
	@echo "✅ Build complete! Output: build/web"

# Deploy to GitHub Pages
deploy: build
	@echo "Deploying to GitHub Pages..."
	@cd build/web && \
	git init && \
	git add . && \
	git commit -m "Deploy to GitHub Pages" && \
	git branch -M gh-pages && \
	git remote add origin https://github.com/$(GITHUB_USER)/$(REPO_NAME).git && \
	git push -f origin gh-pages
	@echo "✅ Deployed to https://$(GITHUB_USER).github.io/$(REPO_NAME)/"
	@echo "Don't forget to enable GitHub Pages in your repo settings!"

# Deploy worker
deploy-worker:
	@echo "Deploying CORS proxy worker..."
	cd cloudflare-worker && npm install && npm run deploy
	@echo "✅ Worker deployed!"

# Deploy everything
deploy-all: deploy-worker deploy
	@echo "✅ All deployments complete!"

# Clean build files
clean:
	@echo "Cleaning build files..."
	flutter clean
	rm -rf build/
	@echo "✅ Clean complete!"

# Quick rebuild without clean
quick-build:
	@echo "Quick building..."
	flutter build web --release
	@echo "✅ Quick build complete!"

# Quick deploy without full rebuild
quick-deploy:
	@echo "Quick deploying..."
	cd build/web && npx wrangler pages deploy . --project-name=train-times
	@echo "✅ Quick deploy complete!"

# Full pipeline: clean, build, deploy
pipeline: clean build deploy
	@echo "✅ Full pipeline complete!"
