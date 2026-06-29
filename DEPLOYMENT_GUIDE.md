# Backend Deployment Guide - Git Push to VPS

## Quick Start: How to Deploy

```bash
# 1. Make changes locally
git add .
git commit -m "feat: add order service"

# 2. Push to GitHub
git push origin main

# 3. GitHub Actions automatically:
#    - Runs tests
#    - Builds Docker image
#    - Deploys to VPS
#    - No manual steps needed!
```

---

## VPS Setup (One-time)

### Step 1: Provision VPS
```bash
# Rent from: DigitalOcean, Linode, AWS EC2, Vultr, etc.
# Requirements:
# - Ubuntu 22.04 LTS
# - 2GB RAM minimum
# - 20GB storage
# - Public IP address
# - SSH access

# Example: DigitalOcean Droplet
# - Size: Basic ($12/month)
# - OS: Ubuntu 22.04 x64
# - Datacenter: Bangalore (closest to India)
```

### Step 2: Install Docker & Docker Compose
```bash
ssh root@YOUR_VPS_IP

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify
docker --version
docker-compose --version
```

### Step 3: Create Deployment User
```bash
# Create user (not root)
useradd -m -s /bin/bash deployer
usermod -aG docker deployer

# Set up SSH key
sudo -u deployer mkdir -p /home/deployer/.ssh
# Copy your public key into /home/deployer/.ssh/authorized_keys
chmod 700 /home/deployer/.ssh
chmod 600 /home/deployer/.ssh/authorized_keys
```

### Step 4: Create App Directory
```bash
ssh deployer@YOUR_VPS_IP

# Create app folder
mkdir -p /home/deployer/fufaji-backend
cd /home/deployer/fufaji-backend

# Create .env file (manually, with secrets from GitHub Actions)
cat > .env << 'EOF'
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_KEY=xxx
FIREBASE_PROJECT_ID=xxx
RAZORPAY_KEY_ID=xxx
RAZORPAY_KEY_SECRET=xxx
RAZORPAY_WEBHOOK_SECRET=xxx
DB_PASSWORD=xxx
ENVIRONMENT=production
EOF

chmod 600 .env
```

---

## GitHub Actions Setup (One-time)

### Step 1: Generate SSH Key for Deployment
```bash
# On your local machine (or VPS user's machine)
ssh-keygen -t ed25519 -f deploy_key -C "github-actions-deployer"

# This creates:
# - deploy_key (private key - goes to GitHub)
# - deploy_key.pub (public key - already on VPS)
```

### Step 2: Add SSH Key to GitHub Secrets
```bash
# In GitHub repo: Settings → Secrets and variables → Actions

# Add new secret: DEPLOY_SSH_KEY
# Paste the contents of deploy_key (private key)

# Add new secret: DEPLOY_HOST
# Value: YOUR_VPS_IP

# Add new secret: DEPLOY_USER
# Value: deployer

# Add new secret: DEPLOY_PATH
# Value: /home/deployer/fufaji-backend
```

### Step 3: Add Other Secrets to GitHub Actions
```bash
# Settings → Secrets and variables → Actions
# Add all environment variables as secrets:

SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx
FIREBASE_PROJECT_ID=xxx
RAZORPAY_KEY_ID=xxx
RAZORPAY_KEY_SECRET=xxx (DO NOT PUT IN REPO)
RAZORPAY_WEBHOOK_SECRET=xxx (DO NOT PUT IN REPO)
DB_PASSWORD=xxx (DO NOT PUT IN REPO)
```

### Step 4: Create GitHub Actions Workflow
Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to VPS

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Dart
      uses: dart-lang/setup-dart@v1
      with:
        sdk: stable
    
    - name: Install dependencies
      run: |
        cd backend
        dart pub get
    
    - name: Analyze
      run: |
        cd backend
        dart analyze
    
    - name: Run tests
      run: |
        cd backend
        dart test

  deploy:
    needs: test-and-build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup SSH
      run: |
        mkdir -p ~/.ssh
        echo "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/deploy_key
        chmod 600 ~/.ssh/deploy_key
        ssh-keyscan -H ${{ secrets.DEPLOY_HOST }} >> ~/.ssh/known_hosts
    
    - name: Deploy to VPS
      run: |
        ssh -i ~/.ssh/deploy_key ${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }} << 'DEPLOY_SCRIPT'
          set -e
          
          # Stop old container
          cd ${{ secrets.DEPLOY_PATH }}
          docker-compose down || true
          
          # Pull latest code
          git pull origin main
          
          # Set environment variables from GitHub Secrets
          cat > .env << EOF
        SUPABASE_URL=${{ secrets.SUPABASE_URL }}
        SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
        FIREBASE_PROJECT_ID=${{ secrets.FIREBASE_PROJECT_ID }}
        RAZORPAY_KEY_ID=${{ secrets.RAZORPAY_KEY_ID }}
        RAZORPAY_KEY_SECRET=${{ secrets.RAZORPAY_KEY_SECRET }}
        RAZORPAY_WEBHOOK_SECRET=${{ secrets.RAZORPAY_WEBHOOK_SECRET }}
        DB_PASSWORD=${{ secrets.DB_PASSWORD }}
        ENVIRONMENT=production
        EOF
          
          # Build and start
          docker-compose build
          docker-compose up -d
          
          # Wait for health check
          sleep 10
          curl -f http://localhost:8080/health || exit 1
          
          echo "✅ Deployment successful"
        DEPLOY_SCRIPT
    
    - name: Notify Slack
      if: always()
      uses: slackapi/slack-github-action@v1
      with:
        webhook-url: ${{ secrets.SLACK_WEBHOOK }}
        payload: |
          {
            "text": "Backend deployment ${{ job.status }}",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "Backend Deploy: ${{ job.status }}\n${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
                }
              }
            ]
          }
