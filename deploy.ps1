# Train Times Deployment Script
# Usage: .\deploy.ps1 [command]

param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

# Configuration - Update these for your repo
$GITHUB_USER = "SebPartof2"
$REPO_NAME = "TrainTimes"

function Show-Help {
    Write-Host "Available commands:" -ForegroundColor Cyan
    Write-Host "  .\deploy.ps1 install        - Install Flutter dependencies"
    Write-Host "  .\deploy.ps1 dev            - Run development server"
    Write-Host "  .\deploy.ps1 build          - Build Flutter web app"
    Write-Host "  .\deploy.ps1 deploy         - Build and deploy to Cloudflare Pages"
    Write-Host "  .\deploy.ps1 deploy-worker  - Deploy CORS proxy worker"
    Write-Host "  .\deploy.ps1 deploy-all     - Deploy both worker and app"
    Write-Host "  .\deploy.ps1 clean          - Clean build files"
    Write-Host "  .\deploy.ps1 quick          - Quick deploy without clean"
}

function Install-Dependencies {
    Write-Host "Installing Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get
    Write-Host "✅ Dependencies installed!" -ForegroundColor Green
}

function Start-Dev {
    Write-Host "Starting development server..." -ForegroundColor Yellow
    flutter run -d chrome
}

function Build-App {
    Write-Host "Building Flutter web app for GitHub Pages..." -ForegroundColor Yellow
    flutter clean
    flutter pub get
    flutter build web --release --base-href="/$REPO_NAME/"
    Write-Host "✅ Build complete! Output: build\web" -ForegroundColor Green
}

function Deploy-App {
    Build-App
    Write-Host "Deploying to GitHub Pages..." -ForegroundColor Yellow

    $originalLocation = Get-Location
    Set-Location build\web

    git init
    git add .
    git commit -m "Deploy to GitHub Pages"
    git branch -M gh-pages
    git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
    git push -f origin gh-pages

    Set-Location $originalLocation

    Write-Host "✅ Deployed to https://$GITHUB_USER.github.io/$REPO_NAME/" -ForegroundColor Green
    Write-Host "Don't forget to enable GitHub Pages in your repo settings!" -ForegroundColor Cyan
}

function Deploy-Worker {
    Write-Host "Deploying CORS proxy worker..." -ForegroundColor Yellow
    Set-Location cloudflare-worker
    npm install
    npm run deploy
    Set-Location ..
    Write-Host "✅ Worker deployed!" -ForegroundColor Green
}

function Deploy-All {
    Deploy-Worker
    Deploy-App
    Write-Host "✅ All deployments complete!" -ForegroundColor Green
}

function Clean-Build {
    Write-Host "Cleaning build files..." -ForegroundColor Yellow
    flutter clean
    if (Test-Path build) {
        Remove-Item -Recurse -Force build
    }
    Write-Host "✅ Clean complete!" -ForegroundColor Green
}

function Quick-Deploy {
    Write-Host "Quick building..." -ForegroundColor Yellow
    flutter build web --release
    Write-Host "Quick deploying..." -ForegroundColor Yellow
    Set-Location build\web
    npx wrangler pages deploy . --project-name=train-times
    Set-Location ..\..
    Write-Host "✅ Quick deploy complete!" -ForegroundColor Green
}

# Command routing
switch ($Command.ToLower()) {
    "help" { Show-Help }
    "install" { Install-Dependencies }
    "dev" { Start-Dev }
    "build" { Build-App }
    "deploy" { Deploy-App }
    "deploy-worker" { Deploy-Worker }
    "deploy-all" { Deploy-All }
    "clean" { Clean-Build }
    "quick" { Quick-Deploy }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Show-Help
    }
}
