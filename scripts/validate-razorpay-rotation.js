#!/usr/bin/env node

/**
 * ============================================================================
 * Razorpay Key Rotation Validator
 * ============================================================================
 *
 * This script validates that the Razorpay key rotation was successful.
 * Run this BEFORE deployment to catch any issues.
 *
 * Usage:
 *   node scripts/validate-razorpay-rotation.js
 *
 * It will:
 * 1. Load environment variables from .env files
 * 2. Validate credential formats
 * 3. Verify secrets are different
 * 4. Check for common issues
 * 5. Generate a validation report
 */

const fs = require('fs');
const path = require('path');

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function success(message) {
  log(`✓ ${message}`, 'green');
}

function error(message) {
  log(`✗ ${message}`, 'red');
}

function warning(message) {
  log(`⚠ ${message}`, 'yellow');
}

function info(message) {
  log(`ℹ ${message}`, 'blue');
}

// ============================================================================

class RazorpayValidator {
  constructor() {
    this.results = {
      passed: [],
      failed: [],
      warnings: []
    };
    this.credentials = {
      development: null,
      production: null
    };
  }

  /**
   * Load environment variables from .env files
   */
  loadEnvironments() {
    info('Loading environment files...');

    const projectRoot = path.resolve(__dirname, '..');
    const envFiles = {
      development: path.join(projectRoot, '.env.development'),
      production: path.join(projectRoot, '.env.production')
    };

    for (const [env, filePath] of Object.entries(envFiles)) {
      if (!fs.existsSync(filePath)) {
        warning(`${env} .env file not found at ${filePath}`);
        continue;
      }

      try {
        const content = fs.readFileSync(filePath, 'utf-8');
        const lines = content.split('\n');
        const vars = {};

        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed || trimmed.startsWith('#')) continue;

          const [key, value] = trimmed.split('=');
          if (key && value) {
            vars[key.trim()] = value.trim();
          }
        }

        this.credentials[env] = vars;
        success(`Loaded ${env} environment`);
      } catch (err) {
        error(`Failed to load ${env}: ${err.message}`);
      }
    }
  }

  /**
   * Validate a single credential set
   */
  validateCredentialSet(env, credentials) {
    info(`\nValidating ${env} credentials...`);

    if (!credentials) {
      error(`No ${env} credentials loaded`);
      return false;
    }

    const keyId = credentials.RAZORPAY_KEY_ID;
    const keySecret = credentials.RAZORPAY_KEY_SECRET;
    const webhookSecret = credentials.RAZORPAY_WEBHOOK_SECRET;

    let isValid = true;

    // Check existence
    if (!keyId) {
      error(`${env}: RAZORPAY_KEY_ID is missing`);
      isValid = false;
    } else {
      success(`${env}: RAZORPAY_KEY_ID present`);
      this.results.passed.push(`${env}: KEY_ID exists`);
    }

    if (!keySecret) {
      error(`${env}: RAZORPAY_KEY_SECRET is missing`);
      isValid = false;
    } else {
      success(`${env}: RAZORPAY_KEY_SECRET present`);
      this.results.passed.push(`${env}: KEY_SECRET exists`);
    }

    if (!webhookSecret) {
      error(`${env}: RAZORPAY_WEBHOOK_SECRET is missing`);
      isValid = false;
    } else {
      success(`${env}: RAZORPAY_WEBHOOK_SECRET present`);
      this.results.passed.push(`${env}: WEBHOOK_SECRET exists`);
    }

    // Validate formats
    if (env === 'production' && keyId && !keyId.startsWith('rzp_live_')) {
      error(`${env}: KEY_ID should start with 'rzp_live_' for production`);
      isValid = false;
    } else if (env === 'production' && keyId) {
      success(`${env}: KEY_ID format correct (rzp_live_)`);
      this.results.passed.push(`${env}: KEY_ID format valid`);
    }

    if (env === 'development' && keyId && !keyId.startsWith('rzp_test_')) {
      warning(`${env}: KEY_ID should start with 'rzp_test_' for testing`);
      this.results.warnings.push(`${env}: KEY_ID format (should be rzp_test_)`);
    } else if (env === 'development' && keyId) {
      success(`${env}: KEY_ID format correct (rzp_test_)`);
      this.results.passed.push(`${env}: KEY_ID format valid`);
    }

    // Validate length
    if (keySecret && keySecret.length < 20) {
      error(`${env}: KEY_SECRET too short (${keySecret.length} chars, min 20)`);
      isValid = false;
    } else if (keySecret) {
      success(`${env}: KEY_SECRET length valid (${keySecret.length} chars)`);
      this.results.passed.push(`${env}: KEY_SECRET length valid`);
    }

    if (webhookSecret && webhookSecret.length < 20) {
      error(`${env}: WEBHOOK_SECRET too short (${webhookSecret.length} chars, min 20)`);
      isValid = false;
    } else if (webhookSecret) {
      success(`${env}: WEBHOOK_SECRET length valid (${webhookSecret.length} chars)`);
      this.results.passed.push(`${env}: WEBHOOK_SECRET length valid`);
    }

    // CRITICAL: Verify they are different
    if (keySecret && webhookSecret && keySecret === webhookSecret) {
      error(`${env}: CRITICAL SECURITY ERROR - KEY_SECRET equals WEBHOOK_SECRET!`);
      this.results.failed.push(`${env}: KEY_SECRET must differ from WEBHOOK_SECRET`);
      isValid = false;
    } else if (keySecret && webhookSecret) {
      success(`${env}: KEY_SECRET and WEBHOOK_SECRET are DIFFERENT ✓`);
      this.results.passed.push(`${env}: Secrets are different`);
    }

    // Check for placeholder values
    if (keySecret && (keySecret.includes('xxx') || keySecret.includes('XXXXX'))) {
      warning(`${env}: KEY_SECRET appears to be a placeholder`);
      this.results.warnings.push(`${env}: KEY_SECRET is placeholder`);
    }

    if (webhookSecret && (webhookSecret.includes('xxx') || webhookSecret.includes('XXXXX'))) {
      warning(`${env}: WEBHOOK_SECRET appears to be a placeholder`);
      this.results.warnings.push(`${env}: WEBHOOK_SECRET is placeholder`);
    }

    return isValid;
  }

  /**
   * Check for leaked secrets in git history
   */
  checkGitHistory() {
    info('\nChecking git history for leaked secrets...');

    const projectRoot = path.resolve(__dirname, '..');
    const gitDir = path.join(projectRoot, '.git');

    if (!fs.existsSync(gitDir)) {
      warning('Not a git repository, skipping history check');
      return;
    }

    try {
      const { execSync } = require('child_process');

      // Search for credential patterns in recent commits
      const patterns = [
        'rzp_live_',
        'RAZORPAY_KEY_SECRET',
        'RAZORPAY_WEBHOOK_SECRET'
      ];

      let foundSecrets = false;

      for (const pattern of patterns) {
        try {
          const result = execSync(`git log -p --all -S "${pattern}" | head -5`, {
            cwd: projectRoot,
            encoding: 'utf-8'
          });

          if (result.trim()) {
            warning(`Potential leaked secret pattern found: ${pattern}`);
            this.results.warnings.push(`Git history: Pattern '${pattern}' found`);
            foundSecrets = true;
          }
        } catch (e) {
          // Pattern not found, which is good
        }
      }

      if (!foundSecrets) {
        success('Git history: No leaked secrets detected ✓');
        this.results.passed.push('Git history: Clean');
      }
    } catch (err) {
      warning(`Git history check skipped: ${err.message}`);
    }
  }

  /**
   * Validate .env.example files (should not contain real secrets)
   */
  checkExampleFiles() {
    info('\nChecking .env.example files...');

    const projectRoot = path.resolve(__dirname, '..');
    const exampleFiles = [
      path.join(projectRoot, '.env.example'),
      path.join(projectRoot, 'backend', '.env.example')
    ];

    for (const filePath of exampleFiles) {
      if (!fs.existsSync(filePath)) {
        warning(`Example file not found: ${filePath}`);
        continue;
      }

      try {
        const content = fs.readFileSync(filePath, 'utf-8');
        const hasRealSecret = /rzp_live_|rzp_test_[^_]/.test(content) &&
                              !content.includes('xxxxx') &&
                              !content.includes('XXXXX');

        if (hasRealSecret) {
          error(`${path.basename(filePath)}: Contains real credentials!`);
          this.results.failed.push(`Example file contains real secrets: ${filePath}`);
        } else {
          success(`${path.basename(filePath)}: Contains only placeholders`);
          this.results.passed.push(`Example file: ${path.basename(filePath)} safe`);
        }
      } catch (err) {
        error(`Failed to check example file: ${err.message}`);
      }
    }
  }

  /**
   * Check .gitignore configuration
   */
  checkGitIgnore() {
    info('\nChecking .gitignore configuration...');

    const projectRoot = path.resolve(__dirname, '..');
    const gitIgnorePath = path.join(projectRoot, '.gitignore');

    if (!fs.existsSync(gitIgnorePath)) {
      error('.gitignore file not found');
      this.results.failed.push('No .gitignore file');
      return;
    }

    try {
      const content = fs.readFileSync(gitIgnorePath, 'utf-8');
      const lines = content.split('\n');

      const shouldIgnore = ['.env', '.env.local', '.env.production.local'];
      let allIgnored = true;

      for (const pattern of shouldIgnore) {
        if (lines.some(line => line.trim() === pattern || line.trim().startsWith(pattern + ' '))) {
          success(`.gitignore: Contains '${pattern}'`);
          this.results.passed.push(`Gitignore: ${pattern} ignored`);
        } else {
          warning(`.gitignore: Missing '${pattern}' pattern`);
          this.results.warnings.push(`Gitignore: ${pattern} not found`);
          allIgnored = false;
        }
      }
    } catch (err) {
      error(`Failed to check .gitignore: ${err.message}`);
    }
  }

  /**
   * Generate final report
   */
  generateReport() {
    console.log('\n' + '='.repeat(70));
    info('RAZORPAY KEY ROTATION VALIDATION REPORT');
    console.log('='.repeat(70) + '\n');

    // Summary
    const totalPassed = this.results.passed.length;
    const totalFailed = this.results.failed.length;
    const totalWarnings = this.results.warnings.length;

    log(`Results: `, 'cyan');
    log(`  Passed:  ${totalPassed}`, 'green');
    log(`  Failed:  ${totalFailed}`, totalFailed > 0 ? 'red' : 'green');
    log(`  Warnings: ${totalWarnings}`, totalWarnings > 0 ? 'yellow' : 'green');

    // Details
    if (this.results.failed.length > 0) {
      console.log('\n' + colors.red + 'FAILURES:' + colors.reset);
      for (const item of this.results.failed) {
        error(`  - ${item}`);
      }
    }

    if (this.results.warnings.length > 0) {
      console.log('\n' + colors.yellow + 'WARNINGS:' + colors.reset);
      for (const item of this.results.warnings) {
        warning(`  - ${item}`);
      }
    }

    if (this.results.passed.length > 0) {
      console.log('\n' + colors.green + 'PASSED CHECKS:' + colors.reset);
      for (const item of this.results.passed.slice(0, 10)) {
        success(`  - ${item}`);
      }
      if (this.results.passed.length > 10) {
        log(`  ... and ${this.results.passed.length - 10} more`, 'cyan');
      }
    }

    // Overall status
    console.log('\n' + '='.repeat(70));
    if (totalFailed === 0) {
      success('VALIDATION PASSED - Ready for deployment ✓');
      console.log('='.repeat(70) + '\n');
      return true;
    } else {
      error('VALIDATION FAILED - Fix issues before deployment');
      console.log('='.repeat(70) + '\n');
      return false;
    }
  }

  /**
   * Run all validations
   */
  run() {
    console.log('\n');
    log('Razorpay Key Rotation Validator v1.0', 'cyan');
    console.log('='.repeat(70) + '\n');

    this.loadEnvironments();
    this.validateCredentialSet('development', this.credentials.development);
    this.validateCredentialSet('production', this.credentials.production);
    this.checkExampleFiles();
    this.checkGitIgnore();
    this.checkGitHistory();

    const success = this.generateReport();
    process.exit(success ? 0 : 1);
  }
}

// ============================================================================
// Run validator
// ============================================================================

const validator = new RazorpayValidator();
validator.run();