```

---

## File Structure on VPS

```bash
/home/deployer/fufaji-backend/
├── docker-compose.yml
├── Dockerfile
├── bin/
├── lib/
├── db/
├── pubspec.yaml
├── pubspec.lock
├── .env                          # NEVER commit this
├── .env.example                  # Template for CI/CD
├── .github/workflows/
│   └── deploy.yml
└── docker-logs/
    └── backend.log
```

---

## Manual VPS Commands

```bash
# Connect to VPS
ssh deployer@YOUR_VPS_IP

# Check running containers
cd /home/deployer/fufaji-backend
docker-compose ps

# View logs
docker-compose logs -f backend

# Stop backend
docker-compose down

# Rebuild from scratch
docker-compose build --no-cache

# Start fresh
docker-compose up -d

# Check health
curl http://localhost:8080/health

# Check database connection
curl http://localhost:8080/admin/db-check
```

---

## Database Migrations on VPS

### Method 1: Auto-migrate on startup (recommended)
In `bin/server.dart`:
```dart
void main() async {
  // Run migrations automatically
  await Database().runMigrations();
  
  // Start server
  var app = shelf.Router();
  // ... setup routes
  
  var server = await shelf_io.serve(app, '0.0.0.0', 8080);
  print('Listening on http://localhost:${server.port}');
}
```

### Method 2: Manual migration
```bash
# SSH into VPS
ssh deployer@YOUR_VPS_IP
cd /home/deployer/fufaji-backend

# Run migration tool
docker-compose exec backend dart run migrate.dart --version latest
```

---

## Troubleshooting

### Docker build fails
```bash
# Check Docker daemon
sudo systemctl status docker

# Free up space
docker system prune -a

# Rebuild with output
docker-compose build --no-cache --progress=plain
```

### Container won't start
```bash
# Check logs
docker-compose logs backend

# Check environment variables
docker-compose config

# Verify .env file exists
ls -la /home/deployer/fufaji-backend/.env
```

### Database connection fails
```bash
# Test Supabase credentials
curl -H "apikey: YOUR_ANON_KEY" https://xxx.supabase.co/rest/v1/

# Check Firestore credentials
# Download JSON from Firebase Console
```

### Port 8080 already in use
```bash
# Find process using port
lsof -i :8080

# Kill it
kill -9 <PID>

# Or use different port in docker-compose.yml
ports:
  - "9000:8080"
```

---

## Production Checklist

Before going live:

- [ ] Secrets rotated (Razorpay, Firebase, DB password)
- [ ] `.env` file is NOT in git
- [ ] All GitHub Actions secrets set
- [ ] Deploy SSH key added to GitHub
- [ ] VPS firewall allows port 8080/443
- [ ] SSL certificate configured (use Let's Encrypt)
- [ ] Database backups scheduled
- [ ] Monitoring/alerting configured
- [ ] Load balancer (if expecting >1000 req/s)
- [ ] Rate limiting enabled on API
- [ ] CORS configured for app domain

---

## Day-1 Operations

### Check deployment
```bash
ssh deployer@YOUR_VPS_IP
docker-compose logs backend | tail -20
curl http://localhost:8080/health
```

### Monitor
```bash
# Watch logs in real-time
docker-compose logs -f backend

# Check CPU/memory
docker stats
```

### Rollback (if something breaks)
```bash
# Revert to previous commit
git revert HEAD --no-edit
git push

# GitHub Actions will auto-deploy old version
# Wait 2-3 minutes for CI/CD to complete
```

---

## Environment Variables Reference

```
# Supabase (PostgreSQL database)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_public_key_xxxx
SUPABASE_SERVICE_KEY=your_service_key_xxxx (for migrations only)

# Firebase (Authentication + Firestore)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your_private_key_json
FIREBASE_CLIENT_EMAIL=your-email@project.iam.gserviceaccount.com

# Razorpay (Payments)
RAZORPAY_KEY_ID=rzp_live_xxxxx (public)
RAZORPAY_KEY_SECRET=rz_key_secret_xxxxx (secret - use GitHub Actions)
RAZORPAY_WEBHOOK_SECRET=rz_webhook_secret_xxxxx (DIFFERENT from key_secret!)

# Database
DB_PASSWORD=your_secure_password

# Server
ENVIRONMENT=production
PORT=8080
LOG_LEVEL=info
```

---

## Git Push → Production Flow

```
1. git commit -m "feat: add order service"
2. git push origin main
   ↓
3. GitHub receives push to main branch
   ↓
4. GitHub Actions workflow triggers
   ├─ Run: dart analyze
   ├─ Run: dart test
   └─ If tests pass → Build Docker image
   ↓
5. SSH into VPS (using DEPLOY_SSH_KEY secret)
   ├─ git pull origin main
   ├─ Copy secrets from GitHub Actions into .env
   ├─ docker-compose build
   ├─ docker-compose up -d
   └─ Verify health check passes
   ↓
6. Slack notification: "✅ Deployment successful"
   ↓
7. Live! Production is updated.

Total time: ~3 minutes
```

---

## Cost Estimate

| Service | Cost/Month | Notes |
|---------|-----------|-------|
| VPS (DigitalOcean) | $12 | 2GB RAM, Ubuntu 22.04 |
| Supabase (Postgres) | Free-$50 | Free tier = 500MB database |
| Firebase (Firestore) | Free-$25 | Free tier = 1GB storage |
| Domain (optional) | $5-15 | For SSL certificate |
| **Total** | **~$30-50** | Very affordable |

---

**That's it!** Your backend will auto-deploy on every git push. 🚀
