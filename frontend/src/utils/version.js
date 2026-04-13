// =============================================================================
// Auto Versioning Utility
// Handles automatic UI versioning and cache busting
// =============================================================================

// Get current version from package.json
const getVersion = () => {
  return process.env.REACT_APP_VERSION || 
         process.env.npm_package_version || 
         '1.0.0-' + Date.now();
};

// Generate cache-busting query string
const getCacheBuster = () => {
  const version = getVersion();
  return `?v=${version}`;
};

// Add cache busting to URLs
const addVersionToUrl = (url) => {
  if (!url) return url;
  
  // Skip external URLs and data URLs
  if (url.startsWith('http') || url.startsWith('data:')) {
    return url;
  }
  
  const separator = url.includes('?') ? '&' : '?';
  return `${url}${separator}v=${getVersion()}`;
};

// Auto-reload detection
let lastVersion = null;
const checkForUpdates = () => {
  const currentVersion = getVersion();
  
  if (lastVersion && lastVersion !== currentVersion) {
    console.log('🔄 Version changed, reloading UI...');
    window.location.reload();
  }
  
  lastVersion = currentVersion;
};

// Initialize version checking
const initVersionChecking = (intervalMs = 5000) => {
  // Check for version updates periodically
  setInterval(checkForUpdates, intervalMs);
  
  // Listen for storage events (cross-tab sync)
  window.addEventListener('storage', (e) => {
    if (e.key === 'app-version') {
      checkForUpdates();
    }
  });
  
  // Store current version
  localStorage.setItem('app-version', getVersion());
};

// Force UI refresh
const forceRefresh = () => {
  const timestamp = Date.now();
  localStorage.setItem('app-version', timestamp);
  window.location.reload();
};

// Get build info
const getBuildInfo = () => {
  return {
    version: getVersion(),
    buildTime: process.env.REACT_APP_BUILD_TIME || new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    cacheBuster: getCacheBuster()
  };
};

export {
  getVersion,
  getCacheBuster,
  addVersionToUrl,
  initVersionChecking,
  forceRefresh,
  getBuildInfo
};
