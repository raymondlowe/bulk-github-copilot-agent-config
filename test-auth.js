#!/usr/bin/env node

// Simple test script to verify GitHub authentication improvements
const path = require('path');
const { GitHubCLI } = require(path.join(__dirname, 'dist/github/cli'));

async function testAuthToken() {
  try {
    console.log('🔍 Testing GitHub CLI token extraction...');
    
    const token = await GitHubCLI.getAuthToken();
    console.log('✅ Token retrieved successfully');
    console.log(`   Token length: ${token.length} characters`);
    console.log(`   Token prefix: ${token.substring(0, 7)}...`);
    
  } catch (error) {
    console.log('❌ Token extraction failed:', error.message);
    
    // This is expected if not authenticated
    if (error.message.includes('not authenticated')) {
      console.log('ℹ️  This is expected if GitHub CLI is not authenticated');
      console.log('   Run "gh auth login" to authenticate');
      return true; // This is an expected outcome
    }
    return false;
  }
  return true;
}

testAuthToken().then(success => {
  if (success) {
    console.log('✅ Authentication test completed successfully');
  } else {
    console.log('❌ Authentication test failed');
    process.exit(1);
  }
});